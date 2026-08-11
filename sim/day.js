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
import { isRatchet, isMultiplicative } from './ratchets.js';

export { isRatchet, isMultiplicative };

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

// --- clamping without bias ---------------------------------------------------
// The resolver works in expectations, so a capped term was previously computed
// as min(E[X], cap). That is wrong whenever a build presses against a cap:
// clamping is non-linear, so E[min(X, cap)] < min(E[X], cap), and the error is
// systematic rather than noise. It matters twice over — it inflates every
// measurement, and the policies evaluate candidate boards with this same
// resolver, so they systematically overvalue cap-pressing builds.
//
// The fix is to carry the variance of each capped term alongside its mean and
// integrate the clamp properly. X is a sum of independent per-slot Bernoulli
// contributions, so a normal approximation is good well before the handful of
// fixtures a real aisle holds.
const SQRT2PI = Math.sqrt(2 * Math.PI);
const normalPdf = (z) => Math.exp(-0.5 * z * z) / SQRT2PI;

function normalCdf(z) {
  // Abramowitz and Stegun 7.1.26, accurate to about 1e-7.
  const sign = z < 0 ? -1 : 1;
  const x = Math.abs(z) / Math.SQRT2;
  const t = 1 / (1 + 0.3275911 * x);
  const y = 1 - ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t
    - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x);
  return 0.5 * (1 + sign * y);
}

/** E[min(X, cap)] for X ~ Normal(mu, sd), falling back to a hard min at sd 0. */
export function expectedClamped(mu, variance, cap) {
  const sd = Math.sqrt(Math.max(0, variance));
  if (sd < 1e-9) return Math.min(mu, cap);
  const z = (mu - cap) / sd;
  // E[max(0, X - cap)] for a normal, subtracted from the mean.
  const overflow = sd * normalPdf(z) + (mu - cap) * normalCdf(z);
  return mu - overflow;
}



/**
 * What today's scaling costs you today.
 *
 * A ratchet pays off later, so it has to hurt now — otherwise long-term
 * investment is free and there is no decision to make. Upkeep decays as the
 * fixture matures: steep while it is young and carrying nothing, negligible
 * once it is carrying the run.
 */
export function ratchetCount(shop) {
  let n = 0;
  for (const { inst } of fixtureInstances(shop)) if (isRatchet(inst.def)) n++;
  return n;
}

/**
 * Does this shop clear the commitment threshold? Past it every ratchet is
 * stronger, which is what stops a hedged build from being the safe optimum.
 */
export function commitMultiplier(content, shop) {
  const cfg = content.economy.ratchets;
  if (!cfg || !cfg.commitThreshold) return 1;
  return ratchetCount(shop) >= cfg.commitThreshold ? 1 + cfg.commitBonus : 1;
}

export function ratchetUpkeep(content, shop, target) {
  const cfg = content.economy.ratchets;
  if (!cfg || !target) return 0;
  // Per-fixture upkeep falls as you hold more, so one or two ratchets is the
  // worst place to stand: full price each, and not enough of them to matter.
  const scale = Math.pow(cfg.upkeepScalePerExtra ?? 1, Math.max(0, ratchetCount(shop) - 1));
  let total = 0;
  for (const { inst } of fixtureInstances(shop)) {
    if (!isRatchet(inst.def)) continue;
    // A linear ratchet's upkeep decays as it matures — steep while it carries
    // nothing, negligible once it carries the run. A compounder is the other
    // way round: it is strongest at the end, so a decaying upkeep would make
    // the most powerful class in the pool free exactly when it wins the game.
    // Its upkeep never decays, and because upkeep is quoted against the
    // target, it climbs with the target for the whole run. That permanent,
    // scaling nut is what makes committing to scaling a real risk instead of
    // a free option.
    const compounding = inst.def.effect.op === 'compound';
    const table = compounding ? cfg.upkeepFractionCompound : cfg.upkeepFractionOfTarget;
    const frac = table[inst.def.rarity] ?? 0;
    const decay = compounding ? (cfg.upkeepDecayCompound ?? 1) : cfg.upkeepDecay;
    total += target * frac * scale * Math.pow(decay, inst.age || 0);
  }
  return total;
}

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
    conversionFlat: 0,
    basketFlat: 0,
    shrinkReduce: 0,
    footfallFeedsBasket: 0,
    footfallRatchetTotal: 0,
    ratchetRateMul: 1,
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
      // Refunds land directly on yesterday's trading profit. Returners as a
      // customer type were cut: see data/customers.json.
      case 'refund_previous': f.refundShare = boss.value; break;
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

    // Every drawback is applied here, whatever class carries it. Splitting
    // them between this loop and the Footfall loop is how a double-count
    // starts, and Loss Leader used to be counted in both.
    if (def.drawback) {
      const dv = def.drawback.value[L];
      switch (def.drawback.id) {
        case 'rent_multiplier': f.rentMul *= dv; break;
        case 'margin_flat': f.marginFlat += dv; break;
        case 'throughput_cost': f.throughputBonus -= dv; break;
        case 'conversion_cost': f.conversionFlat -= dv; break;
        case 'basket_flat': f.basketFlat += dv; break;
        default: break;
      }
    }
    if (isRatchet(def) && def.term === 'footfall') {
      f.footfallRatchetTotal += inst.ratchet || 0;
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
      // Anchor Tenant: whatever brings them in also makes them spend.
      case 'footfall_ratchets_feed_basket':
        f.footfallFeedsBasket = Math.max(f.footfallFeedsBasket, v);
        break;
      case 'ratchet_rate_multiply':
        f.ratchetRateMul *= v;
        break;
      case 'shrink_reduce':
        f.shrinkReduce = Math.max(f.shrinkReduce, v);
        break;
      // reset_ratchets_double_rate and add_aisle_on_acquire fire once, when the
      // fixture is acquired, so they live in shop.js rather than here.
      case 'reset_ratchets_double_rate':
      case 'add_aisle_on_acquire':
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

/**
 * The Margin every customer starts from, before anything on the floor touches
 * them. Exported because the browser build walks individuals and needs the
 * same starting point the aggregate resolver uses.
 */
export function baseMarginFor(content, shop, saleOn = false) {
  let m = content.economy.start.margin;
  const sale = content.economy.micro && content.economy.micro.sale;
  if (saleOn && sale) m += sale.marginDelta;
  if (shop.flags.marginBonus) m += shop.flags.marginBonus;
  return m - marginPenaltyFromStaff(shop);
}

// ---------------------------------------------------------------------------
// The walk
// ---------------------------------------------------------------------------

/** Conditions on a levelled clause. Same vocabulary as a trigger condition. */
export function clauseHolds(clause, type) {
  for (const c of clause.conditions || []) {
    if (c.check === 'customer_type_in' && !c.value.includes(type.id)) return false;
  }
  return true;
}

function conditionsHold(content, shop, def, inst, aisleIdx, type, slotIdx = -1) {
  const L = inst.level - 1;
  const slots = shop.aisles[aisleIdx].slots;
  const prevFilled = () => {
    for (let i = slotIdx - 1; i >= 0; i--) if (slots[i]) return slots[i];
    return null;
  };
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
      // --- position and adjacency ------------------------------------------
      // Order of operations measured 0.0pp because End Cap was the only
      // adjacency effect in the pool. These are the vocabulary the rest of the
      // catalogue needs so that where a fixture sits is worth thinking about.
      case 'slot_is_first':
        if (slotIdx !== 0) return false;
        break;
      case 'slot_is_last':
        if (slotIdx !== slots.length - 1) return false;
        break;
      case 'slot_index_min':
        if (slotIdx < c.value) return false;
        break;
      case 'prev_slot_class': {
        const p = prevFilled();
        if (!p || p.def.class !== c.value) return false;
        break;
      }
      case 'prev_slot_term': {
        const p = prevFilled();
        if (!p || p.def.term !== c.value) return false;
        break;
      }
      case 'aisle_holds_no_class':
        if (slots.some((i) => i && i.def.class === c.value)) return false;
        break;
      // Purity. Pays only if the whole aisle commits to one identity, which is
      // what makes a hedged build worse than either pure one.
      case 'aisle_all_share_tag': {
        const filled = slots.filter(Boolean);
        if (filled.length < (c.min || 2)) return false;
        if (!filled.every((i) => i.def.tagSet.has(c.value))) return false;
        break;
      }
      case 'shop_holds_at_least_tag': {
        let n = 0;
        for (const { inst: fx } of fixtureInstances(shop)) if (fx.def.tagSet.has(c.value)) n++;
        if (n < c.count) return false;
        break;
      }
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
  const commitMul = commitMultiplier(content, shop);
  const aisle = shop.aisles[aisleIdx];
  const passChance = flags.noSkip ? 1 : content.economy.slots.basePassChance;

  // Wallet is what a customer is willing to spend, so it scales a real basket.
  // A Shoplifter's loss is the value of what they walk out with, not a wallet.
  const walletScale = type.sign === 'positive' ? content.walletMean : 1;
  // Crowding. Charged against Patience it is a second-order effect, because
  // Patience only matters once a queue already exists; charged against
  // Conversion it always bites. See REPORT.md.
  const crowd = flags.congestion ? flags.congestion[aisleIdx] : 1;
  const crowdMode = content.economy.congestion?.mode || 'patience';
  const terms = {
    conversion: type.conversion * (crowdMode === 'conversion' ? crowd : 1),
    basket: type.basket * walletScale * flags.basketMul,
    margin: baseMargin + type.marginDelta,
    patience: (type.patienceTicks + aisle.patienceBonus + flags.patienceBonus)
      * flags.patienceMul
      * (crowdMode === 'patience' ? crowd : 1),
  };
  if (flags.basketFixed != null) terms.basket = flags.basketFixed;
  if (shop.flags.basketFixed != null) terms.basket = shop.flags.basketFixed;
  if (shop.flags.basketMultiplier) terms.basket *= shop.flags.basketMultiplier;

  const amps = []; // { term, mult, from, to }
  // Variance of the two capped terms, so the clamp can be integrated rather
  // than applied to the mean. Only Conversion and Margin are capped.
  const variance = { conversion: 0, margin: 0 };

  const apply = (term, op, value, p, strength) => {
    if (term === 'footfall' || term === 'none') return;
    if (op === 'add') {
      let amp = 1;
      for (const a of amps) if (a.term === term) amp *= a.mult;
      const step = value * strength * amp;
      terms[term] += p * step;
      // A Bernoulli contribution of size `step` taken with probability p.
      if (term in variance) variance[term] += step * step * p * (1 - p);
    } else if (op === 'multiply') {
      const m = 1 + (value - 1) * strength;
      const f = 1 + p * (m - 1);
      terms[term] *= f;
      // Approximate: scale the accumulated spread by the same factor. Exact
      // when the multiplier is certain, and the starter pool has no
      // conditional multiplier stacked on a conditional additive.
      if (term in variance) variance[term] *= f * f;
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
    if (!conditionsHold(content, shop, def, inst, aisleIdx, type, i)) continue;
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

    // A ratchet applies whatever it has accumulated so far. It grows once per
    // real trading day, in run.js, never during evaluation.
    if (def.effect.op === 'ratchet') {
      if (def.term !== 'footfall') {
        apply(def.term, 'add', (inst.ratchet || 0) * commitMul, p, strength);
      }
      continue;
    }
    // A growing multiplier. ratchet_mult climbs by addition and compound
    // climbs by multiplication; both are read here as x(1 + ratchet), so the
    // difference between linear and exponential lives entirely in how the
    // number got this big, never in how it is spent.
    if (isMultiplicative(def)) {
      if (def.term !== 'footfall') {
        apply(def.term, 'multiply', 1 + (inst.ratchet || 0) * commitMul, p, strength);
      }
      continue;
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
      // Levelled clauses are data, not branches: see fixtures.json.
      for (const cl of def.clauses || []) {
        if (inst.level < cl.minLevel) continue;
        if (!clauseHolds(cl, type)) continue;
        apply(cl.term, cl.op, cl.value, p, strength);
      }
    }
  }

  // Fixtures whose levelling widened them to the whole shop fire last.
  for (const { inst, def } of flags.globalEffects) {
    if (aisle.slots.includes(inst)) continue; // already applied during the walk
    if (!conditionsHold(content, shop, def, inst, aisleIdx, type)) continue;
    apply(def.term, def.effect.op, def.effect.value[inst.level - 1], 1, 1);
  }

  terms.conversion += flags.conversionFlat;
  terms.basket += flags.basketFlat;
  if (flags.footfallFeedsBasket) {
    terms.basket += flags.footfallRatchetTotal * flags.footfallFeedsBasket;
  }
  if (flags.conversionCertain) terms.conversion = 1;
  if (flags.marginSet != null) terms.margin = flags.marginSet;
  if (shop.flags.marginFixed != null) terms.margin = shop.flags.marginFixed;
  if (flags.marginHalved) terms.margin *= 0.5;
  terms.margin += flags.marginFlat;
  if (type.id === 'pensioner') terms.conversion *= flags.pensionerConvMul;
  if (flags.onlyTypesConvert && !flags.onlyTypesConvert.has(type.id)) terms.conversion = 0;

  // Conversion and Margin are rates, so they cap. They are a floor to defend,
  // not an axis to grow: all unbounded growth lives in Footfall and Basket.
  const caps = content.economy.caps || {};
  const convCap = caps.conversion ?? 1;
  const marginCap = caps.margin ?? 0.95;
  terms.conversion = Math.max(0, expectedClamped(terms.conversion, variance.conversion, convCap));
  terms.margin = Math.max(-1, expectedClamped(terms.margin, variance.margin, marginCap));
  terms.patience = Math.max(0, terms.patience);
  if (type.sign === 'positive') terms.basket = Math.max(0, terms.basket);
  return terms;
}

// ---------------------------------------------------------------------------
// The queue. Tills are hand size; Footfall above throughput is walkouts.
// ---------------------------------------------------------------------------

// The queue's working array is the single hottest allocation in the simulator:
// a fresh Float64Array(ticks * types) on every resolveDay, and policies call
// resolveDay hundreds of times a night. It is reused instead.
let QUEUE_SCRATCH = new Float64Array(0);

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

  // Only types that actually turn up need a lane in the queue. Marketing
  // routinely zeroes two or three, and this loop is the simulator's hot path.
  const active = [];
  for (let k = 0; k < K; k++) if (arrivals[k] > 0) active.push(k);
  const A = active.length;
  if (A === 0) return { served, walkouts };

  const need = ticks * A;
  if (QUEUE_SCRATCH.length < need) QUEUE_SCRATCH = new Float64Array(need);
  const perTick = QUEUE_SCRATCH;
  const pat = new Float64Array(A);
  for (let j = 0; j < A; j++) {
    const rate = arrivals[active[j]] / ticks;
    pat[j] = patience[active[j]];
    for (let t = 0; t < ticks; t++) perTick[t * A + j] = rate;
  }

  const headExp = new Int32Array(A);
  let headServe = 0;

  for (let t = 0; t < ticks; t++) {
    // Patience drains while waiting; at zero it is a walkout.
    for (let j = 0; j < A; j++) {
      const horizon = t - pat[j];
      while (headExp[j] <= horizon && headExp[j] <= t) {
        const idx = headExp[j] * A + j;
        walkouts[active[j]] += perTick[idx];
        perTick[idx] = 0;
        headExp[j]++;
      }
    }

    let cap = capacity;
    while (cap > 1e-9 && headServe <= t) {
      let cohort = 0;
      const base = headServe * A;
      for (let j = 0; j < A; j++) cohort += perTick[base + j];
      if (cohort <= 1e-9) { headServe++; continue; }
      const take = Math.min(cap, cohort);
      const frac = take / cohort;
      for (let j = 0; j < A; j++) {
        const s = perTick[base + j] * frac;
        served[active[j]] += s;
        perTick[base + j] -= s;
      }
      cap -= take;
      if (frac >= 1 - 1e-12) headServe++;
    }
  }

  // Anyone still holding at close is a walkout.
  for (let t = headServe; t < ticks; t++) {
    for (let j = 0; j < A; j++) walkouts[active[j]] += perTick[t * A + j];
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
  const commitMul = commitMultiplier(content, shop);
  let footfall = shop.baseFootfall + shop.carryFootfall;
  if (shop.flags.footfallMultiplier) footfall *= shop.flags.footfallMultiplier;
  for (let a = 0; a < shop.aisles.length; a++) {
    for (const inst of shop.aisles[a].slots) {
      if (!inst || flags.disabled.has(inst)) continue;
      const def = inst.def;
      if (def.term !== 'footfall' || def.trigger.scope !== 'shop') continue;
      const v = def.effect.value[inst.level - 1];
      if (def.effect.op === 'ratchet') footfall += (inst.ratchet || 0) * commitMul;
      else if (isMultiplicative(def)) footfall *= 1 + (inst.ratchet || 0) * commitMul;
      else if (def.effect.op === 'add') footfall += v;
      else if (def.effect.op === 'multiply') footfall *= v;

    }
  }
  // The SALE sign: more people, more of them buy, worse margin — and the extra
  // Footfall lands on the same tills, which is the actual decision.
  const saleCfg = content.economy.micro && content.economy.micro.sale;
  const saleOn = !!shop.saleOn && !!saleCfg;
  if (saleOn) footfall *= saleCfg.footfallMul;
  footfall += flags.footfallAdd;
  footfall *= flags.footfallMul;
  footfall = Math.min(footfall, flags.footfallCap);
  if (shop.flags.footfallOverride) {
    const [lo, hi] = shop.flags.footfallOverride;
    footfall = (lo + hi) / 2;
  }
  footfall = Math.max(0, footfall);

  // --- Base margin ----------------------------------------------------------
  const baseMargin = baseMarginFor(content, shop, saleOn);

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

  // Sampling noise is applied only when the day is really played. Policies
  // evaluate against the expectation, which is exactly what the projection
  // panel shows them — so the plan is honest and the day is a roll.
  const vcfg = content.economy.variance || {};
  const noise = vcfg.enabled && ctx.sampleRng ? ctx.sampleRng : null;

  const arrivals = new Float64Array(K);
  for (const t of types) {
    let share = (pool[t.id] || 0) / poolTotal;
    let n = footfall * share;
    // Who walks through the door is a draw, not a quota.
    if (noise && vcfg.arrivals && n > 0) n = noise.binomial(footfall, share);
    if (t.id === 'shoplifter' && (flags.blockShoplifters || flags.shoplifterBecomes)) {
      const target = flags.blockShoplifters ? null : flags.shoplifterBecomes;
      if (target) arrivals[content.typeIndex.get(target)] += n;
      n = 0;
    }
    arrivals[t.index] += n;
  }

  const traversals = shop.flags.traversals || 1;

  // --- The walk, once per (aisle, type) ------------------------------------
  // Crowding. Nothing else in the ruleset costs anything for funnelling every
  // customer down one aisle, so without this signage has a dominant strategy.
  const cong = content.economy.congestion;
  if (cong && cong.strength > 0 && openAisles.length > 1) {
    const load = new Float64Array(shop.aisles.length);
    let loadTotal = 0;
    for (const t of types) {
      const w = pool[t.id] || 0;
      if (w <= 0) continue;
      loadTotal += w;
      if (t.routing === 'random') {
        for (const a of openAisles) load[a] += w / openAisles.length;
      } else {
        let a = shop.signage[t.id];
        if (a == null || !openAisles.includes(a)) a = openAisles[0];
        load[a] += w;
      }
    }
    const fair = 1 / openAisles.length;
    flags.congestion = shop.aisles.map((_, a) => {
      const share = loadTotal > 0 ? load[a] / loadTotal : 0;
      const over = Math.max(0, share - fair) / fair;
      return Math.max(cong.floor, 1 - cong.strength * over);
    });
  }

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

  // Till triage. A few interventions per day pull customers out of the queue
  // before their patience runs out. Which customers is the whole decision: the
  // Luxury with a £225 basket and 25% conversion, or the Pensioner with £17 and
  // 70% who is about to leave, or neither because the Browser is clogging the
  // till and will buy nothing anyway.
  const micro = content.economy.micro;
  if (shop.triageMode && micro && micro.triage) {
    let budget = Math.max(micro.triage.floor, footfall * micro.triage.fractionOfFootfall);
    const order = [];
    for (let k = 0; k < K; k++) {
      if (walkouts[k] <= 0) continue;
      // Naive triage serves whoever is nearest, so value everyone the same.
      // Smart triage serves by what that customer is actually worth.
      // routed[] only carries patience; a customer's worth has to come from
      // the segments, share-weighted across whichever aisles they take.
      let worth = 1;
      if (shop.triageMode === 'smart') {
        worth = 0;
        for (const seg of segments) {
          if (seg.k !== k) continue;
          worth += seg.share * seg.terms.conversion * seg.terms.basket * seg.terms.margin;
        }
      }
      order.push({ k, worth });
    }
    order.sort((a, b) => b.worth - a.worth);
    for (const { k } of order) {
      if (budget <= 0) break;
      const take = Math.min(budget, walkouts[k]);
      walkouts[k] -= take;
      served[k] += take;
      budget -= take;
    }
  }

  // --- Till ----------------------------------------------------------------
  let sales = 0;
  let revenue = 0;
  let saleProfit = 0;
  let shrink = 0;
  let refunds = 0;
  let unsold = 0;
  let wTotal = 0;
  let returnVisits = 0;
  const salesByType = Object.create(null);
  // Pool averages of the four terms, kept only to show how badly they lie.
  let aConv = 0; let aBasket = 0; let aMargin = 0;

  for (const seg of segments) {
    const t = types[seg.k];
    const { terms, share } = seg;
    if (t.id === 'shoplifter') {
      shrink += arrivals[seg.k] * share * terms.basket * (1 - flags.shrinkReduce);
      continue;
    }
    const seen = served[seg.k] * share;
    // Each customer rolls against their own Conversion at the till.
    const s = noise && vcfg.conversion
      ? noise.binomial(seen, terms.conversion)
      : seen * terms.conversion;
    sales += s;
    salesByType[t.id] = (salesByType[t.id] || 0) + s;
    unsold += seen - s;
    // Wallet rank varies per customer, so basket does too. Variance of a sum
    // of s independent baskets, expressed as a coefficient of variation.
    let rev = s * terms.basket;
    if (noise && s > 0 && vcfg.walletCv) {
      rev += noise.normal() * terms.basket * vcfg.walletCv * Math.sqrt(s);
      if (rev < 0) rev = 0;
    }
    revenue += rev;
    saleProfit += rev * terms.margin;
    aConv += seen * terms.conversion;
    aBasket += seen * terms.basket;
    aMargin += seen * terms.margin;
    wTotal += seen;
  }
  refunds = (flags.refundShare || 0) * Math.max(0, shop.lastTradingProfit || 0);
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
  const rent = rentFor(content, shop, auditMods, ctx.target) * flags.rentMul;
  const upkeepRatchet = ratchetUpkeep(content, shop, ctx.target);
  profit -= rent;
  profit -= shop.marketingUpkeep || 0; // marketing persists and costs upkeep
  profit -= upkeepRatchet; // scaling costs you while it is still young

  // --- Tomorrow -------------------------------------------------------------
  const wcfg = content.economy.walkouts;
  let carry = 0;
  if (flags.unsoldToFootfall > 0) carry += unsold * flags.unsoldToFootfall;
  if (flags.walkoutsToFootfall) carry += totalWalkouts;
  else {
    // Capped: an uncapped penalty lets one bad boss day zero Footfall, and a
    // zero in any of the four terms is an unrecoverable run.
    const penalty = totalWalkouts * wcfg.footfallPenaltyPerWalkout;
    // Against today's Footfall, not the starting Footfall. Otherwise the brake
    // is weightless exactly when it is needed.
    carry -= Math.min(penalty, footfall * (wcfg.maxPenaltyShare ?? 1));
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
    salesByType,
    ratchetUpkeep: upkeepRatchet,
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
