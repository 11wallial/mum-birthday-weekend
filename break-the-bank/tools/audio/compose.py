"""Renders the score's three layers to seamless WAV loops.

The Music bus had nothing but three synth drones. This composes what the
adaptive score actually needs and renders it offline, where a proper
envelope, a stack of partials and a wrapped reverb tail are affordable and
a per-sample GDScript loop is not.

    python3 tools/audio/compose.py

Three stems, all in A natural minor, all 16 seconds at 44.1 kHz mono, all
seamless — every partial is an integer number of cycles per loop and the
reverb is circular, so the join is silent:

  music_bed_loop    the room's chord: A2 and its fifth, a minor third over
                    them, breathing. What the House sounds like standing
                    still. AudioDirector.set_floor drops it a semitone per
                    floor, so the descent is heard as well as read.
  music_fifth_loop  the counting figure: a plucked four-note round that
                    adds up and starts again. Enters on the third floor.
  music_pulse_loop  the machine's pulse: a low thud on the beat and a tick
                    off it, brought up with the surety and dropped when the
                    floor is covered.

Everything here is authored for this project; nothing is sampled.
"""
import math
import pathlib
import struct
import wave

import numpy as np

RATE = 44100
SECONDS = 16.0
BEATS = 16            # one beat a second at 60 BPM
FRAMES = int(RATE * SECONDS)
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "audio" / "music"

# A natural minor, the key the whole score sits in.
A2, C3, E3, A3, C4, E4, G3, D4 = 110.0, 130.81, 164.81, 220.0, 261.63, 329.63, 196.0, 293.66


def _t() -> np.ndarray:
    return np.arange(FRAMES) / RATE


def _lock(freq: float) -> float:
    """Snaps a frequency to a whole number of cycles per loop, so the
    waveform meets itself at the join."""
    return max(1.0, round(freq * SECONDS)) / SECONDS


def _sine(freq: float, amp: float = 1.0, phase: float = 0.0) -> np.ndarray:
    return amp * np.sin(2.0 * np.pi * _lock(freq) * _t() + phase)


def _breath(rate_hz: float, depth: float, phase: float = 0.0) -> np.ndarray:
    """A slow amplitude swell, itself locked to the loop."""
    return 1.0 - depth + depth * 0.5 * (1.0 + np.sin(2.0 * np.pi * _lock(rate_hz) * _t() + phase))


def _reverb(signal: np.ndarray, seconds: float, mix: float, seed: int) -> np.ndarray:
    """Circular convolution with a decaying noise tail: a room, and one
    whose tail wraps into the head so the loop stays seamless."""
    rng = np.random.default_rng(seed)
    length = int(RATE * seconds)
    tail = rng.standard_normal(length) * np.exp(-np.linspace(0.0, 7.0, length))
    tail[0] = 1.0
    kernel = np.zeros(FRAMES)
    kernel[:length] = tail
    wet = np.real(np.fft.ifft(np.fft.fft(signal) * np.fft.fft(kernel)))
    wet /= max(np.max(np.abs(wet)), 1e-9)
    return (1.0 - mix) * signal + mix * wet


def _pluck(freq: float, at: float, decay: float, amp: float) -> np.ndarray:
    """One struck note, wrapped round the loop's end if it runs past it."""
    length = int(RATE * min(decay * 4.0, SECONDS))
    n = np.arange(length) / RATE
    body = (np.sin(2.0 * np.pi * freq * n)
            + 0.5 * np.sin(4.0 * np.pi * freq * n)
            + 0.22 * np.sin(6.0 * np.pi * freq * n))
    # A hammer on the front, then the string.
    body += 0.6 * np.random.default_rng(int(freq)).standard_normal(length) * np.exp(-n * 180.0)
    note = amp * body * np.exp(-n / decay)
    out = np.zeros(FRAMES)
    start = int(RATE * at)
    for i in range(0, length, FRAMES):
        chunk = note[i:i + FRAMES]
        idx = (np.arange(len(chunk)) + start + i) % FRAMES
        out[idx] += chunk
    return out


def bed() -> np.ndarray:
    """The chord the room is tuned to."""
    out = np.zeros(FRAMES)
    # Root and fifth, each with a detuned twin a fraction of a hertz away:
    # the beating between them is what makes a pad sound like air.
    for freq, amp in ((A2, 0.5), (E3, 0.3), (C4, 0.16), (A3, 0.12)):
        out += _sine(freq, amp) * _breath(1.0 / 8.0, 0.35)
        out += _sine(freq * 1.004, amp * 0.7) * _breath(1.0 / 11.0, 0.4, 1.3)
    # A sub under it: the building's own note.
    out += _sine(A2 / 2.0, 0.35) * _breath(1.0 / 16.0, 0.25)
    # The third comes and goes, so the chord is never quite settled.
    out += _sine(C3, 0.14) * _breath(1.0 / 16.0, 0.9, 2.2)
    out = np.tanh(out * 0.9)
    return _reverb(out, 2.6, 0.34, 11)


def fifth() -> np.ndarray:
    """The counting figure: four notes that add up and start again."""
    out = np.zeros(FRAMES)
    figure = [A3, C4, E4, D4]
    for bar in range(BEATS // 4):
        for step, freq in enumerate(figure):
            at = bar * 4.0 + step * 1.0
            # The last note of every second round is held longer: the
            # ledger pausing before it turns the page.
            decay = 1.6 if (step == 3 and bar % 2 == 1) else 0.7
            out += _pluck(_lock(freq), at, decay, 0.30 if step == 0 else 0.22)
    # A high harmonic on the first beat of every bar, quiet: a tally mark.
    for bar in range(BEATS // 4):
        out += _pluck(_lock(E4 * 2.0), bar * 4.0, 0.35, 0.07)
    return _reverb(out, 1.8, 0.3, 23)


def pulse() -> np.ndarray:
    """The machine, ticking over."""
    out = np.zeros(FRAMES)
    rng = np.random.default_rng(37)
    for beat in range(BEATS):
        at = float(beat)
        # The thud: a pitch-dropping sine with a click on the front.
        length = int(RATE * 0.5)
        n = np.arange(length) / RATE
        sweep = 90.0 * np.exp(-n * 9.0) + 42.0
        thud = 0.5 * np.sin(2.0 * np.pi * np.cumsum(sweep) / RATE) * np.exp(-n * 7.0)
        thud += 0.25 * rng.standard_normal(length) * np.exp(-n * 90.0)
        idx = (np.arange(length) + int(RATE * at)) % FRAMES
        out[idx] += thud
        # The tick, off the beat, quieter and drier.
        tick_len = int(RATE * 0.14)
        m = np.arange(tick_len) / RATE
        tick = 0.16 * rng.standard_normal(tick_len) * np.exp(-m * 120.0)
        tick += 0.1 * np.sin(2.0 * np.pi * 1400.0 * m) * np.exp(-m * 70.0)
        jdx = (np.arange(tick_len) + int(RATE * (at + 0.5))) % FRAMES
        out[jdx] += tick
    return _reverb(out, 1.2, 0.22, 41)


def write(name: str, signal: np.ndarray, peak: float) -> None:
    signal = signal / max(np.max(np.abs(signal)), 1e-9) * peak
    data = (signal * 32767.0).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    print("%-24s %6.1f s  %5.0f kB" % (name, SECONDS, (OUT / name).stat().st_size / 1024))


if __name__ == "__main__":
    write("music_bed_loop.wav", bed(), 0.72)
    write("music_fifth_loop.wav", fifth(), 0.62)
    write("music_pulse_loop.wav", pulse(), 0.66)
