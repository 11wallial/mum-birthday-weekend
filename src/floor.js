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

  function resize() {
    const r = canvas.getBoundingClientRect();
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = Math.max(320, r.width * dpr);
    canvas.height = Math.max(200, r.height * dpr);
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { w: r.width, h: r.height };
  }

  function draw(day, shop) {
    const { w, h } = resize();
    const s = day.state;
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
    const strip = Math.min(laneH * 0.5, 74);
    const person = Math.min(strip * 0.78, 46);
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

      // Pendant lights along the ceiling of the lane.
      for (let px = bwSpacing(tillX); px < tillX; px += bwSpacing(tillX)) {
        g.strokeStyle = 'rgba(25,20,16,.45)';
        g.lineWidth = 1;
        g.beginPath(); g.moveTo(px, top); g.lineTo(px, top + 9); g.stroke();
        g.fillStyle = '#f7c331';
        g.beginPath();
        g.moveTo(px - 7, top + 15); g.lineTo(px + 7, top + 15);
        g.lineTo(px + 3, top + 9); g.lineTo(px - 3, top + 9);
        g.closePath(); g.fill();
        g.strokeStyle = INK; g.lineWidth = 1.2; g.stroke();
        // The pool of light it throws.
        g.save();
        g.globalAlpha = 0.075;
        g.fillStyle = '#f7c331';
        g.beginPath();
        g.moveTo(px - 6, top + 15); g.lineTo(px + 6, top + 15);
        g.lineTo(px + 19, floorY); g.lineTo(px - 19, floorY);
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
        const uh = Math.min(laneH - strip * 0.55 - 10, 82);
        const y0 = shelfBase - uh;
        if (!inst) {
          // An empty bay: bare uprights, nothing on them. It should read as a
          // gap in the shop rather than as a dashed UI affordance.
          g.save();
          g.globalAlpha = 0.3;
          g.strokeStyle = 'rgba(25,20,16,.5)';
          g.lineWidth = 1.4;
          g.beginPath();
          g.moveTo(x0 + 2, shelfBase); g.lineTo(x0 + 2, y0 + uh * 0.42);
          g.moveTo(x0 + uw - 2, shelfBase); g.lineTo(x0 + uw - 2, y0 + uh * 0.42);
          g.moveTo(x0 + 2, y0 + uh * 0.42); g.lineTo(x0 + uw - 2, y0 + uh * 0.42);
          g.stroke();
          g.restore();
          g.strokeStyle = INK;
          g.lineWidth = lw;
          continue;
        }
        const tone = inst.def.rarity === 'flagship' ? '#f7c331'
          : inst.def.rarity === 'rare' ? '#d81e63'
            : inst.def.rarity === 'uncommon' ? '#0e8fb5' : '#d63426';

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
          const items = 3 + ((i + r) % 3);
          for (let k = 0; k < items; k++) {
            const slotW = uw / items;
            const iw = slotW * 0.66;
            const kind = (i * 7 + r * 3 + k) % 3;
            const ih = cell * (kind === 0 ? 0.62 : kind === 1 ? 0.48 : 0.55);
            const ix = x0 + slotW * k + (slotW - iw) / 2;
            // Solid at this size. A dot screen only reads as a screen when
            // there is room for several dots across the shape; on a 12px tin
            // it reads as damage.
            g.fillStyle = tone;
            g.globalAlpha = 0.72 + ((i + r + k) % 3) * 0.12;
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

        // Header board — a shelf barker, hung slightly askew.
        g.save();
        g.translate(x0 + uw / 2, y0 - 8);
        g.rotate(((i % 2) ? 1 : -1) * 0.012);
        g.fillStyle = tone;
        g.fillRect(-uw / 2, -8, uw, 16);
        g.strokeRect(-uw / 2, -8, uw, 16);
        g.fillStyle = inst.def.rarity === 'flagship' ? INK : '#fff';
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
    // A shopfront: daylight through the window, the door, the counter and a
    // till on it. This was a large empty tinted rectangle with a queue parked
    // in it, which is most of why the day looked unfinished.
    const frontW = w - tillX;
    screenRect(g, tillX, padT, frontW, h - padT - padB, '#c2ac80', 4, 0.3);
    g.fillStyle = '#efe2c0';
    g.fillRect(tillX + 1, padT + 1, frontW - 2, h - padT - padB - 2);

    // The window wall, with daylight falling in.
    const winY = padT + 14;
    const winH = Math.min(150, (h - padT - padB) * 0.42);
    g.fillStyle = '#cfe6ef';
    g.fillRect(tillX + 14, winY, frontW - 28, winH);
    g.strokeStyle = INK;
    g.lineWidth = lw + 0.6;
    g.strokeRect(tillX + 14, winY, frontW - 28, winH);
    // Glazing bars.
    g.lineWidth = 1.4;
    for (let k = 1; k < 3; k++) {
      const gx = tillX + 14 + ((frontW - 28) / 3) * k;
      g.beginPath(); g.moveTo(gx, winY); g.lineTo(gx, winY + winH); g.stroke();
    }
    g.beginPath();
    g.moveTo(tillX + 14, winY + winH * 0.42);
    g.lineTo(tillX + frontW - 14, winY + winH * 0.42);
    g.stroke();
    // Reversed-out shop name across the glass, as a signwriter would.
    g.fillStyle = 'rgba(25,20,16,.42)';
    g.font = `700 ${Math.min(19, frontW * 0.075)}px Inter, sans-serif`;
    g.fillText('OPEN', tillX + frontW / 2, winY + winH * 0.3);
    // Daylight pooling on the floor below the window.
    g.save();
    g.globalAlpha = 0.13;
    g.fillStyle = '#cfe6ef';
    g.beginPath();
    g.moveTo(tillX + 14, winY + winH);
    g.lineTo(tillX + frontW - 14, winY + winH);
    g.lineTo(tillX + frontW - 2, h - padB - 4);
    g.lineTo(tillX + 2, h - padB - 4);
    g.closePath(); g.fill();
    g.restore();

    // The counter, with a till machine standing on it.
    const tills = Math.max(1, shop.tills);
    const counterY = h - padB - 52;
    g.save();
    g.globalAlpha = 0.3;
    g.fillStyle = '#8f2418';
    g.fillRect(tillX + 3, counterY + 3, frontW - 4, 26);
    g.restore();
    g.fillStyle = halftone(g, '#c8452f', 4, 1);
    g.fillRect(tillX + 1, counterY, frontW - 2, 24);
    g.strokeStyle = INK;
    g.lineWidth = lw;
    g.strokeRect(tillX + 1, counterY, frontW - 2, 24);
    // Counter front panelling.
    g.strokeStyle = 'rgba(25,20,16,.35)';
    g.lineWidth = 1;
    for (let k = 1; k < 5; k++) {
      const cx = tillX + (frontW / 5) * k;
      g.beginPath(); g.moveTo(cx, counterY + 4); g.lineTo(cx, counterY + 20); g.stroke();
    }
    // A till per point of throughput, up to what fits.
    const shown = Math.min(tills, Math.max(1, Math.floor(frontW / 46)));
    for (let t = 0; t < shown; t++) {
      const cw = (frontW - 16) / shown;
      const cx = tillX + 8 + t * cw + cw / 2;
      const ty = counterY - 20;
      g.fillStyle = '#efe2c0';
      g.fillRect(cx - 15, ty, 30, 20);
      g.strokeStyle = INK; g.lineWidth = lw;
      g.strokeRect(cx - 15, ty, 30, 20);
      g.fillStyle = '#191410';                     // the readout
      g.fillRect(cx - 11, ty + 3, 22, 7);
      g.fillStyle = '#7fe3a0';
      g.fillRect(cx - 9, ty + 5, 4, 3);
      g.fillRect(cx - 3, ty + 5, 4, 3);
      g.fillStyle = 'rgba(25,20,16,.5)';           // keys
      for (let kx = 0; kx < 3; kx++) g.fillRect(cx - 10 + kx * 7, ty + 13, 5, 4);
    }
    g.fillStyle = INK;
    g.font = '700 10px Inter, sans-serif';
    g.fillText(`${tills} TILL${tills > 1 ? 'S' : ''}`, tillX + frontW / 2, h - padB - 14);

    // --- customers ---------------------------------------------------------
    hitboxes = [];
    const t = s.tick;
    const qCols = Math.max(1, Math.floor((w - tillX - 20) / Math.max(30, person * 1.05)));
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
        const qi = Math.max(0, s.queue.indexOf(c));
        const col = qi % qCols;
        const row = Math.floor(qi / qCols);
        const colW = (w - tillX - 20) / qCols;
        x = tillX + 12 + col * colW + colW / 2;
        y = counterY - 8 - row * Math.max(26, person * 0.72);
        if (y < padT + person * 1.3) y = padT + person * 1.3;
      } else {
        x = tillX + frontW / 2;
        y = counterY - 4;
        alpha = Math.max(0, 1 - (t - (c.exitAt ?? t)) / 8);
      }

      g.globalAlpha = alpha;
      // Walking figures stride; standing ones sway. Perfectly still figures
      // are what made a shop full of people look like a paused screenshot.
      const walking = c.phase === PHASE.WALKING;
      drawPerson(g, c.type, x, y, person, walking ? c.stridePhase || 0 : 0,
        walking, t * 0.09 + c.id * 1.7);

      if (c.phase === PHASE.QUEUE) {
        const left = Math.max(0, 1 - c.waited / c.patience);
        const bw2 = person * 0.78;
        g.fillStyle = left < 0.34 ? '#d6206a' : left < 0.66 ? '#f2b90c' : '#1c7a3e';
        g.fillRect(x - bw2 / 2, y - person * 1.62, bw2 * left, 4);
        g.strokeStyle = '#16130f';
        g.lineWidth = 1;
        g.strokeRect(x - bw2 / 2, y - person * 1.62, bw2, 4);
        g.lineWidth = lw;
        hitboxes.push({ id: c.id, x, y: y - person * 0.6, r: Math.max(18, person * 0.8) });
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

  return { draw, pick };
}
