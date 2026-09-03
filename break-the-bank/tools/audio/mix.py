"""Measures every cue and sets its level so the mix is even.

A manifest of ninety-six cues, some sourced and some synthesised, will not
sit at one loudness by accident: Kenney's packs are mastered hotter than
the placeholder synthesiser, the stingers were authored by ear months
apart, and nothing had ever measured any of it.

    godot --headless --path . --script res://tools/audio/bake_placeholders.gd -- --out=/tmp/ph
    python3 tools/audio/mix.py --placeholders=/tmp/ph [--write]

For each cue it takes the sourced file if there is one and the baked
placeholder otherwise, measures gated RMS in dBFS — the gate keeps a long
tail of silence from flattering a short hit — and works out the
`base_volume_db` that puts it on its category's target. Without --write it
only reports; with it, the manifest is rewritten.

The targets are relative, not absolute: what matters is that a click never
buries a payout and an ambience bed never competes with either. The bus
layout carries the absolute levels.
"""
import argparse
import pathlib
import re
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
CUES = ROOT / "resources" / "audio" / "cues"
AUDIO = ROOT / "assets" / "audio"

# The target is not invented: it is the level the synthesised cues already
# play at, per category, taken as the median of (file level + the level
# the manifest asks for). Somebody tuned those by ear over months; the
# newly sourced files are the ones out of place, and this pulls them into
# the mix that exists rather than replacing it with a number from a book.
CATEGORY = {0: "UI", 1: "MECHANICAL", 2: "LOGIC", 3: "AMBIENCE", 4: "MUSIC"}
# The score has no synthesised siblings to take a median from, and it is
# meant to sit under everything: it gets a level rather than a vote.
FIXED_TARGETS = {4: -30.0}
# No cue is pushed further than this from where it was authored: a level
# that moves twenty decibels is a measurement mistake, not a mix.
MAX_MOVE = 9.0
FLOOR, CEILING = -34.0, -6.0


def gated_rms_dbfs(path: pathlib.Path) -> float | None:
    try:
        with wave.open(str(path), "rb") as handle:
            frames = handle.readframes(handle.getnframes())
            channels = handle.getnchannels()
    except (wave.Error, FileNotFoundError):
        return None
    if not frames:
        return None
    data = np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0
    if channels > 1:
        data = data.reshape(-1, channels).mean(axis=1)
    if data.size == 0:
        return None
    # 50 ms blocks, keeping only those within 25 dB of the loudest: the
    # sound, not the silence around it.
    block = max(int(0.05 * 44100), 1)
    blocks = data[: (data.size // block) * block].reshape(-1, block)
    if blocks.size == 0:
        blocks = data.reshape(1, -1)
    power = (blocks ** 2).mean(axis=1)
    peak = power.max()
    if peak <= 0.0:
        return None
    kept = power[power >= peak * 10 ** (-25.0 / 10.0)]
    return 10.0 * np.log10(kept.mean())


def read(field: str, text: str, cast=float):
    found = re.search(r"^%s = (.+)$" % field, text, re.M)
    return cast(found.group(1)) if found else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--placeholders", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    baked = pathlib.Path(args.placeholders)

    measurements = []
    for tres in sorted(CUES.glob("*.tres")):
        text = tres.read_text()
        cue = read("id", text, lambda v: v.strip().strip('&"'))
        category = read("category", text, int)
        file_name = read("file_name", text, lambda v: v.strip().strip('"'))
        base = read("base_volume_db", text)
        sourced = AUDIO / file_name
        path = sourced if sourced.exists() else baked / ("%s.wav" % cue)
        measured = gated_rms_dbfs(path)
        if measured is not None:
            measurements.append((category, sourced.exists(), measured, base))
    targets = {}
    for category in sorted(CATEGORY):
        played = [m + b for c, is_src, m, b in measurements if c == category and not is_src]
        if category in FIXED_TARGETS:
            targets[category] = FIXED_TARGETS[category]
        else:
            targets[category] = float(np.median(played)) if played else -26.0
        print("%-11s target %6.1f dBFS  (%s)" % (CATEGORY[category], targets[category],
              "set" if category in FIXED_TARGETS else "median of %d synthesised cues" % len(played)))
    print()

    rows = []
    for tres in sorted(CUES.glob("*.tres")):
        text = tres.read_text()
        cue = read("id", text, lambda v: v.strip().strip('&"'))
        category = read("category", text, int)
        file_name = read("file_name", text, lambda v: v.strip().strip('"'))
        base = read("base_volume_db", text)
        sourced = AUDIO / file_name
        path = sourced if sourced.exists() else baked / ("%s.wav" % cue)
        measured = gated_rms_dbfs(path)
        if measured is None:
            print("  %-26s no audio to measure" % cue)
            continue
        want = targets[category] - measured
        move = max(-MAX_MOVE, min(MAX_MOVE, want - base))
        new = max(FLOOR, min(CEILING, base + move))
        rows.append((cue, CATEGORY[category], sourced.exists(), measured, base, new, tres, text))

    print("%-26s %-11s %-6s %8s %8s %8s" % ("cue", "category", "src", "rms", "was", "now"))
    for cue, category, is_sourced, measured, base, new, _, _ in rows:
        flag = "*" if abs(new - base) >= 1.0 else " "
        print("%-26s %-11s %-6s %7.1f %7.1f %7.1f %s" % (
            cue, category, "file" if is_sourced else "synth", measured, base, new, flag))
    moved = [r for r in rows if abs(r[5] - r[4]) >= 1.0]
    print("\n%d cues measured, %d moved by a decibel or more" % (len(rows), len(moved)))
    if not args.write:
        print("(report only — pass --write to set them)")
        return
    for cue, _, _, _, _, new, tres, text in rows:
        tres.write_text(re.sub(r"^base_volume_db = .+$", "base_volume_db = %.1f" % new,
                               text, count=1, flags=re.M))
    print("manifest written")


if __name__ == "__main__":
    main()
