// Batch runner and the metrics table from section 19.

import { playRun } from './run.js';
import { fixtureInstances } from './shop.js';

const median = (xs) => {
  if (!xs.length) return null;
  const a = xs.slice().sort((x, y) => x - y);
  const m = a.length >> 1;
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
};

export function runBatch(content, opts = {}) {
  const {
    n = 2000, characterId = "default_shop", audit = 1, policy = 'planner', seed0 = 1,
  } = opts;

  const stats = {
    n, characterId, audit, policy,
    wins: 0,
    deaths: [],
    deathCause: {},
    deathByEncounter: new Array(content.run.encounters + 1).fill(0),
    bossFaced: {},
    bossDeaths: {},
    picksTotal: 0,
    combines: 0,
    offeredCount: {},
    pickedCount: {},
    offeredCountT3: {},
    pickedCountT3: {},
    rarityPicksAtT4: {},
    rarityOffersAtT4: {},
    tierRush: 0,
    finalTier: {},
    staffInWins: [],
    rerolls: 0,
  };

  for (let i = 0; i < n; i++) {
    const r = playRun(content, { characterId, audit, policy, seed: seed0 + i });
    const rec = r.record;
    stats.picksTotal += rec.picks.length;
    stats.combines += rec.combines;
    stats.rerolls += rec.rerolls;

    for (const b of rec.bossesFaced) stats.bossFaced[b] = (stats.bossFaced[b] || 0) + 1;

    for (const p of rec.picks) {
      for (const o of p.offered) {
        stats.offeredCount[o.id] = (stats.offeredCount[o.id] || 0) + 1;
        if (p.tier >= 3) stats.offeredCountT3[o.id] = (stats.offeredCountT3[o.id] || 0) + 1;
        if (p.tier >= 4) stats.rarityOffersAtT4[o.rarity] = (stats.rarityOffersAtT4[o.rarity] || 0) + 1;
      }
      stats.pickedCount[p.id] = (stats.pickedCount[p.id] || 0) + 1;
      if (p.tier >= 3) stats.pickedCountT3[p.id] = (stats.pickedCountT3[p.id] || 0) + 1;
      if (p.tier >= 4) stats.rarityPicksAtT4[p.rarity] = (stats.rarityPicksAtT4[p.rarity] || 0) + 1;
    }

    const tier = r.shop.supplierTier;
    stats.finalTier[tier] = (stats.finalTier[tier] || 0) + 1;

    if (r.win) {
      stats.wins++;
      stats.staffInWins.push(r.shop.staff.length);
      // "Rushed" means reaching tier 3 or better before the natural curve makes
      // it cheap, i.e. inside the first half of the run.
      if (rec.tierUpgrades.some((e) => e <= 9) && tier >= 3) stats.tierRush++;
    } else {
      stats.deaths.push(r.deathEncounter);
      stats.deathByEncounter[r.deathEncounter]++;
      stats.deathCause[r.deathCause] = (stats.deathCause[r.deathCause] || 0) + 1;
      if (r.boss) stats.bossDeaths[r.boss] = (stats.bossDeaths[r.boss] || 0) + 1;
    }
  }

  stats.winRate = stats.wins / n;
  stats.medianDeath = median(stats.deaths);
  stats.combineRate = stats.picksTotal ? stats.combines / stats.picksTotal : 0;
  stats.tierRushRate = stats.wins ? stats.tierRush / stats.wins : 0;
  stats.medianStaffInWins = median(stats.staffInWins);
  stats.staffRange = stats.staffInWins.length
    ? [Math.min(...stats.staffInWins), Math.max(...stats.staffInWins)]
    : [0, 0];

  // Deaths in the first quarter of the run, by cause (tuning step 5).
  stats.earlyDeaths = stats.deaths.filter((e) => e <= 8).length;

  stats.pickRates = {};
  for (const id of Object.keys(stats.offeredCountT3)) {
    stats.pickRates[id] = (stats.pickedCountT3[id] || 0) / stats.offeredCountT3[id];
  }
  stats.topPickRate = Object.entries(stats.pickRates).sort((a, b) => b[1] - a[1])[0] || null;

  stats.highRarityPickRateT4 = (() => {
    const picks = stats.rarityPicksAtT4;
    const total = Object.values(picks).reduce((a, b) => a + b, 0);
    if (!total) return null;
    return ((picks.rare || 0) + (picks.flagship || 0)) / total;
  })();

  stats.bossLossShare = {};
  for (const [b, faced] of Object.entries(stats.bossFaced)) {
    stats.bossLossShare[b] = (stats.bossDeaths[b] || 0) / faced;
  }
  return stats;
}

/** Early deaths broken down by cause, which is what tuning step 5 reads. */
export function earlyDeathCauses(content, opts = {}) {
  const { n = 2000, characterId = "default_shop", audit = 1, policy = 'greedy', seed0 = 1 } = opts;
  const causes = {};
  let early = 0;
  for (let i = 0; i < n; i++) {
    const r = playRun(content, { characterId, audit, policy, seed: seed0 + i });
    if (!r.win && r.deathEncounter <= 8) {
      early++;
      causes[r.deathCause] = (causes[r.deathCause] || 0) + 1;
    }
  }
  for (const k of Object.keys(causes)) causes[k] /= early || 1;
  return { early, causes };
}

export const fmtPct = (x) => (x == null ? '  n/a' : `${(x * 100).toFixed(1)}%`);
export const fmtMoney = (x) => `£${Math.round(x).toLocaleString('en-GB')}`;
