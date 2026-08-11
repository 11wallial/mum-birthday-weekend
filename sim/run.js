// A full run: eight quarters, three trading days each, 24 encounters.
// Every third day is a boss. Miss a target and the run is over.

import { makeRng } from './rng.js';
import { auditModifiers } from './content.js';
import { resolveDay } from './day.js';
import {
  addFixture, autoSign, createShop, emptySlots, fixtureInstances, ownedIds, totalSlots,
} from './shop.js';
import {
  makeOffer, rerollCost, rollFixture, supplierUpgradeCost, tillCost,
} from './offers.js';
import { policies } from './policies.js';

const STAFF_SINGLETON = new Set(['security', 'buyer', 'cleaner']);

function costOf(content, shop, opt, auditMods) {
  if (opt === 'till') return tillCost(content, shop);
  if (opt === 'tier') return supplierUpgradeCost(content, shop, auditMods);
  if (opt.startsWith('staff:')) return 0; // wages cost Margin, not cash
  if (opt.startsWith('struct:')) {
    const id = opt.slice(7);
    const def = content.economy.structural.find((s) => s.id === id);
    const mul = shop.flags.structuralCostMultiplier;
    return def.cost * (mul == null ? 1 : mul);
  }
  if (opt.startsWith('marketing:')) {
    const id = opt.slice(10);
    return content.campaigns.find((c) => c.id === id).cost;
  }
  return Infinity;
}

function applyBuy(content, shop, opt, real, rng, auditMods) {
  const cost = costOf(content, shop, opt, auditMods);
  if (!isFinite(cost) || shop.cash < cost) return false;
  shop.cash -= cost;

  if (opt === 'till') { shop.tills += 1; return true; }

  if (opt === 'tier') {
    shop.supplierTier += 1;
    // Upgrading grants an immediate free pick from the newly unlocked band.
    if (real && content.economy.supplierTier.freePickOnUpgrade) {
      const fx = rollFixture(content, shop, rng);
      addFixture(content, shop, fx.id, emptySlots(shop)[0] || null);
    }
    return true;
  }

  if (opt.startsWith('staff:')) {
    const body = opt.slice(6);
    const [id, where] = body.split('@');
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

  if (opt.startsWith('struct:')) {
    const id = opt.slice(7);
    const def = content.economy.structural.find((s) => s.id === id);
    switch (def.effect) {
      case 'add_slot': {
        const shortest = shop.aisles.reduce((a, b) => (a.slots.length <= b.slots.length ? a : b));
        shortest.slots.push(null);
        break;
      }
      case 'add_aisle':
        shop.aisles.push({
          slots: new Array(def.slots).fill(null),
          closed: false,
          patienceBonus: 0,
          restrictTypes: def.restrictTypes || null,
        });
        break;
      case 'aisle_patience':
        shop.aisles[0].patienceBonus += def.value;
        break;
      default:
        break;
    }
    shop.structural.add(id);
    return true;
  }

  if (opt.startsWith('marketing:')) {
    const id = opt.slice(10);
    const c = content.campaigns.find((x) => x.id === id);
    for (const [k, v] of Object.entries(c.add || {})) shop.pool[k] = (shop.pool[k] || 0) + v;
    for (const [k, v] of Object.entries(c.remove || {})) {
      shop.pool[k] = Math.max(0, (shop.pool[k] || 0) - v);
    }
    shop.marketing.push(id);
    shop.marketingUpkeep = (shop.marketingUpkeep || 0) + c.upkeep;
    return true;
  }
  return false;
}

function affordableOptions(content, shop, auditMods) {
  const out = [];
  if (shop.cash >= tillCost(content, shop)) out.push('till');
  if (shop.cash >= supplierUpgradeCost(content, shop, auditMods)) out.push('tier');

  for (const st of content.economy.staff) {
    if (STAFF_SINGLETON.has(st.id)) {
      if (!shop.staff.some((s) => s.id === st.id)) out.push(`staff:${st.id}`);
    }
  }
  const placed = fixtureInstances(shop)
    .filter(({ inst }) => !inst.staff)
    .sort((a, b) => b.inst.level - a.inst.level)
    .slice(0, 3);
  for (const { aisle, slot } of placed) {
    out.push(`staff:assistant@${aisle},${slot}`);
    out.push(`staff:manager@${aisle},${slot}`);
  }

  for (const s of content.economy.structural) {
    if (s.id === 'extra_till') continue;
    if (!s.repeatable && shop.structural.has(s.id)) continue;
    if (shop.cash >= costOf(content, shop, `struct:${s.id}`, auditMods)) {
      out.push(`struct:${s.id}`);
    }
  }
  // Marketing is a committed identity, not a shopping list: you may hold only
  // a few, so choosing who shops here means giving something else up.
  if (shop.marketing.length < (content.marketingMaxHeld ?? 99)) {
    let mk = 0;
    for (const c of content.campaigns) {
      if (shop.marketing.includes(c.id)) continue;
      if (shop.cash >= c.cost && mk++ < 3) out.push(`marketing:${c.id}`);
    }
  }
  return out;
}

function makeNightContext(content, shop, rng, ctx, target, encounter, record) {
  const pickCount = shop.staff.some((s) => s.id === 'buyer')
    ? 4
    : content.economy.offers.picks;
  let rerolls = 0;
  let offers = makeOffer(content, shop, rng, pickCount);

  const nc = {
    content,
    shop,
    rng,
    ctx,
    target,
    encounter,
    get offers() { return offers; },
    rerollCost: () => rerollCost(content, shop, rerolls, ctx.auditMods),
    reroll() {
      const c = nc.rerollCost();
      if (shop.cash < c) return false;
      shop.cash -= c;
      rerolls++;
      record.rerolls++;
      offers = makeOffer(content, shop, rng, pickCount);
      return true;
    },
    take(fx, placement) {
      const before = shop.bench.length + fixtureInstances(shop).length;
      addFixture(content, shop, fx.id, placement);
      const after = shop.bench.length + fixtureInstances(shop).length;
      const combine = after === before;
      if (combine) record.combines++;
      record.picks.push({
        id: fx.id,
        rarity: fx.rarity,
        tier: shop.supplierTier,
        encounter,
        combine,
        offered: offers.map((o) => ({ id: o.id, rarity: o.rarity })),
      });
    },
    /** Decline the pick and bank the cash instead: a real tempo choice. */
    skip() {
      const pay = content.economy.payout;
      shop.cash += pay.flatBase * Math.pow(pay.flatGrowth, encounter - 1)
        * (pay.skipPickReward || 0);
      record.skips++;
      return true;
    },
    costOf: (opt) => costOf(content, shop, opt, ctx.auditMods),
    affordable: () => affordableOptions(content, shop, ctx.auditMods),
    buy: (opt, s = shop) => applyBuy(content, s, opt, s === shop, rng, ctx.auditMods),
  };
  return nc;
}

/**
 * Ratchets grow once per real trading day. Never during evaluation: policies
 * resolve the day hundreds of times a night and must not advance run state.
 */
function tickRatchets(shop, day, isBoss) {
  for (const { inst } of fixtureInstances(shop)) {
    const def = inst.def;
    if (def.effect.op !== 'ratchet') continue;
    let gain = def.effect.value[inst.level - 1];
    if (def.id === 'range_extension' && inst.level >= 3 && isBoss) gain *= 2;
    inst.ratchet = (inst.ratchet || 0) + gain;
    // Word of Mouth: a day of walkouts sets you back.
    if (def.drawback && def.drawback.id === 'reset_on_walkouts' && day.walkoutRate > 0.1) {
      inst.ratchet *= 1 - def.drawback.value[inst.level - 1];
    }
  }
}

function classifyDeath(day, target) {
  if (day.walkoutRate > 0.2) return 'queue';
  if (day.rent > 0.45 * Math.max(1, day.profit + day.rent)) return 'rent';
  const p = day.panel;
  const norm = {
    footfall: p.footfall / 400,
    conversion: p.conversion / 0.85,
    basket: p.basket / 60,
    margin: p.margin / 0.7,
  };
  return Object.entries(norm).sort((a, b) => a[1] - b[1])[0][0];
}

export function playRun(content, opts = {}) {
  const {
    characterId = "default_shop",
    audit = 1,
    policy: policyName = 'planner',
    seed = 1,
    trace = false,
  } = opts;

  const rng = makeRng(seed);
  const auditMods = auditModifiers(content, audit);
  const policy = policies[policyName];
  const shop = createShop(content, characterId);

  // Starting kit is three fixtures; a character's named kit counts toward it.
  while (ownedIds(shop).size < content.economy.start.startingFixtures) {
    const commons = content.byRarity.common;
    const fx = rng.pick(commons);
    if (ownedIds(shop).has(fx.id)) continue;
    addFixture(content, shop, fx.id);
  }
  autoSign(content, shop);

  const bossEvery = auditMods.bossEvery || content.run.bossEvery;
  const bossDeck = rng.shuffle(content.bosses);
  const bossFor = new Map();

  const record = {
    picks: [], rerolls: 0, combines: 0, tierUpgrades: [], bossesFaced: [],
    bossChoices: [], skips: 0, trace: [],
  };
  let lastQuarter = 0;

  for (let enc = 1; enc <= content.run.encounters; enc++) {
    shop.encounter = enc;
    shop.quarter = Math.ceil(enc / content.run.daysPerQuarter);

    // Audit VIII: one random aisle closes at the start of each quarter.
    if (auditMods.quarterlyAisleClosure && shop.quarter !== lastQuarter) {
      for (const a of shop.aisles) a.closed = false;
      const i = rng.int(shop.aisles.length);
      if (shop.aisles.length > 1) shop.aisles[i].closed = true;
    }
    lastQuarter = shop.quarter;

    // Market Stall: the floor wipes every morning, rebuilt from the owned pool.
    if (shop.flags.wipeFloorNightly) {
      const all = [];
      for (const a of shop.aisles) {
        for (let s = 0; s < a.slots.length; s++) {
          if (a.slots[s]) { all.push(a.slots[s]); a.slots[s] = null; }
        }
      }
      all.push(...shop.bench);
      shop.bench = [];
      for (const inst of all) {
        const slot = emptySlots(shop)[0];
        if (slot) shop.aisles[slot.aisle].slots[slot.slot] = inst;
        else shop.bench.push(inst);
      }
    }

    // Boss choice. Two are offered and the player takes one, revealed a couple
    // of encounters ahead so a build can be aimed at it. Every boss attacks a
    // term, so choosing which term to be attacked on is a read of your own
    // build — and it turns boss variance into a decision.
    const bc = content.economy.bossChoice || { options: 1, revealLead: 0 };
    const future = enc + bc.revealLead;
    if (future <= content.run.encounters && future % bossEvery === 0 && !bossFor.has(future)) {
      const options = [];
      for (let i = 0; i < Math.max(1, bc.options) && bossDeck.length; i++) {
        options.push(bossDeck.splice(rng.int(bossDeck.length), 1)[0]);
      }
      if (options.length) {
        const idx = options.length > 1 && policy.chooseBoss
          ? policy.chooseBoss(content, shop, { auditMods, rng }, options, content.targets[future - 1])
          : 0;
        const chosen = options[Math.min(options.length - 1, Math.max(0, idx))];
        bossFor.set(future, chosen);
        record.bossChoices.push({ enc: future, taken: chosen.id, declined: options.filter((o) => o !== chosen).map((o) => o.id) });
        for (const o of options) if (o !== chosen) bossDeck.push(o); // declined bosses go back
      }
    }
    const boss = enc % bossEvery === 0 ? (bossFor.get(enc) || null) : null;
    if (boss) record.bossesFaced.push(boss.id);
    const target = content.targets[enc - 1] * (auditMods.targetMultiplier || 1);
    const ctx = {
      boss,
      auditMods,
      rng,
      target,
      // Rolled here, once, so resolveDay stays deterministic under repeated
      // policy evaluation.
      closedAisle: boss && boss.effect === 'close_aisle' ? rng.int(shop.aisles.length) : -1,
    };

    autoSign(content, shop); // signage is free to reassign every night
    const tierBefore = shop.supplierTier;
    const nc = makeNightContext(content, shop, rng, ctx, target, enc, record);
    policy.night(nc);
    if (shop.supplierTier > tierBefore) record.tierUpgrades.push(enc);

    const day = resolveDay(content, shop, ctx);

    if (trace) {
      // On a boss day, resolve the same shop again with the boss removed. The
      // ratio is what the boss actually costs, which is what tuning step 7
      // needs; loss share alone is confounded by where the boss landed.
      const clean = boss && opts.measureBossDelta
        ? resolveDay(content, shop, { ...ctx, boss: null }).profit
        : null;
      record.trace.push({
        enc, target, profit: day.profit, cleanProfit: clean, boss: boss ? boss.id : null,
        cash: shop.cash, tier: shop.supplierTier, tills: shop.tills,
        panel: day.panel, walkoutRate: day.walkoutRate,
      });
    }

    if (day.profit < target) {
      return {
        win: false, deathEncounter: enc, deathQuarter: shop.quarter,
        deathCause: classifyDeath(day, target), boss: boss ? boss.id : null,
        target, profit: day.profit, record, shop,
      };
    }

    const pay = content.economy.payout;
    if (pay.mode === 'flat') {
      // Cash decoupled from the target: a predictable reward per encounter plus
      // a capped share of the overshoot. The target is then purely a fail
      // condition and can be tuned for tension without inflating the economy.
      shop.cash += pay.flatBase * Math.pow(pay.flatGrowth, enc - 1)
        + Math.min(pay.overshootCap, (day.profit - target) * pay.overshootShare);
    } else {
      shop.cash += day.profit - target;
    }
    const int = content.economy.interest;
    shop.cash += Math.min(int.cap, shop.cash * int.ratePerEncounter);
    shop.carryFootfall = day.carry;
    shop.lastAvgSaleProfit = day.avgSaleProfit;
    shop.lastTradingProfit = day.saleProfit;
    tickRatchets(shop, day, !!boss);
    shop.flagshipHeldYesterday = fixtureInstances(shop)
      .some(({ inst }) => inst.def.rarity === 'flagship' && !day.flags.disabled.has(inst));
  }

  return {
    win: true, deathEncounter: null, deathQuarter: null, deathCause: null,
    record, shop,
  };
}
