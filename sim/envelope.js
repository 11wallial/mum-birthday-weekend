// What profit curve can a good build actually reach?
//
// The ruleset assumes a constant 1.47 growth per encounter. A build does not
// grow that way: it grows fast while there are empty slots and headroom in
// Conversion and Margin, then flattens hard once those two terms saturate at
// 100%. Only Footfall and Basket can keep climbing. So the achievable curve is
// S-shaped and the target curve is exponential, and the two can only agree for
// a handful of encounters.
//
// This measures the achievable curve directly, then fits a target curve to it
// by fixed-point iteration until the planner win rate lands in the band the
// spec asks for.

import { loadContent } from './content.js';
import { playRun } from './run.js';
import { runBatch } from './harness.js';

function percentile(xs, p) {
  if (!xs.length) return 0;
  const a = xs.slice().sort((x, y) => x - y);
  const i = Math.min(a.length - 1, Math.max(0, Math.floor(p * (a.length - 1))));
  return a[i];
}

/** Median profit at each encounter among runs still alive there. */
export function measureEnvelope(content, { n = 300, characterId = 'default_shop', policy = 'planner', p = 0.5 } = {}) {
  const E = content.run.encounters;
  const buckets = Array.from({ length: E }, () => []);
  let alive = new Array(E).fill(0);
  for (let i = 0; i < n; i++) {
    const r = playRun(content, { characterId, policy, seed: 90001 + i, trace: true });
    for (const t of r.record.trace) {
      buckets[t.enc - 1].push(t.profit);
      alive[t.enc - 1]++;
    }
  }
  return {
    curve: buckets.map((b) => percentile(b, p)),
    alive,
    reached: buckets.map((b) => b.length / n),
  };
}

/**
 * Fit a target curve. `shape` comes from the measured envelope; `k` scales it.
 * Iterating matters because the curve changes the cash a run banks, which
 * changes what it can buy, which changes the curve.
 */
export function fitTargets(opts = {}) {
  const {
    n = 300, characterId = 'default_shop', iterations = 3,
    lo: bandLo = 0.55, hi: bandHi = 0.70,
  } = opts;
  const E = loadContent().run.encounters;

  // Seed with a trivially easy curve so nothing dies and we see the raw shape.
  let targetCurve = new Array(E).fill(50);
  let shape = null;
  let k = 0.5;
  let last = null;

  for (let it = 0; it < iterations; it++) {
    const content = loadContent({ targetCurve });
    shape = measureEnvelope(content, { n: Math.round(n / 2), characterId }).curve;
    // Enforce monotonicity: a target curve that dips is not a difficulty curve.
    for (let i = 1; i < shape.length; i++) shape[i] = Math.max(shape[i], shape[i - 1] * 1.02);

    let klo = 0.05; let khi = 1.6;
    for (let step = 0; step < 7; step++) {
      k = (klo + khi) / 2;
      const cand = shape.map((v) => Math.max(40, v * k));
      const c2 = loadContent({ targetCurve: cand });
      const s = runBatch(c2, { n, characterId, policy: 'planner' });
      last = { k, winRate: s.winRate, curve: cand, stats: s };
      if (s.winRate > bandHi) klo = k;
      else if (s.winRate < bandLo) khi = k;
      else break;
    }
    targetCurve = last.curve;
  }
  return last;
}
