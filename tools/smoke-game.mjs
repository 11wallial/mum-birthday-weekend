#!/usr/bin/env node
// Plays full runs through the browser build's own run.js and trading-day.js,
// with no DOM. If the game logic is broken this fails long before anyone opens
// a browser, and it doubles as a regression test for the shared engine.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildContent } from '../sim/content-core.js';
import { makeRng } from '../sim/rng.js';
import { createRun } from '../src/run.js';
import { createTradingDay } from '../src/trading-day.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (f) => JSON.parse(readFileSync(join(ROOT, 'data', f), 'utf8'));
const content = buildContent({
  customers: read('customers.json'), fixtures: read('fixtures.json'),
  economy: read('economy.json'), run: read('run.json'),
});

const N = Number(process.argv[2] || 40);
let wins = 0; let daysTotal = 0; let triaged = 0; const deaths = {};

for (let i = 0; i < N; i++) {
  const g = createRun(content, { characterId: 'default_shop', seed: 1000 + i });
  const rng = makeRng(50000 + i);
  for (;;) {
    g.beginNight();
    if (g.run.over) break;
    if (g.run.pendingBossChoice) g.chooseBoss(rng.int(g.run.pendingBossChoice.options.length));
    // Take an offer into a free slot, or combine.
    const pick = g.run.offers[rng.int(g.run.offers.length)];
    const free = g.shop.aisles.flatMap((a, ai) => a.slots.map((s, si) => (s ? null : { aisle: ai, slot: si })))
      .filter(Boolean);
    g.take(pick.id, free.length ? free[rng.int(free.length)] : null);
    if (rng() < 0.4 && g.shop.cash > 800) g.buy('till');

    const day = createTradingDay(content, g.shop, g.ctx(), rng);
    let guard = 0;
    while (!day.state.finished && guard++ < 20000) {
      day.step();
      // Exercise triage: sometimes rescue whoever is closest to leaving.
      if (day.state.triageLeft > 0 && day.state.queue.length > 3 && rng() < 0.25) {
        const worst = day.state.queue.reduce((a, b) => (a.waited / a.patience > b.waited / b.patience ? a : b));
        if (day.triage(worst.id)) triaged++;
      }
    }
    if (!day.state.finished) throw new Error('trading day never finished');
    const entry = g.settle(day.state);
    daysTotal++;
    if (entry.fatal) { deaths[entry.encounter] = (deaths[entry.encounter] || 0) + 1; break; }
    if (g.run.encounter >= content.run.encounters) { g.run.over = true; g.run.won = true; break; }
  }
  if (g.run.won) wins++;
}

const enc = Object.keys(deaths).map(Number).sort((a, b) => a - b);
console.log(`smoke: ${N} runs, ${daysTotal} trading days simulated`);
console.log(`  wins ${wins} (${(wins / N * 100).toFixed(0)}%)  triage actions ${triaged}`);
console.log(`  deaths at encounters: ${enc.join(', ') || 'none'}`);
console.log('PASS — the browser build plays a full run end to end');
