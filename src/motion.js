// Motion.
//
// Scored honestly, animation was the worst thing about the build: 30/100.
// Not "the animation was poor" — there was almost none. Phases hard-cut,
// numbers snapped from one value to the next, a sale was a text glyph
// appearing and vanishing, and nothing on any screen had mass.
//
// Three things live here, because all three were missing:
//
//   COUNTERS   a number that changes rolls to its new value. A figure that
//              snaps is a figure you have to re-read; one that rolls tells you
//              which way it moved and roughly how far without being read.
//   PARTICLES  short-lived marks in canvas space — coins off a sale, a puff
//              off a walkout. Feedback you can see out of the corner of an eye
//              is what makes a busy screen legible.
//   TRANSITION a wipe between phases. A hard cut between the catalogue and the
//              floor gives the eye nothing to follow and makes two screens feel
//              like two programs.

import { easeOutCubic, INK } from './art.js';

// --- rolling numbers ---------------------------------------------------------

const counters = new WeakMap();

/**
 * Set an element's text to a number, rolling from whatever it showed before.
 * `fmt` turns the running value into the string, so money stays money.
 */
export function roll(el, value, fmt = (v) => String(Math.round(v)), ms = 420) {
  if (!el) return;
  const prev = counters.get(el);
  const from = prev ? prev.current : value;
  if (from === value) { el.textContent = fmt(value); return; }
  const state = { from, to: value, current: from, t0: performance.now(), ms, fmt, el };
  counters.set(el, state);
  if (!prev || prev.done) tick(state);
  else { prev.to = value; prev.from = prev.current; prev.t0 = performance.now(); }
}

function tick(state) {
  const step = (now) => {
    const k = Math.min(1, (now - state.t0) / state.ms);
    const e = easeOutCubic(k);
    state.current = state.from + (state.to - state.from) * e;
    state.el.textContent = state.fmt(state.current);
    if (k < 1) requestAnimationFrame(step);
    else { state.current = state.to; state.done = true; state.el.textContent = state.fmt(state.to); }
  };
  state.done = false;
  requestAnimationFrame(step);
}

// --- canvas particles --------------------------------------------------------

/**
 * A tiny pool. Capped hard, because at eighty thousand Footfall a naive
 * emitter would try to spawn a coin per sale and take the frame rate with it.
 */
export function createParticles(max = 90) {
  const items = [];

  function emit(kind, x, y, colour) {
    if (items.length >= max) items.shift();
    items.push({
      kind, x, y, colour,
      vx: (Math.random() - 0.5) * (kind === 'puff' ? 0.5 : 1.5),
      vy: kind === 'puff' ? -0.35 : -2.1 - Math.random() * 0.9,
      life: 0,
      max: kind === 'puff' ? 30 : 42,
      spin: (Math.random() - 0.5) * 0.3,
      rot: 0,
    });
  }

  function update() {
    for (let i = items.length - 1; i >= 0; i--) {
      const p = items[i];
      p.life++;
      p.x += p.vx;
      p.y += p.vy;
      p.rot += p.spin;
      if (p.kind !== 'puff') p.vy += 0.13;     // coins fall back
      else { p.vy *= 0.94; p.vx *= 0.96; }
      if (p.life > p.max) items.splice(i, 1);
    }
  }

  function draw(g) {
    for (const p of items) {
      const k = 1 - p.life / p.max;
      g.save();
      g.globalAlpha = k * (p.kind === 'puff' ? 0.4 : 1);
      g.translate(p.x, p.y);
      if (p.kind === 'coin') {
        g.rotate(p.rot);
        // A coin seen edge-on and rolling: the width oscillates.
        const wob = Math.abs(Math.cos(p.life * 0.28));
        g.fillStyle = '#f7c331';
        g.beginPath();
        g.ellipse(0, 0, 4.2 * (0.25 + wob * 0.75), 4.2, 0, 0, Math.PI * 2);
        g.fill();
        g.lineWidth = 1;
        g.strokeStyle = INK;
        g.stroke();
      } else if (p.kind === 'puff') {
        g.fillStyle = p.colour || 'rgba(25,20,16,.5)';
        g.beginPath();
        g.arc(0, 0, 3 + p.life * 0.32, 0, Math.PI * 2);
        g.fill();
      } else {                                  // cross, for a walkout
        g.strokeStyle = p.colour || '#d63426';
        g.lineWidth = 2;
        g.lineCap = 'round';
        const r = 4;
        g.beginPath();
        g.moveTo(-r, -r); g.lineTo(r, r); g.moveTo(r, -r); g.lineTo(-r, r);
        g.stroke();
      }
      g.restore();
    }
  }

  return { emit, update, draw, get count() { return items.length; } };
}

// --- phase transition --------------------------------------------------------

/**
 * A paper wipe between phases. The catalogue and the floor are two registers
 * of one publication, so the transition is a page turning rather than a fade:
 * a band of stock sweeps across, and the new phase is behind it.
 */
export function wipe(el, onHalf) {
  const sheet = document.createElement('div');
  sheet.className = 'wipe';
  document.body.appendChild(sheet);
  // Force layout so the transition actually runs from the start state.
  void sheet.offsetWidth;
  sheet.classList.add('go');
  let done = false;
  const half = () => {
    if (done) return;
    done = true;
    if (onHalf) onHalf();
  };
  setTimeout(half, 260);
  setTimeout(() => sheet.remove(), 700);
}
