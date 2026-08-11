// The beep ladder.
//
// Retail owns one of the most recognisable sounds on earth and it is a single
// pure pitched tone. Combining pitches the barcode beep up, L1 to L2 to L3, and
// only L3 gets the till drawer. Three layers: a physical transient, the pitched
// body, and a tail that exists solely to mark reaching level three.
//
// Frenzy is one parameter, 0 to 1, driven by customers processed per second. It
// opens a filter, raises the hum and thickens the mix — the same parameter the
// floor uses to thicken its line weight.

const SCALE = [880, 1108.73, 1318.51, 1567.98]; // A5, C#6, E6, G6

export function createAudio() {
  let ctx = null;
  let hum = null;
  let humGain = null;
  let filter = null;
  let master = null;
  let muted = false;

  function ensure() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.5;
    filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 900;
    filter.connect(master);
    master.connect(ctx.destination);

    // Fluorescent hum: always there, louder when the shop is busy.
    hum = ctx.createOscillator();
    hum.type = 'sawtooth';
    hum.frequency.value = 100;
    humGain = ctx.createGain();
    humGain.gain.value = 0.006;
    hum.connect(humGain);
    humGain.connect(filter);
    hum.start();
    return ctx;
  }

  function tone(freq, dur, type = 'square', gain = 0.14, delay = 0) {
    if (muted) return;
    const c = ensure();
    if (!c) return;
    const t0 = c.currentTime + delay;
    const osc = c.createOscillator();
    const g = c.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    // Short, no reverb tail: rapid sequences would turn to mud otherwise.
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.005);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g);
    g.connect(filter);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  }

  function noise(dur = 0.03, gain = 0.08, delay = 0) {
    if (muted) return;
    const c = ensure();
    if (!c) return;
    const n = Math.floor(c.sampleRate * dur);
    const buf = c.createBuffer(1, n, c.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n) ** 2;
    const src = c.createBufferSource();
    const g = c.createGain();
    g.gain.value = gain;
    src.buffer = buf;
    src.connect(g);
    g.connect(filter);
    src.start(c.currentTime + delay);
  }

  return {
    unlock() { const c = ensure(); if (c && c.state === 'suspended') c.resume(); },
    toggleMute() { muted = !muted; if (master) master.gain.value = muted ? 0 : 0.5; return muted; },
    /** A sale clears the till: the card-machine approved chirp. */
    sale() { tone(1318.51, 0.05, 'square', 0.05); },
    /** A walkout: the sound of nothing happening, low and short. */
    walkout() { tone(180, 0.09, 'sine', 0.05); },
    /** Triage — you pulled someone forward yourself. */
    triage() { tone(1567.98, 0.045, 'square', 0.09); noise(0.02, 0.04); },
    /** Placing a fixture on the floor. */
    place() { noise(0.045, 0.1); tone(220, 0.06, 'triangle', 0.07); },
    /**
     * Combining. Transient, then the pitched body at this level, then — only
     * at L3 — the till drawer, so the ear learns that three is different in
     * kind rather than merely louder.
     */
    combine(level) {
      noise(0.05, 0.12);
      tone(SCALE[Math.min(level, SCALE.length - 1)], 0.16, 'square', 0.16);
      if (level >= 3) {
        tone(SCALE[3], 0.1, 'square', 0.1, 0.09);
        noise(0.16, 0.11, 0.13);
        tone(659.25, 0.5, 'triangle', 0.09, 0.16);
      }
    },
    /** Tannoy chime, for the moment the doors open. */
    tannoy() {
      tone(587.33, 0.34, 'sine', 0.1);
      tone(783.99, 0.42, 'sine', 0.1, 0.16);
    },
    receipt() { for (let i = 0; i < 9; i++) noise(0.012, 0.05, i * 0.035); },
    /** One parameter, several behaviours. */
    setFrenzy(v) {
      if (!ctx) return;
      const t = ctx.currentTime;
      filter.frequency.setTargetAtTime(700 + v * 8000, t, 0.25);
      humGain.gain.setTargetAtTime(0.005 + v * 0.02, t, 0.4);
    },
  };
}
