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
  terms.conversion = clamp(terms.conversion, 0, caps.conversion ?? 1);
  terms.margin = clamp(terms.margin, -1, caps.margin ?? 0.95);
  if (type.sign === 'positive') terms.basket = Math.max(0, terms.basket);
  return terms.conversion * terms.basket * terms.margin;
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
let worst = 0;
let worstRel = 0;
const failures = [];
console.log(`\nWalk verification — ${N.toLocaleString('en-GB')} individual customers per case\n`);
console.log('case                             aggregate    individual    error   sigmas');
console.log('─'.repeat(78));

for (const [name, fixtures] of CASES) {
  const shop = buildShop(fixtures);
  const ctx = { auditMods: {} };
  const agg = resolveDay(content, shop, ctx);

  // Same shop, same pool, one customer at a time.
  const flags = collectFlags(content, shop, ctx);
  const baseMargin = content.economy.start.margin;
  const rng = makeRng(20260811);
  const entries = content.types
    .filter((t) => t.special !== 'steals')
    .map((t) => [t, shop.pool[t.id] || 0]);
  const poolTotal = entries.reduce((a, [, w]) => a + w, 0);
  const allPool = content.types.reduce((a, t) => a + (shop.pool[t.id] || 0), 0);

  let sum = 0;
  let sumSq = 0;
  for (let i = 0; i < N; i++) {
    const t = rng.weighted(entries);
    // Tourists ignore signage and route randomly; day.js averages that outcome
    // across open aisles, so the individual walk has to actually roll it.
    const aisle = t.routing === 'random'
      ? rng.int(shop.aisles.length)
      : (shop.signage[t.id] ?? 0);
    const v = walkIndividual(shop, aisle, t, flags, baseMargin, rng);
    sum += v;
    sumSq += v * v;
  }
  // Scale from "per shopping customer" up to a full day's Footfall.
  const shoppers = agg.footfall * (poolTotal / allPool);
  const mean = sum / N;
  const individual = mean * shoppers;

  // Luxury customers are 1% of the pool carrying 20x the basket, so the
  // sampling error is dominated by how many of them turned up. Judge the
  // agreement against that error, not against a tolerance picked to suit.
  const variance = Math.max(0, sumSq / N - mean * mean);
  const se = Math.sqrt(variance / N) * shoppers;
  const diff = Math.abs(individual - agg.saleProfit);
  const sigmas = se > 0 ? diff / se : 0;
  worst = Math.max(worst, sigmas);
  const err = diff / Math.max(1, agg.saleProfit);
  worstRel = Math.max(worstRel, err);
  // Judged per case. Taking the maximum sigma and the maximum relative error
  // across *different* cases and then failing if either maximum breaches makes
  // the test fail on noise at low N, which is worse than no test at all.
  // A case passes if the observed difference is explainable by sampling noise
  // (3 standard errors) plus the allowed systematic bias from clamping, added
  // together. Testing either alone makes the result depend on sample size.
  const allowed = 3 * se + 0.0075 * Math.max(1, agg.saleProfit);
  if (diff > allowed) {
    failures.push(`${name}: £${diff.toFixed(2)} exceeds £${allowed.toFixed(2)} allowed`);
  }
  console.log(
    `${name.padEnd(32)}${`£${agg.saleProfit.toFixed(2)}`.padStart(10)}`
    + `${`£${individual.toFixed(2)}`.padStart(14)}${`${(err * 100).toFixed(2)}%`.padStart(9)}`
    + `${`${sigmas.toFixed(1)}σ`.padStart(8)}`,
  );
}

console.log('─'.repeat(78));

// Two different things can separate the two numbers, and they need different
// tests. Sampling noise shrinks with N and is judged in standard errors. The
// Conversion and Margin caps introduce a small *systematic* bias that does not
// shrink: clamping is non-linear, so E[min(X, cap)] < min(E[X], cap), and a
// build pressed against a cap loses a little on the individual walk that the
// expectation keeps. It is bounded by the overflow above the cap, which is well
// under 1% for any board the policies actually build.
const BIAS_BOUND = 0.0075;
console.log(`\nworst disagreement ${worst.toFixed(1)} standard errors, `
  + `${(worstRel * 100).toFixed(2)}% relative`);
console.log('a case passes if its gap fits inside 3 standard errors of noise '
  + `plus ${(BIAS_BOUND * 100).toFixed(2)}% cap bias`);
if (N < 150000) {
  console.log(`note: n=${N.toLocaleString('en-GB')} is thin for the Luxury tail; `
    + 'use 300k+ to separate bias from noise');
}
if (failures.length) {
  console.log(`FAIL — ${failures.join('; ')}\n`);
  process.exit(1);
}
console.log('PASS — aggregate resolution matches the individual walk\n');
