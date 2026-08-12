// The shop, heard.
//
// There was no music. There was a room tone and a set of beeps, and a roguelike
// without a tune is a spreadsheet with a timer on it — the loop is the same
// eight decisions over and over, and what carries a player through the
// fortieth repetition is not the decisions, it is the groove they are made to.
//
// So: ONE piece of music, sixteen bars in C minor at 104, swung, playing
// continuously from the first gesture to the last. It never restarts and it
// never crossfades to a different piece. What changes between the cover, the
// catalogue, the trading day and the receipt is the MIX — five layers whose
// gains and a master lowpass move against each other, so the title screen is
// the same tune heard through a shut shutter and the trading day is the same
// tune with the band all in. That continuity is the whole trick: the player
// never hears a seam, so the game feels like one place rather than four
// screens.
//
//   BASS    a walking line, quarter notes, chromatic approach into each chord
//   KEYS    vibraphone comping on the off-beats
//   LEAD    the hook, an eight-bar phrase and its answer an octave up
//   DRUMS   brushed kit — kick, brush snare on two and four, swung ride
//   COLOUR  shaker and a horn pad, opened by the frenzy parameter
//
// And the effects are PART of the music, not laid over it. Every pitched sound
// the game makes is drawn from the chord that is sounding at that instant, so
// a till never lands on a note that fights the tune. A run of sales walks UP
// that chord — the ladder resets after a gap, so chaining sales is audibly a
// thing you are doing rather than a thing that is happening. That ladder is
// most of what "satisfying" means here.

const BPM = 104;
const SPB = 60 / BPM;              // seconds per beat
const SWING = 0.62;                // where the off-eighth sits inside the beat
const BARS = 16;
const LOOKAHEAD = 0.18;            // how far ahead the scheduler writes
const TICK = 25;                   // and how often it wakes up, ms

const rand = (a, b) => a + Math.random() * (b - a);
const mtof = (m) => 440 * (2 ** ((m - 69) / 12));

// Sixteen bars round the circle of fifths in C minor. It resolves at bar 15
// and turns around on bar 16, so the loop point is a musical event rather than
// a splice. Roots are MIDI; the intervals are the chord over that root.
const PROG = [
  [48, [0, 3, 7, 10]],   // Cm7
  [53, [0, 3, 7, 10]],   // Fm7
  [46, [0, 4, 7, 10]],   // Bb7
  [51, [0, 4, 7, 11]],   // EbMaj7
  [56, [0, 4, 7, 11]],   // AbMaj7
  [50, [0, 3, 6, 10]],   // Dm7b5
  [55, [0, 4, 7, 10]],   // G7
  [48, [0, 3, 7, 10]],   // Cm7
  [48, [0, 3, 7, 10]],
  [53, [0, 3, 7, 10]],
  [46, [0, 4, 7, 10]],
  [51, [0, 4, 7, 11]],
  [56, [0, 4, 7, 11]],
  [55, [0, 4, 7, 10]],   // G7
  [48, [0, 3, 7, 10]],   // Cm7
  [55, [0, 4, 7, 10]],   // G7, the turnaround
];

// The hook. [beat within the loop, MIDI, length in beats]. Bars one to eight
// state it; nine to sixteen answer it up an octave and then bring it home.
const MELODY = [
  [1, 67, 0.9], [2, 70, 0.9], [3.5, 67, 0.5],
  [4, 65, 1.8], [6, 68, 0.9], [7, 65, 0.9],
  [8, 74, 1.4], [9.5, 72, 0.5], [10, 70, 0.9], [11, 68, 0.9],
  [12, 67, 3.4],
  [16, 68, 0.9], [17, 72, 0.9], [18, 75, 1.9],
  [20, 74, 0.9], [21, 72, 0.9], [22, 68, 1.9],
  [24, 71, 0.9], [25, 74, 0.9], [26, 77, 0.9], [27, 74, 0.9],
  [28, 72, 3.5],
  [33, 79, 0.9], [34, 82, 0.9], [35.5, 79, 0.5],
  [36, 77, 1.8], [38, 80, 0.9], [39, 77, 0.9],
  [40, 74, 1.4], [41.5, 72, 0.5], [42, 70, 0.9], [43, 68, 0.9],
  [44, 75, 3.4],
  [48, 80, 0.9], [49, 79, 0.9], [50, 75, 1.9],
  [52, 74, 0.9], [53, 71, 0.9], [54, 74, 1.9],
  [56, 72, 2.9], [59, 70, 0.9],
  [60, 67, 0.9], [61, 70, 0.9], [62, 71, 1.8],
];

// Same tune, four rooms. Gains per layer, the master lowpass, and how much of
// it goes to the plate.
const MIX = {
  title:  { bass: 0.72, keys: 0.62, lead: 0.30, drums: 0.06, colour: 0.00, lp: 1700,  rev: 0.5,  vol: 0.66 },
  night:  { bass: 0.95, keys: 0.90, lead: 0.62, drums: 0.34, colour: 0.10, lp: 6800,  rev: 0.3,  vol: 0.80 },
  day:    { bass: 1.00, keys: 0.72, lead: 0.66, drums: 1.00, colour: 0.42, lp: 14000, rev: 0.22, vol: 0.86 },
  settle: { bass: 0.66, keys: 0.58, lead: 0.34, drums: 0.10, colour: 0.00, lp: 2400,  rev: 0.45, vol: 0.70 },
};

/**
 * `opts.context` and `opts.destination` let a caller supply the graph's context
 * and send everything somewhere other than the speakers, which is how
 * tools/audio-shot.mjs records the whole soundtrack to a file — audio you
 * cannot listen back to is audio you are writing blind.
 */
export function createAudio(opts = {}) {
  let ctx = null;
  let muted = false;
  let started = false;
  let phase = 'title';
  let frenzy = 0;

  // Graph
  let master; let limiter; let musicLp; let duck;
  const bus = {};                  // bass / keys / lead / drums / colour
  let sfx; let revIn; let revGain;
  let bedGain; let bedFilter;
  let chatterTimer = null;

  // Transport
  let beat = 0;                    // next beat index to schedule
  let beatAt = 0;                  // and the context time it lands on
  let timer = null;

  // The sale ladder
  let combo = 0;
  let lastSale = -99;

  let noiseBuf = null;

  // --- graph -----------------------------------------------------------------

  function ensure() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!opts.context && !AC) return null;
    ctx = opts.context || new AC();

    limiter = ctx.createDynamicsCompressor();
    limiter.threshold.value = -8;
    limiter.knee.value = 6;
    limiter.ratio.value = 12;
    limiter.attack.value = 0.003;
    limiter.release.value = 0.18;
    limiter.connect(opts.destination || ctx.destination);

    master = ctx.createGain();
    master.gain.value = muted ? 0 : 0.9;
    master.connect(limiter);

    // A plate, built rather than loaded: noise with an exponential tail is a
    // perfectly good small-room impulse and costs nothing to ship.
    const secs = 1.7;
    const n = Math.floor(ctx.sampleRate * secs);
    const ir = ctx.createBuffer(2, n, ctx.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = ir.getChannelData(ch);
      for (let i = 0; i < n; i++) {
        const k = i / n;
        d[i] = (Math.random() * 2 - 1) * (1 - k) ** 2.6 * (i < 200 ? i / 200 : 1);
      }
    }
    const conv = ctx.createConvolver();
    conv.buffer = ir;
    revGain = ctx.createGain();
    revGain.gain.value = MIX.title.rev;
    revIn = ctx.createGain();
    revIn.gain.value = 1;
    revIn.connect(conv);
    conv.connect(revGain);
    revGain.connect(master);

    // Music passes through a lowpass and a ducker; effects do not, so a till
    // stays crisp on the title screen where the tune is behind a shutter.
    duck = ctx.createGain();
    duck.gain.value = 1;
    duck.connect(master);
    musicLp = ctx.createBiquadFilter();
    musicLp.type = 'lowpass';
    musicLp.frequency.value = MIX.title.lp;
    musicLp.Q.value = 0.4;
    musicLp.connect(duck);

    for (const k of ['bass', 'keys', 'lead', 'drums', 'colour']) {
      const g = ctx.createGain();
      g.gain.value = MIX.title[k];
      g.connect(musicLp);
      bus[k] = g;
    }
    // Keys and lead carry the room; bass and drums stay dry or it turns to soup.
    const send = (from, amt) => { const s = ctx.createGain(); s.gain.value = amt; from.connect(s); s.connect(revIn); };
    send(bus.keys, 0.3);
    send(bus.lead, 0.34);
    send(bus.colour, 0.3);
    send(bus.drums, 0.07);

    sfx = ctx.createGain();
    sfx.gain.value = 1;
    sfx.connect(master);
    send(sfx, 0.2);

    noiseBuf = makeNoise(2);
    buildBed();
    applyMix(0.01);
    return ctx;
  }

  function makeNoise(secs) {
    const n = Math.floor(ctx.sampleRate * secs);
    const b = ctx.createBuffer(1, n, ctx.sampleRate);
    const d = b.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    return b;
  }

  /** Room tone, well under the music: a shop is a room before it is a tune. */
  function buildBed() {
    const n = Math.floor(ctx.sampleRate * 4);
    const buf = ctx.createBuffer(1, n, ctx.sampleRate);
    const d = buf.getChannelData(0);
    let last = 0;
    for (let i = 0; i < n; i++) {
      last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02;
      d[i] = last * 3.2;
    }
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.loop = true;
    bedFilter = ctx.createBiquadFilter();
    bedFilter.type = 'lowpass';
    bedFilter.frequency.value = 480;
    bedGain = ctx.createGain();
    bedGain.gain.value = 0.0;
    src.connect(bedFilter);
    bedFilter.connect(bedGain);
    bedGain.connect(master);
    src.start();
  }

  function applyMix(ramp = 0.9) {
    if (!ctx) return;
    const m = MIX[phase] || MIX.night;
    const t = ctx.currentTime;
    for (const k of ['bass', 'keys', 'lead', 'drums', 'colour']) {
      let v = m[k];
      if (k === 'colour') v += frenzy * 0.5;
      if (k === 'drums' && phase === 'day') v = 0.8 + frenzy * 0.3;
      bus[k].gain.setTargetAtTime(v, t, ramp / 3);
    }
    musicLp.frequency.setTargetAtTime(m.lp * (1 + frenzy * 0.5), t, ramp / 3);
    revGain.gain.setTargetAtTime(m.rev, t, ramp / 3);
    master.gain.setTargetAtTime(muted ? 0 : m.vol, t, ramp / 3);
    bedGain.gain.setTargetAtTime(phase === 'day' ? 0.05 + frenzy * 0.1 : 0.0, t, 0.6);
    if (bedFilter) bedFilter.frequency.setTargetAtTime(420 + frenzy * 1400, t, 0.4);
  }

  // --- voices ----------------------------------------------------------------

  function noiseVoice(t, dur, out, { type = 'lowpass', freq = 4000, Q = 1, gain = 0.1, curve = 2 }) {
    const src = ctx.createBufferSource();
    src.buffer = noiseBuf;
    src.playbackRate.value = rand(0.92, 1.08);
    const f = ctx.createBiquadFilter();
    f.type = type;
    f.frequency.value = freq;
    f.Q.value = Q;
    const g = ctx.createGain();
    g.gain.setValueAtTime(gain, t);
    g.gain.setValueAtTime(gain, t + 0.001);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(out);
    src.start(t, rand(0, 1.5));
    src.stop(t + dur + 0.02);
    return g;
  }

  /** The walking bass: fat and short, so it drives without smearing. */
  function vBass(t, midi, dur, gain = 0.5) {
    const hz = mtof(midi);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gain, t + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.setValueAtTime(1600, t);
    f.frequency.exponentialRampToValueAtTime(420, t + Math.min(0.3, dur));
    f.Q.value = 1.4;
    for (const [type, mul, amp] of [['triangle', 1, 1], ['sawtooth', 1.004, 0.28]]) {
      const o = ctx.createOscillator();
      o.type = type;
      o.frequency.value = hz * mul;
      const og = ctx.createGain();
      og.gain.value = amp;
      o.connect(og); og.connect(f);
      o.start(t); o.stop(t + dur + 0.03);
    }
    f.connect(g); g.connect(bus.bass);
  }

  /**
   * Vibraphone. Three partials and a tremolo — the tremolo IS the instrument;
   * without it this is a sine and with it it is a 1950s shop.
   */
  function vKeys(t, midi, dur, gain = 0.16, out = null) {
    const hz = mtof(midi);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gain, t + 0.006);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    const trem = ctx.createGain();
    trem.gain.value = 0.82;
    const lfo = ctx.createOscillator();
    lfo.frequency.value = rand(4.8, 5.6);
    const lg = ctx.createGain();
    lg.gain.value = 0.18;
    lfo.connect(lg); lg.connect(trem.gain);
    lfo.start(t); lfo.stop(t + dur + 0.05);
    for (const [mul, amp] of [[1, 1], [2, 0.24], [4.01, 0.07]]) {
      const o = ctx.createOscillator();
      o.type = 'sine';
      o.frequency.value = hz * mul * rand(0.999, 1.001);
      const og = ctx.createGain();
      og.gain.value = amp;
      o.connect(og); og.connect(g);
      o.start(t); o.stop(t + dur + 0.05);
    }
    g.connect(trem);
    trem.connect(out || bus.keys);
  }

  /** The hook: a whistled tone with a little vibrato and a soft edge. */
  function vLead(t, midi, dur, gain = 0.2) {
    const hz = mtof(midi);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gain, t + 0.035);
    g.gain.setValueAtTime(gain, t + Math.max(0.06, dur - 0.09));
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.value = 2600;
    const vib = ctx.createOscillator();
    vib.frequency.value = 5.1;
    const vg = ctx.createGain();
    vg.gain.value = hz * 0.006;
    vib.connect(vg);
    vib.start(t); vib.stop(t + dur + 0.05);
    for (const [type, mul, amp] of [['triangle', 1, 1], ['sine', 2, 0.16]]) {
      const o = ctx.createOscillator();
      o.type = type;
      o.frequency.value = hz * mul;
      vg.connect(o.frequency);
      const og = ctx.createGain();
      og.gain.value = amp;
      o.connect(og); og.connect(f);
      o.start(t); o.stop(t + dur + 0.05);
    }
    f.connect(g); g.connect(bus.lead);
  }

  /** A soft horn pad, only ever heard when the shop is busy. */
  function vPad(t, midi, dur, gain = 0.06) {
    const o = ctx.createOscillator();
    o.type = 'sawtooth';
    o.frequency.value = mtof(midi);
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.setValueAtTime(400, t);
    f.frequency.linearRampToValueAtTime(1500, t + dur * 0.4);
    f.frequency.linearRampToValueAtTime(500, t + dur);
    f.Q.value = 3;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gain, t + 0.18);
    g.gain.linearRampToValueAtTime(0, t + dur);
    o.connect(f); f.connect(g); g.connect(bus.colour);
    o.start(t); o.stop(t + dur + 0.05);
  }

  /** A struck bell: inharmonic partials, which is what makes metal metal. */
  function bell(t, hz, dur, gain, out) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gain, t + 0.004);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    for (const [mul, amp, dec] of [[1, 1, 1], [2.0, 0.4, 0.7], [2.76, 0.22, 0.5], [5.4, 0.09, 0.3]]) {
      const o = ctx.createOscillator();
      o.type = 'sine';
      o.frequency.value = hz * mul * rand(0.998, 1.002);
      const og = ctx.createGain();
      og.gain.setValueAtTime(amp, t);
      og.gain.exponentialRampToValueAtTime(0.0001, t + dur * dec);
      o.connect(og); og.connect(g);
      o.start(t); o.stop(t + dur + 0.05);
    }
    g.connect(out || sfx);
  }

  function kick(t, gain = 0.5) {
    const o = ctx.createOscillator();
    o.type = 'sine';
    o.frequency.setValueAtTime(125, t);
    o.frequency.exponentialRampToValueAtTime(44, t + 0.085);
    const g = ctx.createGain();
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.19);
    o.connect(g); g.connect(bus.drums);
    o.start(t); o.stop(t + 0.22);
    noiseVoice(t, 0.02, bus.drums, { type: 'lowpass', freq: 1800, gain: gain * 0.18 });
  }

  /** Brushes, not sticks: a swirl with a body, never a crack. */
  function brush(t, gain = 0.16) {
    noiseVoice(t, 0.17, bus.drums, { type: 'bandpass', freq: 1900, Q: 0.8, gain });
    noiseVoice(t, 0.06, bus.drums, { type: 'highpass', freq: 5200, gain: gain * 0.5 });
  }

  const ride = (t, gain = 0.05) =>
    noiseVoice(t, 0.055, bus.drums, { type: 'highpass', freq: 7600, gain });
  const shaker = (t, gain = 0.05) =>
    noiseVoice(t, 0.045, bus.colour, { type: 'bandpass', freq: 6400, Q: 1.6, gain });

  // --- transport --------------------------------------------------------------

  /** Where the eighth note sits: straight would be 0.5, swung sits later. */
  const eighth = (n) => (n % 2 === 0 ? n / 2 : (n - 1) / 2 + SWING);

  function barOf(b) { return Math.floor(b / 4) % BARS; }

  function scheduleBeat(n, t) {
    const loopBeat = ((n % (BARS * 4)) + BARS * 4) % (BARS * 4);
    const bar = Math.floor(loopBeat / 4);
    const inBar = loopBeat % 4;
    const [root, iv] = PROG[bar];
    const [nextRoot] = PROG[(bar + 1) % BARS];

    // BASS — a walking line. Root, third, fifth, then a chromatic step into
    // whatever is coming, which is the whole reason a walking line walks.
    const walk = [root, root + iv[1], root + 7,
      (inBar === 3 ? (nextRoot > root ? nextRoot - 1 : nextRoot + 1) : root)];
    vBass(t, walk[inBar] - 12, SPB * 0.92, 0.42);

    // KEYS — comping off the beat, which is where a comp lives.
    if (inBar === 1 || inBar === 3) {
      const voicing = iv.map((i) => root + 12 + i);
      const stab = t + SPB * (SWING - 0.5) * (inBar === 1 ? 1 : 0.6);
      voicing.forEach((m, k) => vKeys(stab + k * 0.006, m, SPB * 1.7, 0.085));
    }
    if (inBar === 0 && bar % 4 === 0) {
      // A held colour tone at the top of each four-bar phrase.
      vKeys(t, root + 24 + iv[3], SPB * 2.4, 0.05);
    }

    // LEAD — the hook, looked up by beat.
    for (const [b, m, d] of MELODY) {
      if (Math.floor(b) !== loopBeat) continue;
      vLead(t + (b - Math.floor(b)) * SPB, m, d * SPB, 0.16);
    }

    // DRUMS — kick on one and the and-of-three, brushes on two and four, a
    // swung ride throughout.
    if (inBar === 0) kick(t, 0.5);
    if (inBar === 2) kick(t + SPB * SWING, 0.34);
    if (inBar === 1 || inBar === 3) brush(t, 0.15);
    ride(t, 0.055);
    ride(t + SPB * SWING, 0.032);
    // The kit builds with the crowd rather than merely getting louder: the
    // ride doubles once the shop is busy and a tambourine joins on two and
    // four when it is heaving. Layers arriving is what a band does when a room
    // fills up; a fader is what a mixing desk does.
    if (frenzy > 0.45) {
      ride(t + SPB * 0.25, 0.022);
      ride(t + SPB * (SWING + 0.19), 0.022);
    }
    if (frenzy > 0.7 && (inBar === 1 || inBar === 3)) {
      noiseVoice(t, 0.1, bus.colour, { type: 'bandpass', freq: 5200, Q: 1.1, gain: 0.06 });
      noiseVoice(t + 0.012, 0.07, bus.colour, { type: 'highpass', freq: 8000, gain: 0.04 });
    }

    // COLOUR — shaker on the eighths, and a pad under each bar.
    shaker(t, 0.04);
    shaker(t + SPB * SWING, 0.028);
    if (inBar === 0) {
      vPad(t, root + 12 + iv[2], SPB * 3.6, 0.05);
      vPad(t + 0.02, root + 12 + iv[3], SPB * 3.6, 0.035);
    }
  }

  function pump() {
    if (!ctx) return;
    while (beatAt < ctx.currentTime + LOOKAHEAD) {
      scheduleBeat(beat, beatAt);
      beat++;
      beatAt += SPB;
    }
  }

  function startTransport() {
    if (started || !ctx) return;
    started = true;
    beat = 0;
    beatAt = ctx.currentTime + 0.12;
    pump();
    timer = setInterval(pump, TICK);
  }

  // --- effects ----------------------------------------------------------------

  /** The chord sounding right now, laid out over three octaves, low to high. */
  function chordTones() {
    if (!ctx) return [60, 63, 67, 70];
    const b = barOf(Math.max(0, beat - 2));
    const [root, iv] = PROG[b];
    const out = [];
    for (let oct = 0; oct < 4; oct++) for (const i of iv) out.push(root + 24 + i + oct * 12);
    return out.sort((a, b2) => a - b2);
  }

  /** Dip the music so an effect lands on top of it rather than inside it. */
  function dip(amount = 0.72, hold = 0.06) {
    if (!ctx || !duck) return;
    const t = ctx.currentTime;
    duck.gain.cancelScheduledValues(t);
    duck.gain.setValueAtTime(duck.gain.value, t);
    duck.gain.linearRampToValueAtTime(amount, t + 0.012);
    duck.gain.linearRampToValueAtTime(1, t + 0.012 + hold + 0.22);
  }

  function ready() {
    if (muted) return null;
    const c = ensure();
    if (!c) return null;
    if (c.state === 'suspended') c.resume();
    return c;
  }

  return {
    unlock() {
      const c = ensure();
      if (!c) return;
      if (c.state === 'suspended') c.resume();
      startTransport();
      applyMix(0.6);
    },

    /**
     * The same tune, a different room. Nothing restarts; five gains and a
     * filter move, and the seam the player never hears is the point.
     */
    setPhase(name) {
      if (phase === name) return;
      phase = name;
      applyMix(0.9);
    },

    toggleMute() {
      muted = !muted;
      if (ctx) master.gain.setTargetAtTime(muted ? 0 : (MIX[phase] || MIX.night).vol, ctx.currentTime, 0.08);
      return muted;
    },

    /**
     * A sale. The single most repeated sound in the game, so it carries the
     * most weight per byte.
     *
     * The bell is pitched from the chord that is sounding, so it can never
     * clash, and consecutive sales climb that chord — reset by a gap of about
     * a beat. A run of six is audibly a run of six. A drawer closes under it
     * so the till has a body as well as a ring.
     */
    sale() {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      combo = t - lastSale > 1.05 ? 0 : Math.min(11, combo + 1);
      lastSale = t;
      const tones = chordTones();
      const midi = tones[Math.min(tones.length - 1, 4 + combo)];
      const hz = mtof(midi) * rand(0.997, 1.003);
      bell(t, hz, 0.5 + combo * 0.03, 0.16);
      if (combo >= 3) bell(t + 0.02, hz * 1.5, 0.32, 0.05);
      if (combo >= 7) bell(t + 0.05, hz * 2, 0.5, 0.035);
      // The drawer.
      noiseVoice(t, 0.07, sfx, { type: 'lowpass', freq: 420, gain: 0.16 });
      const o = c.createOscillator();
      const g = c.createGain();
      o.type = 'sine';
      o.frequency.setValueAtTime(88, t);
      o.frequency.exponentialRampToValueAtTime(52, t + 0.07);
      g.gain.setValueAtTime(0.11, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.11);
      o.connect(g); g.connect(sfx);
      o.start(t); o.stop(t + 0.13);
      dip(0.86, 0.02);
    },

    /** A walkout: two notes falling, and the door. Regret, not punishment. */
    walkout() {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      const tones = chordTones();
      const hi = tones[3];
      for (const [k, m] of [[0, hi], [0.09, hi - 3]]) {
        const o = c.createOscillator();
        const g = c.createGain();
        o.type = 'triangle';
        o.frequency.value = mtof(m - 12);
        g.gain.setValueAtTime(0, t + k);
        g.gain.linearRampToValueAtTime(0.075, t + k + 0.012);
        g.gain.exponentialRampToValueAtTime(0.0001, t + k + 0.24);
        o.connect(g); g.connect(sfx);
        o.start(t + k); o.stop(t + k + 0.28);
      }
      noiseVoice(t + 0.16, 0.09, sfx, { type: 'lowpass', freq: 340, gain: 0.09 });
      combo = 0;
    },

    /** Triage — you reached in and did that. Crisper than anything else. */
    triage() {
      const c = ready();
      if (!c) return;
      const tones = chordTones();
      bell(c.currentTime, mtof(tones[tones.length - 3]), 0.42, 0.15);
      noiseVoice(c.currentTime, 0.02, sfx, { type: 'highpass', freq: 6000, gain: 0.06 });
      dip(0.85, 0.02);
    },

    /** Placing a fixture: joinery. A knock with wood in it, then it settles. */
    place() {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      noiseVoice(t, 0.055, sfx, { type: 'bandpass', freq: rand(380, 460), Q: 5, gain: 0.4 });
      noiseVoice(t, 0.02, sfx, { type: 'highpass', freq: 3000, gain: 0.08 });
      const o = c.createOscillator();
      const g = c.createGain();
      o.type = 'triangle';
      o.frequency.setValueAtTime(rand(210, 250), t);
      o.frequency.exponentialRampToValueAtTime(120, t + 0.09);
      g.gain.setValueAtTime(0.13, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
      o.connect(g); g.connect(sfx);
      o.start(t); o.stop(t + 0.14);
      const tones = chordTones();
      vKeys(t + 0.02, tones[2], 0.7, 0.07, sfx);
      dip(0.88, 0.02);
    },

    /**
     * Combining. An arpeggio UP the chord that is playing, so levelling a
     * fixture is the tune agreeing with you. Level three gets the full run and
     * a shimmer, so three is different in kind rather than merely louder.
     */
    combine(level) {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      const tones = chordTones();
      const n = level >= 3 ? 6 : level >= 2 ? 4 : 3;
      for (let i = 0; i < n; i++) {
        bell(t + i * 0.055, mtof(tones[2 + i]), 0.6, 0.11 - i * 0.008);
      }
      if (level >= 3) {
        bell(t + 0.34, mtof(tones[tones.length - 2]), 1.4, 0.09);
        noiseVoice(t + 0.34, 0.5, sfx, { type: 'highpass', freq: 7000, gain: 0.05 });
      }
      dip(0.7, 0.14);
    },

    /**
     * The doors. A department-store two-note chime, tuned to the tune — the
     * one sound in the game that is allowed to be nostalgic on purpose.
     */
    tannoy() {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      const tones = chordTones();
      bell(t, mtof(tones[5]), 1.5, 0.16);
      bell(t + 0.26, mtof(tones[2]), 2.2, 0.16);
      noiseVoice(t, 0.35, sfx, { type: 'lowpass', freq: 600, gain: 0.03 });
      dip(0.6, 0.3);
    },

    /** The landlord. A low stab with a tritone in it, and no resolution. */
    boss() {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      for (const [m, amp] of [[36, 0.13], [42, 0.09], [48, 0.05]]) {
        const o = c.createOscillator();
        const g = c.createGain();
        const f = c.createBiquadFilter();
        o.type = 'sawtooth';
        o.frequency.value = mtof(m) * rand(0.997, 1.003);
        f.type = 'lowpass';
        f.frequency.setValueAtTime(2200, t);
        f.frequency.exponentialRampToValueAtTime(300, t + 0.5);
        g.gain.setValueAtTime(0, t);
        g.gain.linearRampToValueAtTime(amp, t + 0.02);
        g.gain.exponentialRampToValueAtTime(0.0001, t + 0.9);
        o.connect(f); f.connect(g); g.connect(sfx);
        o.start(t); o.stop(t + 0.95);
      }
      dip(0.5, 0.35);
    },

    /** The printer, then the tear. */
    receipt() {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      for (let i = 0; i < 16; i++) {
        noiseVoice(t + i * 0.034 + rand(0, 0.008), 0.02, sfx,
          { type: 'bandpass', freq: rand(1800, 3200), Q: 3, gain: 0.09 });
      }
      noiseVoice(t + 0.58, 0.22, sfx, { type: 'highpass', freq: 2400, gain: 0.11 });
      dip(0.8, 0.5);
    },

    /**
     * The verdict. A cadence that lands on the tonic when you clear the
     * target and one that refuses to when you do not — the arithmetic already
     * told you; this is so you knew before you read it.
     */
    verdict(won) {
      const c = ready();
      if (!c) return;
      const t = c.currentTime;
      if (won) {
        [[0, 60], [0.1, 63], [0.2, 67], [0.3, 72]].forEach(([d, m]) =>
          bell(t + d, mtof(m + 12), 1.6, 0.12));
        vBass(t + 0.3, 36, 1.6, 0.4);
      } else {
        [[0, 68], [0.16, 65], [0.32, 62], [0.48, 59]].forEach(([d, m]) =>
          bell(t + d, mtof(m), 1.1, 0.11));
      }
      dip(0.55, 0.5);
    },

    /** A button. Barely anything, but silence on a press feels broken. */
    ui() {
      const c = ready();
      if (!c) return;
      noiseVoice(c.currentTime, 0.018, sfx, { type: 'bandpass', freq: 2400, Q: 4, gain: 0.05 });
    },

    /**
     * One parameter, and it moves the mix rather than a volume: a busy shop
     * opens the filter, brings the shaker and the horn pad up, pushes the kit,
     * and thickens the room tone under all of it.
     */
    setFrenzy(v) {
      const changed = Math.abs(v - frenzy) > 0.02;
      frenzy = v;
      if (!ctx || !changed) return;
      applyMix(0.7);
      if (chatterTimer) clearTimeout(chatterTimer);
      const tick = () => {
        if (!muted && ctx && phase === 'day') {
          const base = rand(150, 340);
          for (const [f2, g2, d2] of [[base, 0.010, 0.09], [base * rand(1.1, 1.6), 0.007, 0.07]]) {
            const o = ctx.createOscillator();
            const g = ctx.createGain();
            o.type = 'triangle';
            o.frequency.value = f2;
            const t = ctx.currentTime + rand(0, 0.1);
            g.gain.setValueAtTime(0, t);
            g.gain.linearRampToValueAtTime(g2, t + 0.02);
            g.gain.exponentialRampToValueAtTime(0.0001, t + d2);
            o.connect(g); g.connect(master);
            o.start(t); o.stop(t + d2 + 0.05);
          }
        }
        chatterTimer = setTimeout(tick, rand(160, 900) / (0.25 + frenzy * 1.6));
      };
      if (v > 0.03 && !muted) chatterTimer = setTimeout(tick, rand(120, 700));
    },

    /** The day is over. Let the room fall away; the tune keeps going. */
    quiet() {
      if (chatterTimer) { clearTimeout(chatterTimer); chatterTimer = null; }
      frenzy = 0;
      combo = 0;
      if (ctx) applyMix(0.9);
    },

    /** For the tools: is anything actually running? */
    get running() { return !!ctx && started; },
    stop() { if (timer) { clearInterval(timer); timer = null; } started = false; },
  };
}
