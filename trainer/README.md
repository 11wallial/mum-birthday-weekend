# DClinPsy Trainer

A preparation engine for UK Doctorate in Clinical Psychology selection, built from
real past papers.

**Open `trainer/index.html`.** It is a single self-contained file — no build step,
no server, no network. All progress is stored in the browser's local storage.

## What is in it

- **199 concepts**, each with an exact formulation and the near-misses that lose marks
- **28 drill items** across five depth levels, including the 15 verbatim MCQs from
  the Surrey / Canterbury Christ Church 2016 paper
- **5 written papers** with **102 rubric points** — the Birmingham 2014 exercise is
  marked against its own official scheme
- **143 verbatim interview questions** from 8 courses (2011–2019), in 22 themes
- **6 multi-model formulation cases**, 24 model formulations
- **3 branching role-plays** scored on process

## How it is arranged

Three tabs, because metrics should not sit in your peripheral vision while you
are trying to think.

| | |
|---|---|
| **Today** | The session it would give you — stated in the headline, with what it covers and why |
| **Practice** | Drill, Papers, Panel, Studio, Room |
| **Progress** | Readiness, calibration, weakest concepts, the Atlas, the Ledger |

The five practice surfaces:

| | |
|---|---|
| **Drill** | The adaptive interleaved core loop |
| **Papers** | Timed written papers, marked to the scheme |
| **Panel** | Real interview questions under the clock, with pressure follow-ups |
| **Studio** | One case, many models — write yours first, then compare |
| **Room** | Role-play, scored on process not content |

Today shows the queue before you commit to it: which clusters the session will
cover, how many items each, and why each was chosen — due, sure-and-wrong,
lapsed, or unseen. Changing the duration re-plans it live. That panel is not a
summary written for display; it is the same priority calculation the drill runs
on.

While you are working, the navigation leaves and the item is alone on the page.
The bottom bar holds your confidence rating and the primary action, then becomes
the result panel — verdict, teaching, the precise formulation, the near-misses,
and the error classification.

## The design system

One rule governs colour: **neutrals carry the interface; colour is only ever data
or outcome.** Chrome and the primary action are warm ink on warm paper — there is
no decorative accent hue. The three domain colours appear only where they encode
a domain; the three status colours only where they encode an outcome.

Type is Instrument Sans for the interface and Newsreader for clinical and exam
material, in three weights and six steps, with tracking that tightens as size
grows. Spacing is a strict 4px scale, radius has four values, elevation has three
layered steps, and motion has four durations and three curves — all as tokens in
`trainer/src/styles.css`, with the rules written at the top of that file.

## Keyboard

`⌘K` command palette — actions first, then every mode, paper, theme, case,
role-play and concept · `?` the full list · `1–5` set confidence ·
`A–F` pick a choice · `⏎` continue · `Esc` close a dialog or leave a session ·
`← →` move between tabs

Single-key shortcuts can be switched off in the keyboard sheet (`?`).

## Accessibility

Every screen has a URL, so the browser's back button works and any screen can be
linked to. The dialog traps focus and gives it back. The drill moves focus to
each new question rather than dropping it. Answer selection, confidence and
rubric ticks all expose their state to a screen reader, and one polite announcer
carries the verdict rather than the whole action bar re-reading itself. Contrast
is held to 4.5:1 for text and 3:1 for control boundaries in both themes, and
`tools/check_design.py` fails the build if that stops being true.

## Rebuilding

```bash
python3 tools/gen_concepts.py     # concept graph
python3 tools/gen_items.py        # drill items
python3 tools/gen_written.py      # written papers + rubrics
python3 tools/gen_interview.py    # interview bank
python3 tools/gen_practice.py     # formulation + role-play
python3 tools/build_trainer.py    # inline everything into trainer/index.html
python3 tools/check_design.py     # fails on a contrast, head, colour-rule or font violation
```

`check_design.py` is the design system's teeth: 48 contrast pairs across both
themes, the document head, the colour rule, and the canvas typefaces. It exits
non-zero, so a violation stops the build rather than shipping.

The design rationale, including what was deliberately not built, is in
[`docs/TRAINER_DESIGN.md`](../docs/TRAINER_DESIGN.md).

## Caveats worth reading

- Free-text answers are matched against rubric cues and then **you** adjudicate
  each point. The matcher is literal; you are not. That adjudication is the exercise.
- Cardiff is the only one of the three confirmed courses represented in the
  corpus. Guidance for UCL and UEA is general. **Verify every course's current
  selection process on its own site** — these change year to year.
- Rubrics are transcribed from an official marking scheme only for Birmingham 2014.
  Everywhere else they are reconstructed from the question wording, and each
  paper's provenance field says which.
