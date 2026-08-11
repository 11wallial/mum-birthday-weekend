#!/usr/bin/env node
// Checks the aggregate resolution against an individual-customer walk.
//
// day.js resolves the walk once per (aisle, type) at the mean wallet, and
// treats slot skipping and End Cap amplification as expectations. That is only
// legitimate if walking thousands of individuals — each with their own wallet
// rank and their own coin flip at every slot — lands on the same number.
//
// Scope: the walk. Queueing is excluded by giving the shop enough till
// throughput that nobody waits, so any disagreement is walk maths and not
// queue maths.
//
//   node sim/verify.js [--n=200000]

import { loadContent } from './content.js';
import { clauseHolds, collectFlags, resolveDay } from './day.js';
import { addFixture, autoSign, createShop, projectRatchets } from './shop.js';
import { makeRng } from './rng.js';

const argv = process.argv.slice(2);
const flagOf = (k, d) => {
  const m = argv.find((a) => a.startsWith(`--${k}=`));
  return m ? Number(m.split('=')[1]) : d;
};

const content = loadContent();
const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

/** One customer, one wallet roll, one coin flip per slot. */
function walkIndividual(shop, aisleIdx, type, flags, baseMargin, rng) {
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

function buildShop(fixtures) {
  const shop = createShop(content, 'default_shop');
  shop.tills = 40; // remove the queue from the comparison entirely
  for (const [id, copies] of fixtures) {
    for (let c = 0; c < copies; c++) addFixture(content, shop, id);
  }
  projectRatchets(shop, 12); // run the ratchets forward so they have something to apply
  autoSign(content, shop);
  return shop;
}

const CASES = [
  ['bare shop', []],
  ['three commons', [['greeter', 1], ['sample_table', 1], ['own_brand', 1]]],
  ['end cap before sample table', [['end_cap', 1], ['sample_table', 1]]],
  ['levelled stack', [['sample_table', 3], ['greeter', 2], ['end_cap', 2], ['own_brand', 1]]],
  ['multiplicative mix', [['end_cap', 1], ['sample_table', 2], ['concierge', 1], ['own_brand', 2]]],
  ['ratchets running', [['range_extension', 2], ['trade_account', 1], ['end_cap', 1]]],
];

const N = flagOf('n', 200000);
const BIAS_BOUND = 0.0075;
const failures = [];

/** Walk `count` individuals through this shop and summarise the disagreement. */
function sampleCase(shop, agg, flags, count) {
  const baseMargin = content.economy.start.margin;
  const rng = makeRng(20260811);
  const entries = content.types
    .filter((t) => t.special !== 'steals')
    .map((t) => [t, shop.pool[t.id] || 0]);
  const poolTotal = entries.reduce((a, [, w]) => a + w, 0);
  const allPool = content.types.reduce((a, t) => a + (shop.pool[t.id] || 0), 0);

  let sum = 0; let sumSq = 0; let clamps = 0;
  for (let i = 0; i < count; i++) {
    const t = rng.weighted(entries);
    // Tourists ignore signage and route randomly; day.js averages that outcome
    // across open aisles, so the individual walk has to actually roll it.
    const aisle = t.routing === 'random'
      ? rng.int(shop.aisles.length)
      : (shop.signage[t.id] ?? 0);
    const r = walkIndividual(shop, aisle, t, flags, baseMargin, rng);
    sum += r.value;
    sumSq += r.value * r.value;
    if (r.clamped) clamps++;
  }
  const shoppers = agg.footfall * (poolTotal / allPool);
  const mean = sum / count;
  const individual = mean * shoppers;
  const variance = Math.max(0, sumSq / count - mean * mean);
  const se = Math.sqrt(variance / count) * shoppers;
  const diff = Math.abs(individual - agg.saleProfit);
  return {
    individual,
    se,
    diff,
    sigmas: se > 0 ? diff / se : 0,
    rel: diff / Math.max(1, agg.saleProfit),
    clampRate: clamps / count,
  };
}

console.log(`\nWalk verification — ${N.toLocaleString('en-GB')} individual customers per case`);
console.log('Each case is also run at a quarter of that. Sigma that GROWS with the');
console.log('sample is the signature of real bias; noise alone leaves it flat.\n');
console.log('case                          aggregate   individual   err    σ@n/4    σ@n  clamped');
console.log('─'.repeat(88));

for (const [name, fixtures] of CASES) {
  const shop = buildShop(fixtures);
  const ctx = { auditMods: {} };
  const agg = resolveDay(content, shop, ctx);
  const flags = collectFlags(content, shop, ctx);

  const small = sampleCase(shop, agg, flags, Math.max(1000, Math.floor(N / 4)));
  const big = sampleCase(shop, agg, flags, N);

  console.log(
    `${name.padEnd(29)}${`£${agg.saleProfit.toFixed(0)}`.padStart(10)}`
    + `${`£${big.individual.toFixed(0)}`.padStart(13)}`
    + `${`${(big.rel * 100).toFixed(2)}%`.padStart(7)}`
    + `${small.sigmas.toFixed(1).padStart(8)}`
    + `${big.sigmas.toFixed(1).padStart(7)}`
    + `${`${(big.clampRate * 100).toFixed(1)}%`.padStart(9)}`,
  );

  // The clamp allowance is only available to cases that actually clamp.
  // Granting it unconditionally makes any systematic bias below the bound
  // undetectable everywhere in the walk maths, at any sample size, which is
  // the opposite of what a verifier is for.
  const clamps = big.clampRate > 0.005;
  const allowed = 3 * big.se + (clamps ? BIAS_BOUND * Math.max(1, agg.saleProfit) : 0);
  if (big.diff > allowed) {
    failures.push(`${name}: £${big.diff.toFixed(2)} exceeds £${allowed.toFixed(2)}`
      + `${clamps ? ' (clamp allowance already granted)' : ' (no clamping, so no allowance)'}`);
  }
}

console.log('─'.repeat(88));
console.log(`\nA case passes if its gap fits inside 3 standard errors of sampling noise,`);
console.log(`plus ${(BIAS_BOUND * 100).toFixed(2)}% clamp bias ONLY where walkers actually hit a cap.`);
if (failures.length) {
  console.log(`\nFAIL — ${failures.join('; ')}\n`);
  process.exit(1);
}
console.log('PASS — aggregate resolution matches the individual walk\n');
