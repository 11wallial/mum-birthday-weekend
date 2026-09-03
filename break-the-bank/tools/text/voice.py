"""Reads every string the player sees and flags the ones out of register.

The bible sets the voice: dry, exact, faintly predatory, never cruel. The
House counts things; it does not threaten, apologise or shout, and it has
never heard of a button. Content in .tres has held that line for months.
The strings written in code — prompts, cards, the statement, the Clerk —
are the ones that drift, because each was written alone.

    python3 tools/text/voice.py            # report
    python3 tools/text/voice.py --strings  # every string it read

This flags, it does not fix: the register is a judgement, and a script
that rewrote prose by rule would flatten exactly what makes it a voice.
"""
import argparse
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
CONTENT_FIELDS = ("description", "intro", "tell", "line", "brief", "flavour",
                  "display_name", "requirement", "epitaph", "body", "text")
# Files whose string literals reach the player.
CODE = ["scripts/presentation/casino_room.gd", "scripts/presentation/tutorial_director.gd",
        "scripts/presentation/inspector.gd", "scripts/presentation/recap_panel.gd",
        "scripts/presentation/hud.gd", "scripts/presentation/title_screen.gd",
        "scripts/presentation/shop_panel.gd", "scripts/presentation/contract_panel.gd",
        "scripts/simulation/run_recap.gd", "scripts/simulation/endless.gd",
        # The cabinet's own words, which the pseudolocale check found nobody
        # was reading: the console keys, the drums' verdicts, the receipt,
        # the inspection card and the signs around the room.
        "scripts/presentation/control_deck.gd", "scripts/presentation/slot_view_3d.gd",
        "scripts/presentation/payout_receipt.gd", "scripts/presentation/room_dressing.gd",
        "scripts/presentation/look/machine_frame.gd", "scripts/presentation/look/room_set.gd",
        # Two in the simulation whose strings are shown as they stand: the
        # names of the systems a floor grants, and the patterns the line can
        # land in. The simulation never translates them; the cabinet does.
        "scripts/simulation/systems.gd", "scripts/simulation/artifact_engine.gd"]

RULES = [
    ("shouts", re.compile(r"!")),
    ("apologises", re.compile(r"\b(sorry|please|oops|whoops|congratulations)\b", re.I)),
    ("names the interface", re.compile(r"\b(menu|screen|window|dialog|click|UI|HUD)\b", re.I)),
    ("names the game", re.compile(r"\b(player|gamer|level up|respawn|XP)\b", re.I)),
    ("threatens", re.compile(r"\b(you'll regret|you will regret|beware|doomed)\b", re.I)),
    ("double space", re.compile(r"[a-z],  [a-z]")),
]
# Words the House would not use, and what it says instead. Deliberately
# short: "money" and "boss" are the House's own words — it has a pit boss
# and it talks about money — and a list that flags good prose is a list
# nobody runs twice.
BANNED_SYNONYMS = {"cash prize": "payout", "enemy": "the House's people",
                   "upgrade": "hardware", "buff": "hardware", "loot": "hardware",
                   "power-up": "hardware", "mini-game": None}
# A key hint has to name keys, and a touch hint has to name taps. Those
# are instructions, not the House talking.
HINT = re.compile(r"\b(SPACE|ENTER|ESC|TAB|F2|F5|SHIFT|CTRL|arrows|D-pad|1-%d|Tap|tap)\b")


def strings_from_content(shortest: int = 4) -> list[tuple[str, str]]:
    """Every player-visible string in the content. The default skips the very
    short ones, which carry no voice to judge; the extractor asks for all of
    them, because "IOU" needs translating as much as a paragraph does."""
    out = []
    for tres in sorted((ROOT / "resources").rglob("*.tres")):
        for line in tres.read_text().splitlines():
            found = re.match(r'^(\w+) = "(.*)"$', line)
            if found and found.group(1) in CONTENT_FIELDS and len(found.group(2)) >= shortest:
                out.append(("%s:%s" % (tres.relative_to(ROOT), found.group(1)), found.group(2)))
    return out


def strings_from_code() -> list[tuple[str, str]]:
    out = []
    for name in CODE:
        path = ROOT / name
        if not path.exists():
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if line.strip().startswith("#") or line.strip().startswith("##"):
                continue
            for text in re.findall(r'"((?:[^"\\]|\\.)*)"', line):
                # Prose, not a node path, a key, a format or a class name.
                if len(text) < 12 or " " not in text:
                    continue
                if text.startswith("res://") or text.startswith("user://"):
                    continue
                if re.fullmatch(r"[%\w\s.:,\-+/()]*%[sdfx][%\w\s.:,\-+/()]*", text):
                    pass
                if not re.search(r"[a-z]{3}\s[a-z]{2}", text):
                    continue
                out.append(("%s:%d" % (name, number), text))
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strings", action="store_true")
    args = parser.parse_args()
    content = strings_from_content()
    code = strings_from_code()
    print("read %d strings from content and %d from code" % (len(content), len(code)))
    flagged = 0
    for where, text in content + code:
        if HINT.search(text):
            continue
        hits = [name for name, rule in RULES if rule.search(text)]
        for word, instead in BANNED_SYNONYMS.items():
            if instead and re.search(r"\b%s\b" % word, text, re.I):
                hits.append("says %s, not %s" % (word, instead))
        if hits:
            flagged += 1
            print("\n  %s\n    %s\n    → %s" % (where, text[:150], ", ".join(hits)))
    print("\n%d of %d strings out of register" % (flagged, len(content) + len(code)))
    if args.strings:
        for where, text in content + code:
            print("%-58s %s" % (where, text[:110]))


if __name__ == "__main__":
    main()
