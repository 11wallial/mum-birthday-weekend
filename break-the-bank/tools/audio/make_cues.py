#!/usr/bin/env python3
"""Generates the game's audio cues as 16-bit mono WAVs.

The cues are synthesised rather than sourced so they are reproducible, tiny and
unambiguously ours. Run from the project root after changing a cue:

    python3 tools/audio/make_cues.py

Every cue is short and dry; the 3D layer places them via AudioStreamPlayer3D, so
reverb and distance are the scene's business, not the sample's.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path("assets/audio")


def envelope(i: int, n: int, attack: float, release: float) -> float:
    t = i / n
    if t < attack:
        return t / attack
    if t > 1.0 - release:
        return max(0.0, (1.0 - t) / release)
    return 1.0


def tone(freq: float, seconds: float, *, harmonics=(1.0, 0.35, 0.12),
         attack=0.01, release=0.6, detune=0.0):
    n = int(RATE * seconds)
    for i in range(n):
        t = i / RATE
        value = 0.0
        for h, amp in enumerate(harmonics, start=1):
            value += amp * math.sin(2.0 * math.pi * freq * h * t)
            if detune:
                value += amp * 0.5 * math.sin(2.0 * math.pi * (freq * h + detune) * t)
        yield value * envelope(i, n, attack, release)


def noise_click(seconds: float, cutoff: float = 0.55):
    """A dry mechanical knock: filtered noise with a fast decay."""
    n = int(RATE * seconds)
    state = 0.0
    seed = 12345
    for i in range(n):
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        white = (seed / 0x3FFFFFFF) - 1.0
        state += cutoff * (white - state)
        yield state * envelope(i, n, 0.002, 0.85) * 1.4


def sequence(*parts):
    for part in parts:
        yield from part


def silence(seconds: float):
    for _ in range(int(RATE * seconds)):
        yield 0.0


def write(name: str, samples, gain: float = 0.6) -> None:
    frames = bytearray()
    peak = 0.0
    data = list(samples)
    for value in data:
        peak = max(peak, abs(value))
    scale = (gain / peak) if peak > 0 else 0.0
    for value in data:
        clamped = max(-1.0, min(1.0, value * scale))
        frames += struct.pack("<h", int(clamped * 32767))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(frames))
    print(f"{path}  {len(data) / RATE:.2f}s  {len(frames)} bytes")


def main() -> None:
    # A reel stopping: mechanical, no pitch, has to survive being played 3x fast.
    write("reel_stop.wav", noise_click(0.09), gain=0.5)
    # Payout: a rising third, bright and short.
    write("payout.wav", sequence(
        tone(660.0, 0.10, release=0.5),
        tone(880.0, 0.22, release=0.7),
    ))
    # A big win leans on the same interval but adds a fifth above.
    write("payout_big.wav", sequence(
        tone(660.0, 0.09, release=0.4),
        tone(880.0, 0.09, release=0.4),
        tone(1320.0, 0.34, harmonics=(1.0, 0.4, 0.2, 0.08), release=0.75),
    ))
    # Artifact trigger: metallic and slightly detuned, so it reads as machinery.
    write("artifact.wav", tone(392.0, 0.26, harmonics=(1.0, 0.6, 0.3, 0.15),
                               detune=3.5, release=0.7), gain=0.5)
    # Floor cleared: a four-note climb, the only cue allowed to feel triumphant.
    write("floor_cleared.wav", sequence(
        tone(523.0, 0.11, release=0.45), tone(659.0, 0.11, release=0.45),
        tone(784.0, 0.11, release=0.45), tone(1046.0, 0.38, release=0.8),
    ))
    # Run lost: the same shape inverted and detuned flat.
    write("run_lost.wav", sequence(
        tone(392.0, 0.14, release=0.5), tone(311.0, 0.16, release=0.5),
        tone(233.0, 0.5, harmonics=(1.0, 0.5, 0.25), release=0.85),
    ), gain=0.5)
    # Coin drop for the accumulating cash stacks in the room.
    write("coin.wav", sequence(
        noise_click(0.02), tone(1174.0, 0.10, harmonics=(1.0, 0.5), release=0.8),
    ), gain=0.35)


if __name__ == "__main__":
    main()
