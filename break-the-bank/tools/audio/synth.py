"""Renders the cues whose briefs are a synthesis spec rather than a search.

Twenty-four of the ninety-six cues describe themselves in frequencies and
in the word *seamless* — "60-120 Hz rumble, gentle 2 kHz air", "90-140 Hz
plus rotational flutter near 12 Hz, must loop with no seam", "300/450 Hz,
deliberately unpleasant". A library recording of room tone has to be
loop-matched by hand and still will not hit that. These are cheaper and
better made than found, and they cost nothing to re-cut when a playtest
says the vig sting is too kind.

    python3 tools/audio/synth.py

Every loop is locked the way compose.py locks the score: each partial gets
an integer number of cycles in the file, and the noise beds are crossfaded
into themselves, so the join is silent rather than nearly silent. The
one-shots are free of that constraint and shaped by their envelope.

Written to assets/audio/. Each file still needs its CREDITS row — they are
project-owned, but the audit does not distinguish and a file nobody can
trace is a file nobody can clear.
"""

import pathlib
import wave

import numpy as np

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "audio"
RNG = np.random.default_rng(20260904)


def _n(seconds: float) -> int:
    return int(round(seconds * RATE))


def _t(seconds: float) -> np.ndarray:
    return np.arange(_n(seconds), dtype=np.float64) / RATE


def _lock(freq: float, seconds: float) -> float:
    """The nearest frequency with a whole number of cycles in the loop."""
    cycles = max(1.0, round(freq * seconds))
    return cycles / seconds


def _sine(freq: float, seconds: float, amp: float = 1.0, loop: bool = True,
          phase: float = 0.0) -> np.ndarray:
    f = _lock(freq, seconds) if loop else freq
    return amp * np.sin(2.0 * np.pi * f * _t(seconds) + phase)


def _noise(seconds: float, loop: bool = True) -> np.ndarray:
    """White noise that meets itself. A quarter-second equal-power crossfade
    from the tail into the head, which is inaudible on a broadband bed and
    is the difference between a loop and a click every few seconds."""
    n = _n(seconds)
    if not loop:
        return RNG.normal(0.0, 1.0, n)
    # The overlap is generated past the end and folded back into the head, so
    # the bed is exactly as long as the tones it sits under. Trimming the
    # crossfade off instead left the noise shorter than everything else.
    k = min(_n(0.25), n // 4)
    x = RNG.normal(0.0, 1.0, n + k)
    ramp = np.linspace(0.0, 1.0, k)
    x[:k] = x[:k] * np.sqrt(ramp) + x[n:n + k] * np.sqrt(1.0 - ramp)
    return x[:n]


def _band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """A brick-wall band, done on the spectrum because it is exact and the
    render is offline. Keeps a looped bed looping: the bin grid is the loop."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spec[(freqs < lo) | (freqs > hi)] = 0.0
    return np.fft.irfft(spec, n=len(x))


def _breath(rate_hz: float, seconds: float, depth: float) -> np.ndarray:
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(
        2.0 * np.pi * _lock(rate_hz, seconds) * _t(seconds)))


def _env(seconds: float, attack: float, decay: float, power: float = 1.5) -> np.ndarray:
    t = _t(seconds)
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    d = np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-4)) ** power
    return a * d


def _sputter(seconds: float, per_second: float, width: float) -> np.ndarray:
    """Sparse crackle: the neon's intermittent fault, the sign's sputter."""
    out = np.zeros(_n(seconds))
    for at in RNG.uniform(0.0, seconds, int(seconds * per_second)):
        i = _n(at)
        k = _n(width)
        if i + k >= len(out):
            continue
        out[i:i + k] += RNG.normal(0.0, 1.0, k) * np.linspace(1.0, 0.0, k) ** 2
    return out


def write(path: str, signal: np.ndarray, peak: float) -> None:
    signal = signal / max(np.max(np.abs(signal)), 1e-9) * peak
    data = (np.clip(signal, -1.0, 1.0) * 32767.0).astype("<i2")
    target = OUT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    print("%-38s %5.1f s  %6.0f kB" % (path, len(signal) / RATE,
                                       target.stat().st_size / 1024))


# --- the beds ------------------------------------------------------------
# Seamless, eventless, and quiet. These sit under everything for a whole run,
# so anything with a recognisable event in it becomes a tic by the third floor.

def room_hum() -> None:
    s = 24.0
    low = sum(_sine(f, s, a) for f, a in [(62, 1.0), (93, 0.42), (124, 0.2)])
    air = _band(_noise(s), 1400, 3200) * 0.05
    write("ambience/amb_room_hum_loop.wav", (low * _breath(0.08, s, 0.12) + air), 0.42)


def vault_drone() -> None:
    s = 10.0
    sub = sum(_sine(f, s, a) for f, a in [(31, 1.0), (46, 0.5), (78, 0.22)])
    plant = _band(_noise(s), 90, 420) * 0.09
    write("ambience/amb_vault_drone_loop.wav", (sub + plant) * _breath(0.06, s, 0.1), 0.46)


def neon_buzz() -> None:
    s = 14.0
    # Mains doubled: a transformer buzzes at twice the supply, with its odd
    # harmonics, and the fault is the crackle rather than the tone.
    buzz = sum(_sine(120 * k, s, 1.0 / (k ** 1.3)) for k in range(1, 9))
    write("ambience/amb_neon_buzz_loop.wav",
          buzz * 0.5 + _band(_sputter(s, 2.2, 0.02), 800, 6000) * 0.7, 0.4)


def wind() -> None:
    s = 8.0
    write("ambience/amb_wind_loop.wav",
          _band(_noise(s), 120, 1800) * _breath(0.22, s, 0.55), 0.36)


def mech_clatter() -> None:
    s = 20.0
    bed = _band(_noise(s), 60, 500) * 0.16
    clunks = np.zeros(_n(s))
    for at in RNG.uniform(0.4, s - 0.6, 14):
        i = _n(at)
        k = _n(0.18)
        hit = _band(RNG.normal(0, 1, k), 90, 900) * np.exp(-np.linspace(0, 7, k))
        clunks[i:i + k] += hit * RNG.uniform(0.3, 1.0)
    write("ambience/amb_mech_clatter_loop.wav", bed + clunks * 0.5, 0.34)


def machine_hum() -> None:
    s = 6.0
    mains = _sine(50, s) + _sine(100, s, 0.45) + _sine(150, s, 0.18)
    fan = _sine(400, s, 0.09) + _band(_noise(s), 300, 900) * 0.04
    write("mechanical/machine_hum_loop.wav", mains * 0.5 + fan, 0.34)


def coil_buzz() -> None:
    s = 3.0
    thin = sum(_sine(f, s, a) for f, a in [(2400, 1.0), (3600, 0.4), (4800, 0.18)])
    write("mechanical/coil_buzz_loop.wav",
          thin * 0.25 + _band(_sputter(s, 6.0, 0.008), 2000, 9000) * 0.5, 0.3)


def axle_whir() -> None:
    s = 0.8
    motor = sum(_sine(f, s, a) for f, a in [(88, 1.0), (176, 0.35), (264, 0.14)])
    armature = _band(_noise(s), 900, 4200) * 0.11
    write("mechanical/axle_whir_loop.wav", motor * 0.55 + armature, 0.44)


def reel_spin() -> None:
    s = 0.8
    # The drum: a fundamental with the flutter of a thing going round, which
    # is what stops it reading as a tone.
    drum = sum(_sine(f, s, a) for f, a in [(112, 1.0), (224, 0.3), (336, 0.12)])
    flutter = _breath(12.5, s, 0.3)
    edge = _band(_noise(s), 1200, 5200) * 0.13
    write("mechanical/reel_spin_loop.wav", (drum * 0.55 + edge) * flutter, 0.5)


def crt_hum() -> None:
    s = 4.0
    mains = _sine(50, s) + _sine(100, s, 0.3) + _sine(150, s, 0.12)
    flyback = _sine(15625, s, 0.05)
    write("retro/crt_hum_loop.wav",
          mains * 0.34 + flyback + _band(_noise(s), 2000, 9000) * 0.02, 0.26)


def nixie_hum() -> None:
    s = 3.0
    write("retro/nixie_hum_loop.wav",
          _sine(320, s, 0.5) * 0.3 + _band(_noise(s), 1800, 7000) * 0.05
          + _band(_sputter(s, 1.4, 0.006), 3000, 9000) * 0.3, 0.2)


def sign_buzz() -> None:
    s = 3.0
    buzz = sum(_sine(100 * k, s, 1.0 / (k ** 1.2)) for k in range(1, 7))
    write("retro/sign_buzz_loop.wav",
          buzz * 0.45 + _band(_sputter(s, 3.0, 0.015), 600, 5000) * 0.5, 0.34)


# --- the one-shots -------------------------------------------------------

def ante_siren() -> None:
    s = 1.6
    t = _t(s)
    sweep = 180 + 140 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * t - np.pi / 2))
    tone = np.sin(2 * np.pi * np.cumsum(sweep) / RATE)
    write("logic/ante_warning_siren.wav", tone * _env(s, 0.12, 1.6, 0.7), 0.5)


def default_alarm() -> None:
    s = 1.15
    t = _t(s)
    gate = (np.sin(2 * np.pi * 2.6 * t) > 0).astype(float)
    two = np.sin(2 * np.pi * 300 * t) * gate + np.sin(2 * np.pi * 450 * t) * (1 - gate)
    write("logic/debt_default_alarm.wav", two * _env(s, 0.02, 1.1, 0.6), 0.62)


def alarm_pulse() -> None:
    s = 1.15
    t = _t(s)
    gate = (np.sin(2 * np.pi * 4.0 * t) > 0.2).astype(float)
    tone = (np.sin(2 * np.pi * 620 * t) + 0.4 * np.sin(2 * np.pi * 930 * t)) * gate
    write("logic/alarm_pulse.wav", tone * _env(s, 0.01, 1.1, 0.6), 0.56)


def heat_rising() -> None:
    s = 0.7
    t = _t(s)
    glide = 84.0 * np.power(2.0, np.clip(t / 0.45, 0, 1) / 12.0)
    tone = np.sin(2 * np.pi * np.cumsum(glide) / RATE)
    body = tone + 0.4 * np.sin(2 * np.pi * np.cumsum(glide * 2) / RATE)
    write("logic/heat_rising.wav", body * _env(s, 0.06, 0.6, 0.8), 0.44)


def mult_swell() -> None:
    s = 0.9
    t = _t(s)
    rise = 220.0 * np.power(2.0, np.clip(t / 0.7, 0, 1))
    saw = np.zeros(len(t))
    for detune in (0.994, 1.0, 1.006):
        ph = np.cumsum(rise * detune) / RATE
        saw += 2.0 * (ph - np.floor(ph + 0.5))
    vib = 1.0 + 0.02 * np.sin(2 * np.pi * 5.5 * t)
    write("logic/mult_swell.wav", saw * vib * _env(s, 0.08, 0.7), 0.5)


def debt_sting() -> None:
    s = 0.8
    t = _t(s)
    drop = 120.0 * np.power(2.0, -np.clip(t / 0.55, 0, 1) * 1.6)
    write("logic/debt_sting.wav",
          np.sin(2 * np.pi * np.cumsum(drop) / RATE) * _env(s, 0.01, 0.5, 1.0), 0.66)


def tube_overload() -> None:
    s = 0.95
    t = _t(s)
    strain = np.sin(2 * np.pi * 100 * t) + 0.6 * np.sin(2 * np.pi * 300 * t)
    strain = np.tanh(strain * 3.2)
    fizz = _band(RNG.normal(0, 1, len(t)), 2000, 11000) * 0.5
    write("mechanical/tube_overload.wav", (strain + fizz) * _env(s, 0.02, 0.7), 0.6)


def synergy() -> None:
    s = 0.65
    t = _t(s)
    # Harmonically related to the payout chime so the two stack cleanly.
    shimmer = sum(np.sin(2 * np.pi * 660 * k * t) / k for k in (1, 2, 3, 4, 6, 8))
    rise = np.clip(t / 0.4, 0, 1)
    write("logic/synergy_activate.wav", shimmer * rise * _env(s, 0.05, 0.4), 0.44)


def _brass(freq: float, at: float, seconds: float, hold: float, amp: float,
           total: float) -> np.ndarray:
    out = np.zeros(_n(total))
    k = _n(seconds)
    i = _n(at)
    if i + k > len(out):
        k = len(out) - i
    t = np.arange(k) / RATE
    tone = sum(np.sin(2 * np.pi * freq * h * t) / (h ** 1.4) for h in (1, 2, 3, 4, 5))
    env = np.clip(t / 0.04, 0, 1) * np.exp(-np.maximum(t - hold, 0) / 0.3)
    out[i:i + k] += tone * env * amp
    return out


def floor_fanfare() -> None:
    s = 2.2
    notes = [(220.0, 0.0), (277.2, 0.16), (330.0, 0.32), (440.0, 0.5)]
    sig = sum(_brass(f, at, s - at, 0.5, 1.0, s) for f, at in notes)
    write("logic/floor_clear_fanfare.wav", sig, 0.55)


def win_fanfare() -> None:
    s = 3.4
    notes = [(220.0, 0.0), (277.2, 0.16), (330.0, 0.32), (440.0, 0.5),
             (554.4, 0.9), (659.3, 1.3)]
    sig = sum(_brass(f, at, s - at, 0.9, 1.0, s) for f, at in notes)
    coins = _band(_noise(s, loop=False), 1800, 9000) * np.exp(-_t(s) / 1.4) * 0.35
    write("logic/run_win_fanfare.wav", sig + coins, 0.6)


def sign_pop() -> None:
    s = 0.06
    k = _n(s)
    write("retro/sign_pop.wav",
          _band(RNG.normal(0, 1, k), 400, 7000) * np.exp(-np.linspace(0, 9, k)), 0.5)


def vig_deduct() -> None:
    s = 0.34
    t = _t(s)
    fall = 900.0 * np.power(2.0, -t / 0.22)
    thin = np.sin(2 * np.pi * np.cumsum(fall) / RATE)
    # Ends unresolved: cut while still falling rather than landing on a note.
    write("logic/debt_vig_deduct.wav", thin * _env(s, 0.01, 0.26, 0.9), 0.4)


ALL = [room_hum, vault_drone, neon_buzz, wind, mech_clatter, machine_hum,
       coil_buzz, axle_whir, reel_spin, crt_hum, nixie_hum, sign_buzz,
       ante_siren, default_alarm, alarm_pulse, heat_rising, mult_swell,
       debt_sting, tube_overload, synergy, floor_fanfare, win_fanfare,
       sign_pop, vig_deduct]

if __name__ == "__main__":
    for job in ALL:
        job()
    print("%d cues rendered" % len(ALL))
