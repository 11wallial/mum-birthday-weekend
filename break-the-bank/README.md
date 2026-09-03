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
| Hurry a payout (the whole performance, scaled; the pause stays) | hold Space or the lever | hold A | hold |
| Hold a reel, or nudge it | 1–5, or the machine's buttons | — | tap the button |
| Settle the floor early, once the ante is covered | click **SETTLE NOW** | — | tap it |
| Spend a chit from the pocket, at its moment | click its key on the console | — | tap it |
| Buy the draft's chit, or pay the doorman | click the line on the form | D-pad to mark, A | tap it |
| Buy artifact 1–5 in the draft | 1–5, or click the row | D-pad / arrows to mark, A to buy | tap the row |
| Leave the draft | Space or Q | B / Circle | **Leave the shop** |
| Swap machine ↔ room view | Tab | Y / Triangle | **View** |
| New run | F5 | — | **New run** |
| Run this seed back, once the run is over | R | — | — |
| The door: pause, settings, skip the lesson, abandon | Esc | Start | **Setup** |

A session opens on the door — the title over the idling machine — where the
machine, the audit (the difficulty ladder, rungs opening on a win at the one
below) and the challenge are chosen, a seed typed or the daily taken, and a
run on the table resumed. A profile's first run is walked through the basement
by the Clerk on the tannoy; the lesson can be skipped from the door.

Bindings live in `project.godot` under `[input]` as `bb_*` actions; rebind there
rather than in code.

Touch is not a separate build. `TouchBar` shows its strip of buttons only when
`DisplayServer.is_touchscreen_available()`, and the prompts that name a key ask
`TouchBar.hint()` for the wording that suits the device — so one package reads
correctly whether it is opened on a desktop or a phone.

A spin is a performance, not a number. Once the last drum lands, every symbol
and device on the receipt scores as its own beat — the plate lights in the
accent, the drum jolts, a bell climbs a semitone a beat, a device breaks the
rhythm with its own voice — then the cash tubes roll up to just short of the
total, everything stops for slightly longer than is comfortable, and the
digits land. Six tiers judged against par decide what that does to the room:
scraping, paid, strong, heavy, overload. A loss has weight too. The surety
column on the machine's right flank — how much of you the House holds —
moves on the same beat, and the picture degrades with it.

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

Two currencies, kept apart. **Credits** are what the reels pay and what the
spin, the ante and the vig take. **Chips** are the House's scrip: they buy the
draft and settle nothing. A floor pays a stipend in chips when its ante is
settled, and a chip for every spin left on the clock when the floor is settled
early — which a run may do the moment its purse covers the vig and the ante,
trading the rest of the allowance for the draft. Chips held over earn one more
per five; the bank symbol pays one wherever it lands on a paying row; the slate
turns a chip price into debt at the House's rate, with the markup on top.
Priced in credits the draft was free from floor three; priced in chips it is
never quite affordable, which is what a draft is for.

Beside the draft sits **the press**: two jobs on the reel every floor, paid
in chips and permanent for the run. *Strike* takes weight off a symbol (the
skull, usually), *print* adds weight to one, *gild* adds to what a symbol —
or a whole family, the fruit together — pays. The reel is yours to edit;
this is where the editing is bought. Per-reel editing is not in the sim
(one reel serves every drum), and that is the next step on the roadmap.

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

| Floor | Name | Ante | Spins | Chips | What it introduces |
| --- | --- | --- | --- | --- | --- |
| 1 | The Basement | 40 | 9 | 5 | Hold and nudge |
| 2 | The Casino | 105 | 10 | 6 | The market: reroll, sell, the slate |
| 3 | The High Roller Room | 255 | 10 | 7 | The stake and the gamble ladder |
| 4 | The Vault | 810 | 11 | 10 | The vault: collateral and dividends |
| 5 | The Back Office | 1,730 | 12 | 12 | Contracts |
| 6 | The Engine Room | 4,080 | 13 | 14 | The works: reels and rows |
| 7 | The House | 16,300 | 15 | 18 | The count |

Fourteen symbols on the reel: five fruit (cherry, lemon, orange, grapes,
watermelon — a family, so any two of them pair), the bar and the double bar,
the bell, the horseshoe, the seven, the diamond, the wild, the skull, and the
bank, which pays a chip. Each is printed in two inks with a keyline, a shadow
and a gloss, from one instruction list that the GPU bake and the CPU icons
both read.

From the Casino up, every floor has one of the House's people on it — eighteen
`BossDef`s across floors 2 to 7, three a floor, one rule each, drawn from the
run's own stream so a seed always meets the same staff: the Croupier takes the
sevens off the reel, the Bouncer doubles every lock, the Collector charges the
vig again halfway through, the Notary pays pairs two-thirds, the Meter raises
the ante with every spin, the Cooler sends the good symbols outside, the
Cashier freezes the stake, the Manager skims. Each is announced with the floor
and printed on the ledger for the whole of it. `docs/FLOORS.md` has the table.

Artifacts are data, not scripts: a closed vocabulary of twenty-nine effects
resolved in `ArtifactEngine`. Eighteen read the line and the economy
(`FLAT_BONUS`, `MULT_BONUS`, `SYMBOL_BONUS`, `PATTERN_MULT`, `INTEREST`,
`EXTRA_SPINS`, `WEIGHT_SHIFT`, `ANTE_DISCOUNT`, `RETRIGGER`, `CURSE_WARD`,
`MULT_PER_FLOOR`, `MULT_PER_ARTIFACT`, `DEBT_PAYDOWN`, `DEBT_LEVERAGE`,
`SPIN_REFUND`, `NUDGE_BONUS`, `VAULT_YIELD`, `HEAT_SHIELD`); eleven read the
run and the board, which is where the builds come from — a tally of every
symbol that has landed (`MULT_PER_SEEN`), the boiler that lights after so many
spins (`AWAKENED_MULT`), the exchange that pays per other artifact that
triggered (`MULT_PER_TRIGGER`), the partner that pays only beside a named
artifact (`PARTNER_MULT`), and multipliers per skull standing, per reel held,
per nudge spent, per stake level, per paying spin in a row, per device of a
tag, and per spin left on the floor. That keeps balance edits confined to
`.tres` files and keeps the effect surface small enough to reason about.
Owning three artifacts sharing a tag lights a synergy and adds to every line's
multiplier.

Eighty-six artifacts, sixty-one of them belonging to one of eight named builds
(`resources/archetypes/`): the Payroll (skulls as wages), the Clamp (paid per
reel held), the Trail (paid per nudge), the Marker (the debt as leverage), the
Whale (the stake made superlinear), the Clock (spins and boilers), the
Exchange (many small triggers and a switchboard) and the Orchard (the tally of
everything landed). Each build has enablers on the first two floors, amplifiers
in the middle, a capstone from floor six, and something written down that
pushes back against it; the content suite holds every build to that shape,
and `docs/ARCHETYPES.md` is the design.

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
is the batch's win rate among runs at the same market depth — how deep a run
got and how deep a tier it bought from — in the same proportions as the
cohort's own runs, and `anomalies` lists whatever still sits far from it. The
report also carries `archetype_win_rates`, each named build measured as a
build (a run counts once it owns two of the build's artifacts), and
`pick_rates`, every artifact's pick rate beside its lift over the pack's
median lift with a verdict — trap, auto, sleeper, dead, fair — for the four
corners of that scatter worth a look.

The shipped numbers were calibrated with `tools/casino_lab/sweep.gd` against a
target win rate of 15–20%. Over 10,000 seeded runs (`--seed=1`) with the
built-in, deliberately mediocre `AutoPlayer`, measured 2026-09-02:

| Metric | Value |
| --- | --- |
| Win rate | 17.2% |
| Mean floors cleared | 5.17 of 7 |
| Earnings | mean 71,171 · p50 11,542 · p95 481,710 · p99 828,284 |
| Deaths by floor | 92 · 144 · 320 · 803 · 1,886 · 1,894 · 2,525, then 614 to the final debt |
| Debt | vig mean 1,051 (p95 1,970) · 1.7% of runs default · 9.1% buy a paydown |
| Chips | mean 68 a run · 14.2 artifacts owned · 69% of the draft taken · 0.12 floors settled early |

Deaths climb all the way to the House, which kills a quarter of everything
that reaches it; a further 614 clear it and cannot repay what they owe. The
curve was re-cut on 2 September around two currencies. With the draft paid in
chips the automated player owns fourteen artifacts a run instead of buying
every offer, and a machine that size could not climb the old antes — 1.7% at
the first try — so floors 3 to 7 came down (255 · 810 · 1,800 · 4,250 ·
17,000) and the stipends went up a fifth, which is where 17.2% and a draft
three-quarters affordable meet. The chip supply is the sharpest knob in the
game: the lab's `chips` sweep runs 1.7% → 6% → 22% → 24% across ×1, ×1.25,
×1.5, ×2 with nothing else moved.

What remains worth knowing, recorded in `.claude/skills/balance-loop`:

1. **Payouts are very widely spread.** Mean earnings are 80,174 against a
   median of 9,421, with a p99 over a hundred times the median — the builds
   that come together run away with it, which is what a build is for. The
   mean is no summary at all; read p50 and p95.
2. **The House is the wall, and the debt is the coda.** 1,785 of 10,000 runs
   die to the House's ante and 574 more to the repayment after it. Both are
   the first numbers to revisit once a human has played: a loss after the
   last floor reads very differently to a person than to a bot.
3. **The stake had to be priced.** A spin cost one credit against payouts in
   the hundreds, so the top of the stake was right whenever the purse could
   stand it; every level above the first now costs a tenth of the floor's
   ante per spin, and the Whale's hardware is what makes that worth paying.
4. **Settling early is usually wrong, and the bot knows it.** The first
   settle policy left a floor the moment the ante was covered and lost twenty
   points of win rate to it: a built machine's spins are worth far more in
   credits than the House pays for them in chips. The bot now settles only
   when the House pays better per spin than the machine has been — a tenth
   of its floors — and a person will find the same trade on the numbers.

## Seeds, dailies and meta-progression

**The machines.** What a run starts on, chosen at the door: the Standard;
the Overdraft (more cash, more debt); the Strongbox (the vault from the
basement, cash and chips in hand, payouts down a tenth). Three, deliberately
— the balance guide asked for three deep starts rather than eight shallow
ones, and each machine multiplies the surface the lab has to hold. The
Lean, the High Roller, the Bone Press and the Orchard are in git at
`58b5fc5` and come back one at a time, each measured. Each machine is a
`MachineDef` under `resources/meta/machines/`, reaches the run only as
`RunOptions`, opens through an unlock, and can be measured with
`run_lab.gd --machine=<id>`.

**The chits.** The consumable class: slips bought at the draft for chips
into a pocket of two and spent once, at their moment — a respin with the
decision still on the table, forty off the count, a vig deferred to the
principal, a wild marked for the last drum, the next line peeked at on
the ledger. Paper is a decision bought in advance; hardware stays. Measured on 3
September 2026: 15.0% at 10k with the chits in, inside every band.

**The collection.** The profile keeps what it has met — every piece of
hardware offered or owned, every one of the House's people faced, every
contract signed — and the door has a page for it: names and their lines
once seen, a dash until then. A first sighting is said once in the run's
log as it happens.

**The reel today.** Every seed ships its reel leaned: one symbol three
draw-weight heavier, one lighter, drawn off the run's own `lean` stream so
the reels' draws never move for it, and said with the first floor ("THE
REEL TODAY — cherries heavy, bars light"). The balance guide's restart
novelty: minute one of run two is not minute one of run one, and it is the
first thing a veteran reads before the first spin.

**The offers.** The draft's generator keeps the balance guide's four rules:
no dead offers (an artifact keyed to a symbol the reel cannot land is not
put out; a draft the purse can buy nothing from is re-dealt one affordable
slot), a light lean toward the builds the run has started, no more than two
of one build in a draft, staleness, and builds dealt evenly — an artifact's
weight divided by how many of its build are in the pool. The lab reports
`top_build_share` — the share of winning runs whose primary build is the
most common one — as the solved-metagame tell. Measured on 2 September
2026: before the even deal the Exchange, with thirteen members to the
others' five or six, was the primary build of 69% of wins at its own
baseline win rate — availability, not strength; after it, 26%, and the
batch rose from 15.0% to 17.2% on the variety alone (16.7% at 10k, inside
every band).

**The notice.** The House acts against success, not only on a schedule: a
single spin paying sixteen pars — most of an ante in one — is loud enough
for it to notice, and it answers at once and out loud, naming the spin and
the person it is sending to the next floor. That watcher arrives beside the
floor's own boss and carries a rule the same way; every notice also puts two
percent on every ante for the rest of the run. Measured on 2 September
2026: the notice as first authored (ten pars, five percent) cost five
points of win rate, so it sits at sixteen and two with floors 5–7 eased four
percent (1,730 · 4,080 · 16,300) — 15.3% at 10k, inside every band, the
House noticing 0.85 times a run. The player's one answer is **the doorman**:
at the draft after a notice, six chips (and three more each time) and the
House sends nobody. The ante markup stands; the chips were the draft's.

A seed is a run, so a shared seed is a shared run. Seeds are shown and entered as
five spoken words — `SOLAR-MIRTH-CANDLE-OX-DRIFT` — which survive being read
aloud or typed back in. The door (Esc) also accepts a plain number, or any
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

**The lifetime ledger** on the door keeps the spins, the biggest single
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

`tools/visual_qa/record.gd -- --out=/tmp/spin --seconds=3 --fps=20` records
a spin as a numbered PNG sequence — the performance in motion, which no
still can show and the trailer's opening shot needs; `ffmpeg -i
frame_%04d.png` assembles it.

It renders under Compatibility rather than Forward+, so volumetric fog and glow
are absent from the shots; geometry, scale and framing are exact. Locally it
renders in Forward+. `--settle=<s>` is how long each frame waits before the
capture; the default covers a spin's whole scoring performance, and a shorter
one (`--settle=1.3`) catches the chain mid-flight.

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
