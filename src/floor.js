// Day: the cutaway floor.
//
// Richard Scarry cross-section. The shop as a doll's house cutaway, aisles as
// stacked horizontal lanes, customers walking left to right. Flat bright
// colour, clean black line, no gradients and no lighting model — every asset is
// a flat side-on shape, which is the cheapest thing on the shortlist to draw
// and the one that shares print DNA with the catalogue.
//
// Each customer type has to be silhouette-distinct at a glance, because at two
// thousand Footfall that silhouette is all you get.

import { PHASE } from './trading-day.js';
import {
  INK, PAPER, contact, halftone, rr, screenRect, easeOutCubic,
} from './art.js';

// What fraction of the time between two shelves is spent moving. The rest is
// spent standing still, which is the point.
const HOP_SHARE = 0.34;

/** Roughly one pendant every this many pixels, snapped to a whole number. */
const bwSpacing = (w) => w / Math.max(2, Math.round(w / 210));

const COLOUR = {
  family: '#d6206a', student: '#0aa3c2', pensioner: '#7a5cbf', trade: '#e07b1a',
  luxury: '#0f8a4a', tourist: '#f2b90c', browser: '#9a9086', shoplifter: '#2a2622',
};

// A shelf takes the colour of the TERM it feeds, not its rarity.
//
// Rarity was the wrong variable to paint with. Most of what a shop holds is
// common, so most of the shop came out in one red — a monotone floor that told
// the player nothing they could not read off the card, and that fought the
// customers for attention. Term is the thing a build is actually made of, so
// colouring by it turns the floor into a diagram of the shop: four cyan units
// and one green one is a Footfall build with a Margin problem, seen at a
// glance and without reading a word. Rarity still shows, as furniture — a
// heavier barker and a gold star.
const TERM_TONE = {
  footfall: '#0e8fb5', conversion: '#d81e63', basket: '#e8a80c', margin: '#17703c',
};
const shelfTone = (def) => TERM_TONE[def.term] || '#8a5a3c';

/** Stable pseudo-random in 0..1 from three integers. No allocation, no state. */
function hash(a, b, c) {
  let n = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791);
  n = (n ^ (n >>> 13)) >>> 0;
  return ((n * 1274126177) >>> 0) / 4294967296;
}

/**
 * A person, drawn as an illustration rather than as a rounded rectangle.
 *
 * Every figure gets legs that actually stride, an arm that swings, a contact
 * shadow, a coat in the type's colour laid as a dot screen, and one accessory
 * that carries the read at a glance. The old version was a capsule and a
 * circle: silhouette-distinct in principle, placeholder-grade in practice.
 *
 * `phase01` is where the figure is in its own stride, 0..1. Standing figures
 * are given a slow idle sway instead so nothing on the floor is ever perfectly
 * still — stillness is what made the shop look paused.
 */
function drawPerson(g, t, x, y, s, walkPhase, onFloor = false, idle = 0) {
  const c = COLOUR[t.id] || '#8a8175';
  const stride = Math.sin(walkPhase * Math.PI * 2);
  const lift = Math.abs(Math.cos(walkPhase * Math.PI * 2)) * s * 0.035;
  const sway = Math.sin(idle) * s * 0.012;

  contact(g, x, y + 1, s * (t.id === 'family' ? 1.15 : 0.85), onFloor ? 0.1 : 0.2);

  g.save();
  g.translate(x + sway, y - (walkPhase > 0 ? lift : 0));
  g.globalAlpha *= onFloor ? 0.62 : 1;
  const line = onFloor ? 'rgba(25,20,16,.6)' : INK;
  g.lineWidth = Math.max(1, s * 0.075);
  g.lineJoin = 'round';
  g.lineCap = 'round';

  const H = s;                    // shoulder height above the floor line
  const legTop = -H * 0.42;

  // Legs first, so the coat overlaps them.
  g.strokeStyle = line;
  g.lineWidth = Math.max(1.4, s * 0.1);
  g.beginPath();
  g.moveTo(-s * 0.07, legTop);
  g.lineTo(-s * 0.07 + stride * s * 0.17, -s * 0.01);
  g.moveTo(s * 0.07, legTop);
  g.lineTo(s * 0.07 - stride * s * 0.17, -s * 0.01);
  g.stroke();

  // Coat: a screened body, misregistered a hair so it reads as printed.
  const bw = t.id === 'trade' ? s * 0.62 : s * 0.5;
  const bh = H * 0.66;
  g.save();
  g.globalAlpha *= 0.45;
  g.fillStyle = c;
  rr(g, -bw / 2 + 1.2, -H * 0.98 + 1.2, bw, bh, s * 0.12);
  g.fill();
  g.restore();
  g.fillStyle = halftone(g, c, Math.max(2, s * 0.09), 0.95);
  rr(g, -bw / 2, -H * 0.98, bw, bh, s * 0.12);
  g.fill();
  g.strokeStyle = line;
  g.lineWidth = Math.max(1, s * 0.075);
  g.stroke();

  // Arm, swinging opposite the leading leg.
  g.beginPath();
  g.moveTo(bw * 0.36, -H * 0.86);
  g.lineTo(bw * 0.36 - stride * s * 0.13, -H * 0.42);
  g.stroke();

  // Head.
  g.fillStyle = '#f0d9bd';
  g.beginPath();
  g.arc(0, -H * 1.12, s * 0.19, 0, Math.PI * 2);
  g.fill();
  g.stroke();

  // One accessory each. This is what does the actual identifying.
  g.fillStyle = INK;
  switch (t.id) {
    case 'family': { // a child alongside, holding on
      g.save();
      g.translate(s * 0.34, 0);
      g.scale(0.58, 0.58);
      g.fillStyle = halftone(g, c, Math.max(2, s * 0.07), 0.95);
      rr(g, -s * 0.24, -H * 0.98, s * 0.48, H * 0.66, s * 0.1);
      g.fill(); g.stroke();
      g.fillStyle = '#f0d9bd';
      g.beginPath(); g.arc(0, -H * 1.12, s * 0.19, 0, Math.PI * 2); g.fill(); g.stroke();
      g.restore();
      break;
    }
    case 'student': // satchel on a strap
      g.strokeStyle = line;
      g.beginPath(); g.moveTo(-bw * 0.2, -H * 0.95); g.lineTo(bw * 0.5, -H * 0.6); g.stroke();
      g.fillStyle = '#3b4a52';
      rr(g, bw * 0.34, -H * 0.66, s * 0.26, s * 0.3, 2); g.fill(); g.stroke();
      break;
    case 'pensioner': // stick, and a hat
      g.beginPath(); g.moveTo(bw * 0.62, -H * 0.5); g.lineTo(bw * 0.68, 0); g.stroke();
      g.fillStyle = '#6b6155';
      rr(g, -s * 0.24, -H * 1.34, s * 0.48, s * 0.11, 2); g.fill(); g.stroke();
      break;
    case 'trade': // a box under the arm, and a flat cap
      g.fillStyle = halftone(g, '#b4772f', 3, 1);
      g.fillRect(-bw * 0.78, -H * 0.86, s * 0.42, s * 0.34);
      g.strokeRect(-bw * 0.78, -H * 0.86, s * 0.42, s * 0.34);
      g.fillStyle = '#4a4038';
      g.beginPath();
      g.moveTo(-s * 0.24, -H * 1.26); g.lineTo(s * 0.2, -H * 1.28);
      g.lineTo(s * 0.26, -H * 1.2); g.lineTo(-s * 0.24, -H * 1.19);
      g.closePath(); g.fill(); g.stroke();
      break;
    case 'luxury': // top hat and a long coat
      g.fillStyle = INK;
      g.fillRect(-s * 0.3, -H * 1.32, s * 0.6, s * 0.06);
      g.fillRect(-s * 0.19, -H * 1.62, s * 0.38, s * 0.31);
      g.strokeRect(-s * 0.19, -H * 1.62, s * 0.38, s * 0.31);
      break;
    case 'tourist': // camera at the chest
      g.strokeStyle = line;
      g.beginPath(); g.arc(0, -H * 0.98, s * 0.16, 0.15, Math.PI - 0.15); g.stroke();
      g.fillStyle = INK;
      rr(g, -s * 0.12, -H * 0.84, s * 0.24, s * 0.17, 2); g.fill(); g.stroke();
      break;
    case 'browser': // hands behind the back, head tilted at a shelf
      g.strokeStyle = line;
      g.beginPath(); g.arc(-bw * 0.42, -H * 0.62, s * 0.09, -1, 2); g.stroke();
      break;
    case 'shoplifter': // collar up, one hand in the coat
      g.fillStyle = INK;
      g.beginPath();
      g.moveTo(-s * 0.2, -H * 1.02); g.lineTo(0, -H * 1.2); g.lineTo(s * 0.2, -H * 1.02);
      g.lineTo(s * 0.12, -H * 0.9); g.lineTo(-s * 0.12, -H * 0.9);
      g.closePath(); g.fill();
      break;
    default: break;
  }
  g.restore();
}

export function createFloorRenderer(canvas) {
  const g = canvas.getContext('2d');
  let hitboxes = [];
  // Where feedback should come from. Events happen at the till, so that is
  // where coins fly off and crosses appear — anywhere else and the eye has to
  // hunt for what just changed.
  let till = { x: 0, y: 0 };
  let queueRight = 0;

  function resize() {
    const r = canvas.getBoundingClientRect();
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = Math.max(320, r.width * dpr);
    canvas.height = Math.max(200, r.height * dpr);
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { w: r.width, h: r.height };
  }

  function draw(day, shop, particles) {
    const { w, h } = resize();
    const s = day.state;
    const t = s.tick;
    const frenzy = s.frenzy;

    g.clearRect(0, 0, w, h);
    g.fillStyle = '#f7efdb';
    g.fillRect(0, 0, w, h);

    const lanes = s.openAisles.length;
    const padT = 8;
    const padB = 8;
    const laneH = (h - padT - padB) / lanes;
    // The till end is the only part of this screen you can act on, so it gets
    // a third of it. It used to get a strip: the queue stacked eight deep in a
    // column while four fifths of the screen showed people walking past
    // shelves, which is the part you cannot touch.
    const tillX = Math.round(w * 0.66);
    // The floor strip customers walk along sits at the bottom of each lane;
    // the shelving stands on it. Person height is set from the strip, not the
    // whole lane, so three aisles and five still read the same.
    // Guarded at the source. Every size below is derived from these two, so a
    // short canvas or a five-aisle shop used to push half the geometry
    // negative and canvas throws on that rather than clamping.
    const strip = Math.max(18, Math.min(laneH * 0.5, 74));
    const person = Math.max(12, Math.min(strip * 0.78, 46));
    // Which bays have somebody standing at them right now.
    //
    // Nothing on the floor reacted when a fixture did its job: the customer
    // walked, the number moved, and the two were never visibly connected. A
    // bay with a customer at it lights its barker, so "every fixture fires as
    // they pass" is something you watch rather than something you read in the
    // rules. It is computed before the shelving is drawn because the shelving
    // is drawn first.
    const busy = new Set();
    for (const c of s.customers) {
      if (c.phase !== PHASE.WALKING) continue;
      const nSlots = Math.max(1, shop.aisles[c.aisle].slots.length);
      const idx = Math.min(nSlots, Math.floor(c.progress * (nSlots + 1)));
      if (idx >= 1) busy.add(`${c.lane}:${idx - 1}`);
    }

    const lw = 1.5 + frenzy * 1.5;
    g.lineWidth = lw;
    g.strokeStyle = '#16130f';
    g.textAlign = 'center';

    for (let li = 0; li < lanes; li++) {
      const a = s.openAisles[li];
      const aisle = shop.aisles[a];
      const top = padT + li * laneH;
      const floorY = top + laneH - 6;
      const shelfBase = floorY - strip * 0.5;
      // Shelf height is a property of the lane, not of the bay, so it is
      // settled before anything in the lane is drawn — the pendant lights hang
      // from a rod down to it, which is both what a shop looks like and what
      // stops the lamps colliding with the barkers on a five-aisle floor.
      // Never negative: at five aisles the lane is short enough that the
      // derived height went below zero and every stock item drew inside out.
      const uh = Math.max(22, Math.min(laneH - strip * 0.55 - 30, 150));
      const y0 = shelfBase - uh;

      // --- the room ----------------------------------------------------
      // Back wall, skirting, floor. Three tones instead of one flat fill is
      // the difference between a room and a rectangle, and it costs nothing.
      screenRect(g, 0, top, tillX, laneH - 3, li % 2 ? '#c9b489' : '#c2ac80', 4, 0.34);
      g.fillStyle = '#efe2c0';
      g.fillRect(0, floorY, tillX, laneH - 3 - (floorY - top));
      // Floor boards, receding — the only perspective cue the cutaway gets.
      g.strokeStyle = 'rgba(25,20,16,.10)';
      g.lineWidth = 1;
      for (let bx = 0; bx < tillX; bx += 34) {
        g.beginPath(); g.moveTo(bx, floorY); g.lineTo(bx - 7, top + laneH - 3); g.stroke();
      }
      // Skirting board.
      g.fillStyle = '#b9a276';
      g.fillRect(0, floorY - 4, tillX, 4);
      g.strokeStyle = INK;
      g.lineWidth = lw;
      g.beginPath();
      g.moveTo(0, floorY); g.lineTo(tillX, floorY);
      g.stroke();

      // Pendant lights, hung on a rod that reaches down to just above the
      // shelving. They used to be pinned 9px under the ceiling whatever the
      // lane height, which on a tall lane left them stranded in blank wall and
      // on a short one put them through the shelf barkers.
      const lampY = Math.max(top + 8, y0 - 22);
      for (let px = bwSpacing(tillX); px < tillX; px += bwSpacing(tillX)) {
        g.strokeStyle = 'rgba(25,20,16,.55)';
        g.lineWidth = 1.4;
        g.beginPath(); g.moveTo(px, top); g.lineTo(px, lampY); g.stroke();
        g.fillStyle = '#f7c331';
        g.beginPath();
        g.moveTo(px - 8, lampY + 7); g.lineTo(px + 8, lampY + 7);
        g.lineTo(px + 3, lampY); g.lineTo(px - 3, lampY);
        g.closePath(); g.fill();
        g.strokeStyle = INK; g.lineWidth = 1.2; g.stroke();
        // The pool of light it throws. Kept faint and wide: at the old value
        // it read as a vertical streak down an empty lane rather than as
        // light, which is the sort of thing that looks like a bug.
        g.save();
        g.globalAlpha = 0.05;
        g.fillStyle = '#f7c331';
        g.beginPath();
        g.moveTo(px - 7, lampY + 7); g.lineTo(px + 7, lampY + 7);
        g.lineTo(px + 34, floorY); g.lineTo(px - 34, floorY);
        g.closePath(); g.fill();
        g.restore();
      }
      g.strokeStyle = INK;
      g.lineWidth = lw;

      // --- shelving ------------------------------------------------------
      const n = aisle.slots.length;
      const bw = tillX / n;
      for (let i = 0; i < n; i++) {
        const inst = aisle.slots[i];
        const x0 = i * bw + bw * 0.08;
        const uw = bw * 0.84;
        if (!inst) {
          // An empty bay is a real thing in a real shop: a stripped unit with
          // bare boards on it. It used to be three ghost lines at 30% alpha,
          // which reads as an unfinished interface rather than as a gap in a
          // shop — and two thirds of an early floor is empty.
          const eh = uh * 0.72;
          const ey = shelfBase - eh;
          contact(g, x0 + uw / 2, shelfBase + 1, uw * 0.9, 0.12, 0.02);
          g.save();
          g.fillStyle = '#e7dbbc';
          g.fillRect(x0 + uw * 0.06, ey, uw * 0.88, eh);
          g.strokeStyle = 'rgba(25,20,16,.4)';
          g.lineWidth = 1.2;
          g.strokeRect(x0 + uw * 0.06, ey, uw * 0.88, eh);
          for (let r = 1; r < 3; r++) {
            const sy = ey + (eh / 3) * r;
            g.fillStyle = '#cdbb93';
            g.fillRect(x0 + uw * 0.06, sy, uw * 0.88, 2.5);
            g.strokeRect(x0 + uw * 0.06, sy, uw * 0.88, 2.5);
          }
          g.restore();
          g.strokeStyle = INK;
          g.lineWidth = lw;
          continue;
        }
        const tone = shelfTone(inst.def);

        // Carcass, with a plate offset behind it.
        g.save();
        g.globalAlpha = 0.35;
        g.fillStyle = tone;
        g.fillRect(x0 + 2, y0 + 2, uw, uh);
        g.restore();
        g.fillStyle = '#fdf7e8';
        g.fillRect(x0, y0, uw, uh);
        g.strokeRect(x0, y0, uw, uh);

        // Shelf boards, drawn with thickness so they are joinery rather than
        // hairlines, and stock that varies in shape and height per shelf.
        const rows = 3;
        for (let r = 0; r < rows; r++) {
          const sy = y0 + (uh / rows) * (r + 1);
          const cell = uh / rows;
          // Varied, and not full. Fifteen identically-sized marks per unit
          // across fifteen units reads as wallpaper — a real shelf has gaps
          // where things have sold, sizes that disagree, and the odd thing
          // stacked two high. All of it comes off one hash so it is stable
          // frame to frame and costs nothing.
          const items = 3 + (hash(i, r, 1) * 3 | 0);
          for (let k = 0; k < items; k++) {
            const seed = hash(i * 31 + k, r, 7);
            if (seed < 0.13) continue;            // a gap where stock has gone
            const slotW = uw / items;
            const iw = slotW * (0.44 + seed * 0.34);
            const kind = (i * 7 + r * 3 + k) % 3;
            const ih = cell * (0.36 + hash(k, i + r, 3) * 0.4);
            const ix = x0 + slotW * k + (slotW - iw) / 2;
            // Solid at this size. A dot screen only reads as a screen when
            // there is room for several dots across the shape; on a 12px tin
            // it reads as damage.
            g.fillStyle = tone;
            g.globalAlpha = 0.6 + seed * 0.4;
            if (kind === 2) {                     // bottles
              rr(g, ix + iw * 0.2, sy - ih, iw * 0.6, ih, 1.5);
              g.fill();
              g.fillRect(ix + iw * 0.36, sy - ih - cell * 0.12, iw * 0.28, cell * 0.12);
            } else if (kind === 1) {              // tins
              rr(g, ix, sy - ih, iw, ih, iw * 0.16);
              g.fill();
            } else {                              // boxes
              g.fillRect(ix, sy - ih, iw, ih);
            }
            g.strokeStyle = 'rgba(25,20,16,.55)';
            g.lineWidth = 1;
            g.globalAlpha = 1;
            if (kind === 0) g.strokeRect(ix, sy - ih, iw, ih); else g.stroke();
            // Something stacked on top, now and then.
            if (seed > 0.82 && ih < cell * 0.55) {
              g.fillStyle = tone;
              g.globalAlpha = 0.5 + seed * 0.3;
              g.fillRect(ix + iw * 0.12, sy - ih - cell * 0.2, iw * 0.76, cell * 0.19);
              g.globalAlpha = 1;
              g.strokeRect(ix + iw * 0.12, sy - ih - cell * 0.2, iw * 0.76, cell * 0.19);
            }
          }
          // The board itself.
          g.fillStyle = '#c8b285';
          g.fillRect(x0, sy, uw, 3);
          g.strokeStyle = INK;
          g.lineWidth = lw;
          g.strokeRect(x0, sy, uw, 3);
          // A price ticket clipped to the front edge, every other shelf.
          if ((i + r) % 2 === 0 && uw > 54) {
            g.fillStyle = '#fffdf4';
            g.fillRect(x0 + uw * 0.1, sy + 3, uw * 0.16, 5);
            g.fillStyle = 'rgba(25,20,16,.42)';
            g.fillRect(x0 + uw * 0.115, sy + 5, uw * 0.13, 1.2);
            g.strokeStyle = 'rgba(25,20,16,.35)';
            g.lineWidth = 0.8;
            g.strokeRect(x0 + uw * 0.1, sy + 3, uw * 0.16, 5);
            g.strokeStyle = INK;
            g.lineWidth = lw;
          }
        }

        // Header board — a shelf barker, hung slightly askew, and lit while
        // somebody is standing at the bay.
        const firing = busy.has(`${li}:${i}`);
        g.save();
        g.translate(x0 + uw / 2, y0 - 8);
        g.rotate(((i % 2) ? 1 : -1) * 0.012);
        if (firing) {
          const beat = 0.5 + 0.5 * Math.sin(t * 0.4 + i);
          g.save();
          g.globalAlpha = 0.2 + beat * 0.24;
          g.fillStyle = '#f7c331';
          g.fillRect(-uw / 2 - 7, -15, uw + 14, 30);
          g.restore();
          g.scale(1 + beat * 0.035, 1 + beat * 0.05);
        }
        g.fillStyle = tone;
        g.fillRect(-uw / 2, -8, uw, 16);
        g.strokeRect(-uw / 2, -8, uw, 16);
        // Rarity is furniture now that term has the colour: a rare line gets a
        // second rule inside the barker, a flagship gets two.
        if (inst.def.rarity === 'rare' || inst.def.rarity === 'flagship') {
          g.lineWidth = 1;
          g.strokeRect(-uw / 2 + 2.5, -5.5, uw - 5, 11);
          if (inst.def.rarity === 'flagship') g.strokeRect(-uw / 2 + 4.5, -3.5, uw - 9, 7);
          g.lineWidth = lw;
        }
        g.fillStyle = inst.def.term === 'basket' ? INK : '#fff';
        g.font = `700 ${Math.max(8, Math.min(11, uw * 0.105))}px Inter, sans-serif`;
        g.fillText(inst.def.name.toUpperCase().slice(0, 18), 0, 4);
        g.restore();

        if (inst.level > 1) {
          // A gold star for a levelled line, which is what a catalogue would
          // put there.
          g.save();
          g.translate(x0 + uw - 12, y0 + 11);
          g.fillStyle = '#f7c331';
          g.beginPath();
          for (let a = 0; a < 10; a++) {
            const rad = a % 2 ? 4.4 : 9;
            const ang = (a / 10) * Math.PI * 2 - Math.PI / 2;
            const fn = a ? 'lineTo' : 'moveTo';
            g[fn](Math.cos(ang) * rad, Math.sin(ang) * rad);
          }
          g.closePath(); g.fill();
          g.lineWidth = 1.2; g.strokeStyle = INK; g.stroke();
          g.fillStyle = INK;
          g.font = '700 8px Inter, sans-serif';
          g.fillText(String(inst.level), 0, 3);
          g.restore();
          g.lineWidth = lw;
        }
      }
    }

    // --- the front of shop -------------------------------------------------
    // The till hall. This was, in order down the screen: a window, a very
    // large nothing, and a thin red band at the bottom that read as a rug.
    // Three quarters of the only part of the screen the player can act on was
    // empty, which is most of why the day looked unfinished.
    const frontW = w - tillX;
    const frontH = h - padT - padB;
    screenRect(g, tillX, padT, frontW, frontH, '#c2ac80', 4, 0.3);
    g.fillStyle = '#efe2c0';
    g.fillRect(tillX + 1, padT + 1, frontW - 2, frontH - 2);

    const winY = padT + 20;
    const winH = Math.min(132, frontH * 0.34);
    const counterH = 30;
    const counterY = h - padB - counterH - 26;

    // Tiled floor. The aisles have boards; the till hall is tiled, which
    // separates the two halves of the shop and — mostly — puts something
    // under the queue's feet.
    const tile = Math.max(20, Math.min(38, frontW / 6));
    g.save();
    g.beginPath();
    g.rect(tillX + 1, winY + winH, frontW - 2, counterY - winY - winH);
    g.clip();
    for (let ty = winY + winH; ty < counterY; ty += tile) {
      for (let tx = tillX; tx < w; tx += tile) {
        const dark = (Math.round(tx / tile) + Math.round(ty / tile)) % 2 === 0;
        g.fillStyle = dark ? '#e3d3ac' : '#f3e8cc';
        g.fillRect(tx, ty, tile, tile);
      }
    }
    g.strokeStyle = 'rgba(25,20,16,.09)';
    g.lineWidth = 1;
    for (let ty = winY + winH; ty < counterY; ty += tile) {
      g.beginPath(); g.moveTo(tillX, ty); g.lineTo(w, ty); g.stroke();
    }
    g.restore();

    // The window, and the street beyond it. A flat pale rectangle is a hole in
    // the wall; a skyline is a shop that is somewhere.
    g.fillStyle = '#bfdfec';
    g.fillRect(tillX + 14, winY, frontW - 28, winH);
    g.save();
    g.beginPath();
    g.rect(tillX + 14, winY, frontW - 28, winH);
    g.clip();
    // Buildings across the road, in two planes so it has depth.
    const base = winY + winH * 0.74;
    g.fillStyle = 'rgba(25,20,16,.13)';
    for (let bx = tillX + 8, k = 0; bx < w; bx += 34, k++) {
      const bh = 34 + ((k * 37) % 5) * 9;
      g.fillRect(bx, base - bh, 30, bh);
    }
    g.fillStyle = 'rgba(25,20,16,.24)';
    for (let bx = tillX + 22, k = 0; bx < w; bx += 46, k++) {
      const bh = 22 + ((k * 53) % 4) * 8;
      g.fillRect(bx, base - bh, 40, bh);
      g.fillStyle = 'rgba(247,239,219,.55)';       // lit windows
      for (let wy = 0; wy < 2; wy++) {
        for (let wx = 0; wx < 3; wx++) {
          if ((k + wx + wy) % 3 === 0) g.fillRect(bx + 6 + wx * 11, base - bh + 7 + wy * 12, 6, 7);
        }
      }
      g.fillStyle = 'rgba(25,20,16,.24)';
    }
    // The pavement, and someone going past on it.
    g.fillStyle = 'rgba(25,20,16,.10)';
    g.fillRect(tillX + 14, base, frontW - 28, winH);
    const px = tillX + 20 + ((t * 0.7) % (frontW - 20));
    g.fillStyle = 'rgba(25,20,16,.35)';
    g.fillRect(px, base - 15, 5, 11);
    g.beginPath(); g.arc(px + 2.5, base - 18, 3, 0, Math.PI * 2); g.fill();
    g.restore();

    g.strokeStyle = INK;
    g.lineWidth = lw + 0.6;
    g.strokeRect(tillX + 14, winY, frontW - 28, winH);
    g.lineWidth = 1.4;
    for (let k = 1; k < 3; k++) {
      const gx = tillX + 14 + ((frontW - 28) / 3) * k;
      g.beginPath(); g.moveTo(gx, winY); g.lineTo(gx, winY + winH); g.stroke();
    }
    g.beginPath();
    g.moveTo(tillX + 14, winY + winH * 0.34);
    g.lineTo(tillX + frontW - 14, winY + winH * 0.34);
    g.stroke();
    // Signwritten across the glass, reversed, as it would be from inside.
    g.fillStyle = 'rgba(25,20,16,.34)';
    g.font = `700 ${Math.min(19, frontW * 0.075)}px Inter, sans-serif`;
    g.fillText('OPEN', tillX + frontW / 2, winY + winH * 0.24);

    // A striped valance under the window head. One stripe of saturated colour
    // is what the whole screen was missing.
    const vh = 13;
    for (let sx = tillX + 6, k = 0; sx < w - 6; sx += 15, k++) {
      g.fillStyle = k % 2 ? '#d63426' : '#f7efdb';
      g.beginPath();
      g.moveTo(sx, winY + winH);
      g.lineTo(Math.min(w - 6, sx + 15), winY + winH);
      g.lineTo(Math.min(w - 6, sx + 15), winY + winH + vh * 0.6);
      g.lineTo(Math.min(w - 6, sx + 7.5), winY + winH + vh);
      g.lineTo(sx, winY + winH + vh * 0.6);
      g.closePath(); g.fill();
    }
    g.strokeStyle = INK;
    g.lineWidth = 1.2;
    g.beginPath();
    g.moveTo(tillX + 6, winY + winH); g.lineTo(w - 6, winY + winH);
    g.stroke();

    // Daylight pooling on the tiles.
    g.save();
    g.globalAlpha = 0.16;
    g.fillStyle = '#cfe6ef';
    g.beginPath();
    g.moveTo(tillX + 14, winY + winH + vh);
    g.lineTo(tillX + frontW - 14, winY + winH + vh);
    g.lineTo(tillX + frontW - 2, counterY);
    g.lineTo(tillX + 2, counterY);
    g.closePath(); g.fill();
    g.restore();

    // --- the wall the queue faces ------------------------------------------
    // On a tall canvas with five aisles the hall is six hundred pixels of
    // empty tiling, because everything in it was pinned to the window at the
    // top or the counter at the bottom. A shop puts things on that wall.
    const wallY = winY + winH + vh + 12;
    if (counterY - wallY > 120) {
      // A price board: TODAY, and a few ruled lines of nothing in particular.
      const bw2 = Math.min(190, frontW * 0.46);
      const bx = tillX + frontW - bw2 - 16;
      contact(g, bx + bw2 / 2, wallY + 78, bw2, 0.1, 0.02);
      g.fillStyle = '#26221c';
      g.fillRect(bx, wallY, bw2, 74);
      g.strokeStyle = INK; g.lineWidth = lw;
      g.strokeRect(bx, wallY, bw2, 74);
      g.fillStyle = '#f7c331';
      g.font = '700 13px Inter, sans-serif';
      g.fillText('TODAY', bx + bw2 / 2, wallY + 18);
      g.fillStyle = 'rgba(247,239,219,.5)';
      for (let r = 0; r < 3; r++) {
        g.fillRect(bx + 12, wallY + 30 + r * 13, bw2 * (0.42 + (r % 2) * 0.2), 3);
        g.fillRect(bx + bw2 - 40, wallY + 30 + r * 13, 26, 3);
      }

      // A clock, because a shop that opens at nine has one on the wall.
      const cx2 = tillX + 46;
      g.fillStyle = '#efe2c0';
      g.beginPath(); g.arc(cx2, wallY + 30, 21, 0, Math.PI * 2); g.fill();
      g.strokeStyle = INK; g.lineWidth = lw + 0.5; g.stroke();
      g.lineWidth = 2;
      const mins = (s.tick / Math.max(1, s.ticks)) * (8.5 * 60) + 9 * 60;
      g.beginPath();
      g.moveTo(cx2, wallY + 30);
      g.lineTo(cx2 + Math.sin((mins / 720) * Math.PI * 2) * 11,
        wallY + 30 - Math.cos((mins / 720) * Math.PI * 2) * 11);
      g.moveTo(cx2, wallY + 30);
      g.lineTo(cx2 + Math.sin((mins / 60) * Math.PI * 2) * 15,
        wallY + 30 - Math.cos((mins / 60) * Math.PI * 2) * 15);
      g.stroke();

      // Crates on the floor, stacked against the wall — up by the clock, not
      // down at the counter where the scales already stand.
      const kx = tillX + 22;
      const ky = wallY + 96;
      contact(g, kx + 22, ky + 20, 58, 0.14, 0.05);
      for (let k = 0; k < 3; k++) {
        const ox = k === 2 ? 11 : k * 24;
        const oy = k === 2 ? -17 : 0;
        g.fillStyle = halftone(g, '#b4772f', 3, 1);
        g.fillRect(kx + ox, ky + oy, 22, 18);
        g.strokeStyle = INK; g.lineWidth = 1.4;
        g.strokeRect(kx + ox, ky + oy, 22, 18);
        g.beginPath();
        g.moveTo(kx + ox, ky + oy + 6); g.lineTo(kx + ox + 22, ky + oy + 6);
        g.stroke();
      }
    }

    // A rope barrier down the left of the hall, which is what makes it a
    // queue rather than a crowd.
    g.strokeStyle = 'rgba(25,20,16,.5)';
    for (let ry = winY + winH + 34; ry < counterY - 10; ry += 64) {
      g.lineWidth = 2.5;
      g.beginPath(); g.moveTo(tillX + 7, ry); g.lineTo(tillX + 7, ry + 26); g.stroke();
      g.fillStyle = '#c8452f';
      g.beginPath(); g.arc(tillX + 7, ry - 2, 3.5, 0, Math.PI * 2); g.fill();
      g.lineWidth = 1.6;                            // the rope, slack
      g.beginPath();
      g.moveTo(tillX + 7, ry + 2);
      g.quadraticCurveTo(tillX + 13, ry + 30, tillX + 7, ry + 64);
      g.stroke();
    }

    // --- the counter -------------------------------------------------------
    // Waist-high joinery with a top you can put a till on, not a coloured band
    // laid on the floor. It gets a plinth, a front face, a proper top surface
    // and a contact shadow, and it stops short of the wall at each end so it
    // reads as furniture standing in a room.
    const tills = Math.max(1, shop.tills);
    const cLeft = tillX + 8;
    const cW = frontW - 16;
    contact(g, cLeft + cW / 2, counterY + counterH + 4, cW, 0.16, 0.012);
    g.save();                                       // plate offset
    g.globalAlpha = 0.32;
    g.fillStyle = '#8f2418';
    g.fillRect(cLeft + 3, counterY + 3, cW, counterH);
    g.restore();
    g.fillStyle = halftone(g, '#c8452f', 4, 1);     // front face
    g.fillRect(cLeft, counterY + 7, cW, counterH - 7);
    g.strokeStyle = INK;
    g.lineWidth = lw;
    g.strokeRect(cLeft, counterY + 7, cW, counterH - 7);
    g.strokeStyle = 'rgba(25,20,16,.3)';            // panelling
    g.lineWidth = 1;
    for (let k = 1; k < 6; k++) {
      const cx = cLeft + (cW / 6) * k;
      g.beginPath(); g.moveTo(cx, counterY + 11); g.lineTo(cx, counterY + counterH - 4); g.stroke();
    }
    g.fillStyle = '#e8d7ae';                        // the top, seen slightly on
    g.fillRect(cLeft - 4, counterY, cW + 8, 8);
    g.strokeStyle = INK;
    g.lineWidth = lw;
    g.strokeRect(cLeft - 4, counterY, cW + 8, 8);
    g.fillStyle = 'rgba(255,255,255,.5)';           // highlight along the edge
    g.fillRect(cLeft - 3, counterY + 1, cW + 6, 2);

    // A till per point of throughput, up to what fits. They occupy the right
    // of the counter and the queue forms along it to the left — they used to
    // be centred, which is exactly where the queue stood, so the machines were
    // never once visible.
    // The till end is sized to the tills, not to a fixed third of the counter:
    // one machine used to sit alone in a hundred and fifty pixels of counter
    // while the queue was squeezed into what was left.
    const tillZone = Math.min(frontW * 0.52, Math.max(70, Math.min(tills, 6) * 48));
    const tillLeft = tillX + frontW - tillZone;
    const shown = Math.min(tills, Math.max(1, Math.floor(tillZone / 40)));
    for (let ti = 0; ti < shown; ti++) {
      const cw = tillZone / shown;
      const cx = tillLeft + ti * cw + cw / 2;
      const ty = counterY - 22;
      contact(g, cx, counterY + 1, 34, 0.16);
      g.fillStyle = '#efe2c0';
      g.fillRect(cx - 15, ty, 30, 22);
      g.strokeStyle = INK; g.lineWidth = lw;
      g.strokeRect(cx - 15, ty, 30, 22);
      g.fillStyle = '#191410';                      // the readout
      g.fillRect(cx - 11, ty + 3, 22, 7);
      g.fillStyle = '#7fe3a0';
      g.fillRect(cx - 9, ty + 5, 4, 3);
      g.fillRect(cx - 3, ty + 5, 4, 3);
      g.fillStyle = 'rgba(25,20,16,.5)';            // keys
      for (let kx = 0; kx < 3; kx++) g.fillRect(cx - 10 + kx * 7, ty + 14, 5, 4);
    }
    // A pair of scales and a bag stand at the quiet end, because a counter
    // with nothing on it is a shelf.
    if (tillLeft - cLeft > 110) {
      const sx = cLeft + 32;
      contact(g, sx, counterY + 1, 34, 0.14);
      g.strokeStyle = INK; g.lineWidth = 1.4;
      g.fillStyle = '#d8cba6';                      // scale pan and column
      g.fillRect(sx - 15, counterY - 9, 30, 9);
      g.strokeRect(sx - 15, counterY - 9, 30, 9);
      g.beginPath(); g.moveTo(sx, counterY - 9); g.lineTo(sx, counterY - 21); g.stroke();
      g.fillStyle = '#f7c331';                      // the dial
      g.beginPath(); g.arc(sx, counterY - 26, 8, 0, Math.PI * 2); g.fill(); g.stroke();
      g.beginPath(); g.moveTo(sx, counterY - 26); g.lineTo(sx + 4, counterY - 31); g.stroke();
      g.fillStyle = '#c8a97a';                      // a stack of paper bags
      g.fillRect(sx + 34, counterY - 13, 22, 13);
      g.strokeRect(sx + 34, counterY - 13, 22, 13);
      g.beginPath();
      g.moveTo(sx + 34, counterY - 9); g.lineTo(sx + 56, counterY - 9);
      g.stroke();
    }

    g.fillStyle = INK;
    g.font = '700 10px Inter, sans-serif';
    g.fillText(`${tills} TILL${tills > 1 ? 'S' : ''}`, tillLeft + tillZone / 2, h - padB - 8);
    till = { x: tillLeft + tillZone / 2, y: counterY - 16 };
    queueRight = tillLeft - 6;

    // --- customers ---------------------------------------------------------
    hitboxes = [];
    // People in a queue stand closer together than people browsing, but not
    // inside one another: at 1.05 the columns were narrower than a Family with
    // a child alongside, so the front of the queue was a pile.
    const qPerson = person * 0.86;
    const qCols = Math.max(1, Math.floor((queueRight - tillX - 14) / Math.max(30, qPerson * 1.3)));
    for (const c of s.customers) {
      if ((c.phase === PHASE.DONE || c.phase === PHASE.LOST) && t - (c.exitAt ?? 0) > 8) continue;
      const li = c.lane;
      const top = padT + li * laneH;
      const floorY = top + laneH - 6;
      let x; let y = floorY; let alpha = 1;

      if (c.phase === PHASE.WALKING) {
        // They STEP between shelves, they do not glide.
        //
        // A continuous slide across four fifths of the screen is the single
        // most eye-catching thing a screen can do, and there are a hundred of
        // them doing it at once, all the same speed, all the same direction.
        // Smooth pursuit is involuntary: your eyes get dragged along whether
        // you want them to or not, and after ten seconds it hurts.
        //
        // A printed cutaway does not slide. It shows people standing AT
        // shelves. So progress quantises to the slot they are at, with a quick
        // hop between and a long dwell — nothing to track, and each figure is
        // legibly beside a fixture, which is what the walk is meant to show.
        const nSlots = Math.max(1, shop.aisles[c.aisle].slots.length);
        const stops = nSlots + 1;
        const at = c.progress * stops;
        const idx = Math.min(stops - 1, Math.floor(at));
        const within = at - idx;
        const hop = Math.min(1, within / HOP_SHARE);
        const eased = hop * hop * (3 - 2 * hop);          // smoothstep
        const step = (tillX - 24) / stops;
        x = 8 + (idx + eased) * step;
        // Two paces per hop, and none at all during the dwell.
        c.stridePhase = hop < 1 ? hop * 2 : 0;
      } else if (c.phase === PHASE.QUEUE) {
        // Rows fill UP from the counter, so the front of the queue is the row
        // touching the tills and the shop visibly fills from the front. The
        // old version stacked downward from the top of an empty box, which
        // read as a waiting room rather than a queue.
        // Fill from the till end. Index 0 is the person being served next, so
        // filling left-to-right put the front of the queue at the far end of
        // the counter from the machines — and parked the whole queue on top of
        // the scales, which stand at the quiet end precisely because it is
        // quiet.
        const qi = Math.max(0, s.queue.indexOf(c));
        const col = qCols - 1 - (qi % qCols);
        const row = Math.floor(qi / qCols);
        const colW = (queueRight - tillX - 14) / qCols;
        x = tillX + 10 + col * colW + colW / 2;
        y = counterY - 8 - row * Math.max(26, qPerson * 0.8);
        if (y < padT + qPerson * 1.3) y = padT + qPerson * 1.3;
      } else {
        x = tillX + frontW / 2;
        y = counterY - 4;
        alpha = Math.max(0, 1 - (t - (c.exitAt ?? t)) / 8);
      }

      g.globalAlpha = alpha;
      // Walking figures stride; standing ones sway. Perfectly still figures
      // are what made a shop full of people look like a paused screenshot.
      const walking = c.phase === PHASE.WALKING;
      const size = c.phase === PHASE.QUEUE ? qPerson : person;
      drawPerson(g, c.type, x, y, size, walking ? c.stridePhase || 0 : 0,
        walking, t * 0.09 + c.id * 1.7);

      if (c.phase === PHASE.QUEUE) {
        const left = Math.max(0, 1 - c.waited / c.patience);
        const bw2 = qPerson * 0.7;
        g.fillStyle = left < 0.34 ? '#d6206a' : left < 0.66 ? '#f2b90c' : '#1c7a3e';
        g.fillRect(x - bw2 / 2, y - qPerson * 1.68, bw2 * left, 4);
        g.strokeStyle = '#16130f';
        g.lineWidth = 1;
        g.strokeRect(x - bw2 / 2, y - qPerson * 1.68, bw2, 4);
        g.lineWidth = lw;
        hitboxes.push({ id: c.id, x, y: y - qPerson * 0.6, r: Math.max(18, qPerson * 0.8) });
      }
      if (c.phase === PHASE.DONE && c.bought) {
        g.fillStyle = '#1c7a3e';
        g.font = 'bold 13px Inter, sans-serif';
        g.fillText('£', x, y - person * 1.7);
      }
      if (c.phase === PHASE.LOST) {
        g.fillStyle = '#d6206a';
        g.font = 'bold 14px Inter, sans-serif';
        g.fillText('✕', x, y - person * 1.7);
      }
      g.globalAlpha = 1;
    }

    if (particles) particles.draw(g);

    // --- day clock ---------------------------------------------------------
    g.fillStyle = 'rgba(22,19,15,.15)';
    g.fillRect(0, h - 3, w * Math.min(1, s.tick / s.ticks), 3);
  }

  /** Which queued customer did the player tap? */
  function pick(px, py) {
    let best = null;
    for (const b of hitboxes) {
      const d = Math.hypot(b.x - px, b.y - py);
      if (d < b.r && (!best || d < best.d)) best = { id: b.id, d };
    }
    return best ? best.id : null;
  }

  return { draw, pick, tillPoint: () => till };
}
