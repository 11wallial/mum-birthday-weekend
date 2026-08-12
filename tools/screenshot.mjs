#!/usr/bin/env node
// Drives the browser build and captures each phase, so the game can be checked
// without a human in the loop.
//
//   python3 -m http.server 8099 &
//   npm install --no-save playwright
//   node tools/screenshot.mjs [outDir]

import { chromium } from 'playwright';
import { existsSync, mkdirSync } from 'node:fs';

const OUT = process.argv[2] || 'shots';
const URL = process.env.FOOTFALL_URL || 'http://127.0.0.1:8099/';
mkdirSync(OUT, { recursive: true });

// The container ships a Chromium that may not match the installed Playwright
// build number, so point at it rather than downloading a second one.
const EXECUTABLE = process.env.FOOTFALL_CHROME || '/opt/pw-browsers/chromium';
const browser = await chromium.launch(
  existsSync(EXECUTABLE) ? { executablePath: EXECUTABLE } : {},
);
const page = await browser.newPage({ viewport: { width: 1360, height: 860 } });

const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(`PAGEERROR: ${e.message}`));

const shot = (n) => page.screenshot({ path: `${OUT}/${n}.png` });

await page.goto(URL, { waitUntil: 'networkidle' });
await page.waitForTimeout(600);
await shot('1-title');

await page.click('#btn-start');
await page.waitForTimeout(400);
await shot('2-night');

// Take an offer and place it, then settle any boss choice.
const entry = await page.$('#offers .entry');
if (entry) {
  await entry.click();
  await page.waitForTimeout(150);
  const slot = await page.$('.slot.target');
  if (slot) await slot.click();
}
await page.waitForTimeout(200);
const boss = await page.$('#boss-options .bosscard');
if (boss) await boss.click();
await page.waitForTimeout(200);
await shot('3-placed');

// The two sheets, because a page that only ever gets photographed in its
// default state is a page whose other states rot.
await page.click('#btn-map');
await page.waitForTimeout(250);
await shot('3b-runmap');
await page.keyboard.press('Escape');
await page.waitForTimeout(150);
await page.click('#btn-help');
await page.waitForTimeout(250);
await shot('3c-rules');
await page.keyboard.press('Escape');
await page.waitForTimeout(150);

// The card for something already placed. A fixture you cannot re-read is a
// fixture you cannot make a decision about.
const filled = await page.$('.slot.filled');
if (filled) {
  await filled.click();
  await page.waitForTimeout(250);
  await shot('3d-inspect');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(120);
}

await page.click('#btn-open');
await page.waitForTimeout(2600);
await shot('4-day');

// Triage: click a waiting customer.
const box = await page.$('#floor');
if (box) {
  const b = await box.boundingBox();
  await page.mouse.click(b.x + b.width * 0.86, b.y + b.height * 0.55);
}
await page.waitForTimeout(6000);
await shot('5-day-later');

// Run the day out and land on the receipt.
for (let i = 0; i < 60; i++) {
  const onSettle = await page.evaluate(() => !document.getElementById('settle').hidden);
  if (onSettle) break;
  await page.waitForTimeout(700);
}
// The phase change happens at the half-way point of the page turn, so shooting
// the instant it flips photographs the wipe rather than the receipt.
await page.waitForTimeout(900);
await shot('6-receipt');

const stage = await page.evaluate(() => ['title', 'night', 'day', 'settle']
  .filter((i) => !document.getElementById(i).hidden));
const panel = await page.evaluate(() => ({
  footfall: document.getElementById('p-footfall').textContent,
  conv: document.getElementById('p-conv').textContent,
  basket: document.getElementById('p-basket').textContent,
  margin: document.getElementById('p-margin').textContent,
  profit: document.getElementById('p-profit').textContent,
}));

console.log('stage:', stage.join(',') || '(none)');
console.log('panel:', JSON.stringify(panel));
console.log('console errors:', errors.length ? errors.slice(0, 10) : 'none');
await browser.close();
if (errors.length) process.exit(1);
