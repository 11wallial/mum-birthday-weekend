// The shop, heard.
//
// The first version had one continuous voice: a raw sawtooth at 100Hz through a
// lowpass, gained up with the frenzy parameter. That recipe is not a shop, it
// is an electrical fault — a buzzing edge tone with no variety and nothing
// behind it. It also ran unchanged from the first customer to the last, so
// there was no ambience, only a drone.
//
// What a 1950s shop floor actually sounds like, in layers:
//
//   BED       a warm room tone — filtered noise, not an oscillator, because
//             rooms are noise. Two detuned sine partials sit under it for
//             body. This is the thing that was missing entirely.
//   ROOM      a slow tape-style wobble on the bed, so it breathes instead of
//             sitting still. Static tone is what makes a drone a drone.
//   EVENTS    tills, the bell over the door, the tannoy. Every one of them
//             varies: pitch drifts, timbre alternates, timing scatters.
//
// Frenzy is still one parameter, and it still drives everything — but it now
// moves the bed's brightness and depth, the chatter density and the till
// pitch, rather than simply turning a buzz up.

const SCALE = [880, 1108.73, 1318.51, 1567.98]; // A5, C#6, E6, G6
const rand = (a, b) => a + Math.random() * (b - a);

export function createAudio() {
  let ctx = null;
  let master = null;
  let bus = null;          // events go here, through the shared tone shaping
  let bedGain = null;
  let bedFilter = null;
  let wobble = null;
  let muted = false;
  let chatterTimer = null;

  function ensure() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();

    master = ctx.createGain();
    master.gain.value = 0.5;
    master.connect(ctx.destination);

    // A gentle high shelf on everything, so nothing is ever shrill.
    const tame = ctx.createBiquadFilter();
    tame.type = 'lowpass';
    tame.frequency.value = 6200;
    tame.Q.value = 0.5;
    tame.connect(master);
    bus = tame;

    buildBed();
    return ctx;
  }

  /**
   * Room tone. Looping filtered noise plus two quiet detuned partials — a room
   * is air moving, which is noise, and the partials are the fridges.
   */
  function buildBed() {
    const secs = 4;
    const n = Math.floor(ctx.sampleRate * secs);
    const buf = ctx.createBuffer(1, n, ctx.sampleRate);
    const d = buf.getChannelData(0);
    // Brown-ish noise: integrate white and keep it centred. Brown reads as a
    // room; white reads as a hiss and pink reads as rain.
    let last = 0;
    for (let i = 0; i < n; i++) {
      const white = Math.random() * 2 - 1;
      last = (last + 0.02 * white) / 1.02;
      d[i] = last * 3.2;
    }
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.loop = true;

    bedFilter = ctx.createBiquadFilter();
    bedFilter.type = 'lowpass';
    bedFilter.frequency.value = 520;
    bedFilter.Q.value = 0.7;

    bedGain = ctx.createGain();
    bedGain.gain.value = 0.16;

    src.connect(bedFilter);
    bedFilter.connect(bedGain);
    bedGain.connect(bus);
    src.start();

    // The fridges. Two partials a whisker apart, so they beat slowly against
    // each other instead of sitting on one dead pitch.
    for (const [f, g] of [[58, 0.020], [87.3, 0.011], [116.6, 0.006]]) {
      const o = ctx.createOscillator();
      const og = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = f;
      og.gain.value = g;
      o.connect(og);
      og.connect(bedGain);
      o.start();
      // Slow drift, so it never quite repeats.
      const lfo = ctx.createOscillator();
      const lg = ctx.createGain();
      lfo.frequency.value = rand(0.03, 0.09);
      lg.gain.value = f * 0.004;
      lfo.connect(lg);
      lg.connect(o.frequency);
      lfo.start();
    }

    // Tape wobble on the whole bed: the difference between a room and a drone.
    wobble = ctx.createOscillator();
    const wg = ctx.createGain();
    wobble.frequency.value = 0.13;
    wg.gain.value = 90;
    wobble.connect(wg);
    wg.connect(bedFilter.frequency);
    wobble.start();
  }

  /**
   * One event tone. `spread` detunes it slightly each time it fires — the
   * single biggest reason the old set sounded mechanical was that every beep
   * was bit-identical to the last.
   */
  function tone(freq, dur, type = 'square', gain = 0.14, delay = 0, spread = 0.012) {
    if (muted) return;
    const c = ensure();
    if (!c) return;
    const t0 = c.currentTime + delay;
    const osc = c.createOscillator();
    const g = c.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq * rand(1 - spread, 1 + spread), t0);
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.006);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g);
    g.connect(bus);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  }

  function noise(dur = 0.03, gain = 0.08, delay = 0, cutoff = 3000) {
    if (muted) return;
    const c = ensure();
    if (!c) return;
    const n = Math.max(1, Math.floor(c.sampleRate * dur));
    const buf = c.createBuffer(1, n, c.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n) ** 2;
    const src = c.createBufferSource();
    const f = c.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.value = cutoff;
    const g = c.createGain();
    g.gain.value = gain;
    src.buffer = buf;
    src.connect(f);
    f.connect(g);
    g.connect(bus);
    src.start(c.currentTime + delay);
  }

  /** Distant voices: two very quiet, very short filtered blips. Never a word. */
  function murmur() {
    if (muted || !ctx) return;
    const base = rand(150, 340);
    tone(base, rand(0.05, 0.13), 'triangle', 0.012, 0, 0.06);
    tone(base * rand(1.1, 1.6), rand(0.04, 0.1), 'sine', 0.008, rand(0.04, 0.14), 0.06);
  }

  return {
    unlock() { const c = ensure(); if (c && c.state === 'suspended') c.resume(); },
    toggleMute() {
      muted = !muted;
      if (master) master.gain.setTargetAtTime(muted ? 0 : 0.5, ctx.currentTime, 0.05);
      return muted;
    },

    /** A sale clears the till. Alternates two timbres so a run of them lilts. */
    sale() {
      const up = Math.random() < 0.5;
      tone(up ? 1318.51 : 1244.51, 0.05, up ? 'square' : 'triangle', 0.05, 0, 0.02);
    },
    /** A walkout: the door, and nothing after it. */
    walkout() {
      tone(rand(150, 200), 0.11, 'sine', 0.05, 0, 0.05);
      noise(0.05, 0.02, 0.01, 900);
    },
    /** Triage — you pulled someone forward yourself. Crisper than a sale. */
    triage() { tone(1567.98, 0.045, 'square', 0.09); noise(0.02, 0.04, 0, 5000); },
    /** Placing a fixture: a wooden knock, not a beep. */
    place() {
      noise(0.05, 0.11, 0, 1400);
      tone(rand(190, 240), 0.08, 'triangle', 0.08, 0, 0.03);
    },
    /**
     * Combining. Transient, then the pitched body at this level, then — only
     * at L3 — the till drawer, so the ear learns that three is different in
     * kind rather than merely louder.
     */
    combine(level) {
      noise(0.05, 0.12, 0, 4000);
      tone(SCALE[Math.min(level, SCALE.length - 1)], 0.16, 'square', 0.16);
      if (level >= 3) {
        tone(SCALE[3], 0.1, 'square', 0.1, 0.09);
        noise(0.16, 0.11, 0.13, 2600);
        tone(659.25, 0.5, 'triangle', 0.09, 0.16);
        tone(987.77, 0.44, 'sine', 0.05, 0.2);
      }
    },
    /** The bell over the door, for the moment the doors open. */
    tannoy() {
      tone(587.33, 0.5, 'sine', 0.09);
      tone(880, 0.62, 'sine', 0.07, 0.13);
      tone(1174.66, 0.5, 'sine', 0.04, 0.19);
      noise(0.3, 0.02, 0, 700);
    },
    receipt() { for (let i = 0; i < 9; i++) noise(0.012, 0.05, i * 0.035, 4200); },

    /**
     * One parameter, several behaviours — but now they are behaviours of a
     * room rather than the volume of a buzz. A busy shop is brighter, fuller
     * and more talkative; a quiet one is close to silent.
     */
    setFrenzy(v) {
      if (!ctx) return;
      const t = ctx.currentTime;
      bedFilter.frequency.setTargetAtTime(420 + v * 1500, t, 0.35);
      bedGain.gain.setTargetAtTime(0.13 + v * 0.16, t, 0.4);
      wobble.frequency.setTargetAtTime(0.11 + v * 0.5, t, 0.6);

      // Chatter density follows the crowd. Scheduled rather than continuous,
      // because a room's voices arrive at random and a loop does not.
      if (chatterTimer) clearTimeout(chatterTimer);
      const tick = () => {
        murmur();
        const gap = rand(140, 900) / (0.25 + v * 1.6);
        chatterTimer = setTimeout(tick, gap);
      };
      if (v > 0.03 && !muted) chatterTimer = setTimeout(tick, rand(120, 700));
    },

    /** Stop the room when the day ends, so the night is quiet. */
    quiet() {
      if (chatterTimer) { clearTimeout(chatterTimer); chatterTimer = null; }
      if (!ctx) return;
      bedGain.gain.setTargetAtTime(0.05, ctx.currentTime, 0.5);
    },
  };
}
