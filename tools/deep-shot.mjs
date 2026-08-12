#!/usr/bin/env node
// Play a dozen days quickly and photograph a shop that has filled up.
//
// The renderer had only ever been checked on day one, where nine tenths of the
// floor is empty, one till stands on the counter and the queue is four people.
// Everything interesting about the drawing — a full board, several tills, a
// queue that stacks, term colours across four aisles — only exists later.
//
//   python3 -m http.server 8099 &
//   node tools/deep-shot.mjs shots

import { chromium } from 'playwright';
import { existsSync, mkdirSync } from 'node:fs';

const OUT = process.argv[2] || 'shots';
const URL = process.env.FOOTFALL_URL || 'http://127.0.0.1:8099/';
mkdirSync(OUT, { recursive: true });

const EXEC = process.env.FOOTFALL_CHROME || '/opt/pw-browsers/chromium';
const browser = await chromium.launch(existsSync(EXEC) ? { executablePath: EXEC } : {});
const page = await browser.newPage({ viewport: { width: 1360, height: 860 } });

const errs = [];
page.on('pageerror', (e) => errs.push(`PAGEERROR: ${e.message}`));
page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });

// Click through the DOM rather than through the mouse: half of these targets
// are conditional, and a missing one should be a no-op rather than a timeout.
const tap = (sel) => page.evaluate((s) => {
  const el = document.querySelector(s);
  if (!el || el.disabled) return false;
  el.click();
  return true;
}, sel);

const visible = (id) => page.evaluate((i) => !document.getElementById(i).hidden, id);

await page.goto(URL, { waitUntil: 'networkidle' });
await page.waitForTimeout(500);
await page.fill('#seed', process.env.FOOTFALL_SEED || '4242');
await tap('#btn-start');
await page.waitForTimeout(500);

const fast = () => page.evaluate(() => {
  const b = document.getElementById('btn-speed');
  for (let i = 0; i < 4 && !/4/.test(b.textContent); i++) b.click();
});

let day = 0;
let ended = '';
for (day = 1; day <= 14; day++) {
  await tap('#coach-x');
  await tap('#boss-options .bosscard');
  await page.waitForTimeout(120);
  // Take the best line on the page rather than the first. A bot that picks at
  // random dies on day three — which is exactly what sim/cli.js check says a
  // random policy does, so it is not a bug, it is a bot that cannot play.
  await page.evaluate(() => {
    const rank = { flagship: 3, rare: 2, uncommon: 1, common: 0 };
    const best = [...document.querySelectorAll('#offers .entry')]
      .filter((e) => !e.classList.contains('passed') && !e.classList.contains('ordered'))
      .sort((a, b) => {
        const ra = [...a.classList].find((c) => c.startsWith('r-')).slice(2);
        const rb = [...b.classList].find((c) => c.startsWith('r-')).slice(2);
        return (rank[rb] ?? 0) - (rank[ra] ?? 0);
      })[0];
    if (best) best.click();
  });
  await page.waitForTimeout(150);
  await tap('.slot.target');
  await page.waitForTimeout(120);
  await tap('#i-yes');                      // confirm a scrap, once the board fills
  // Spend whatever is left; an empty till and one aisle is not a shop.
  for (let k = 0; k < 3; k++) {
    if (!await page.evaluate(() => {
      const b = [...document.querySelectorAll('#buys .buy')].find((x) => !x.disabled);
      if (!b) return false;
      b.click();
      return true;
    })) break;
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(200);
  if (!await tap('#btn-open')) break;
  await fast();
  for (let i = 0; i < 120; i++) {
    if (await visible('settle')) break;
    await page.waitForTimeout(250);
  }
  await page.waitForTimeout(700);
  const label = await page.evaluate(() => document.getElementById('btn-continue').textContent);
  if (label !== 'Lock up') { ended = label; break; }
  await tap('#btn-continue');
  await page.waitForTimeout(700);
}

console.log(`reached day ${day}${ended ? ` — ${ended}` : ''}`);
await page.screenshot({ path: `${OUT}/deep-night.png` });
await tap('#btn-map');
await page.waitForTimeout(300);
await page.screenshot({ path: `${OUT}/deep-runmap.png` });
await page.keyboard.press('Escape');
await page.waitForTimeout(150);
if (await tap('#btn-open')) {
  await page.waitForTimeout(4200);
  await page.screenshot({ path: `${OUT}/deep-day.png` });
}
console.log('console errors:', errs.length ? errs.slice(0, 8) : 'none');
await browser.close();
if (errs.length) process.exit(1);
