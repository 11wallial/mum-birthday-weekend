// One customer, walked individually: their own wallet rank, their own coin
// flip at every slot.
//
// This is the authoritative reading of section 2 — customers enter one at a
// time and every fixture they pass fires in path order. The aggregate resolver
// in day.js is a fast equivalent used for planning and for batch simulation;
// verify.js checks the two agree.
//
// Shared, because it is now used in three places and a hand-mirrored copy has
// already drifted once: the verifier, and the browser build, which walks real
// customers across the floor while the projection panel shows the aggregate.

import { clauseHolds, conditionsHold } from './day.js';
import { isMultiplicative } from './ratchets.js';

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

/** One customer, one wallet roll, one coin flip per slot. */
export function walkIndividual(content, shop, aisleIdx, type, flags, baseMargin, rng, onFire) {
  const aisle = shop.aisles[aisleIdx];
  const passChance = flags.noSkip ? 1 : content.economy.slots.basePassChance;
  const w = content.wallet;
  const rank = 1 + rng.int(w.ranks);
  const wallet = w.min + ((rank - 1) * (w.max - w.min)) / (w.ranks - 1);

  const crowd = flags.congestion ? flags.congestion[aisleIdx] : 1;
  const crowdMode = content.economy.congestion?.mode || 'patience';
  const terms = {
    conversion: type.conversion * (crowdMode === 'conversion' ? crowd : 1),
    basket: type.basket * (type.sign === 'positive' ? wallet : 1) * flags.basketMul,
    margin: baseMargin + type.marginDelta,
    patience: (type.patienceTicks + aisle.patienceBonus + flags.patienceBonus)
      * flags.patienceMul * (crowdMode === 'patience' ? crowd : 1),
  };

  // Character rules that rewrite a term outright. These lived only in the
  // aggregate resolver, so the browser build — which walks individuals — has
  // been playing five of the seven shops differently from the simulator that
  // measured them. verify.js never caught it because it only ever built
  // default_shop.
  if (flags.basketFixed != null) terms.basket = flags.basketFixed;
  if (shop.flags.basketFixed != null) terms.basket = shop.flags.basketFixed;
  if (shop.flags.basketMultiplier) terms.basket *= shop.flags.basketMultiplier;

  const amps = [];
  const apply = (term, op, value, strength) => {
    if (term === 'footfall' || term === 'none') return;
    if (op === 'add') {
      let amp = 1;
      for (const a of amps) if (a.term === term) amp *= a.mult;
      terms[term] += value * strength * amp;
    } else if (op === 'multiply') {
      terms[term] *= 1 + (value - 1) * strength;
    }
  };

  for (let i = 0; i < aisle.slots.length; i++) {
    for (let k = amps.length - 1; k >= 0; k--) {
      if (i < amps[k].from || i > amps[k].to) amps.splice(k, 1);
    }
    const inst = aisle.slots[i];
    if (!inst || flags.disabled.has(inst)) continue;
    const def = inst.def;
    const L = inst.level - 1;
    if (def.trigger.scope === 'shop' || def.trigger.scope === 'exit') continue;

    // The SAME condition check the resolver uses. This file used to implement
    // exactly one of the eleven — customer_type_in — so every fixture gated on
    // a slot position, an adjacency, a tag or a rarity fired unconditionally
    // during the trading day. The player was getting effects the projection
    // panel had already told them they would not get, which is the one promise
    // the panel makes.
    //
    // It hid because verify.js only built boards out of unconditional commons.
    // The character cases brought in Appointment Book and Bulk Buy as starting
    // fixtures, and the Estate Agent's Conversion came out 35% high.
    //
    // The ENGINE here is deliberately a second implementation; the CONTENT
    // rules are not duplicated, because duplicating those is not independence,
    // it is drift. Same ruling as the levelled clauses below.
    if (!conditionsHold(content, shop, def, inst, aisleIdx, type, i)) continue;

    let strength = 1;
    let forced = false;
    if (inst.staff === 'manager') { forced = true; strength = 0.5; }
    if (def.breadth && def.breadth.check === 'scope_widen'
        && def.breadth.value[L] !== 'customer') forced = true;
    const walked = forced || rng() < passChance;

    if (def.trigger.scope === 'next_slots') {
      if (!walked) continue;
      const count = def.trigger.count[L];
      amps.push({
        term: def.term,
        mult: 1 + (def.effect.value[L] - 1) * strength,
        from: inst.level >= 3 ? i : i + 1,
        to: i + count,
      });
      continue;
    }
    // A ratchet applies whatever it has accumulated, like any other add.
    // A growing multiplier, rather than a growing addend — whether it grew by
    // addition (ratchet_mult) or by multiplication (compound).
    if (isMultiplicative(def)) {
      if (walked && def.term !== 'footfall') {
        apply(def.term, 'multiply', 1 + (inst.ratchet || 0), strength);
        if (onFire) onFire(i, def);
      }
      continue;
    }
    if (def.effect.op === 'ratchet') {
      if (walked && def.term !== 'footfall') {
        apply(def.term, 'add', inst.ratchet || 0, strength);
        if (onFire) onFire(i, def);
      }
      continue;
    }

    const times = inst.staff === 'assistant' ? 2 : 1;
    if (walked && onFire) onFire(i, def);
    for (let t = 0; t < times; t++) {
      if (walked) apply(def.term, def.effect.op, def.effect.value[L], strength);
      // Levelled clauses are read from the same JSON the resolver reads. The
      // *engine* here is deliberately a second independent implementation;
      // duplicating the *content* is not independence, it is drift, and it had
      // already silently dropped Greeter's clause.
      //
      // A clause rolls its own trigger — see ruling 8 in sim/README.md:
      // sharing one roll across two terms couples them, and a coupled pair
      // cannot be resolved by expectation.
      for (const cl of def.clauses || []) {
        if (inst.level < cl.minLevel) continue;
        if (!clauseHolds(cl, type)) continue;
        if (forced || rng() < passChance) apply(cl.term, cl.op, cl.value, strength);
      }
    }
  }

  // This tail is in the SAME ORDER as the equivalent block in day.js, and the
  // order is load-bearing: a fixed Margin set before `marginFlat` is added is a
  // different number from one set after it. Having the two engines apply the
  // same rules in a different sequence is drift that no amount of independence
  // justifies — it put the Estate Agent 27% apart from its own resolver.
  terms.conversion += flags.conversionFlat || 0;
  terms.basket += flags.basketFlat || 0;
  if (flags.footfallFeedsBasket) {
    terms.basket += (flags.footfallRatchetTotal || 0) * flags.footfallFeedsBasket;
  }
  if (flags.conversionCertain) terms.conversion = 1;
  if (flags.marginSet != null) terms.margin = flags.marginSet;
  if (shop.flags.marginFixed != null) terms.margin = shop.flags.marginFixed;
  if (flags.marginHalved) terms.margin *= 0.5;
  terms.margin += flags.marginFlat;
  if (type.id === 'pensioner') terms.conversion *= flags.pensionerConvMul;
  if (flags.onlyTypesConvert && !flags.onlyTypesConvert.has(type.id)) terms.conversion = 0;
  const caps = content.economy.caps || {};
  const convCap = caps.conversion ?? 1;
  const marginCap = caps.margin ?? 0.95;
  // Whether this walker actually hit a cap is the thing that decides if the
  // clamp allowance may be spent on this case at all.
  const clamped = terms.conversion > convCap || terms.margin > marginCap;
  terms.conversion = clamp(terms.conversion, 0, convCap);
  terms.margin = clamp(terms.margin, -1, marginCap);
  if (type.sign === 'positive') terms.basket = Math.max(0, terms.basket);
  terms.patience = Math.max(0, terms.patience);
  return { value: terms.conversion * terms.basket * terms.margin, clamped, terms };
}

