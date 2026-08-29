# DClinPsy Trainer — design rationale

The brief asked for something pedagogically optimal rather than merely good. This
document records what was chosen, what was rejected, and why — so the decisions
can be argued with rather than inherited.

## 1. What the engine optimises for

The stated north star is **transferable clinical and research reasoning under
realistic selection conditions**. Everything below follows from taking that
literally rather than decoratively.

Three consequences:

1. **Coverage is not the objective.** Nothing counts the number of items answered.
   The learner model has no "% complete".
2. **Recognition is not mastery.** A concept's depth can only advance when an item
   at that depth is actually passed, and a failed transfer item takes depth back.
3. **The unit of practice is a reasoning move, not a fact.** The largest content
   investment is in rubrics — 102 marking points across five written papers, and
   "what the panel is listening for" for 22 interview themes.

## 2. The source material

Everything in the trainer derives from a corpus of real selection material:

| Source | What it gave |
|---|---|
| Birmingham 2014 written exercise | **The official marking scheme** — 44 points with weightings and marker instructions |
| Birmingham 2018 pre-selection test | Verbatim paper and its explicit marking instructions |
| Surrey / Canterbury Christ Church 2016 | 15 real stats/methods MCQs + a structured-abstract task |
| Cardiff 2016 written task | The non-1:1 scenario and its four suggested dimensions |
| South Wales 2015 written task | The reflective-letter scenario |
| Interview write-ups from 8 courses, 2011–2019 | 143 verbatim questions, tagged by course, year and panel |
| Two candidate tips documents | The meta-competencies (hypothesis language, tolerating not knowing) |

**Nothing in the question bank is invented.** Where a rubric had to be
reconstructed rather than transcribed, the provenance field says so explicitly.

## 3. The learner model

### Multidimensional, not a percentage

The brief was right to reject a single number, and specifically right to reject
"64% statistics mastery". Each of the 199 concepts carries:

- **depth** — the highest level actually passed: `recognise → recall → apply →
  discriminate → transfer`
- **stability** — a spaced-repetition memory strength, in days
- **retrievability** — `R = 0.9 ^ (elapsed / stability)`
- **accuracy** and **confident-error count**

Mastery is then `ceiling(depth) × decay(R) × accuracy`, where the ceiling is
`depth/5`. The practical effect: a concept you once transferred but have not
touched for two months reads lower than one you transferred last week, and a
concept you have only ever recognised cannot exceed 20 whatever you do to it.

### Readiness weights the weakest domain

`readiness = 0.62 × mean(domains) + 0.38 × min(domains)`

Selection filters candidates on their weakest panel, not their strongest. A
simple mean would let strong clinical reasoning hide weak methods — which is
exactly this learner's documented risk.

### Tier weighting

Domain scores weight tier-1 concepts ×3 and tier-2 ×2. Knowing what a funnel plot
is does not compensate for being shaky on what a p-value means.

## 4. Scheduling

A simplified FSRS. Stability grows multiplicatively on success, with a **spacing
bonus**: the gain is larger when retrievability had fallen, so successfully
recalling something you nearly forgot is worth more than drilling something fresh.

Three deliberate departures from a standard SRS:

- **Confident errors collapse stability to near zero** and are re-inserted later
  in the same session. High-confidence-wrong is the highest-value signal in the
  system, because it means the belief felt settled.
- **Transfer failures cost depth**, not just scheduling. If you cannot apply it in
  an unfamiliar context, you did not hold that level.
- **The scheduler is deadline-aware.** Inside 45 days to interview, intervals
  tighten to 0.7×; inside 14 days, to 0.5×. The phase shifts from acquisition to
  retrieval fluency.

## 5. Interleaving and session composition

Items are priority-scored on overdueness, lapse count, the weakness and centrality
of the concepts they touch, and confident-error history — then **interleaved with
a hard constraint that no more than two consecutive items come from the same
cluster.** This forces the learner to answer "what kind of problem is this?"
before answering the problem, which is precisely the discrimination the selection
tests demand and the thing blocked practice never trains.

## 6. Precision correction

The brief identified the central learning problem as *good intuition, insufficient
technical precision*. Every one of the 199 concepts therefore carries two fields:

- `precision` — the exact, defensible formulation
- `notThis` — the near-miss statements that lose marks

So after a wrong answer the engine can show the exact formulation **and** the
specific near-misses it is usually confused with. Example, from `p_value`:

> **Is:** the probability of obtaining data at least as extreme as those observed,
> IF the null hypothesis were true.
> **Is not:** the probability that the null hypothesis is true · the probability
> the result occurred by chance · the size or importance of the effect.

## 7. Free-text scoring — and its honest limits

Written answers are scored by matching text against per-point cue patterns, then
**the learner adjudicates every tick.**

This is a deliberate design choice, not only a technical constraint. The app is a
single static file with no backend, so it works offline, forever, and cannot lose
the learner's data to a service going away. But there is a genuine pedagogical
argument too: comparing your own answer against a marker's list, point by point,
and deciding whether you actually made that point is a well-evidenced
metacognitive intervention. Automatic marking would remove that step.

**The limitation is real and stated in the UI:** the matcher is literal and the
learner is not. It will miss points made in unexpected words, and occasionally
award points for coincidental phrasing. The interface tells the learner this
before showing them a single tick.

Traps are only evaluated on answers of 20+ words, because several are negative
lookaheads for a missing move and would otherwise fire on every stub.

## 8. Error classification and the misconception graph

Every error is banked with its concepts, confidence, level and timestamp, and the
learner classifies it against the nine error types from the brief. That gives two
independent diagnoses — the learner's and the engine's.

The **misconception graph** then propagates error counts up parent edges (at 0.75
weight). When several separate errors turn out to be children of one node, the
Ledger surfaces the parent: teach the node beneath five facts, not the five facts.

## 9. Motivation without empty points

There is no XP, no level, no streak of raw days. The reward structure is:

- **The competence narrative** — "You can now discriminate mediation from
  moderation in unfamiliar clinical studies" is generated at the moment depth
  advances, and shown as *what changed*.
- **The Atlas** — a live force-directed map of the concept graph in three domain
  lobes. Hue carries the domain and fill intensity carries mastery, so a lit lobe
  beside two pale ones tells you where you are thin at a glance. Dim, high-degree
  hubs are the highest-leverage targets.
- **A shrinking Ledger.**
- **A streak of days practised**, shown small in the top bar and hidden entirely
  at zero — present enough to matter, quiet enough not to become the point.

## 9a. Interface design

The surface has to survive months of daily use by someone under real pressure, so
it is built for calm and legibility rather than for looking like an app. The
reference points are Linear, Stripe and the BMJ rather than Duolingo: precise,
quiet, clinical, demanding. Eight decisions carry it.

**Structure, not cards.** An early version made every piece of information a
white card floating on a shadow. It read as a UI kit. The page is now a sequence
of *sections* — a small uppercase label, a hairline rule, and content — and
homogeneous lists are single bordered *plates* whose rows are divided by
hairlines. One container, many items, instead of one container per item. This is
the single largest change in the look of the thing.

**Explicit hierarchy.** Practice does not present five equal choices. Drill is
the engine, so it sits alone under *Recommended* as a wide feature row; the four
simulation surfaces sit under *Simulate the real thing*; the Atlas and the Ledger
sit under *Study the map*. The grouping does the explaining that five identical
tiles could not.

**One thing at a time.** There is no permanent metrics rail beside the work.
Readiness, calibration and the error ledger live in their own tab. While you are
answering, the top bar leaves and the item is alone on the page.

**The action bar is the spine.** A persistent bottom bar holds the confidence
control and the primary action, then *becomes* the result panel — tinted green or
red, carrying the verdict, the teaching, the precise formulation, the near-misses
and the error classification. Every surface puts its controls there, so the
learner never hunts for the next step.

**Select, then check.** Choosing an option does not submit it. That single change
turns an item from a reflex into a decision, and makes the confidence rating
meaningful, since you commit to both before seeing the outcome.

**Violet is an accent, not an atmosphere.** It marks the one primary action and
the currently selected state, and almost nothing else. Icons are stroke glyphs in
their domain hue with no coloured chip behind them; metadata is inline
dot-separated text rather than a row of pills; the greeting is deliberately
smaller than the thing you are meant to do next. If violet appears three times on
a screen, something has gone wrong.

**A design system with a small vocabulary.** Spacing is a strict 4px scale
(4·8·12·16·24·32·48·64) with no arbitrary values. There are four radii (10, 14,
20, pill) and three elevations, all subtle enough to say "this is above that"
without saying "this is floating". The type scale is fixed at display / h1 / h2 /
h3 / body / small / micro. Motion is short and eased — a 1px hover lift, a 2%
press, a 400ms entrance — never a bounce.

**Two typefaces doing structural work.** Inter for the interface, Newsreader for
clinical and exam material. Vignettes, interview questions, transcripts and paper
stimuli are all set in serif, so "the app" and "the thing you are reading" never
blur. Interview questions are set as a large serif quotation, because somebody is
asking you them.

### Making the engine legible

The most interesting thing about this tool is that it decides what you should
practise, and an interface that hides that decision wastes it. So Today does not
just offer a Start button: it renders the queue `buildSession()` is about to hand
the drill — which clusters it will cover, how many items each, and *why* each was
chosen (due for review, you were sure and wrong here, you have lost this one
before, not yet seen). Changing the duration re-plans it live. Nothing in that
panel is written for display; it is the same priority calculation the session
runs on.

Progress reports movement the same way — from events that actually happened
(depth advancements up, recorded errors down, over a seven-day window) rather
than a synthesised delta. Depth is drawn as a five-rung ladder next to each
concept, so "discriminate" is visible as a shape and not only as a word, and
mastery is never reduced to a lone percentage.

The command palette (⌘K) is a real command layer rather than a search box:
grouped, with the actions the engine can take at the top, then every mode, paper,
interview theme, case, role-play and concept in the build.

## 10. Ecological validity

Practice increasingly resembles the actual task:

- **Bench** runs papers to their real clock, and closes when time is up.
- **Panel** puts a 60-second or 3-minute clock on real questions, offers live
  speech transcription where the browser supports it, and follows every answer
  with a pressure follow-up drawn from the same theme.
- **Room** scores role-plays on process moves — opening, reflecting, validating,
  staying with experience — and penalises advising, exactly as Glasgow's brief
  specifies ("there is no expectation for you to resolve the problem"). It is
  rendered as a real conversation: asymmetric bubbles, the other person in serif,
  your own turns in sans, with the score for each move shown inline.
- **Studio** requires you to write your own formulation *before* revealing model
  accounts, and every model entry includes a falsification test, because a
  formulation that cannot be wrong is not a formulation.

## 11. What was deliberately not built

- **An LLM marker.** It would grade free text better. It would also make the app
  dependent on a service, a key, and a network. Given that the value of this tool
  is measured in months of daily use before a fixed deadline, durability won.
- **Content coverage of everything.** 28 drill items is deliberately thin next to
  199 concepts and 143 interview questions. The rubrics and the multi-model cases
  are where the transfer training lives; more MCQs would have been the cheapest
  and least useful thing to add.
- **A single mastery percentage.** Explicitly rejected by the brief and by the
  evidence.

## 12. Known limitations

1. **Item bank depth.** 28 drill items covers the research/statistics spine well
   and clinical/professional concepts thinly. Most clinical concepts currently
   gain depth only through Studio, Panel and Bench, which do not feed the
   spaced-repetition scheduler in the same granular way.
2. **Free-text matching is literal** (§7).
3. **Course specifics.** Cardiff is the only one of the three confirmed courses
   represented in the corpus. UCL and UEA guidance in the app is general, and the
   app says so. Selection processes change annually and must be checked against
   each course's own site.
4. **Self-scored speech.** Where the Web Speech API is unavailable, Panel scoring
   is honest self-assessment against a rubric.

## 13. Extending it

Content lives in `trainer/data/*.json`, generated by `tools/gen_*.py`. Edit the
generator, re-run it, then `python3 tools/build_trainer.py` to inline everything
into the shipped single file. Adding the fourth course means adding its verified
selection profile — no structural change.
