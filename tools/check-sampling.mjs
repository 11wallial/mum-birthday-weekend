#!/usr/bin/env node
// Does the SAMPLED trading day still add up?
//
// Above economy.day.maxWalkers the browser build stops drawing a sprite per
// customer and walks a weighted sample instead. That is an approximation the
// rest of the project does not have, so it needs measuring rather than
// assuming: verify.js proves the aggregate resolver against individually
// walked customers, and this proves the thing the player actually plays
// against the aggregate resolver, at the scales where sampling bites.
//
//   node tools/check-sampling.mjs [--days=400]

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { buildContent } from '../sim/content-core.js';
import { createShop, addFixture, autoSign } from '../sim/shop.js';
import { projectRatchets } from '../sim/shop.js';
import { makeRng } from '../sim/rng.js';
import { createTradingDay } from '../src/trading-day.js';

const HERE = dirname(fileURLToPath(import.meta.url));
const rd = (f) => JSON.parse(readFileSync(join(HERE, '..', 'data', f), 'utf8'));
const content = buildContent({
  customers: rd('customers.json'), fixtures: rd('fixtures.json'),
  economy: rd('economy.json'), run: rd('run.json'),
});

const DAYS = Number((process.argv.find((a) => a.startsWith('--days=')) || '').slice(7)) || 400;

/** A shop grown to roughly a target Footfall, so sampling is actually engaged. */
function shopAt(fixtures, projectDays, tills) {
  const shop = createShop(content, 'default_shop');
  for (const [id, copies] of fixtures) {
    for (let c = 0; c < copies; c++) addFixture(content, shop, id);
  }
  shop.tills = tills;
  projectRatchets(shop, projectDays, { sales: 400, served: 500, walkouts: 60, salesByType: {} });
  autoSign(content, shop);
  return shop;
}

const CASES = [
  ['small, no sampling', shopAt([['bus_route', 1], ['sample_table', 1]], 2, 2)],
  ['at the threshold', shopAt([['bus_route', 3], ['pavement_sign', 2], ['open_late', 2]], 14, 6)],
  ['well past it', shopAt([['word_of_mouth', 3], ['bus_route', 3], ['high_street_pull', 2]], 16, 20)],
  ['far past it', shopAt([['word_of_mouth', 3], ['catchment_area', 3], ['retail_park', 2]], 20, 40)],
];

const ctx = { boss: null, auditMods: {}, target: 5000, closedAisle: -1 };
const pct = (a, b) => (b === 0 ? 0 : Math.abs(a - b) / Math.abs(b));

console.log(`\nSampled trading day vs aggregate resolver — ${DAYS} days per case`);
console.log('The walk is a weighted sample above economy.day.maxWalkers'
  + ` (${content.economy.day.maxWalkers}).\n`);
console.log('case                    footfall  walkers  weight   mean profit'
  + '   resolver   err     sigmas');
console.log('─'.repeat(96));

let failed = 0;
for (const [name, shop] of CASES) {
  let sum = 0; let sumSq = 0; let walkers = 0; let weight = 0; let footfall = 0; let expect = 0;
  let served = 0; let sales = 0; let walkouts = 0; let exServed = 0; let exSales = 0; let exWalk = 0;
  for (let d = 0; d < DAYS; d++) {
    const day = createTradingDay(content, shop, ctx, makeRng(7000 + d));
    while (!day.state.finished) day.step();
    const p = day.state.tradingProfit;
    sum += p; sumSq += p * p;
    served += day.state.served; sales += day.state.sales; walkouts += day.state.walkouts;
    walkers = day.state.customers.length;
    footfall = day.state.footfall;
    weight = day.state.walkerWeight;
    expect = day.state.projection.saleProfit;
    exServed = day.state.projection.served;
    exSales = day.state.projection.sales;
    exWalk = day.state.projection.walkouts;
  }
  const mean = sum / DAYS;
  const se = Math.sqrt(Math.max(0, sumSq / DAYS - mean * mean) / DAYS);
  const err = pct(mean, expect);
  const sigmas = se > 0 ? Math.abs(mean - expect) / se : 0;
  // Sampling only adds variance, so the bar is the same as verify.js: the gap
  // has to sit inside the noise it is drawn from.
  const ok = sigmas <= 3 || err < 0.02;
  if (!ok) failed++;
  console.log(`${name.padEnd(22)}${footfall.toLocaleString('en-GB').padStart(10)}`
    + `${String(walkers).padStart(9)}${weight.toFixed(1).padStart(8)}`
    + `${('£' + Math.round(mean).toLocaleString('en-GB')).padStart(14)}`
    + `${('£' + Math.round(expect).toLocaleString('en-GB')).padStart(11)}`
    + `${(err * 100).toFixed(2).padStart(7)}%${sigmas.toFixed(1).padStart(9)}${ok ? '' : '  <-- FAIL'}`);
  // The funnel, not just the bottom line: profit alone cannot tell you whether
  // the walk served too many people or converted too many of them, and the two
  // had different causes.
  const f = (a, b) => `${Math.round(a).toLocaleString('en-GB')} vs ${Math.round(b).toLocaleString('en-GB')}`;
  console.log(`${''.padEnd(22)}served ${f(served / DAYS, exServed)}`
    + `   sales ${f(sales / DAYS, exSales)}   walkouts ${f(walkouts / DAYS, exWalk)}`);
}
console.log('─'.repeat(96));
if (failed) {
  console.log(`\nFAIL — ${failed} case(s) drift beyond sampling noise\n`);
  process.exit(1);
}
console.log('\nPASS — the sampled walk agrees with the resolver at every scale\n');
