// Drawing primitives with print DNA.
//
// The day used to be flat `fillRect` shapes in bright colours. That reads as a
// debug view, not an illustration, and it shared nothing with the catalogue
// page except a palette — two screens, two unrelated styles.
//
// A mid-century printed cutaway has four things this file supplies:
//
//   HALFTONE     large areas are dot screens, not solid ink. Cheap presses
//                could not lay flat colour, so they did not.
//   MISREGISTER  plates land a hair apart. One or two pixels of coloured
//                offset behind a shape is the single strongest period signal
//                there is, and it costs one extra fill.
//   INK LINE     drawn line, not vector stroke — a little weight variation and
//                a slightly overshooting corner.
//   TOOTH        paper has texture, so the darkest ink is never quite black
//                and edges are never quite clean.
//
// All of it is canvas 2D and all of it is cheap: patterns are built once and
// cached, and nothing here allocates inside the draw loop.

export const INK = '#191410';
export const PAPER = '#f7efdb';

const patternCache = new Map();

/**
 * A halftone dot screen in one colour. Cached by colour and scale, because
 * building a pattern per fill would allocate a canvas sixty times a second.
 */
export function halftone(g, colour, scale = 3, alpha = 0.85) {
  const key = `${colour}|${scale}|${alpha}`;
  let p = patternCache.get(key);
  if (!p) {
    const c = document.createElement('canvas');
    c.width = scale * 2;
    c.height = scale * 2;
    const x = c.getContext('2d');
    x.fillStyle = colour;
    x.globalAlpha = alpha;
    // Two dots offset diagonally: a 45-degree screen, which is what a press
    // uses for the dominant plate because the eye reads it as texture rather
    // than as rows.
    x.beginPath();
    x.arc(scale * 0.5, scale * 0.5, scale * 0.42, 0, Math.PI * 2);
    x.arc(scale * 1.5, scale * 1.5, scale * 0.42, 0, Math.PI * 2);
    x.fill();
    p = g.createPattern(c, 'repeat');
    patternCache.set(key, p);
  }
  return p;
}

/** Fill a rect as a dot screen over a paper ground. */
export function screenRect(g, x, y, w, h, colour, scale = 3, alpha = 0.9) {
  g.fillStyle = PAPER;
  g.fillRect(x, y, w, h);
  g.fillStyle = halftone(g, colour, scale, alpha);
  g.fillRect(x, y, w, h);
}

/**
 * Draw something twice: once in a plate colour, offset, then in ink. The
 * offset is the whole trick — it is what makes a shape look printed rather
 * than rendered.
 */
export function misregistered(g, plate, dx, dy, drawFn) {
  g.save();
  g.translate(dx, dy);
  g.globalAlpha = 0.5;
  g.fillStyle = plate;
  g.strokeStyle = plate;
  drawFn(true);
  g.restore();
  drawFn(false);
}

/** A hand-drawn-feeling rectangle: corners overshoot, weight varies a little. */
export function inkRect(g, x, y, w, h, lw = 1.6, seed = 0) {
  const o = () => ((Math.sin(seed++ * 12.9898) * 43758.5453) % 1) * 0.9;
  g.lineWidth = lw;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(x - o(), y);
  g.lineTo(x + w + o(), y);
  g.moveTo(x + w, y - o());
  g.lineTo(x + w, y + h + o());
  g.moveTo(x + w + o(), y + h);
  g.lineTo(x - o(), y + h);
  g.moveTo(x, y + h + o());
  g.lineTo(x, y - o());
  g.stroke();
}

/**
 * Contact shadow. A soft ellipse on the ground under a standing thing — the
 * cheapest depth cue there is, and its absence is most of why flat shapes
 * float.
 */
export function contact(g, x, y, w, alpha = 0.17) {
  g.save();
  g.globalAlpha = alpha;
  g.fillStyle = INK;
  g.beginPath();
  g.ellipse(x, y, w * 0.55, w * 0.15, 0, 0, Math.PI * 2);
  g.fill();
  g.restore();
}

/** Rounded rect that works everywhere, including older Safari. */
export function rr(g, x, y, w, h, r) {
  const k = Math.min(r, w / 2, h / 2);
  g.beginPath();
  g.moveTo(x + k, y);
  g.arcTo(x + w, y, x + w, y + h, k);
  g.arcTo(x + w, y + h, x, y + h, k);
  g.arcTo(x, y + h, x, y, k);
  g.arcTo(x, y, x + w, y, k);
  g.closePath();
}

// --- easing -----------------------------------------------------------------
// Nothing in the build eased. Everything snapped, which is most of why it read
// as a prototype: real interfaces have mass.

export const easeOutCubic = (t) => 1 - (1 - t) ** 3;
export const easeOutBack = (t) => {
  const c = 1.9;
  return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2;
};
export const easeInOut = (t) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);
/** Overshoot and settle, for anything that lands. */
export const spring = (t) => 1 - Math.cos(t * Math.PI * 2.6) * Math.exp(-t * 5.2);
