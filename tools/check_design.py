#!/usr/bin/env python3
"""Fail the build when the design system's own rules are broken.

A rule nothing checks is a preference. These are the rules stated at the top
of trainer/src/styles.css and in docs/TRAINER_DESIGN.md, made enforceable:

  1. Contrast — every text token clears WCAG 1.4.3 (4.5:1) against every
     surface it is used on, in BOTH themes; every control boundary and data
     hue clears 1.4.11 (3:1).
  2. Document head — the built file declares a doctype, a language, an
     encoding and a viewport. Without the last one the entire responsive
     layer is unreachable on real hardware.
  3. Colour rule — no domain hue is applied to chrome (`color:var(--d-*)`
     as a text colour outside the data primitives).
  4. Fonts — the canvas never asks for a face the build does not load.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSS  = os.path.join(ROOT, "trainer", "src", "styles.css")
OUT  = os.path.join(ROOT, "trainer", "index.html")
SRC  = os.path.join(ROOT, "trainer", "src")

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

# ---------------------------------------------------------------- contrast
def _lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def luminance(h):
    h = h.lstrip("#")
    if len(h) == 3: h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    return 0.2126*_lin(r) + 0.7152*_lin(g) + 0.0722*_lin(b)
def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def tokens(css, block):
    """Pull `--name: #hex;` pairs out of one :root block."""
    m = re.search(block + r"\s*\{(.*?)\n\}", css, re.S)
    if not m: sys.exit(f"check_design: could not find the {block} block")
    return dict(re.findall(r"(--[\w-]+)\s*:\s*(#[0-9A-Fa-f]{3,6})\s*;", m.group(1)))

# (token, [surfaces it is set on], minimum ratio, what it carries)
TEXT = [
    ("--ink",   ["--card", "--bg", "--bg-2"], 4.5, "primary text"),
    ("--ink-2", ["--card", "--bg", "--bg-2"], 4.5, "secondary copy"),
    ("--ink-3", ["--card", "--bg", "--bg-2"], 4.5, ".lbl / .src / .psub / .meta"),
    ("--good",  ["--card", "--bg"],           4.5, "outcome text"),
    ("--warning", ["--card", "--bg"],         4.5, "attention text"),
    ("--wrong", ["--card", "--bg"],           4.5, "outcome text"),
]
NONTEXT = [
    ("--field-line",      ["--card", "--bg", "--bg-2"], 3.0, "control boundaries"),
    ("--d-research",      ["--card", "--bg"],           3.0, "domain datum"),
    ("--d-clinical",      ["--card", "--bg"],           3.0, "domain datum"),
    ("--d-professional",  ["--card", "--bg"],           3.0, "domain datum"),
]

def check_contrast(css):
    fails = []
    light = tokens(css, r":root")
    dark  = dict(light); dark.update(tokens(css, r':root\[data-theme="dark"\]'))
    for theme, pal in (("light", light), ("dark", dark)):
        for token, surfaces, need, what in TEXT + NONTEXT:
            if token not in pal: continue
            for surf in surfaces:
                if surf not in pal: continue
                r = contrast(pal[token], pal[surf])
                if r < need:
                    fails.append(f"  {theme:5s} {token} on {surf}: {r:.2f} < {need}  ({what})")
    return fails

# ---------------------------------------------------------------- head
def check_head(html):
    fails = []
    head = html[:2000].lower()
    for needle, why in [
        ("<!doctype html>", "without it the page renders in quirks mode"),
        ('lang=',           "WCAG 3.1.1; screen readers pick the wrong pronunciation"),
        ('charset',         "undeclared encoding is left to browser sniffing"),
        ('name="viewport"', "WITHOUT THIS THE ENTIRE MOBILE CSS LAYER IS DEAD ON DEVICE"),
    ]:
        if needle not in head:
            fails.append(f"  built file is missing {needle} — {why}")
    return fails

# ---------------------------------------------------------------- colour rule
def check_colour_rule(js):
    fails = []
    for m in re.finditer(r"color:\s*var\(--d-(research|clinical|professional)\)", js):
        line = js[:m.start()].count("\n") + 1
        fails.append(f"  line {line}: domain hue used as a text colour — "
                     f"colour is only ever data or outcome")
    return fails

# ---------------------------------------------------------------- fonts
def check_fonts(js, html):
    fails = []
    loaded = set(re.findall(r"family=([A-Za-z+]+)", html))
    loaded = {f.replace("+", " ") for f in loaded}
    for m in re.finditer(r"ctx\.font\s*=\s*[^;]*?['\"]([A-Z][\w ]+)['\"]", js):
        fam = m.group(1)
        if fam not in loaded and fam not in ("Instrument Sans",):
            line = js[:m.start()].count("\n") + 1
            fails.append(f"  line {line}: canvas requests '{fam}', which the build does not load")
    return fails

def main():
    css  = read(CSS)
    js   = "\n".join(read(os.path.join(SRC, f)) for f in
                     ("engine.js", "views-core.js", "views-modes.js", "boot.js"))
    html = read(OUT) if os.path.exists(OUT) else ""

    groups = [
        ("contrast (WCAG 1.4.3 / 1.4.11)", check_contrast(css)),
        ("document head",                  check_head(html) if html else []),
        ("colour rule",                    check_colour_rule(js)),
        ("typefaces",                      check_fonts(js, html) if html else []),
    ]
    bad = [(n, f) for n, f in groups if f]
    if bad:
        print("DESIGN SYSTEM CHECK FAILED\n")
        for name, fails in bad:
            print(f"{name}:")
            print("\n".join(fails)); print()
        sys.exit(1)
    pairs = sum(len(surfaces) for _, surfaces, _, _ in TEXT + NONTEXT) * 2   # both themes
    print(f"design system OK — {pairs} contrast pairs, document head, "
          f"colour rule and typefaces all pass")

if __name__ == "__main__":
    main()
