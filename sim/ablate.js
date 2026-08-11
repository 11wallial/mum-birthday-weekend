// Where does the skill gap actually come from?
//
// The project's health check is the gap between a weak and a strong policy. A
// single number is not enough, because a gap can be manufactured by writing a
// weak opponent. Two decompositions:
//
//   depth   win rate as a function of lookahead depth alone, everything else
//           held at the greedy setting. If one step recovers most of the gap,
//           the skill ceiling is low and the ratchet bet is weak.
//   ablate  each planner capability switched on alone, and switched off from
//           the full planner. A capability that adds nothing alone and costs
//           nothing to remove is not carrying skill.

import { registerPolicy, GREEDY_CFG, PLANNER_CFG } from './policies.js';
import { runBatch } from './harness.js';

export function lookaheadCurve(content, { n = 600, characterId = 'default_shop' } = {}) {
  const depths = [0, 1, 2, 4, 8, 16];
  const out = [];
  for (const d of depths) {
    const name = `depth${d}`;
    registerPolicy(name, { ...GREEDY_CFG, lookahead: d });
    const s = runBatch(content, { n, characterId, policy: name });
    out.push({ depth: d, winRate: s.winRate, medianDeath: s.medianDeath });
  }
  return out;
}

const CAPABILITIES = ['lookahead', 'stress', 'balance', 'tempo', 'sign', 'reorder', 'reroll'];

/**
 * Every cell of an ablation run on one seed block is a single draw from the
 * seed space. Cells are paired — each uses seeds seed0..seed0+n — which kills
 * a lot of variance, but it does not make one table trustworthy. So the whole
 * table is run over several disjoint blocks and the spread is reported, and
 * only rows whose sign is stable across every block should be concluded from.
 *
 * This exists because the first version of this measurement produced a
 * confident claim about lookahead drawn from its least stable cell.
 */
export function capabilityAblation(content, {
  n = 500, characterId = 'default_shop', blocks = 3,
} = {}) {
  const seedBlocks = [];
  for (let b = 0; b < blocks; b++) seedBlocks.push(1 + b * 100000);

  const across = (policy) => seedBlocks.map(
    (seed0) => runBatch(content, { n, characterId, policy, seed0 }).winRate,
  );

  const base = across('greedy');
  const full = across('planner');

  const solo = [];
  const drop = [];
  for (const cap of CAPABILITIES) {
    const on = cap === 'lookahead' ? PLANNER_CFG.lookahead : true;
    const off = cap === 'lookahead' ? 0 : false;

    registerPolicy(`solo_${cap}`, { ...GREEDY_CFG, [cap]: on });
    const s = across(`solo_${cap}`);
    solo.push({ cap, deltas: s.map((v, i) => v - base[i]) });

    registerPolicy(`drop_${cap}`, { ...PLANNER_CFG, [cap]: off });
    const d = across(`drop_${cap}`);
    drop.push({ cap, deltas: d.map((v, i) => v - full[i]) });
  }
  return { base, full, solo, drop, seedBlocks };
}

/** A row is only worth concluding from if every block agrees on the sign. */
export function signStable(deltas, epsilon = 0.01) {
  const meaningful = deltas.filter((d) => Math.abs(d) > epsilon);
  if (meaningful.length === 0) return true; // stably nothing, which is a finding
  return meaningful.every((d) => d > 0) || meaningful.every((d) => d < 0);
}

/**
 * Commitment. The design goal is that over-committing to scaling or to tempo
 * both kill you, that a flat blend of the two is merely mediocre, and that the
 * strong play is a *schedule* — invest, then harvest — which is a much higher
 * ceiling than any fixed mix. This measures both curves so the claim is
 * falsifiable rather than asserted.
 */
export function commitmentCurves(content, { n = 400, characterId = 'default_shop' } = {}) {
  const statics = [];
  for (const b of [0, 0.25, 0.5, 0.75, 1]) {
    const name = `bias${b}`;
    registerPolicy(name, { ...PLANNER_CFG, scalingBias: b });
    statics.push({ bias: b, winRate: runBatch(content, { n, characterId, policy: name }).winRate });
  }
  const pivots = [];
  for (const p of [3, 6, 9, 12, 15, 18]) {
    const name = `pivot${p}`;
    registerPolicy(name, { ...PLANNER_CFG, pivotAt: p });
    pivots.push({ pivot: p, winRate: runBatch(content, { n, characterId, policy: name }).winRate });
  }
  return { statics, pivots };
}

/**
 * The commitment mechanics act on how many ratchets you hold, so that is what
 * has to be varied to test them. A quota of 0 is pure tempo; past the
 * threshold in economy.json every ratchet is stronger and upkeep per fixture
 * is cheaper. The design wants this curve to dip in the middle.
 */
export function ratchetQuotaCurve(content, { n = 350, characterId = 'default_shop' } = {}) {
  const out = [];
  for (const q of [0, 1, 2, 3, 4, 5, 6]) {
    const name = `quota${q}`;
    registerPolicy(name, { ...PLANNER_CFG, ratchetQuota: q });
    const s = runBatch(content, { n, characterId, policy: name });
    out.push({ quota: q, winRate: s.winRate });
  }
  return out;
}
