#!/usr/bin/env node
// Record the soundtrack, and measure it.
//
// Everything else in tools/ looks at the game. Nothing listened to it, so the
// only evidence the audio worked was that it did not throw — which is equally
// true of silence. This drives createAudio() through a scripted run: the cover,
// the catalogue, a trading day with a run of sales, and the receipt. It writes
// a webm you can play and prints levels you can argue with.
//
//   python3 -m http.server 8099 &
//   node tools/audio-shot.mjs shots/footfall.webm

import { chromium } from 'playwright';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const OUT = process.argv[2] || 'shots/footfall-audio.webm';
const URL = process.env.FOOTFALL_URL || 'http://127.0.0.1:8099/';
mkdirSync(dirname(OUT), { recursive: true });

const EXEC = process.env.FOOTFALL_CHROME || '/opt/pw-browsers/chromium';
const browser = await chromium.launch({
  ...(existsSync(EXEC) ? { executablePath: EXEC } : {}),
  args: ['--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage();
const errs = [];
page.on('pageerror', (e) => errs.push(`PAGEERROR: ${e.message}`));
page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });

await page.goto(`${URL}tools/audio-harness.html`, { waitUntil: 'networkidle' });

// A whole loop of the game, in order, at the pace it is actually played.
const plan = [
  { phase: 'title', ms: 7000 },
  { call: 'ui', ms: 400 },
  { phase: 'night', ms: 2600 },
  { call: 'place', ms: 1200 },
  { call: 'combine', args: [2], ms: 1600 },
  { call: 'combine', args: [3], ms: 2200 },
  { call: 'boss', ms: 2600 },
  { phase: 'day', ms: 300 },
  { call: 'tannoy', frenzy: 0.15, ms: 2600 },
  // A run of sales: the ladder is the point, so it has to be heard as a run.
  ...Array.from({ length: 8 }, () => ({ call: 'sale', ms: 330 })),
  { frenzy: 0.55, ms: 900 },
  { call: 'walkout', ms: 700 },
  { call: 'triage', ms: 700 },
  ...Array.from({ length: 5 }, () => ({ call: 'sale', ms: 260 })),
  { frenzy: 0.9, ms: 2400 },
  { call: 'sale', ms: 300 },
  { call: 'sale', ms: 300 },
  { call: 'sale', ms: 1400 },
  { phase: 'settle', frenzy: 0, ms: 200 },
  { call: 'receipt', ms: 900 },
  { call: 'verdict', args: [true], ms: 4200 },
  { phase: 'night', ms: 3200 },
];

const res = await page.evaluate((p) => window.recordAudio(p), plan);
writeFileSync(OUT, Buffer.from(res.b64, 'base64'));
const wav = OUT.replace(/\.webm$/, '.wav');
writeFileSync(wav, Buffer.from(res.wavB64, 'base64'));

const secs = res.frames / 10;
console.log(`wrote ${OUT} and ${wav} — ~${secs.toFixed(0)}s`);
console.log(`mean RMS  ${res.meanRms.toFixed(4)}`);
console.log(`max RMS   ${res.maxRms.toFixed(4)}`);
console.log(`max peak  ${res.maxPeak.toFixed(4)}${res.clipped ? `  (${res.clipped} clipped frames)` : ''}`);
console.log(`silence   ${res.silentFrames}/${res.frames} frames`);
console.log('\nsame song, different mix');
console.log('  phase    level   brightness');
for (const [k, v] of Object.entries(res.byPhase)) {
  console.log(`  ${k.padEnd(8)} ${v.rms.toFixed(4)}  ${Math.round(v.cen)} Hz`);
}
console.log('console errors:', errs.length ? errs.slice(0, 6) : 'none');

await browser.close();
// A soundtrack that is silent a third of the time, or that pins the limiter,
// is a bug the screenshotter can never see.
if (errs.length) process.exit(1);
if (res.meanRms < 0.005) { console.error('FAIL — effectively silent'); process.exit(1); }
if (res.silentFrames > res.frames * 0.12) { console.error('FAIL — long silences'); process.exit(1); }
if (res.clipped > res.frames * 0.02) { console.error('FAIL — clipping'); process.exit(1); }
console.log('\nPASS — it makes a sound, all the way through, without clipping');
