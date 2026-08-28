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

## The eight surfaces

| | |
|---|---|
| **Today** | Your brief, the session launcher, what changed, and the misconceptions underneath your errors |
| **Drill** | The adaptive interleaved core loop |
| **Bench** | Timed written papers, marked to the scheme |
| **Panel** | Real interview questions under the clock, with pressure follow-ups |
| **Studio** | One case, many models — write yours first, then compare |
| **Room** | Role-play, scored on process not content |
| **Atlas** | A live map of the concept graph |
| **Ledger** | Your errors, classified, and what they share |

## Keyboard

`⌘K` command palette · `D 1–7` switch surface · `1–5` set confidence ·
`⏎` continue · `Esc` close

## Rebuilding

```bash
python3 tools/gen_concepts.py     # concept graph
python3 tools/gen_items.py        # drill items
python3 tools/gen_written.py      # written papers + rubrics
python3 tools/gen_interview.py    # interview bank
python3 tools/gen_practice.py     # formulation + role-play
python3 tools/build_trainer.py    # inline everything into trainer/index.html
```

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
