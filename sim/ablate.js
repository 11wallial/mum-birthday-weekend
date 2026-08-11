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

export function capabilityAblation(content, { n = 600, characterId = 'default_shop' } = {}) {
  const base = runBatch(content, { n, characterId, policy: 'greedy' });
  const full = runBatch(content, { n, characterId, policy: 'planner' });

  const solo = [];
  const drop = [];
  for (const cap of CAPABILITIES) {
    const on = cap === 'lookahead' ? PLANNER_CFG.lookahead : true;
    const off = cap === 'lookahead' ? 0 : false;

    registerPolicy(`solo_${cap}`, { ...GREEDY_CFG, [cap]: on });
    solo.push({ cap, winRate: runBatch(content, { n, characterId, policy: `solo_${cap}` }).winRate });

    registerPolicy(`drop_${cap}`, { ...PLANNER_CFG, [cap]: off });
    drop.push({ cap, winRate: runBatch(content, { n, characterId, policy: `drop_${cap}` }).winRate });
  }
  return { base: base.winRate, full: full.winRate, solo, drop };
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
