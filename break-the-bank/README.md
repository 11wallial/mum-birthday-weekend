# Break the Bank

A systems-heavy slot machine roguelike: seven floors of a casino, one machine
you bolt parts onto, and a debt that compounds while you play.

Built to the 3D roguelike build specification — Godot 4.4, Forward+, statically
typed GDScript, with a headless simulation core that the 3D layer only watches.

## Quick start

```bash
# Play it
godot --path break-the-bank

# Run the tests (see "GdUnit4" below for the one-time install)
cd break-the-bank
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue -a tests

# Run 10,000 headless runs and write the telemetry
godot --headless --path . --script res://tools/casino_lab/run_lab.gd -- \
    --runs=10000 --seed=1 --out=res://reports/balance_report.json
```

In game: **space** spins and advances, **tab** swaps between the machine view
and the room view, **esc** starts a fresh run.

## Architecture

```
                       ┌─────────────────────────┐
                       │     GAME SIMULATION     │
                       │ Pure GDScript / Headless│
                       └────────────┬────────────┘
                                    │
                             RunState / EffectBus
                                    │
           ┌────────────────────────┴────────────────────────┐
           ▼                                                 ▼
┌─────────────────────┐                           ┌─────────────────────┐
│     GAME LOGIC      │                           │   3D PRESENTATION   │
│ Probability & RNG   │                           │ Slot machine meshes │
│ Economy & debt      │                           │ Reel animations     │
│ Effects & triggers  │                           │ Room environment    │
│ Synergy calculation │                           │ Particles & lights  │
└─────────────────────┘                           └─────────────────────┘
```

The simulation never calls into the presentation layer. It emits events on
`EffectBus` and exposes `RunState`; `SlotView3D`, `CameraController` and the HUD
listen. Three properties fall out of that, and all three are load-bearing:

- **Headless.** `SimEngine.new().simulate_run(seed)` returns a finished run
  without loading a single node. Measured throughput is ~415 runs/second, so a
  10k batch is ~25 seconds and a 100k batch about four minutes.
- **Deterministic.** Every subsystem draws from its own named `RngStream`, so a
  new die roll in the shop cannot shift the reels. A seed replays exactly.
- **Severable.** Delete `scripts/presentation/` and the game still runs and
  still passes its tests.

### Key types

| Type | Role |
| --- | --- |
| `SimEngine` | Drives floors, spins and shops. The only thing that mutates a run. |
| `RunState` | Everything that changes during a run. The boundary object. |
| `CoreEconomy` | Cash, debt, ante settlement, interest, shop pricing. |
| `Probability` | Reel building, weighted draws, pattern detection. Static, pure. |
| `ArtifactEngine` | The one place that knows what an `ArtifactDef.Effect` does. |
| `EffectBus` | Simulation → world. Muted in batch mode so 100k runs stay cheap. |
| `ContentDB` | Loads the `.tres` content set once per process. |

## The run

Each floor gives you a number of spins to bank its ante. Spins cost a credit and
pay out only when the line makes a pattern — matched families, a jackpot, or a
clean sweep of distinct symbols. A skull on the line costs credits *and* the
pattern bonus. Clear the ante, shop for artifacts, take the next floor. Clear all
seven and you still have to repay the debt that has been compounding since the
first spin.

| Floor | Name | Ante | Spins | What it introduces |
| --- | --- | --- | --- | --- |
| 1 | The Basement | 40 | 8 | Base slot mechanics |
| 2 | The Casino | 60 | 9 | Shop and secondary devices |
| 3 | The High Roller Room | 235 | 10 | High-stakes modifiers |
| 4 | The Vault | 1,040 | 10 | Capital and interest |
| 5 | The Back Office | 2,500 | 11 | Rule manipulation, contracts |
| 6 | The Engine Room | 3,000 | 12 | Machine interconnection |
| 7 | The House | 4,400 | 14 | Casino-wide rules, final encounter |

Artifacts are data, not scripts: a small closed vocabulary of effects
(`FLAT_BONUS`, `MULT_BONUS`, `SYMBOL_BONUS`, `PATTERN_MULT`, `INTEREST`,
`EXTRA_SPINS`, `WEIGHT_SHIFT`, `ANTE_DISCOUNT`) resolved in `ArtifactEngine`.
That keeps balance edits confined to `.tres` files and keeps the effect surface
small enough to reason about. Owning three artifacts sharing a tag lights a
synergy and adds to every line's multiplier.

Artifacts with a `module_scene_path` physically bolt themselves onto the machine
frame when acquired — the Brass Multiplier adds a gearbox, the Entropy Engine a
glowing core — so a build is visible on the machine, not just in a list.

## Casino Lab

`tools/casino_lab/` runs the simulation in bulk and writes JSON telemetry: win
and death rates, deaths by floor, mean/p50/p95/p99 for earnings, spins and floors
cleared, per-artifact and per-synergy win rates, and an `anomalies` list.

Each win rate is judged against its own cohort rather than the headline number:
an artifact that unlocks on floor 5 is only owned by runs that reached floor 5,
so against the whole batch every late artifact looks overpowered. The baseline
is the win rate among runs that got far enough to be offered it, and `anomalies`
flags entries 25+ points off *that*.

The shipped numbers were calibrated against a target death curve rather than
guessed. Over 5,000 seeded runs (14 seconds headless) with the built-in,
deliberately mediocre shop policy:

| Metric | Value |
| --- | --- |
| Win rate | 40.5% |
| Mean floors cleared | 4.09 of 7 |
| Earnings | mean 5,324 · p50 3,586 · p95 11,950 · p99 12,459 |
| Deaths by floor | 643 · 511 · 542 · 621 · 563 · 46 · 29, then 21 to the final debt |

Two known balance problems, both recorded in `.claude/skills/balance-loop`:

1. **Late floors sit on a cliff.** By floor 5 the naive policy has bought most of
   the artifact pool, so income plateaus; raising floor 6's ante from 3,000 to
   4,200 drops the win rate from ~40% to under 1%. The pool needs more late-game
   artifacts before those antes can be tuned safely.
2. **Debt barely bites.** Starting debt of 50 compounds to roughly 120 by the
   end, against final cash in the thousands. It decides only a handful of runs.

## Visual QA

Transforms, framing and lighting are checked by looking, not by assertion —
`tools/visual_qa/screenshot.gd` boots the real scene under a software GL driver
and writes a storyboard of PNGs:

```bash
cd break-the-bank
xvfb-run -a godot --rendering-driver opengl3 \
    --script res://tools/visual_qa/screenshot.gd -- --out=res://shots --spins=6
```

It renders under Compatibility rather than Forward+, so volumetric fog and glow
are absent from the shots; geometry, scale and framing are exact.

Audio cues are synthesised by `tools/audio/make_cues.py` rather than sourced, so
they are reproducible and tiny. Edit the generator and re-run it.

## GdUnit4

The addon is not vendored. Install it once:

```bash
curl -fsSL https://github.com/MikeSchulze/gdUnit4/archive/refs/tags/v5.0.5.zip -o /tmp/gdunit.zip
unzip -q /tmp/gdunit.zip -d /tmp/gdunit
mv /tmp/gdunit/gdUnit4-*/addons/gdUnit4 break-the-bank/addons/gdUnit4
```

`--ignoreHeadlessMode` is required — GdUnit4 exits 103 under `--headless`
without it. Its guard concerns `InputEvent` delivery, which no suite here uses.

`tests/unit/` asserts against hand-built fixtures so balance changes never turn a
correctness test red. `tests/simulation/` asserts against the shipped content,
but only on guardrails — that runs terminate, that seeds replay, that the game is
neither unwinnable nor free.

## CI

`.github/workflows/godot.yml` installs Godot and GdUnit4, imports the project,
runs both suites, runs a 5,000-run balance batch, and uploads the report as an
artifact. A second job boots the project headless and fails on any script error —
with untyped declarations promoted to errors in `project.godot`, that boot is the
strict-typing gate.

## Repository layout

```
break-the-bank/
├── .claude/            CLAUDE.md, the balance-loop skill, /lab and /sim-test
├── addons/             GdUnit4 goes here (not vendored)
├── assets/3d/          machines, room dressing, artifact modules
├── resources/          symbols, artifacts, floors, balance config (.tres)
├── scenes/3d/          casino_room.tscn, slot_machine_3d.tscn
├── scenes/ui/          hud.tscn
├── scripts/simulation/ the headless core
├── scripts/presentation/ the 3D face
├── scripts/resources/  Resource subclasses
├── tests/              unit/ and simulation/ suites
└── tools/casino_lab/   Monte Carlo harness + headless entry point
```
