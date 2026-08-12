#!/usr/bin/env node
// Queue verification.
//
// verify.js proves the aggregate resolver's *fixture* arithmetic against
// individually walked customers, and has done since part one. It has never
// touched the queue — it sets tills to 40 specifically to remove the queue from
// the comparison. Meanwhile the queue does 29.5% of the early killing, triage
// makes it a mechanic the player reaches into, and the whole late game is an
// equilibrium between Footfall and throughput. It has been the committed next
// item twice.
//
// runQueue is a fluid model: arrivals as a continuous rate per type, cohorts
// served FIFO, a cohort expiring when it has waited longer than its type's
// patience. This runs the same scenarios as a DISCRETE queue of individual
// customers — one object each, their own arrival tick, their own place in the
// line — and checks the fluid model predicts the discrete mean.
//
// The discrete side deliberately matches how the browser build spawns: arrival
// times uniform across the day, each arrival's type drawn from the pool. So the
// count of each type is multinomial rather than fixed, which is the thing a
// fluid model is least likely to get right, and the thing the player actually
// experiences.
//
//   node sim/verify-queue.js [--days=4000]

import { runQueue } from './day.js';
import { makeRng } from './rng.js';

const flag = (k, d) => {
  const m = process.argv.find((a) => a.startsWith(`--${k}=`));
  return m ? Number(m.slice(k.length + 3)) : d;
};
const DAYS = flag('days', 4000);

/**
 * The discrete queue: every customer is an individual with an arrival tick and
 * a patience, served first-come-first-served, one line, `capacity` per tick.
 */
function discreteDay(arrivals, capacity, ticks, patience, rng) {
  const K = arrivals.length;
  let total = 0;
  for (let k = 0; k < K; k++) total += arrivals[k];
  const n = Math.round(total);
  const served = new Float64Array(K);
  const walkouts = new Float64Array(K);
  if (n <= 0) return { served, walkouts };

  // Types drawn from the pool, in proportion — not a fixed count each.
  const entries = [];
  for (let k = 0; k < K; k++) if (arrivals[k] > 0) entries.push([k, arrivals[k]]);

  // Arrival times uniform across the day, as the browser build spawns them.
  const line = [];
  for (let i = 0; i < n; i++) {
    line.push({ k: rng.weighted(entries), at: Math.floor((i / n) * ticks) });
  }

  let head = 0;
  let credit = 0;
  for (let t = 0; t < ticks; t++) {
    credit += capacity;
    // Expiring and serving have to happen in one pass over the head of the
    // line. Doing them as two loops stalls the till behind a customer who has
    // already walked out: types are interleaved and have different patience,
    // so the moment an expired one surfaces mid-tick the till stops for the
    // rest of the tick instead of stepping over them.
    for (;;) {
      if (head >= line.length || line[head].at > t) break;
      const c = line[head];
      if (t - c.at > patience[c.k]) { walkouts[c.k] += 1; head++; continue; }
      if (credit < 1) break;
      served[c.k] += 1;
      head++;
      credit -= 1;
    }
  }
  // Anyone still holding at close leaves.
  for (let i = head; i < line.length; i++) walkouts[line[i].k] += 1;
  return { served, walkouts };
}

// Scenarios chosen to cover the shapes the game actually reaches, including
// the late-game equilibrium where Footfall sits at a multiple of throughput.
const CASES = [
  {
    name: 'well under capacity',
    arrivals: [40, 30, 20], patience: [8, 12, 6], capacity: 2, ticks: 165,
  },
  {
    name: 'just under capacity',
    arrivals: [120, 90, 60], patience: [8, 12, 6], capacity: 2, ticks: 165,
  },
  {
    name: 'just over capacity',
    arrivals: [180, 140, 100], patience: [8, 12, 6], capacity: 2.5, ticks: 165,
  },
  {
    name: 'heavy overload',
    arrivals: [900, 700, 500], patience: [8, 12, 6], capacity: 4, ticks: 165,
  },
  {
    name: 'late-game equilibrium',
    arrivals: [4000, 3000, 2200], patience: [9, 14, 7], capacity: 28, ticks: 165,
  },
  {
    name: 'split patience',
    arrivals: [400, 400], patience: [2, 40], capacity: 2, ticks: 165,
  },
  {
    name: 'one impatient type',
    arrivals: [600], patience: [3], capacity: 2, ticks: 165,
  },
  {
    name: 'fractional capacity',
    arrivals: [200, 120], patience: [10, 10], capacity: 0.7, ticks: 165,
  },
  {
    name: 'eight types',
    arrivals: [300, 250, 200, 180, 160, 140, 120, 100],
    patience: [4, 6, 8, 10, 12, 14, 16, 18], capacity: 5, ticks: 165,
  },
  {
    name: 'twelve times overload',
    arrivals: [12000, 9000, 6000], patience: [9, 14, 7], capacity: 22, ticks: 165,
  },
];

console.log(`\nQueue verification — ${DAYS.toLocaleString('en-GB')} discrete days per case`);
console.log('runQueue is a fluid model. Each case runs the same arrivals as a queue');
console.log('of individual customers and checks it predicts the discrete mean.\n');
console.log('case                        served  fluid    err   sigmas   '
  + 'walkouts  fluid    err   sigmas');
console.log('─'.repeat(100));

let failures = 0;
for (const c of CASES) {
  const fluid = runQueue(
    Float64Array.from(c.arrivals), c.capacity, c.ticks, Float64Array.from(c.patience),
  );
  const fServed = fluid.served.reduce((a, b) => a + b, 0);
  const fWalk = fluid.walkouts.reduce((a, b) => a + b, 0);

  const rng = makeRng(20260812);
  let sS = 0; let sS2 = 0; let sW = 0; let sW2 = 0;
  const byType = new Float64Array(c.arrivals.length);
  for (let d = 0; d < DAYS; d++) {
    const r = discreteDay(c.arrivals, c.capacity, c.ticks, c.patience, rng);
    let s = 0; let w = 0;
    for (let k = 0; k < r.served.length; k++) { s += r.served[k]; byType[k] += r.served[k]; }
    for (let k = 0; k < r.walkouts.length; k++) w += r.walkouts[k];
    sS += s; sS2 += s * s; sW += w; sW2 += w * w;
  }
  const mS = sS / DAYS; const mW = sW / DAYS;
  const seS = Math.sqrt(Math.max(0, sS2 / DAYS - mS * mS) / DAYS);
  const seW = Math.sqrt(Math.max(0, sW2 / DAYS - mW * mW) / DAYS);
  const errS = Math.abs(mS - fServed) / Math.max(1, fServed);
  const errW = Math.abs(mW - fWalk) / Math.max(1, fWalk);
  const sigS = seS > 0 ? Math.abs(mS - fServed) / seS : 0;
  const sigW = seW > 0 ? Math.abs(mW - fWalk) / seW : 0;

  // A fluid model of a discrete queue carries a genuine discretisation
  // difference of order one customer, so the bar is three standard errors OR
  // one per cent, whichever is kinder — but never both waived.
  const ok = (sigS <= 3 || errS < 0.01) && (sigW <= 3 || errW < 0.01);
  if (!ok) failures++;
  const f = (v) => Math.round(v).toLocaleString('en-GB');
  console.log(`${c.name.padEnd(24)}${f(mS).padStart(9)}${f(fServed).padStart(7)}`
    + `${(errS * 100).toFixed(2).padStart(7)}%${sigS.toFixed(1).padStart(8)}   `
    + `${f(mW).padStart(8)}${f(fWalk).padStart(7)}`
    + `${(errW * 100).toFixed(2).padStart(7)}%${sigW.toFixed(1).padStart(8)}`
    + `${ok ? '' : '  <-- FAIL'}`);

  // Per-type, because a queue can get the total right while routing the wrong
  // people through it — the four terms differ hugely by type, so a mix error is
  // a profit error even when the headcount matches.
  //
  // Judged as a share of the WHOLE day, not as a share of the type's own count:
  // nine served where eleven were owed is a 0.2pp shift in who came through the
  // till, and reading it as an 18% error on that type says the opposite.
  const parts = [];
  let worstMix = 0;
  for (let k = 0; k < c.arrivals.length; k++) {
    const got = byType[k] / DAYS;
    const want = fluid.served[k];
    const mix = Math.abs(got - want) / Math.max(1, mS);
    if (mix > worstMix) worstMix = mix;
    parts.push(`${f(got)}/${f(want)}`);
  }
  if (worstMix > 0.01) failures++;
  console.log(`${''.padEnd(24)}by type  ${parts.join('  ')}`
    + `    worst mix shift ${(worstMix * 100).toFixed(2)}pp of the day`
    + `${worstMix > 0.01 ? '  <-- FAIL' : ''}`);
}
console.log('─'.repeat(100));
if (failures) {
  console.log(`\nFAIL — ${failures} disagreement(s) beyond noise\n`);
  process.exit(1);
}
console.log('\nPASS — the fluid queue predicts the discrete queue, in total and by type\n');
