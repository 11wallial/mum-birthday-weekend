# Break the Bank

A systems-heavy slot machine roguelike: seven floors of a casino, one machine
you bolt parts onto, and a debt that compounds while you play.

Built to the 3D roguelike build specification — Godot 4.4, Forward+, statically
typed GDScript, with a headless simulation core that the 3D layer only watches.

## Playing it

You do not need Godot to play. Every build is self-contained: the content, the
UI and the audio are all inside the package, nothing is fetched at launch, and
a first run offline behaves exactly like any other.

| You have | Take | How it runs |
| --- | --- | --- |
| Windows | `BreakTheBank.exe` | One file. Double-click it. |
| macOS | `BreakTheBank.zip` | Unzip, open the app. Unsigned, so the first launch is right-click → Open. |
| Linux | `BreakTheBank.x86_64` | `chmod +x` once, then run it. |
| Android | `BreakTheBank.apk` | Allow install from your browser or file manager, then open it. |
| Anything with a browser | the `web/` folder | Serve it over HTTP and open `index.html`. |

Builds come from the **Package playable builds** job on any CI run — open the
run and download `breakthebank-desktop`, `breakthebank-android` or
`breakthebank-web`. To build them yourself, see [docs/PACKAGING.md](docs/PACKAGING.md).

The Android build locks to landscape and drives the whole game by touch. The web
build is the fallback for anything else, phones included; it needs a web server
rather than a `file://` path, because browsers refuse to load WebAssembly from
the filesystem.

## Working on it

```bash
# Play it from source
godot --path break-the-bank

# Run the tests (see "GdUnit4" below for the one-time install)
cd break-the-bank
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue -a tests

# Run 10,000 headless runs and write the telemetry
godot --headless --path . --script res://tools/casino_lab/run_lab.gd -- \
    --runs=10000 --seed=1 --out=res://reports/balance_report.json
```

### Controls

| Action | Keyboard / mouse | Gamepad | Touch |
| --- | --- | --- | --- |
| Spin, settle an ante, advance | Space, left click | A / Cross | tap the room |
| Buy artifact 1–5 in the draft | 1–5, or click the row | — | tap the row |
| Leave the draft | Space or Q | B / Circle | **Leave the shop** |
| Swap machine ↔ room view | Tab | Y / Triangle | **View** |
| New run | F5 | — | **New run** |
| Run setup (seeds, daily, meta) | F2 | — | **Setup** |

Bindings live in `project.godot` under `[input]` as `bb_*` actions; rebind there
rather than in code.

Touch is not a separate build. `TouchBar` shows its strip of buttons only when
`DisplayServer.is_touchscreen_available()`, and the prompts that name a key ask
`TouchBar.hint()` for the wording that suits the device — so one package reads
correctly whether it is opened on a desktop or a phone.

When a floor's spins run out the ante is not settled silently — the run pauses
on what is due against what you hold, and waits. Clearing a floor opens the
draft, which stays open until you leave it: unaffordable offers stay listed,
because knowing what you cannot afford is most of the decision.

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
  without loading a single node. Measured throughput is ~37 runs/second now
  that the automated player works all seven systems, so a 10k batch is about
  four and a half minutes and a 100k batch most of an hour. Quote the report's
  `elapsed_ms`, not this paragraph.
- **Deterministic.** Every subsystem draws from its own named `RngStream`, so a
  new die roll in the shop cannot shift the reels. A seed replays exactly.
- **Severable.** Delete `scripts/presentation/` and the game still runs and
  still passes its tests.
- **Replayable.** Every public verb on `SimEngine` is journaled when it comes
  from outside the engine, so a run is its seed plus a list of verbs. That is
  what a save file is, and what the input-replay tests assert on.

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

Clear the debt and the House offers it back, with a chair: a run that stays at
the table plays on past the last floor, each ante compounding on the one
before, until an ante is missed. The win is recorded either way. Staying is the
leaderboard's mode — how many floors after hours a build lasted.

Debt is a running cost, not a closing bill. From floor 2 it charges a vig — a
percentage of the principal, in cash, due *before* the ante, so every floor it
competes with survival. Paying the vig is interest only and never reduces what
you owe; the principal comes down through `DEBT_PAYDOWN` artifacts or not at
all, and it compounds 80% per floor. Miss a payment and the shortfall returns as
principal with a penalty on top.

| Floor | Name | Ante | Spins | What it introduces |
| --- | --- | --- | --- | --- |
| 1 | The Basement | 40 | 8 | Base slot mechanics |
| 2 | The Casino | 60 | 9 | Shop and secondary devices |
| 3 | The High Roller Room | 235 | 10 | High-stakes modifiers |
| 4 | The Vault | 1,040 | 10 | Capital and interest |
| 5 | The Back Office | 2,500 | 11 | Rule manipulation, contracts |
| 6 | The Engine Room | 4,600 | 12 | Machine interconnection |
| 7 | The House | 12,000 | 14 | Casino-wide rules, final encounter |

Artifacts are data, not scripts: a closed vocabulary of eighteen effects
(`FLAT_BONUS`, `MULT_BONUS`, `SYMBOL_BONUS`, `PATTERN_MULT`, `INTEREST`,
`EXTRA_SPINS`, `WEIGHT_SHIFT`, `ANTE_DISCOUNT`, the late-game `RETRIGGER`,
`CURSE_WARD`, `MULT_PER_FLOOR`, `MULT_PER_ARTIFACT`, `DEBT_PAYDOWN`, and the
five the later floors' systems asked for — `DEBT_LEVERAGE`, `SPIN_REFUND`,
`NUDGE_BONUS`, `VAULT_YIELD`, `HEAT_SHIELD`) resolved in `ArtifactEngine`.
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

The shipped numbers were calibrated with `tools/casino_lab/sweep.gd` against a
target win rate of 15–20%. Over 10,000 seeded runs (`--seed=1`) with the
built-in, deliberately mediocre `AutoPlayer`, measured 2026-09-02:

| Metric | Value |
| --- | --- |
| Win rate | 19.6% |
| Mean floors cleared | 5.58 of 7 |
| Earnings | mean 34,755 · p50 23,629 · p95 119,936 · p99 188,305 |
| Deaths by floor | 85 · 185 · 437 · 674 · 985 · 1240 · 2141, then 2,295 to the final debt |
| Debt | vig mean 478 (p95 767) · 0.5% of runs default · 30.8% buy a paydown |

Deaths climb floor by floor, and the biggest killer is not a floor at all: a
fifth of runs clear the House and still cannot repay what they owe. The floor 6
cliff and the floor 5 spike of earlier calibrations are both gone — the first
to the Tier 3/4 artifacts that keep income growing late, the second to the back
office opening on the way into floor five rather than out of it.

What remains worth knowing, recorded in `.claude/skills/balance-loop`:

1. **Payouts are widely spread.** Mean earnings are 34,755 against a median of
   23,629, with a p99 eight times the median — a few builds run away with it.
   That is roguelike shaped, but it means the mean is a poor summary; read p50
   and p95.
2. **The final debt is the wall.** 2,295 of 10,000 runs clear all seven floors
   and lose to the repayment. The shape is deliberate — the debt is the run's
   clock, and the House is meant to keep some winners — but it is the first
   number to revisit once a human has played, because a loss after the last
   floor reads very differently to a person than to a bot.

## Seeds, dailies and meta-progression

A seed is a run, so a shared seed is a shared run. Seeds are shown and entered as
five spoken words — `SOLAR-MIRTH-CANDLE-OX-DRIFT` — which survive being read
aloud or typed back in. The setup panel (F2) also accepts a plain number, or any
phrase: `mum's birthday` hashes to a stable run you can tell someone about
without explaining what a seed is.

The **daily challenge** derives its seed from the UTC date, so everyone plays the
same run and the day turns over at the same instant everywhere.

**The run in progress** survives the game closing. Nothing about `RunState` is
serialised: the save (`user://run_in_progress.json`) is the seed, the options
and a journal of every verb the player used, and on the next launch the room
replays that journal headlessly — a few hundred moves take milliseconds — and
lands on the exact board, draft or signature the player left. A save written
against different content, or by a newer build, is set aside with a warning
and the game starts fresh, the same rule as every other loader here. Starting a
new run, or ending one, forgets it.

**Meta-progression** persists in `user://profile.json` as plain JSON — readable,
hand-editable, and unable to execute anything on load, which a `.tres` save
could. Unlocks gate the most distinctive artifacts, two starter variants, the
ladder and the challenges; the panel shows what each still needs, nearest
first. Unlocks reach the simulation only as `RunOptions`, so the core stays
pure and the balance lab can pass the default (nothing restricted) and go on
measuring the whole content set.

**The ladder** is eight audits of the account, each a `DifficultyDef` in
`resources/meta/difficulties/` and each carrying every rule below it: a
dearer ante, a heavier vig, a tighter purse, a bigger debt, faster interest,
an adjusted machine, and house rules on top. A win on one
rung opens the next. **Challenges** (`resources/meta/challenges/`) are
eighteen rules of their own — no holds, skulls on the payroll, the vig
doubled, the engine room closed, every verb from the basement — each a
complete ruleset with the starter and the audit set aside, opened through
play. Both reach the run only as
`RunOptions`, and `tools/casino_lab/ladder.gd` prints what each does to the
win rate:

```bash
godot --headless --path . --script res://tools/casino_lab/ladder.gd -- --runs=1000
godot --headless --path . --script res://tools/casino_lab/run_lab.gd -- --runs=2500 --difficulty=house_rules
```

**The lifetime ledger** on the setup panel keeps the spins, the biggest single
spin, the vig paid to the House across every run, the deepest table after
hours, and the artifact most often owned at the end of a run.

**Leaderboard telemetry** is written to `user://leaderboard.json`, scored per
ruleset — a Marked Deck run is not comparable to a standard one — and per daily
key. There is no server: `Leaderboard.submit()` is the single seam a backend
would replace, and it already records everything a remote board would need.

## Playtesting

Every played run is recorded to `user://playtests/` — each spin, purchase and
pass, with deliberation time. Because a seed replays exactly, the same seed can
be re-run with the built-in policy and the two diffed:

```bash
godot --headless --path . --script res://tools/playtest/compare.gd
```

It prints outcome, floors, spins and earnings side by side, plus the artifacts
each took that the other did not and what the human passed on. Set
`record_playtest = false` on the room to turn recording off.

**Not yet done:** no human has played this. The instrument exists; the sessions
it is for have not happened, so there are no findings about where player
judgement beats or trails the policy.

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

## Audio

Audio is manifest-driven: every cue is declared in `resources/audio/cues/*.tres`
and nothing in code names a file or a volume. A cue whose asset has not been
sourced yet is **synthesised on demand**, so the manifest can be complete long
before the library is, and replacing a placeholder with a recording is a file
drop with no code change.

```bash
# What is sourced, what is still a placeholder, what is missing a licence
godot --headless --path . --script res://tools/audio/audit.gd
# Hear the intended shape of every placeholder before sourcing it
godot --headless --path . --script res://tools/audio/bake_placeholders.gd -- \
    --out=res://placeholder_preview
```

The full asset manifest, sourcing strategy and bus architecture are in
[docs/AUDIO.md](docs/AUDIO.md). Every sourced file must have a row in
`assets/audio/CREDITS.md`; `audit.gd --strict` fails the build otherwise, and CI
runs it.

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
runs both suites, runs a 5,000-run balance batch, judges it against
`resources/rules/balance_bands.tres`, and uploads the report as an artifact. A
second job boots the project headless and fails on any script error — with
untyped declarations promoted to errors in `project.godot`, that boot is the
strict-typing gate.

`.github/workflows/balance-nightly.yml` runs the full 10,000 every night on
the default branch (or by hand from the Actions tab on any branch), gates it
against the same bands, and prints the delta against the previous night. A
failed nightly is the alarm: the game moved, and nobody meant it to.

```bash
# Judge any report against the bands; exits 1 when one is broken
godot --headless --path . --script res://tools/casino_lab/gate.gd -- \
    --report=res://reports/balance_report.json
```

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
