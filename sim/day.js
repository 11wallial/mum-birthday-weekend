// One trading day: the walk, the queue, the till, the exit.
//
// Resolution note. The ruleset describes customers entering one at a time.
// Every value a customer ends the walk with is a pure function of (type, aisle,
// wallet), and Basket is linear in wallet, so resolving once per (aisle, type)
// at the mean wallet gives the same expected profit as walking thousands of
// individuals. That is what makes 100k runs tractable. `exact: true` walks
// individuals instead and is used by verify.js to confirm the two agree.

import {
  aisleHoldsRarity,
  fixtureInstances,
  marginPenaltyFromStaff,
  rentFor,
  shopHoldsTag,
  totalSlots,
} from './shop.js';

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

// ---------------------------------------------------------------------------
// Rule fixtures and boss effects collapse into one flags object per day.
// ---------------------------------------------------------------------------

export function collectFlags(content, shop, ctx) {
  const boss = ctx.boss || null;
  const f = {
    noSkip: shop.structural.has('one_way_barriers'),
    throughputBonus: 0,
    throughputCap: Infinity,
    tillDelta: 0,
    footfallCap: Infinity,
    footfallMul: 1,
    footfallAdd: 0,
    basketFixed: null,
    basketMul: 1,
    marginSet: null,
    marginFlat: 0,
    patienceBonus: 0,
    patienceMul: 1,
    shoplifterBecomes: null,
    blockShoplifters: false,
    conversionCertain: false,
    pensionerConvMul: 1,
    buyersReturn: 0,
    unsoldToFootfall: 0,
    walkoutsToFootfall: false,
    onlyTypesConvert: null,
    disableBasketAdditive: false,
    globalEffects: [],
    disabled: new Set(),
    closedAisle: -1,
    rentMul: 1,
    poolOverride: null,
  };

  // Staff, shop-wide
  for (const s of shop.staff) {
    if (s.def.effect === 'block_shoplifters') f.blockShoplifters = true;
    if (s.def.effect === 'patience') f.patienceBonus += s.def.value;
  }
  // Wide Aisle raises Patience on the aisle it was bought for, not shop-wide,
  // so it is applied at purchase time as an aisle property.
  if (shop.structural.has('second_entrance')) f.footfallAdd += 40;

  // --- boss effects (section 15) -------------------------------------------
  if (boss) {
    switch (boss.effect) {
      case 'footfall_multiply': f.footfallMul *= boss.value; break;
      case 'basket_multiply_patience_multiply':
        f.basketMul *= boss.value[0]; f.patienceMul *= boss.value[1]; break;
      case 'only_types_convert': f.onlyTypesConvert = new Set(boss.value); break;
      case 'health_inspection': break; // handled per fixture below
      case 'disable_unstaffed': break;
      case 'footfall_multiply_till_disable':
        f.footfallMul *= boss.value[0]; f.tillDelta -= boss.value[1]; break;
      case 'disable_term_class': f.disableBasketAdditive = true; break;
      case 'margin_halved_unless_staffed_aisles': break;
      case 'footfall_multiply_margin_flat':
        f.footfallMul *= boss.value[0]; f.marginFlat += boss.value[1]; break;
      // Which aisle closes is rolled once per encounter in run.js: resolveDay
      // must stay free of RNG, because policies call it hundreds of times.
      case 'close_aisle': f.closedAisle = ctx.closedAisle ?? 0; break;
      case 'force_pool': f.poolOverride = boss.value; break;
      case 'pool_blend': f.poolBlend = { pool: boss.value, blend: boss.blend }; break;
      case 'rent_multiply': f.rentMul *= boss.value; break;
      case 'disable_rarity': break;
      default: break;
    }
  }

  const placed = fixtureInstances(shop);

  // Fixture disabling, before any rule fixture is read.
  if (boss && boss.effect === 'disable_unstaffed') {
    for (const { inst } of placed) if (!inst.staff) f.disabled.add(inst);
  }
  if (boss && boss.effect === 'disable_rarity') {
    for (const { inst } of placed) {
      if (inst.def.rarity === boss.value) f.disabled.add(inst);
    }
  }
  if (ctx.auditMods && ctx.auditMods.flagshipTwoDayCondition) {
    // Audit VI: a flagship must have met its condition yesterday too.
    for (const { inst } of placed) {
      if (inst.def.rarity === 'flagship' && !shop.flagshipHeldYesterday) f.disabled.add(inst);
    }
  }

  const fixtureCount = placed.length;

  for (const { inst } of placed) {
    if (f.disabled.has(inst)) continue;
    const def = inst.def;
    const L = inst.level - 1;

    // Multiplicative fixtures whose levelling widens scope to the whole shop.
    if (def.breadth && def.breadth.check === 'scope_widen'
        && def.breadth.value[L] === 'shop') {
      f.globalEffects.push({ inst, def });
    }

    if (def.effect.op !== 'rule') continue;
    const v = def.effect.value[L];
    const d = def.drawback ? def.drawback.value[L] : null;

    switch (def.effect.rule) {
      case 'shoplifters_become_browsers':
        f.shoplifterBecomes = inst.level >= 3 ? 'family' : 'browser';
        f.marginFlat -= d;
        break;
      case 'no_skip':
        f.noSkip = true;
        f.patienceBonus += d;
        break;
      case 'throughput':
        f.throughputBonus += v;
        f.pensionerConvMul *= 1 - d;
        break;
      case 'unsold_to_footfall':
        f.unsoldToFootfall = Math.max(f.unsoldToFootfall, v);
        if (inst.level >= 3) f.walkoutsToFootfall = true;
        break;
      case 'buyers_return':
        f.buyersReturn = Math.max(f.buyersReturn, d);
        break;
      case 'conversion_certain':
        f.conversionCertain = true;
        f.footfallCap = Math.min(f.footfallCap, d);
        break;
      case 'footfall_multiply_flat_basket':
        f.footfallMul *= v;
        f.basketFixed = d;
        break;
      case 'basket_multiply_single_till':
        f.basketMul *= v;
        f.throughputCap = Math.min(f.throughputCap, d);
        break;
      case 'margin_set':
        // A commitment: it only holds while the shop stays small enough.
        if (fixtureCount <= d) f.marginSet = v;
        break;
      default: break;
    }
  }

  // Mystery Shopper: Margin halved unless every aisle holds a staffed fixture.
  if (boss && boss.effect === 'margin_halved_unless_staffed_aisles') {
    const ok = shop.aisles.every((a) =>
      a.closed || a.slots.some((i) => i && i.staff));
    if (!ok) f.marginHalved = true;
  }
  return f;
}

// ---------------------------------------------------------------------------
// The walk
// ---------------------------------------------------------------------------

function conditionsHold(content, shop, def, inst, aisleIdx, type) {
  const L = inst.level - 1;
  for (const c of def.trigger.conditions || []) {
    switch (c.check) {
      case 'customer_type_in': {
        const list = def.breadth && def.breadth.check === 'customer_type_in'
          ? def.breadth.value[L]
          : c.value;
        if (!list.includes(type.id)) return false;
        break;
      }
      case 'aisle_holds_no_rarity':
        if (aisleHoldsRarity(shop, aisleIdx, c.value)) return false;
        break;
      case 'shop_holds_no_tag':
        if (shopHoldsTag(shop, c.value)) return false;
        break;
      case 'wallet_at_least':
        return false; // no starter fixture uses this; see README on wallet linearity
      default: break;
    }
  }
  return true;
}

/**
 * Walk one aisle as one customer type. Returns their personal terms at the till.
 */
export function walkAisle(content, shop, aisleIdx, type, flags, baseMargin) {
  const aisle = shop.aisles[aisleIdx];
  const passChance = flags.noSkip ? 1 : content.economy.slots.basePassChance;

  // Wallet is what a customer is willing to spend, so it scales a real basket.
  // A Shoplifter's loss is the value of what they walk out with, not a wallet.
  const walletScale = type.sign === 'positive' ? content.walletMean : 1;
  const terms = {
    conversion: type.conversion,
    basket: type.basket * walletScale * flags.basketMul,
    margin: baseMargin + type.marginDelta,
    patience: (type.patienceTicks + aisle.patienceBonus + flags.patienceBonus)
      * flags.patienceMul,
  };
  if (flags.basketFixed != null) terms.basket = flags.basketFixed;
  if (shop.flags.basketFixed != null) terms.basket = shop.flags.basketFixed;
  if (shop.flags.basketMultiplier) terms.basket *= shop.flags.basketMultiplier;

  const amps = []; // { term, mult, from, to }

  const apply = (term, op, value, p, strength) => {
    if (term === 'footfall' || term === 'none') return;
    if (op === 'add') {
      let amp = 1;
      for (const a of amps) if (a.term === term) amp *= a.mult;
      terms[term] += p * value * strength * amp;
    } else if (op === 'multiply') {
      const m = 1 + (value - 1) * strength;
      terms[term] *= 1 + p * (m - 1);
    }
  };

  for (let i = 0; i < aisle.slots.length; i++) {
    // Expire amplifiers that no longer cover this slot.
    for (let k = amps.length - 1; k >= 0; k--) {
      if (i < amps[k].from || i > amps[k].to) amps.splice(k, 1);
    }

    const inst = aisle.slots[i];
    if (!inst || flags.disabled.has(inst)) continue;
    const def = inst.def;
    const L = inst.level - 1;
    const scope = def.trigger.scope;
    if (scope === 'shop' || scope === 'exit') continue;
    if (!conditionsHold(content, shop, def, inst, aisleIdx, type)) continue;
    if (flags.disableBasketAdditive && def.class === 'additive' && def.term === 'basket') {
      continue;
    }

    // Staff attach to fixtures, not to the shop (section 12).
    let p = passChance;
    let strength = 1;
    let times = 1;
    if (inst.staff === 'assistant') times = 2;
    if (inst.staff === 'manager') { p = 1; strength = 0.5; }
    // Levelled scope_widen fixtures stop caring whether you walked past them.
    if (def.breadth && def.breadth.check === 'scope_widen') {
      const w = def.breadth.value[L];
      if (w === 'aisle' || w === 'shop') p = 1;
    }

    if (scope === 'next_slots') {
      const count = def.trigger.count[L];
      const from = inst.level >= 3 ? i : i + 1;
      const mult = 1 + (def.effect.value[L] - 1) * strength;
      amps.push({ term: def.term, mult: 1 + p * (mult - 1), from, to: i + count });
      continue;
    }

    for (let t = 0; t < times; t++) {
      apply(def.term, def.effect.op, def.effect.value[L], p, strength);
      // L3 clauses: a visible new clause rather than a bigger number.
      if (inst.level >= 3) {
        if (def.id === 'sample_table') apply('conversion', 'add', 0.05, p, strength);
        if (def.id === 'greeter') apply('patience', 'add', 2, p, strength);
        if (def.id === 'own_brand') apply('basket', 'add', -2, p, strength);
        if (def.id === 'bargain_bin' && (type.id === 'family' || type.id === 'student')) {
          apply('conversion', 'add', 0.1, p, strength);
        }
      }
    }
  }

  // Fixtures whose levelling widened them to the whole shop fire last.
  for (const { inst, def } of flags.globalEffects) {
    if (aisle.slots.includes(inst)) continue; // already applied during the walk
    if (!conditionsHold(content, shop, def, inst, aisleIdx, type)) continue;
    apply(def.term, def.effect.op, def.effect.value[inst.level - 1], 1, 1);
  }

  if (flags.conversionCertain) terms.conversion = 1;
  if (flags.marginSet != null) terms.margin = flags.marginSet;
  if (shop.flags.marginFixed != null) terms.margin = shop.flags.marginFixed;
  if (flags.marginHalved) terms.margin *= 0.5;
  terms.margin += flags.marginFlat;
  if (type.id === 'pensioner') terms.conversion *= flags.pensionerConvMul;
  if (flags.onlyTypesConvert && !flags.onlyTypesConvert.has(type.id)) terms.conversion = 0;

  terms.conversion = clamp(terms.conversion, 0, 1);
  terms.margin = clamp(terms.margin, -1, 0.95);
  terms.patience = Math.max(0, terms.patience);
  if (type.sign === 'positive') terms.basket = Math.max(0, terms.basket);
  return terms;
}

// ---------------------------------------------------------------------------
// The queue. Tills are hand size; Footfall above throughput is walkouts.
// ---------------------------------------------------------------------------

export function runQueue(arrivals, capacity, ticks, patience) {
  const K = arrivals.length;
  const served = new Float64Array(K);
  const walkouts = new Float64Array(K);
  let total = 0;
  for (let k = 0; k < K; k++) total += arrivals[k];
  if (total <= 0) return { served, walkouts };

  // Under capacity there is never a queue, which is the overwhelmingly common
  // case in a well-built shop, so skip the tick loop entirely.
  if (total <= capacity * ticks * 0.999) {
    const lambda = total / ticks;
    if (lambda <= capacity) {
      for (let k = 0; k < K; k++) served[k] = arrivals[k];
      return { served, walkouts };
    }
  }

  const perTick = new Float64Array(ticks * K);
  for (let k = 0; k < K; k++) {
    const rate = arrivals[k] / ticks;
    for (let t = 0; t < ticks; t++) perTick[t * K + k] = rate;
  }

  const headExp = new Int32Array(K);
  let headServe = 0;

  for (let t = 0; t < ticks; t++) {
    // Patience drains while waiting; at zero it is a walkout.
    for (let k = 0; k < K; k++) {
      const horizon = t - patience[k];
      while (headExp[k] <= horizon && headExp[k] <= t) {
        const idx = headExp[k] * K + k;
        walkouts[k] += perTick[idx];
        perTick[idx] = 0;
        headExp[k]++;
      }
    }

    let cap = capacity;
    while (cap > 1e-9 && headServe <= t) {
      let cohort = 0;
      const base = headServe * K;
      for (let k = 0; k < K; k++) cohort += perTick[base + k];
      if (cohort <= 1e-9) { headServe++; continue; }
      const take = Math.min(cap, cohort);
      const frac = take / cohort;
      for (let k = 0; k < K; k++) {
        const s = perTick[base + k] * frac;
        served[k] += s;
        perTick[base + k] -= s;
      }
      cap -= take;
      if (frac >= 1 - 1e-12) headServe++;
    }
  }

  // Anyone still holding at close is a walkout.
  for (let t = headServe; t < ticks; t++) {
    for (let k = 0; k < K; k++) walkouts[k] += perTick[t * K + k];
  }
  return { served, walkouts };
}

// ---------------------------------------------------------------------------
// The day
// ---------------------------------------------------------------------------

export function resolveDay(content, shop, ctx = {}) {
  const flags = collectFlags(content, shop, ctx);
  const auditMods = ctx.auditMods || {};
  const types = content.types;
  const K = types.length;

  const openAisles = [];
  for (let a = 0; a < shop.aisles.length; a++) {
    if (!shop.aisles[a].closed && a !== flags.closedAisle) openAisles.push(a);
  }
  if (openAisles.length === 0) openAisles.push(0);

  // --- Footfall -------------------------------------------------------------
  let footfall = shop.baseFootfall + shop.carryFootfall;
  if (shop.flags.footfallMultiplier) footfall *= shop.flags.footfallMultiplier;
  for (let a = 0; a < shop.aisles.length; a++) {
    for (const inst of shop.aisles[a].slots) {
      if (!inst || flags.disabled.has(inst)) continue;
      const def = inst.def;
      if (def.term !== 'footfall' || def.trigger.scope !== 'shop') continue;
      const v = def.effect.value[inst.level - 1];
      if (def.effect.op === 'add') footfall += v;
      else if (def.effect.op === 'multiply') footfall *= v;
      if (def.id === 'loss_leader') {
        flags.marginFlat += def.drawback.value[inst.level - 1];
      }
    }
  }
  footfall += flags.footfallAdd;
  footfall *= flags.footfallMul;
  footfall = Math.min(footfall, flags.footfallCap);
  if (shop.flags.footfallOverride) {
    const [lo, hi] = shop.flags.footfallOverride;
    footfall = (lo + hi) / 2;
  }
  footfall = Math.max(0, footfall);

  // --- Base margin ----------------------------------------------------------
  let baseMargin = content.economy.start.margin;
  if (shop.flags.marginBonus) baseMargin += shop.flags.marginBonus;
  baseMargin -= marginPenaltyFromStaff(shop);

  // --- Pool -----------------------------------------------------------------
  let pool = flags.poolOverride || shop.flags.forcedPool || shop.pool;
  if (flags.poolBlend) {
    // Blend rather than replace, so a pool-editing boss shifts the mix instead
    // of removing every buyer from the shop.
    const { pool: bp, blend } = flags.poolBlend;
    const norm = (p) => {
      let s = 0;
      for (const t of types) s += p[t.id] || 0;
      return s || 1;
    };
    const a = norm(pool); const b = norm(bp);
    const mixed = {};
    for (const t of types) {
      mixed[t.id] = ((pool[t.id] || 0) / a) * (1 - blend) + ((bp[t.id] || 0) / b) * blend;
    }
    pool = mixed;
  }
  let poolTotal = 0;
  for (const t of types) poolTotal += pool[t.id] || 0;
  if (poolTotal <= 0) poolTotal = 1;

  const arrivals = new Float64Array(K);
  for (const t of types) {
    let share = (pool[t.id] || 0) / poolTotal;
    let n = footfall * share;
    if (t.id === 'shoplifter' && (flags.blockShoplifters || flags.shoplifterBecomes)) {
      const target = flags.blockShoplifters ? null : flags.shoplifterBecomes;
      if (target) arrivals[content.typeIndex.get(target)] += n;
      n = 0;
    }
    arrivals[t.index] += n;
  }

  const traversals = shop.flags.traversals || 1;

  // --- The walk, once per (aisle, type) ------------------------------------
  // A customer type can be split across aisles (Tourists ignore signage), so a
  // type becomes one or more segments. Averaging the four terms across aisles
  // and then multiplying would understate profit for the same reason the
  // projection panel cannot multiply pool averages: the terms are correlated,
  // and a stocked aisle is better on all four at once.
  const segments = []; // { k, aisle, share, terms }
  const routed = []; // per type: share-weighted patience, for the queue
  for (const t of types) {
    const k = t.index;
    // Shoplifters never shop, so nothing on the floor touches them. Only
    // Security and Security Tag, which are handled in the pool above.
    if (t.special === 'steals') {
      const terms = { conversion: 0, basket: t.basket, margin: 0, patience: 0 };
      segments.push({ k, aisle: 0, share: 1, terms });
      routed.push({ terms });
      continue;
    }
    let aisle = shop.signage[t.id];
    if (aisle == null || !openAisles.includes(aisle)) aisle = openAisles[0];

    const lanes = t.routing === 'random' ? openAisles : [aisle];
    const share = 1 / lanes.length;
    let patience = 0;
    for (const a of lanes) {
      const terms = walkAisle(content, shop, a, t, flags, baseMargin);
      segments.push({ k, aisle: a, share, terms });
      patience += terms.patience * share;
    }
    routed.push({ terms: { patience } });
  }

  // --- Queue ---------------------------------------------------------------
  const shoplifterIdx = content.typeIndex.get('shoplifter');
  const queueArrivals = new Float64Array(K);
  for (let k = 0; k < K; k++) {
    queueArrivals[k] = k === shoplifterIdx ? 0 : arrivals[k] * traversals;
  }

  const maxAisleLen = Math.max(...openAisles.map((a) => shop.aisles[a].slots.length));
  const ticks = Math.max(
    10,
    Math.round(content.economy.day.ticks - maxAisleLen * content.economy.day.walkTicksPerSlot),
  );
  let capacity = (shop.tills + flags.tillDelta) * content.economy.day.tillRate
    + flags.throughputBonus;
  capacity = Math.min(capacity, flags.throughputCap);
  capacity = Math.max(0.0001, capacity);

  const patience = new Float64Array(K);
  for (let k = 0; k < K; k++) patience[k] = Math.max(0, routed[k].terms.patience);

  let { served, walkouts } = shop.flags.noQueue
    ? { served: queueArrivals, walkouts: new Float64Array(K) }
    : runQueue(queueArrivals, capacity, ticks, patience);

  // --- Till ----------------------------------------------------------------
  let sales = 0;
  let revenue = 0;
  let saleProfit = 0;
  let shrink = 0;
  let refunds = 0;
  let unsold = 0;
  let wTotal = 0;
  let returnVisits = 0;
  // Pool averages of the four terms, kept only to show how badly they lie.
  let aConv = 0; let aBasket = 0; let aMargin = 0;

  for (const seg of segments) {
    const t = types[seg.k];
    const { terms, share } = seg;
    if (t.id === 'shoplifter') {
      shrink += arrivals[seg.k] * share * terms.basket; // basket is a flat loss
      continue;
    }
    if (t.id === 'returner') {
      refunds += served[seg.k] * share * shop.lastAvgSaleProfit;
      continue;
    }
    const seen = served[seg.k] * share;
    const s = seen * terms.conversion;
    sales += s;
    unsold += seen - s;
    revenue += s * terms.basket;
    saleProfit += s * terms.basket * terms.margin;
    aConv += seen * terms.conversion;
    aBasket += seen * terms.basket;
    aMargin += seen * terms.margin;
    wTotal += seen;
  }
  let profit = saleProfit + shrink - refunds;

  // Loyalty Card: buyers come back once more the same day.
  if (flags.buyersReturn > 0) {
    for (const seg of segments) {
      const t = types[seg.k];
      if (t.sign !== 'positive') continue;
      const terms = seg.terms;
      const back = served[seg.k] * seg.share * terms.conversion;
      returnVisits += back; // they walk back in, so they are Footfall again
      const extra = back * terms.conversion * flags.buyersReturn;
      sales += extra;
      revenue += extra * terms.basket;
      saleProfit += extra * terms.basket * terms.margin;
      profit += extra * terms.basket * terms.margin;
    }
  }

  const totalWalkouts = walkouts.reduce((a, b) => a + b, 0);
  const rent = rentFor(content, shop, auditMods) * flags.rentMul;
  profit -= rent;
  profit -= shop.marketingUpkeep || 0; // marketing persists and costs upkeep

  // --- Tomorrow -------------------------------------------------------------
  const wcfg = content.economy.walkouts;
  let carry = 0;
  if (flags.unsoldToFootfall > 0) carry += unsold * flags.unsoldToFootfall;
  if (flags.walkoutsToFootfall) carry += totalWalkouts;
  else {
    // Capped: an uncapped penalty lets one bad boss day zero Footfall, and a
    // zero in any of the four terms is an unrecoverable run.
    const penalty = totalWalkouts * wcfg.footfallPenaltyPerWalkout;
    carry -= Math.min(penalty, shop.baseFootfall * (wcfg.maxPenaltyShare ?? 1));
  }

  // The projection panel (section 17). The four terms are chained funnel
  // ratios, not pool averages, so Footfall x Conversion x Basket x Margin
  // multiplies out to exactly the trading profit before costs. Pool averages
  // do not: Conversion and Basket are strongly negatively correlated across
  // customer types, so their product overstates. See sim/README.md.
  // Footfall for the panel counts presentations at the till, so a Loyalty Card
  // return and a Corner Shop re-traverse are extra Footfall rather than
  // Conversion above 100%, which would make the panel unreadable.
  let visits = returnVisits;
  for (let k = 0; k < K; k++) visits += queueArrivals[k];

  const panel = {
    footfall: Math.round(visits),
    conversion: visits > 0 ? sales / visits : 0,
    basket: sales > 0 ? revenue / sales : 0,
    margin: revenue > 0 ? saleProfit / revenue : 0,
    trading: saleProfit,
    rent,
    shrink,
    refunds,
    upkeep: shop.marketingUpkeep || 0,
    naive: wTotal > 0
      ? footfall * (aConv / wTotal) * (aBasket / wTotal) * (aMargin / wTotal)
      : 0,
  };

  return {
    profit,
    rent,
    revenue,
    saleProfit,
    shrink,
    footfall,
    served: wTotal,
    sales,
    walkouts: totalWalkouts,
    walkoutRate: footfall > 0 ? totalWalkouts / (footfall * traversals) : 0,
    avgSaleProfit: sales > 0 ? saleProfit / sales : 0,
    carry,
    panel,
    flags,
  };
}
