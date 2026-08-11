// The tuning sweeps from section 20, in the order the spec demands, because
// later numbers depend on earlier ones.

import { loadContent } from './content.js';
import { runBatch, earlyDeathCauses, fmtPct } from './harness.js';

const row = (label, cells) => console.log(`${String(label).padEnd(14)}${cells.join('')}`);
const cell = (s, w = 12) => String(s).padStart(w);

function sweepOver(values, build, report, opts) {
  const out = [];
  for (const v of values) {
    const content = loadContent(build(v));
    out.push({ v, ...report(content, opts) });
  }
  return out;
}

const base = (content, opts, policy = 'planner') => runBatch(content, {
  n: opts.n, characterId: opts.character, audit: 1, policy,
});

export const SWEEPS = {
  // 1. Level payoff. Is combining worth two and a half picks?
  level: {
    label: 'L2/L3 additive scalars — combine rate wants ~35% of picks',
    run(opts) {
      const sets = [
        [1, 1.6, 2.4], [1, 2.0, 3.6], [1, 2.5, 5.5], [1, 3.0, 7.0], [1, 4.0, 10.0],
      ];
      row('scalars', [cell('combine%'), cell('planner win'), cell('greedy win')]);
      for (const s of sets) {
        const content = loadContent({ levelAdditive: s });
        const p = base(content, opts);
        const g = base(content, opts, 'greedy');
        row(s.join('/'), [
          cell(fmtPct(p.combineRate)), cell(fmtPct(p.winRate)), cell(fmtPct(g.winRate)),
        ]);
      }
    },
  },

  // 2. Target growth rate. 1.47 is a guess.
  growth: {
    label: 'target growth per encounter — planner win wants 55-70%',
    run(opts) {
      row('growth', [cell('planner win'), cell('greedy win'), cell('median death')]);
      for (const g of [1.38, 1.41, 1.44, 1.47, 1.5, 1.55]) {
        const content = loadContent({ targetGrowth: g });
        const p = base(content, opts);
        const gr = base(content, opts, 'greedy');
        row(g.toFixed(2), [
          cell(fmtPct(p.winRate)), cell(fmtPct(gr.winRate)), cell(p.medianDeath ?? '-'),
        ]);
      }
    },
  },

  // 3. Supplier Tier cost curve. ~30% of winning runs should rush a tier.
  tier: {
    label: 'supplier tier cost scale — tier rush among winners wants ~30%',
    run(opts) {
      row('cost x', [cell('tier rush'), cell('planner win'), cell('median tier')]);
      for (const k of [0.4, 0.6, 0.8, 1.0, 1.3, 1.8]) {
        const content = loadContent({ supplierCostScale: k });
        const p = base(content, opts);
        const tiers = Object.entries(p.finalTier).sort((a, b) => b[1] - a[1])[0];
        row(k.toFixed(1), [
          cell(fmtPct(p.tierRushRate)), cell(fmtPct(p.winRate)), cell(tiers ? tiers[0] : '-'),
        ]);
      }
    },
  },

  // 4. Rarity EV spread. High-rarity pick rate at Tier 4 wants ~50%, not 90%.
  rarity: {
    label: 'rarity EV spread — high-rarity pick rate at Tier 4 wants ~50%',
    run(opts) {
      const sets = [
        { common: 100, uncommon: 105, rare: 112, flagship: 120 },
        { common: 100, uncommon: 110, rare: 122, flagship: 138 },
        { common: 100, uncommon: 115, rare: 135, flagship: 160 },
        { common: 100, uncommon: 125, rare: 155, flagship: 195 },
        { common: 100, uncommon: 140, rare: 190, flagship: 260 },
      ];
      row('spread', [cell('hi-rarity T4'), cell('planner win'), cell('top pick rate')]);
      for (const s of sets) {
        const content = loadContent({ rarityEv: s });
        const p = base(content, opts);
        row(`${s.uncommon}/${s.rare}/${s.flagship}`, [
          cell(fmtPct(p.highRarityPickRateT4)),
          cell(fmtPct(p.winRate)),
          cell(p.topPickRate ? fmtPct(p.topPickRate[1]) : '-'),
        ]);
      }
    },
  },

  // 5. Till throughput. Queue drowning wants ~25% of early losses.
  till: {
    label: 'day length in ticks — queue share of early losses wants ~25%',
    run(opts) {
      row('ticks', [cell('queue share'), cell('early losses'), cell('planner win')]);
      for (const t of [90, 120, 150, 180, 220, 280]) {
        const content = loadContent({ dayTicks: t });
        const ed = earlyDeathCauses(content, {
          n: opts.n, characterId: opts.character, policy: 'greedy',
        });
        const p = base(content, opts);
        row(t, [
          cell(fmtPct(ed.causes.queue || 0)), cell(ed.early), cell(fmtPct(p.winRate)),
        ]);
      }
    },
  },

  // 6. Staff Margin cost. Winning builds want 0 to 8 staff, not a cluster.
  staff: {
    label: 'staff margin cost scale — staff in winning builds wants a 0-8 range',
    run(opts) {
      row('cost x', [cell('median staff'), cell('range'), cell('planner win')]);
      for (const k of [0.5, 0.75, 1.0, 1.5, 2.0]) {
        const content = loadContent({ staffMarginScale: k });
        const p = base(content, opts);
        row(k.toFixed(2), [
          cell(p.medianStaffInWins ?? '-'),
          cell(p.staffRange.join('-')),
          cell(fmtPct(p.winRate)),
        ]);
      }
    },
  },

  // Supporting knob: how often a customer walks past a slot at all.
  slots: {
    label: 'base slot pass chance — how much layout order matters',
    run(opts) {
      row('pass', [cell('planner win'), cell('greedy win'), cell('gap pp')]);
      for (const s of [0.6, 0.75, 0.9, 1.0]) {
        const content = loadContent({ slotPassChance: s });
        const p = base(content, opts);
        const g = base(content, opts, 'greedy');
        row(s.toFixed(2), [
          cell(fmtPct(p.winRate)), cell(fmtPct(g.winRate)),
          cell(((p.winRate - g.winRate) * 100).toFixed(1)),
        ]);
      }
    },
  },
};

export function runSweep(knob, opts) {
  const s = SWEEPS[knob];
  console.log(`\n${s.label}\n`);
  s.run(opts);
  console.log('');
}
