// Run state: eight quarters, three trading days each, 24 encounters.
// The night decisions, and the bookkeeping between days.

import {
  addFixture, auditModifiers, autoSign, createShop, emptySlots, findInstance,
  fixtureInstances, makeOffer, makeRng, ownedIds, rerollCost, rollFixture,
  supplierUpgradeCost, tillCost, resolveDay,
} from './engine.js';

const STAFF_SINGLETON = new Set(['security', 'buyer', 'cleaner']);

export function createRun(content, { characterId = 'default_shop', audit = 1, seed } = {}) {
  const runSeed = seed ?? (Date.now() & 0x7fffffff);
  const rng = makeRng(runSeed);
  const auditMods = auditModifiers(content, audit);
  const shop = createShop(content, characterId);

  while (ownedIds(shop).size < content.economy.start.startingFixtures) {
    const fx = rng.pick(content.byRarity.common);
    if (ownedIds(shop).has(fx.id)) continue;
    addFixture(content, shop, fx.id);
  }
  autoSign(content, shop);

  const bossEvery = auditMods.bossEvery || content.run.bossEvery;
  const bossDeck = rng.shuffle(content.bosses);
  const bossFor = new Map();

  const run = {
    seed: runSeed,
    content,
    shop,
    auditMods,
    audit,
    encounter: 0,
    over: false,
    won: false,
    log: [],
    rng,
    bossEvery,
    pendingBossChoice: null,
    offers: [],
    rerolls: 0,
    picked: false,
  };

  function target(enc) {
    return content.targets[enc - 1] * (auditMods.targetMultiplier || 1);
  }

  function ctx() {
    const boss = run.encounter % bossEvery === 0 ? bossFor.get(run.encounter) || null : null;
    return {
      boss,
      auditMods,
      target: target(run.encounter),
      closedAisle: run.closedAisle ?? -1,
    };
  }

  /** Move to the next encounter and set up the night. */
  function beginNight() {
    run.encounter++;
    if (run.encounter > content.run.encounters) {
      run.over = true;
      run.won = true;
      return;
    }
    shop.encounter = run.encounter;
    shop.quarter = Math.ceil(run.encounter / content.run.daysPerQuarter);

    if (auditMods.quarterlyAisleClosure && run.encounter % content.run.daysPerQuarter === 1) {
      for (const a of shop.aisles) a.closed = false;
      if (shop.aisles.length > 1) shop.aisles[rng.int(shop.aisles.length)].closed = true;
    }
    if (shop.flags.wipeFloorNightly) {
      const all = [];
      for (const a of shop.aisles) {
        for (let s = 0; s < a.slots.length; s++) if (a.slots[s]) { all.push(a.slots[s]); a.slots[s] = null; }
      }
      all.push(...shop.bench);
      shop.bench = [];
      for (const inst of all) {
        const slot = emptySlots(shop)[0];
        if (slot) shop.aisles[slot.aisle].slots[slot.slot] = inst;
        else shop.bench.push(inst);
      }
    }

    // Boss choice, revealed a couple of encounters ahead.
    const bc = content.economy.bossChoice || { options: 1, revealLead: 0 };
    const future = run.encounter + bc.revealLead;
    run.pendingBossChoice = null;
    if (future <= content.run.encounters && future % bossEvery === 0 && !bossFor.has(future)) {
      const options = [];
      for (let i = 0; i < Math.max(1, bc.options) && bossDeck.length; i++) {
        options.push(bossDeck.splice(rng.int(bossDeck.length), 1)[0]);
      }
      if (options.length === 1) bossFor.set(future, options[0]);
      else if (options.length) run.pendingBossChoice = { forEncounter: future, options };
    }

    const boss = run.encounter % bossEvery === 0 ? bossFor.get(run.encounter) || null : null;
    run.closedAisle = boss && boss.effect === 'close_aisle' ? rng.int(shop.aisles.length) : -1;

    run.rerolls = 0;
    run.picked = false;
    run.offers = makeOffer(content, shop, rng, pickCount());
    autoSign(content, shop);
  }

  const pickCount = () => (shop.staff.some((s) => s.id === 'buyer') ? 4 : content.economy.offers.picks);

  function chooseBoss(index) {
    const p = run.pendingBossChoice;
    if (!p) return;
    const taken = p.options[index];
    bossFor.set(p.forEncounter, taken);
    for (const o of p.options) if (o !== taken) bossDeck.push(o); // declined goes back
    run.pendingBossChoice = null;
  }

  function take(fixtureId, placement) {
    if (run.picked) return false;
    const fx = content.fixtureById.get(fixtureId);
    if (!fx || !run.offers.some((o) => o.id === fixtureId)) return false;
    addFixture(content, shop, fixtureId, placement);
    run.picked = true;
    autoSign(content, shop);
    return true;
  }

  function skipPick() {
    if (run.picked) return false;
    const pay = content.economy.payout;
    shop.cash += pay.flatBase * Math.pow(pay.flatGrowth, run.encounter - 1)
      * (pay.skipPickReward || 0);
    run.picked = true;
    return true;
  }

  function reroll() {
    const cost = rerollCost(content, shop, run.rerolls, auditMods);
    if (run.picked || shop.cash < cost) return false;
    shop.cash -= cost;
    run.rerolls++;
    run.offers = makeOffer(content, shop, rng, pickCount());
    return true;
  }
  const currentRerollCost = () => rerollCost(content, shop, run.rerolls, auditMods);

  function costOf(opt) {
    if (opt === 'till') return tillCost(content, shop);
    if (opt === 'tier') return supplierUpgradeCost(content, shop, auditMods);
    if (opt.startsWith('staff:')) return 0; // wages cost Margin, not cash
    if (opt.startsWith('struct:')) {
      const def = content.economy.structural.find((s) => s.id === opt.slice(7));
      const mul = shop.flags.structuralCostMultiplier;
      return def.cost * (mul == null ? 1 : mul);
    }
    if (opt.startsWith('marketing:')) {
      return content.campaigns.find((c) => c.id === opt.slice(10)).cost;
    }
    return Infinity;
  }

  function buy(opt) {
    const cost = costOf(opt);
    if (!Number.isFinite(cost) || shop.cash < cost) return false;

    if (opt.startsWith('staff:')) {
      const [id, where] = opt.slice(6).split('@');
      const def = content.economy.staff.find((s) => s.id === id);
      if (!def) return false;
      if (STAFF_SINGLETON.has(id) && shop.staff.some((s) => s.id === id)) return false;
      let aisle = null; let slot = null;
      if (def.attaches) {
        if (!where) return false;
        [aisle, slot] = where.split(',').map(Number);
        const inst = shop.aisles[aisle] && shop.aisles[aisle].slots[slot];
        if (!inst || inst.staff) return false;
        inst.staff = id;
      }
      shop.staff.push({ id, def, aisle, slot });
      return true;
    }

    shop.cash -= cost;
    if (opt === 'till') { shop.tills += 1; return true; }
    if (opt === 'tier') {
      shop.supplierTier += 1;
      if (content.economy.supplierTier.freePickOnUpgrade) {
        const fx = rollFixture(content, shop, rng);
        addFixture(content, shop, fx.id, emptySlots(shop)[0] || null);
      }
      return true;
    }
    if (opt.startsWith('struct:')) {
      const def = content.economy.structural.find((s) => s.id === opt.slice(7));
      if (def.effect === 'add_slot') {
        shop.aisles.reduce((a, b) => (a.slots.length <= b.slots.length ? a : b)).slots.push(null);
      } else if (def.effect === 'add_aisle') {
        shop.aisles.push({
          slots: new Array(def.slots).fill(null),
          closed: false, patienceBonus: 0, restrictTypes: def.restrictTypes || null,
        });
      } else if (def.effect === 'aisle_patience') {
        shop.aisles[0].patienceBonus += def.value;
      }
      shop.structural.add(def.id);
      autoSign(content, shop);
      return true;
    }
    if (opt.startsWith('marketing:')) {
      const c = content.campaigns.find((x) => x.id === opt.slice(10));
      if (shop.marketing.length >= (content.marketingMaxHeld ?? 99)) { shop.cash += cost; return false; }
      for (const [k, v] of Object.entries(c.add || {})) shop.pool[k] = (shop.pool[k] || 0) + v;
      for (const [k, v] of Object.entries(c.remove || {})) shop.pool[k] = Math.max(0, (shop.pool[k] || 0) - v);
      shop.marketing.push(c.id);
      shop.marketingUpkeep = (shop.marketingUpkeep || 0) + c.upkeep;
      return true;
    }
    return false;
  }

  /** Book a finished trading day and decide whether the run continues. */
  function settle(dayState) {
    const tgt = target(run.encounter);
    const entry = {
      encounter: run.encounter,
      target: tgt,
      profit: dayState.profit,
      trading: dayState.tradingProfit,
      shrink: dayState.shrink,
      rent: dayState.rent,
      upkeep: dayState.upkeep + (dayState.ratchetUpkeep || 0),
      walkouts: dayState.walkouts,
      rescued: dayState.rescued,
      sales: dayState.sales,
      footfall: dayState.footfall,
    };
    run.log.push(entry);

    if (dayState.profit < tgt) {
      run.over = true;
      run.won = false;
      entry.fatal = true;
      return entry;
    }

    const pay = content.economy.payout;
    if (pay.mode === 'flat') {
      shop.cash += pay.flatBase * Math.pow(pay.flatGrowth, run.encounter - 1)
        + Math.min(pay.overshootCap, (dayState.profit - tgt) * pay.overshootShare);
    } else {
      shop.cash += dayState.profit - tgt;
    }
    const int = content.economy.interest;
    const cap = int.capFractionOfTarget != null
      ? Math.max(int.capFloor ?? 0, tgt * int.capFractionOfTarget)
      : int.cap;
    entry.interest = Math.min(cap, shop.cash * int.ratePerEncounter);
    shop.cash += entry.interest;

    shop.carryFootfall = dayState.carry;
    shop.lastAvgSaleProfit = dayState.avgSaleProfit;
    shop.lastTradingProfit = dayState.tradingProfit;
    shop.flagshipHeldYesterday = fixtureInstances(shop)
      .some(({ inst }) => inst.def.rarity === 'flagship');

    // Ratchets grow, and age out of their upkeep, once per real trading day.
    const isBoss = run.encounter % bossEvery === 0;
    for (const { inst } of fixtureInstances(shop)) {
      if (inst.def.effect.op !== 'ratchet') continue;
      let gain = inst.def.effect.value[inst.level - 1];
      const rb = inst.def.ratchetBonus;
      if (rb && inst.level >= rb.minLevel && (rb.when !== 'boss_day' || isBoss)) gain *= rb.multiply;
      inst.ratchet = (inst.ratchet || 0) + gain;
      inst.age = (inst.age || 0) + 1;
      if (inst.def.drawback && inst.def.drawback.id === 'reset_on_walkouts'
          && dayState.walkouts / Math.max(1, dayState.footfall) > 0.1) {
        inst.ratchet *= 1 - inst.def.drawback.value[inst.level - 1];
      }
    }
    return entry;
  }

  const projection = () => resolveDay(content, shop, ctx());
  const boss = () => (run.encounter % bossEvery === 0 ? bossFor.get(run.encounter) || null : null);
  const nextBoss = () => {
    for (let e = run.encounter + 1; e <= content.run.encounters; e++) {
      if (bossFor.has(e)) return { encounter: e, boss: bossFor.get(e) };
    }
    return null;
  };

  return {
    run, shop, ctx, target, beginNight, chooseBoss, take, skipPick, reroll,
    currentRerollCost, buy, costOf, settle, projection, boss, nextBoss, findInstance,
  };
}
