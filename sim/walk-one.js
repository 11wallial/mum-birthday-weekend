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

import { clauseHolds } from './day.js';

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

/** One customer, one wallet roll, one coin flip per slot. */
export function walkIndividual(content, shop, aisleIdx, type, flags, baseMargin, rng) {
  const aisle = shop.aisles[aisleIdx];
  const passChance = flags.noSkip ? 1 : content.economy.slots.basePassChance;
  const w = content.wallet;
  const rank = 1 + rng.int(w.ranks);
  const wallet = w.min + ((rank - 1) * (w.max - w.min)) / (w.ranks - 1);

  const terms = {
    conversion: type.conversion,
    basket: type.basket * (type.sign === 'positive' ? wallet : 1) * flags.basketMul,
    margin: baseMargin + type.marginDelta,
  };

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

    let ok = true;
    for (const c of def.trigger.conditions || []) {
      if (c.check === 'customer_type_in') {
        const list = def.breadth && def.breadth.check === 'customer_type_in'
          ? def.breadth.value[L] : c.value;
        if (!list.includes(type.id)) ok = false;
      }
    }
    if (!ok) continue;

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
    if (def.effect.op === 'ratchet') {
      if (walked && def.term !== 'footfall') apply(def.term, 'add', inst.ratchet || 0, strength);
      continue;
    }

    const times = inst.staff === 'assistant' ? 2 : 1;
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

  terms.margin += flags.marginFlat;
  if (type.id === 'pensioner') terms.conversion *= flags.pensionerConvMul;
  const caps = content.economy.caps || {};
  const convCap = caps.conversion ?? 1;
  const marginCap = caps.margin ?? 0.95;
  // Whether this walker actually hit a cap is the thing that decides if the
  // clamp allowance may be spent on this case at all.
  const clamped = terms.conversion > convCap || terms.margin > marginCap;
  terms.conversion = clamp(terms.conversion, 0, convCap);
  terms.margin = clamp(terms.margin, -1, marginCap);
  if (type.sign === 'positive') terms.basket = Math.max(0, terms.basket);
  return { value: terms.conversion * terms.basket * terms.margin, clamped };
}

