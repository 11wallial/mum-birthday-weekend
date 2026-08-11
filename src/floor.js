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

const COLOUR = {
  family: '#d6206a', student: '#0aa3c2', pensioner: '#7a5cbf', trade: '#e07b1a',
  luxury: '#0f8a4a', tourist: '#f2b90c', browser: '#9a9086', shoplifter: '#2a2622',
};

/** Silhouettes. Distinct at a glance is the entire requirement. */
function drawPerson(g, t, x, y, s, bob) {
  const c = COLOUR[t.id] || '#666';
  g.save();
  g.translate(x, y + bob);
  g.lineWidth = Math.max(1, s * 0.09);
  g.strokeStyle = '#16130f';
  g.fillStyle = c;

  const body = (w, h, r = 0) => {
    g.beginPath();
    g.roundRect(-w / 2, -h, w, h, r);
    g.fill();
    g.stroke();
  };
  const head = (r, dy = 0) => {
    g.beginPath();
    g.arc(0, -s * 1.02 + dy, r, 0, Math.PI * 2);
    g.fill();
    g.stroke();
  };

  switch (t.id) {
    case 'family': // two figures, one small
      g.save(); g.translate(-s * 0.22, 0); body(s * 0.5, s * 0.9, 2); head(s * 0.2); g.restore();
      g.save(); g.translate(s * 0.3, 0); g.scale(0.62, 0.62);
      body(s * 0.5, s * 0.9, 2); head(s * 0.2); g.restore();
      break;
    case 'student': // backpack
      body(s * 0.46, s * 0.92, 2); head(s * 0.19);
      g.fillStyle = '#16130f';
      g.beginPath(); g.roundRect(s * 0.2, -s * 0.85, s * 0.24, s * 0.42, 2); g.fill();
      break;
    case 'pensioner': // small, stooped, stick
      g.save(); g.translate(0, 0); g.scale(0.86, 0.8);
      body(s * 0.48, s * 0.9, 3); head(s * 0.2); g.restore();
      g.beginPath(); g.moveTo(s * 0.3, -s * 0.05); g.lineTo(s * 0.34, -s * 0.6); g.stroke();
      break;
    case 'trade': // wide, carrying a box
      body(s * 0.66, s * 0.92, 1); head(s * 0.19);
      g.fillStyle = '#b4772f';
      g.beginPath(); g.rect(-s * 0.5, -s * 0.72, s * 0.42, s * 0.34); g.fill(); g.stroke();
      break;
    case 'luxury': // tall, hat
      g.save(); g.scale(1, 1.16); body(s * 0.44, s * 0.92, 2); head(s * 0.18); g.restore();
      g.fillStyle = '#16130f';
      g.beginPath(); g.rect(-s * 0.34, -s * 1.42, s * 0.68, s * 0.07); g.fill();
      g.beginPath(); g.rect(-s * 0.2, -s * 1.62, s * 0.4, s * 0.22); g.fill();
      break;
    case 'tourist': // camera round the neck
      body(s * 0.48, s * 0.9, 2); head(s * 0.19);
      g.fillStyle = '#16130f';
      g.beginPath(); g.rect(-s * 0.16, -s * 0.6, s * 0.32, s * 0.2); g.fill();
      break;
    case 'browser': // thin, hands behind back, drifting
      g.save(); g.scale(0.72, 1); body(s * 0.44, s * 0.9, 2); head(s * 0.2); g.restore();
      break;
    case 'shoplifter': // hunched, dark, hood
      g.save(); g.scale(0.94, 0.92); body(s * 0.5, s * 0.88, 4); g.restore();
      g.beginPath(); g.arc(0, -s * 0.95, s * 0.24, Math.PI * 0.9, Math.PI * 2.1); g.fill(); g.stroke();
      break;
    default:
      body(s * 0.48, s * 0.9, 2); head(s * 0.2);
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
    g.fillStyle = '#f4ead6';
    g.fillRect(0, 0, w, h);

    const lanes = s.openAisles.length;
    const padT = 8;
    const padB = 8;
    const laneH = (h - padT - padB) / lanes;
    const tillX = Math.round(w * 0.82);
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

      // Lane ground
      g.fillStyle = li % 2 ? '#eee2c8' : '#f1e7d1';
      g.fillRect(0, top, tillX, laneH - 3);
      g.beginPath();
      g.moveTo(0, floorY); g.lineTo(tillX, floorY);
      g.stroke();

      // Shelving units, one per slot, standing on the floor line.
      const n = aisle.slots.length;
      const bw = tillX / n;
      for (let i = 0; i < n; i++) {
        const inst = aisle.slots[i];
        const x0 = i * bw + bw * 0.08;
        const uw = bw * 0.84;
        const uh = Math.min(laneH - strip * 0.55 - 10, 76);
        const y0 = shelfBase - uh;
        if (!inst) {
          g.setLineDash([4, 5]);
          g.strokeStyle = 'rgba(22,19,15,.28)';
          g.strokeRect(x0, y0, uw, uh);
          g.setLineDash([]);
          g.strokeStyle = '#16130f';
          continue;
        }
        const tone = inst.def.rarity === 'flagship' ? '#f2b90c'
          : inst.def.rarity === 'rare' ? '#d6206a'
            : inst.def.rarity === 'uncommon' ? '#0aa3c2' : '#c7a86b';
        g.fillStyle = '#e6d9ba';
        g.fillRect(x0, y0, uw, uh);
        g.strokeRect(x0, y0, uw, uh);
        // Shelves, with stock on them in the fixture's own colour.
        const rows = 3;
        for (let r = 0; r < rows; r++) {
          const sy = y0 + (uh / rows) * (r + 1);
          g.beginPath(); g.moveTo(x0, sy); g.lineTo(x0 + uw, sy); g.stroke();
          const items = 4;
          for (let k = 0; k < items; k++) {
            const iw = uw / items * 0.62;
            const ih = (uh / rows) * 0.5;
            g.fillStyle = tone;
            g.globalAlpha = 0.55 + ((i + r + k) % 3) * 0.15;
            g.fillRect(x0 + (uw / items) * k + iw * 0.28, sy - ih, iw, ih);
            g.globalAlpha = 1;
          }
        }
        // Header board
        g.fillStyle = tone;
        g.fillRect(x0, y0 - 13, uw, 13);
        g.strokeRect(x0, y0 - 13, uw, 13);
        g.fillStyle = '#16130f';
        g.font = `600 ${Math.max(8, Math.min(11, uw * 0.11))}px Inter, sans-serif`;
        g.fillText(inst.def.name.toUpperCase().slice(0, 18), x0 + uw / 2, y0 - 3.5);
        if (inst.level > 1) {
          g.fillStyle = '#16130f';
          g.fillRect(x0 + uw - 17, y0 + 3, 14, 12);
          g.fillStyle = '#f4ead6';
          g.font = 'bold 9px Inter, sans-serif';
          g.fillText(`L${inst.level}`, x0 + uw - 10, y0 + 12);
        }
      }
    }

    // --- till bank ---------------------------------------------------------
    g.fillStyle = '#e2d3ae';
    g.fillRect(tillX, padT, w - tillX, h - padT - padB);
    g.strokeStyle = '#16130f';
    g.lineWidth = lw;
    g.strokeRect(tillX + 0.5, padT + 0.5, w - tillX - 1, h - padT - padB - 1);
    const tills = Math.max(1, shop.tills);
    for (let t = 0; t < Math.min(tills, 6); t++) {
      const ty = padT + 8 + t * 16;
      g.fillStyle = '#16130f';
      g.fillRect(tillX + 10, ty, 22, 9);
      g.fillStyle = '#0aa3c2';
      g.fillRect(tillX + 12, ty + 2, 6, 5);
    }
    g.fillStyle = '#16130f';
    g.font = '600 11px Inter, sans-serif';
    g.fillText(`${tills} TILL${tills > 1 ? 'S' : ''}`, (tillX + w) / 2, h - padB - 8);

    // --- customers ---------------------------------------------------------
    hitboxes = [];
    const t = s.tick;
    const qCols = Math.max(1, Math.floor((w - tillX - 24) / Math.max(26, person * 0.8)));
    for (const c of s.customers) {
      if ((c.phase === PHASE.DONE || c.phase === PHASE.LOST) && t - (c.exitAt ?? 0) > 8) continue;
      const li = c.lane;
      const top = padT + li * laneH;
      const floorY = top + laneH - 6;
      let x; let y = floorY; let alpha = 1;

      if (c.phase === PHASE.WALKING) {
        x = 8 + c.progress * (tillX - 24);
      } else if (c.phase === PHASE.QUEUE) {
        const qi = Math.max(0, s.queue.indexOf(c));
        const col = qi % qCols;
        const row = Math.floor(qi / qCols);
        x = tillX + 16 + col * ((w - tillX - 28) / qCols);
        y = padT + 30 + row * Math.max(24, person * 0.62) + person * 0.2;
        if (y > h - padB - 14) y = h - padB - 14;
      } else {
        x = tillX + 18;
        y = padT + 26;
        alpha = Math.max(0, 1 - (t - (c.exitAt ?? t)) / 8);
      }

      g.globalAlpha = alpha;
      const bob = c.phase === PHASE.WALKING ? Math.sin((t * 1.4 + c.id) * 0.9) * 1.8 : 0;
      drawPerson(g, c.type, x, y, person, bob);

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
