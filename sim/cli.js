#!/usr/bin/env node
// Headless simulator CLI.
//
//   node sim/cli.js panel                 day-one projection panel
//   node sim/cli.js check   [--n=2000]    the section 19 health check
//   node sim/cli.js chars   [--n=1000]    win rate spread across characters
//   node sim/cli.js ladder  [--n=1000]    planner win rate per Audit level
//   node sim/cli.js bosses  [--n=3000]    loss share per boss
//   node sim/cli.js trace   [--seed=1]    one run, encounter by encounter
//   node sim/cli.js bench   [--n=2000]    runs per second
//   node sim/cli.js sweep <knob> [--n=800]

import { loadContent } from './content.js';
import { resolveDay } from './day.js';
import { createShop, addFixture, autoSign, ownedIds } from './shop.js';
import { playRun } from './run.js';
import { runBatch, earlyDeathCauses, fmtPct, fmtMoney } from './harness.js';
import { runSweep, SWEEPS } from './sweep.js';
import { measureEnvelope, fitTargets } from './envelope.js';
import {
  lookaheadCurve, capabilityAblation, commitmentCurves, ratchetQuotaCurve, signStable,
  microAblation,
} from './ablate.js';

const argv = process.argv.slice(2);
const cmd = argv[0] || 'check';
const flags = {};
for (const a of argv.slice(1)) {
  const m = /^--([^=]+)(?:=(.*))?$/.exec(a);
  if (m) flags[m[1]] = m[2] === undefined ? true : m[2];
}
const num = (k, d) => (flags[k] != null ? Number(flags[k]) : d);
const str = (k, d) => (flags[k] != null ? String(flags[k]) : d);

// Global tuning overrides, so every command can be pointed at a candidate
// balance without editing /data.
const overrides = {};
if (flags.growth) overrides.targetGrowth = Number(flags.growth);
if (flags.base) overrides.targetBase = Number(flags.base);
if (flags.ticks) overrides.dayTicks = Number(flags.ticks);
if (flags.pass) overrides.slotPassChance = Number(flags.pass);
if (flags.rent) overrides.rentScale = Number(flags.rent);
if (flags.payout) overrides.payoutMode = String(flags.payout);
if (flags.congestion) overrides.congestion = Number(flags.congestion);
if (flags.congmode) overrides.congestionMode = String(flags.congmode);
if (flags.variance != null) overrides.variance = Number(flags.variance);
const content = loadContent(overrides);
const rule = (n = 74) => console.log('─'.repeat(n));

function panel() {
  const shop = createShop(content, str("character", "default_shop"));
  while (ownedIds(shop).size < content.economy.start.startingFixtures) {
    const fx = content.byRarity.common[ownedIds(shop).size % content.byRarity.common.length];
    if (ownedIds(shop).has(fx.id)) break;
    addFixture(content, shop, fx.id);
  }
  autoSign(content, shop);
  const d = resolveDay(content, shop, { auditMods: {} });
  const p = d.panel;
  const target = content.targets[0];
  console.log('');
  console.log(`  Footfall ${p.footfall}  ×  Conversion ${fmtPct(p.conversion)}  ×  `
    + `Basket ${fmtMoney(p.basket)}  ×  Margin ${fmtPct(p.margin)}`);
  console.log(`  = Trading ${fmtMoney(p.trading)}   Rent ${fmtMoney(p.rent)}   `
    + `Shrink ${fmtMoney(p.shrink)}   Profit ${fmtMoney(d.profit)}`);
  console.log(`  Target ${fmtMoney(target)}      Gap ${fmtMoney(d.profit - target)}`);
  console.log(`  Served ${d.served.toFixed(0)}   Walkouts ${d.walkouts.toFixed(0)} `
    + `(${fmtPct(d.walkoutRate)})`);
  console.log(`  If the panel multiplied POOL AVERAGES instead of funnel `
    + `ratios it would read ${fmtMoney(p.naive)} `
    + `(${(p.naive / Math.max(1, p.trading)).toFixed(2)}x the truth)`);
  console.log('');
}

function check() {
  const n = num('n', 2000);
  const audit = num('audit', 1);
  const character = str("character", "default_shop");
  console.log(`\nHealth check — ${character}, Audit ${audit}, ${n} runs per policy\n`);
  rule();
  console.log('policy    win rate   target        median death   combine   top pick rate');
  rule();
  const targets = {
    random: [0, 0.02], greedy: [0.15, 0.25], planner: [0.55, 0.7],
  };
  const results = {};
  for (const policy of ['random', 'greedy', 'planner']) {
    const s = runBatch(content, { n, characterId: character, audit, policy });
    results[policy] = s;
    const [lo, hi] = targets[policy];
    const ok = s.winRate >= lo && s.winRate <= hi ? 'ok ' : '!! ';
    const top = s.topPickRate ? `${s.topPickRate[0]} ${fmtPct(s.topPickRate[1])}` : 'n/a';
    console.log(
      `${policy.padEnd(9)} ${fmtPct(s.winRate).padStart(7)}   `
      + `${ok}${(lo * 100).toFixed(0)}-${(hi * 100).toFixed(0)}%`.padEnd(13)
      + `${String(s.medianDeath ?? '-').padStart(8)}       `
      + `${fmtPct(s.combineRate).padStart(6)}    ${top}`,
    );
  }
  rule();
  const gap = (results.planner.winRate - results.greedy.winRate) * 100;
  console.log(`\n  Greedy-versus-planner gap: ${gap.toFixed(1)}pp  `
    + `(milestone 0 wants > 30pp, section 22)`);
  const ed = earlyDeathCauses(content, { n: Math.min(n, 1500), characterId: character, audit, policy: 'greedy' });
  console.log(`  Early losses (enc <= 8), greedy: ${ed.early}`);
  const causes = Object.entries(ed.causes).sort((a, b) => b[1] - a[1]);
  console.log('  by cause: ' + causes.map(([k, v]) => `${k} ${fmtPct(v)}`).join('  '));
  console.log(`  queue share wants ~25% (tuning step 5)\n`);
  const st = results.planner;
  console.log(`  Staff in winning builds: median ${st.medianStaffInWins}, `
    + `range ${st.staffRange[0]}-${st.staffRange[1]} (wants 0-8, not clustered)`);
  console.log(`  Tier rush rate among winners: ${fmtPct(st.tierRushRate)} (wants ~30%)`);
  console.log(`  High-rarity pick rate at Tier 4+: ${fmtPct(st.highRarityPickRateT4)} (wants ~50%)`);
  console.log('');
}

function chars() {
  const n = num('n', 1000);
  const audit = num('audit', 1);
  console.log(`\nCharacter spread — Audit ${audit}, planner, ${n} runs each\n`);
  rule(60);
  console.log('character        win rate   median death   rule');
  rule(60);
  const rates = [];
  for (const c of content.characters) {
    const s = runBatch(content, { n, characterId: c.id, audit, policy: 'planner' });
    rates.push(s.winRate);
    console.log(`${c.id.padEnd(16)} ${fmtPct(s.winRate).padStart(7)}   `
      + `${String(s.medianDeath ?? '-').padStart(8)}       ${c.rule.slice(0, 40)}`);
  }
  rule(60);
  const spread = (Math.max(...rates) - Math.min(...rates)) * 100;
  console.log(`\n  Spread: ${spread.toFixed(1)}pp (wants within 10pp)\n`);
}

function ladder() {
  const n = num('n', 1000);
  const character = str("character", "default_shop");
  console.log(`\nAudit ladder — ${character}, planner, ${n} runs each\n`);
  rule(52);
  console.log('audit   win rate   median death');
  rule(52);
  for (const a of content.audits) {
    const s = runBatch(content, { n, characterId: character, audit: a.id, policy: 'planner' });
    console.log(`${a.name.padEnd(8)}${fmtPct(s.winRate).padStart(7)}   `
      + `${String(s.medianDeath ?? '-').padStart(8)}`);
  }
  rule(52);
  console.log('\n  Audit I wants 55-70%, Audit VIII wants 8-15%\n');
}

function bosses() {
  const n = num('n', 3000);
  const s = runBatch(content, { n, characterId: str("character", "default_shop"), audit: num('audit', 1), policy: 'planner' });
  console.log(`\nBoss loss share — planner, ${n} runs\n`);
  rule(56);
  console.log('boss                      faced   deaths   loss share');
  rule(56);
  const rows = Object.entries(s.bossLossShare).sort((a, b) => b[1] - a[1]);
  for (const [b, share] of rows) {
    const flag = share > 0.4 || share < 0.05 ? ' <-- rebalance' : '';
    console.log(`${b.padEnd(24)}${String(s.bossFaced[b]).padStart(7)}`
      + `${String(s.bossDeaths[b] || 0).padStart(9)}   ${fmtPct(share).padStart(7)}${flag}`);
  }
  rule(56);
  console.log('\n  Wants every boss between 5% and 40% (tuning step 7)\n');
}

function trace() {
  const r = playRun(content, {
    characterId: str("character", "default_shop"),
    audit: num('audit', 1),
    policy: str('policy', 'planner'),
    seed: num('seed', 1),
    trace: true,
  });
  console.log(`\n${str('policy', 'planner')} — ${str("character", "default_shop")}, seed ${num('seed', 1)}\n`);
  rule(96);
  console.log(' enc  target      profit      cash     tier tills  '
    + 'footfall  conv   basket  margin  walkout  boss');
  rule(96);
  for (const t of r.record.trace) {
    const p = t.panel;
    console.log(
      `${String(t.enc).padStart(4)} ${fmtMoney(t.target).padStart(10)} `
      + `${fmtMoney(t.profit).padStart(11)} ${fmtMoney(t.cash).padStart(9)} `
      + `${String(t.tier).padStart(5)}${String(t.tills).padStart(6)}  `
      + `${String(p.footfall).padStart(8)} ${fmtPct(p.conversion).padStart(6)} `
      + `${fmtMoney(p.basket).padStart(7)} ${fmtPct(p.margin).padStart(7)} `
      + `${fmtPct(t.walkoutRate).padStart(7)}  ${t.boss || ''}`,
    );
  }
  rule(96);
  if (r.win) console.log('\n  WON\n');
  else {
    console.log(`\n  LOST at encounter ${r.deathEncounter} `
      + `(${r.deathCause}${r.boss ? `, boss: ${r.boss}` : ''}) — `
      + `${fmtMoney(r.profit)} against ${fmtMoney(r.target)}\n`);
  }
  const build = r.shop.aisles.map((a, i) => `  aisle ${i + 1}: `
    + a.slots.map((s) => (s ? `${s.def.name}${s.level > 1 ? ` L${s.level}` : ''}` : '·')).join(' | ')).join('\n');
  console.log(build);
  console.log(`  staff: ${r.shop.staff.map((s) => s.id).join(', ') || 'none'}`);
  console.log(`  marketing: ${r.shop.marketing.join(', ') || 'none'}\n`);
}

function bench() {
  const n = num('n', 2000);
  for (const policy of ['random', 'greedy', 'planner']) {
    const t0 = process.hrtime.bigint();
    runBatch(content, { n, policy });
    const ms = Number(process.hrtime.bigint() - t0) / 1e6;
    console.log(`${policy.padEnd(8)} ${n} runs in ${(ms / 1000).toFixed(2)}s  `
      + `= ${Math.round(n / (ms / 1000)).toLocaleString('en-GB')} runs/sec  `
      + `-> 100k in ${((100000 / n) * (ms / 1000)).toFixed(0)}s`);
  }
}

function sweep() {
  const knob = argv[1];
  if (!knob || !SWEEPS[knob]) {
    console.log(`\nknobs: ${Object.keys(SWEEPS).join(', ')}\n`);
    return;
  }
  runSweep(knob, { n: num('n', 800), character: str("character", "default_shop") });
}

function envelope() {
  const n = num('n', 240);
  const character = str('character', 'default_shop');
  console.log(`\nAchievable profit envelope — ${character}, planner, ${n} runs\n`);
  const easy = loadContent({ targetCurve: new Array(24).fill(50) });
  const env = measureEnvelope(easy, { n, characterId: character });
  rule(64);
  console.log(' enc   median profit   growth vs prev   spec target (1.47)');
  rule(64);
  for (let i = 0; i < env.curve.length; i++) {
    const g = i === 0 ? null : env.curve[i] / Math.max(1, env.curve[i - 1]);
    console.log(`${String(i + 1).padStart(4)} ${fmtMoney(env.curve[i]).padStart(15)}   `
      + `${(g == null ? '-' : `x${g.toFixed(2)}`).padStart(14)}   `
      + `${fmtMoney(content.targets[i]).padStart(18)}`);
  }
  rule(64);
  const total = env.curve[23] / Math.max(1, env.curve[0]);
  console.log(`\n  Total climb over 24 encounters: x${Math.round(total).toLocaleString('en-GB')}`);
  console.log(`  Implied constant growth:        x${Math.pow(total, 1 / 23).toFixed(3)} per encounter`);
  console.log(`  Spec asks for:                  x${content.targetGrowth} per encounter `
    + `(x${Math.round(Math.pow(content.targetGrowth, 23)).toLocaleString('en-GB')} over the run)\n`);
}

function fit() {
  const n = num('n', 300);
  const character = str('character', 'default_shop');
  console.log(`\nFitting a target curve — ${character}, ${n} runs per probe\n`);
  const r = fitTargets({ n, characterId: character });
  rule(58);
  console.log(' enc      target   growth      enc      target   growth');
  rule(58);
  for (let i = 0; i < 12; i++) {
    const j = i + 12;
    const gi = i === 0 ? '-' : `x${(r.curve[i] / r.curve[i - 1]).toFixed(2)}`;
    const gj = `x${(r.curve[j] / r.curve[j - 1]).toFixed(2)}`;
    console.log(`${String(i + 1).padStart(4)} ${fmtMoney(r.curve[i]).padStart(11)}   ${gi.padStart(6)}`
      + `   ${String(j + 1).padStart(6)} ${fmtMoney(r.curve[j]).padStart(11)}   ${gj.padStart(6)}`);
  }
  rule(58);
  console.log(`\n  planner win rate at this curve: ${fmtPct(r.winRate)}\n`);
  console.log('  Paste into data/run.json as targets.curve to adopt it.');
  console.log(`  ${JSON.stringify(r.curve.map((v) => Math.round(v)))}\n`);
}

function bossimpact() {
  const n = num('n', 400);
  const character = str('character', 'default_shop');
  // Easy enough that runs survive to meet every boss, but the SHAPE of the real
  // curve — rent is a declining fraction of the target, so a flat probe curve
  // makes every rent-based effect inaudible and every capacity-based one free.
  // Rate Review kept 97.4% of a clean day under a flat 50 and that was the
  // probe, not the boss.
  const easy = loadContent({
    targetCurve: content.targets.map((t) => t * 0.10),
  });
  const acc = {};
  for (let i = 0; i < n; i++) {
    const r = playRun(easy, {
      characterId: character, policy: 'planner', seed: 4000 + i,
      trace: true, measureBossDelta: true,
    });
    for (const t of r.record.trace) {
      if (!t.boss || t.cleanProfit == null || t.cleanProfit <= 0) continue;
      (acc[t.boss] ||= []).push(t.profit / t.cleanProfit);
    }
  }
  console.log(`\nBoss impact — median profit kept versus the same shop with no boss\n`);
  rule(62);
  console.log('boss                      samples   profit kept   verdict');
  rule(62);
  const rows = Object.entries(acc)
    .map(([b, xs]) => {
      const a = xs.slice().sort((x, y) => x - y);
      return [b, a.length, a[a.length >> 1]];
    })
    .sort((x, y) => x[2] - y[2]);
  for (const [b, cnt, keep] of rows) {
    const verdict = keep < 0.45 ? 'brutal' : keep > 0.92 ? 'barely felt' : 'ok';
    console.log(`${b.padEnd(24)}${String(cnt).padStart(8)}   ${fmtPct(keep).padStart(11)}   ${verdict}`);
  }
  rule(62);
  const all = rows.map((r) => r[2]).sort((a, b) => a - b);
  console.log(`\n  Median across all bosses: ${fmtPct(all[all.length >> 1])} of a clean day.`);
  console.log('  The target curve rises straight through boss days, so this is'
    + '\n  the multiplier a boss target should carry (section 15 and step 7).\n');
}

function depth() {
  const n = num('n', 600);
  const character = str('character', 'default_shop');
  console.log(`\nSkill gap versus lookahead depth — ${character}, ${n} runs per depth`);
  console.log('Everything except lookahead is held at the greedy setting.\n');
  rule(56);
  console.log('lookahead   win rate   median death   gain vs depth 0');
  rule(56);
  const rows = lookaheadCurve(content, { n, characterId: character });
  const zero = rows[0].winRate;
  for (const r of rows) {
    console.log(`${String(r.depth).padStart(9)}   ${fmtPct(r.winRate).padStart(8)}   `
      + `${String(r.medianDeath ?? '-').padStart(12)}   `
      + `${((r.winRate - zero) * 100).toFixed(1).padStart(10)}pp`);
  }
  rule(56);
  const first = rows[1].winRate - zero;
  const total = rows[rows.length - 1].winRate - zero;
  console.log(`\n  One step of lookahead recovers ${fmtPct(total > 0 ? first / total : 0)} `
    + `of everything depth ever buys.`);
  console.log('  A steep step then a flat line means a low ceiling: the skill is'
    + '\n  learnable in one sitting. A curve that keeps climbing means depth pays.\n');
}

function ablate() {
  const n = num('n', 500);
  const blocks = num('blocks', 3);
  const character = str('character', 'default_shop');
  console.log(`\nCapability ablation — ${character}, ${n} runs x ${blocks} disjoint seed blocks\n`);
  const r = capabilityAblation(content, { n, characterId: character, blocks });
  const mean = (a) => a.reduce((x, y) => x + y, 0) / a.length;
  const fmtRange = (d) => {
    const lo = Math.min(...d) * 100; const hi = Math.max(...d) * 100;
    return `${mean(d) * 100 >= 0 ? '+' : ''}${(mean(d) * 100).toFixed(1)}pp `
      + `[${lo.toFixed(1)} to ${hi.toFixed(1)}]`;
  };
  rule(78);
  console.log(`greedy ${fmtPct(mean(r.base))}   planner ${fmtPct(mean(r.full))}   `
    + `gap ${((mean(r.full) - mean(r.base)) * 100).toFixed(1)}pp`);
  rule(78);
  console.log('capability      alone                      removed                    stable');
  rule(78);
  for (let i = 0; i < r.solo.length; i++) {
    const s = r.solo[i]; const d = r.drop[i];
    const stable = signStable(s.deltas) && signStable(d.deltas);
    console.log(`${s.cap.padEnd(14)} ${fmtRange(s.deltas).padEnd(26)} `
      + `${fmtRange(d.deltas).padEnd(26)} ${stable ? 'yes' : 'NO'}`);
  }
  rule(78);
  console.log('\n  Only rows marked stable are safe to conclude from. A row whose'
    + '\n  range spans zero is one draw from the seed space, not a finding.\n');
}

function micro() {
  const n = num('n', 300);
  const blocks = num('blocks', 3);
  const character = str('character', 'default_shop');
  console.log(`\nMicro — ${character}, ${n} runs x ${blocks} disjoint seed blocks`);
  console.log('What the player does DURING the trading day, added to the full planner.\n');
  const rows = microAblation(content, { n, characterId: character, blocks });
  const mean = (a) => a.reduce((x, y) => x + y, 0) / a.length;
  const base = mean(rows[0].rates);
  rule(72);
  console.log('variant                 win rate   per block            delta vs none');
  rule(72);
  for (const r of rows) {
    const m = mean(r.rates);
    const per = r.rates.map((v) => (v * 100).toFixed(1)).join(' ');
    const d = (m - base) * 100;
    console.log(`${r.label.padEnd(22)} ${fmtPct(m).padStart(7)}   ${per.padEnd(20)} `
      + `${(d >= 0 ? '+' : '') + d.toFixed(1)}pp`);
  }
  rule(72);
  console.log('\n  Compare against the pillars this game already has: tempo and'
    + '\n  signage are worth about 11pp each. Under 2pp means decoration.\n');
}

function quota() {
  const n = num('n', 350);
  const character = str('character', 'default_shop');
  const th = content.economy.ratchets.commitThreshold;
  console.log(`\nCommitment by ratchets held — ${character}, ${n} runs per cell`);
  console.log(`Threshold for the commitment bonus is ${th}.\n`);
  rule(48);
  console.log('ratchets held   win rate');
  rule(48);
  const rows = ratchetQuotaCurve(content, { n, characterId: character });
  for (const r of rows) {
    const mark = r.quota >= th ? '  (committed)' : '';
    console.log(`${String(r.quota).padStart(13)}   ${fmtPct(r.winRate).padStart(7)}${mark}`);
  }
  rule(48);
  const none = rows[0].winRate;
  const mid = Math.min(...rows.slice(1, th).map((r) => r.winRate));
  const committed = Math.max(...rows.filter((r) => r.quota >= th).map((r) => r.winRate));
  console.log(`\n  none ${fmtPct(none)}   hedged ${fmtPct(mid)}   committed ${fmtPct(committed)}`);
  console.log(`  the design wants hedged to be the WORST of the three; it is `
    + `${mid < none && mid < committed ? 'holding' : 'NOT holding'}\n`);
}

function commit() {
  const n = num('n', 400);
  const character = str('character', 'default_shop');
  console.log(`\nCommitment — ${character}, ${n} runs per cell\n`);
  const r = commitmentCurves(content, { n, characterId: character });
  rule(58);
  console.log('static mix (0 = pure tempo, 1 = pure scaling)');
  rule(58);
  for (const s of r.statics) {
    console.log(`  bias ${s.bias.toFixed(2)}   ${fmtPct(s.winRate).padStart(7)}`);
  }
  rule(58);
  console.log('pivot schedule (invest until encounter N, then harvest)');
  rule(58);
  for (const p of r.pivots) {
    console.log(`  pivot @${String(p.pivot).padStart(2)}   ${fmtPct(p.winRate).padStart(7)}`);
  }
  rule(58);
  const bestStatic = Math.max(...r.statics.map((s) => s.winRate));
  const bestPivot = Math.max(...r.pivots.map((p) => p.winRate));
  console.log(`\n  best static ${fmtPct(bestStatic)}   best pivot ${fmtPct(bestPivot)}   `
    + `schedule is worth ${((bestPivot - bestStatic) * 100).toFixed(1)}pp over any fixed mix\n`);
}

const commands = {
  panel, check, chars, ladder, bosses, trace, bench, sweep, envelope, fit, bossimpact,
  depth, ablate, commit, quota, micro,
};
if (!commands[cmd]) {
  console.log(`unknown command: ${cmd}\ncommands: ${Object.keys(commands).join(', ')}`);
  process.exit(1);
}
commands[cmd]();
