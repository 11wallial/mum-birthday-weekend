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
import { collectFlags, resolveDay } from './day.js';
import { walkIndividual } from './walk-one.js';
import { addFixture, autoSign, createShop, projectRatchets } from './shop.js';
import { makeRng } from './rng.js';

const argv = process.argv.slice(2);
const flagOf = (k, d) => {
  const m = argv.find((a) => a.startsWith(`--${k}=`));
  return m ? Number(m.split('=')[1]) : d;
};

const content = loadContent();
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
  // The scaling cards, which is where the seven-figure ending lives. A verifier
  // whose cases predate the content it is meant to check proves nothing.
  ['growing multiplier', [['concession_stand', 1], ['weighing_scales', 2], ['end_cap', 1]]],
  ['accelerating stack', [['bulk_pallets', 2], ['deli_counter', 1], ['long_life_stock', 1]]],
  ['anchor tenant feed', [['anchor_tenant', 1], ['bus_route', 2], ['gift_wrapping', 1]]],
  ['capped and pressing', [['staff_training', 3], ['greeter', 2], ['long_life_stock', 2]]],
];

const N = flagOf('n', 200000);
const BIAS_BOUND = 0.031; // per unit of clamp rate
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
    const r = walkIndividual(content, shop, aisle, t, flags, baseMargin, rng);
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
console.log(`plus ${(BIAS_BOUND * 100).toFixed(1)}% clamp bias per unit of clamp rate, so a board`);
console.log('where nobody clamps gets no allowance at all.');
if (failures.length) {
  console.log(`\nFAIL — ${failures.join('; ')}\n`);
  process.exit(1);
}
console.log('PASS — aggregate resolution matches the individual walk\n');
