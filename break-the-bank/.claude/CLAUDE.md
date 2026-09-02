# Break the Bank — working notes

A systems-heavy slot machine roguelike. Godot 4.4, Forward+, statically typed
GDScript. The game is a headless simulation with a 3D face bolted on; keeping
those two apart is the single most important rule in this repo.

## The aesthetic north star

**Retro-techno-steampunk.** Every visual decision is judged against it:

- Every part looks like it does something. A gear is on a shaft that goes
  somewhere; a dial is plumbed into a value; a cable carries power you can
  see arrive. Decoration that cannot explain itself gets cut or given a job.
- The machine is volatile. Steam pneumatics, arc-light, a lever you haul —
  operating it should feel slightly dangerous, Tesla-coil energy rather than
  casino chrome.
- The palette is rich, not drab: oxidised iron, brass and copper, verdigris,
  oxblood, aged ivory, phosphor green and arc blue as the electric accents.
- Information is hardware (the strip, the CRT, the Nixies) and controls are
  physical (the lever, lit buttons on the machine) before they are overlays.

## The one architectural rule

`scripts/simulation/` must never reference a node, a scene, the scene tree, the
clock, or input. It talks to the rest of the game by emitting events on
`EffectBus` and by exposing `RunState`. If you find yourself wanting `get_node`,
`await`, or `_process` in a simulation file, the logic belongs in
`scripts/presentation/` instead.

Consequences worth protecting:

- A run is a function call: `SimEngine.new().simulate_run(seed)` returns a
  finished `RunState`. That is what makes 100k-run batches cheap.
- A seed replays exactly. RNG is drawn from named `RngStream`s so adding a die
  roll in the shop cannot shift the reels.
- Deleting the whole presentation layer leaves a playable, testable game.

## Layout

| Path | What lives there |
| --- | --- |
| `scripts/simulation/` | Economy, probability, artifacts, run driver. Pure GDScript. |
| `scripts/resources/` | `Resource` subclasses — the shapes of the content files. |
| `scripts/presentation/` | Everything that listens to `EffectBus` and draws. |
| `resources/` | The content set itself, as `.tres`. Balance lives here, not in code. |
| `tests/` | GdUnit4 suites. `unit/` uses fixtures; `simulation/` uses shipped content. |
| `tools/casino_lab/` | Monte Carlo harness and its headless entry point. |

## Balance edits

Numbers belong in `resources/rules/balance_config.tres` and
`resources/rules/floors/*.tres`, or on an artifact's `.tres`. Never inline a
tuning constant in `scripts/simulation/` — if a number needs a name, add an
`@export` to `BalanceConfig`.

Artifacts are data. `ArtifactDef.Effect` is a small, closed vocabulary resolved
in one place (`ArtifactEngine`). Prefer expressing a new artifact with the
existing effects; add a new `Effect` only when the idea genuinely cannot be
composed, and handle it in `ArtifactEngine._apply_one` (line effects) or
`_scaling_gain` (effects that read the run or the board) plus its own helper.
`tests/simulation/test_shipped_archetypes.gd` pins the vocabulary's size, so
growing it is a deliberate edit with the reason in the commit.

Rules the synergy web added, each learnt by breaking something:

- A tally (`RunState.tallies`, read through `state.tally()`) moves only in
  `ArtifactEngine.record_spin`, which the engine calls once per settled spin
  from `collect`. Never touch a tally from `evaluate_spin`: it is called for
  previews, for every nudge and for every bought row, and a ledger that grew
  when it was looked at would pay a different number each time the hint lamp
  lit. `release()` erases the artifact's tally, so the market cannot keep a
  ledger without its keeper.
- `symbol_filter` names a symbol id or a family (`fruit`, `bar`), everywhere
  it is read — `SYMBOL_BONUS`, `WEIGHT_SHIFT`, `MULT_PER_SEEN` — through
  `ArtifactEngine.symbol_matches` and `Probability.build_reel`. Do not add a
  second matching rule.
- Every artifact that belongs to a build names it in `archetype`, by
  `ArchetypeDef` id under `resources/archetypes/`. A build needs an enabler
  by floor 2, an amplifier, a capstone from floor 6, a `brief` and a
  `counter`; the content suite holds it to that. `AutoPlayer.shop` leans
  towards whichever build the run has most of, so the lab measures builds a
  person would actually assemble; `archetype_win_rates` in the report is
  the build measured as a build.
- The lab judges every cohort — artifact, tag, build — against runs at the
  same market depth in the same proportions (`_stratified_rates`). Comparing
  against "everyone who got at least this far" put every dear late item a
  dozen points above a cohort it was never in, and called every floor-one
  trinket a trap. `pick_rates` puts each artifact's pick rate beside its
  lift over the pack's median lift; with the bot buying by price a pick
  rate mostly says what it could afford, so read the verdicts as an
  instrument for human batches.

To choose a number rather than check one, sweep it — this mutates content in
memory and writes nothing:

```
godot --headless --path . --script res://tools/casino_lab/sweep.gd -- \
    --knob=ante --floor=6 --values=3800,4200,4600 --runs=2500
```

Knobs: `ante`, `spins`, `payout_scale` (all with `--floor`), `debt`, `service`,
`debt_growth`, `synergy_bonus`.

After any balance edit, run the lab and compare against the previous report:

```
godot --headless --path . --script res://tools/casino_lab/run_lab.gd -- --runs=10000 --out=res://reports/balance_report.json
```

A 10k batch takes about four and a half minutes at ~37 runs/s, so run it in
the background or with a long timeout, and quote the report's `elapsed_ms`
rather than remembering a number: the player has grown more careful and the
batch slower every time a floor has been given a real verb.

Then judge it. `tools/casino_lab/gate.gd` checks a report against
`resources/rules/balance_bands.tres` — win rate, where the deaths fall, how
many runs the final debt takes, the lab's anomaly list — and exits non-zero
when a band is broken. CI runs it on every push and the nightly runs it at
10k; the 400-run smoke suite runs it too. The bands are deliberately wide: a
rebalance that needs to move one moves the `.tres`, with the reason in the
commit, and never the tool.

## Tests

```
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue -a tests
```

`--ignoreHeadlessMode` is required: GdUnit4 otherwise exits 103 under
`--headless`. Its guard is about `InputEvent` delivery, which no suite here
relies on.

`tests/unit/` asserts on hand-built fixtures (`TestFixtures`) so balance changes
never turn a correctness test red. `tests/simulation/` asserts on the shipped
content, but only on guardrails — "the game is neither unwinnable nor free",
not "the win rate is 40%".

## The floors

Each floor grants one system (`Systems`, claimed by `FloorDef.grants`) and the
system stays for the rest of the run. `docs/FLOORS.md` is the design; the rules
worth knowing before touching the simulation:

- Gate on `RunState.has_system()`, never on a floor index.
- The floors past the last authored one exist only for a run that has stayed
  at the table, made by `Endless` from the last floor. Ask `state.floor_at()`
  for the floor after this one, never `content.floor_at()`: the content says
  the run is over, the state knows whether the House has kept it.
- A spin does not end when the reels stop. `SimEngine.spin` leaves the run at a
  decision (`RunState.Decision`); `collect` is what moves the credits. The view
  animates on `SPIN_RESOLVED` and celebrates on `PAYOUT_CALCULATED`.
- The stake is priced off the ante, not the spin: every level above the first
  costs `BalanceConfig.stake_ante_percent` of the floor's ante per spin
  (`RunState.stake_premium`). A spin cost one credit against payouts in the
  hundreds, so playing at the top of the stake was right whenever the purse
  could stand it, and the bot found that out the moment the whale's hardware
  gave it a reason to raise. `AutoPlayer.stake` raises only when the machine
  pays more per spin than a level costs, or when it owns `MULT_PER_STAKE`.
- Every verb is a public `SimEngine` method the automated policy also calls, so
  a hand-played run and a batch exercise one code path. `clear_policies()` hands
  them all back for a human.
- `AutoPlayer` is that policy — a competent player's habits, kept out of the
  engine so "what the game allows" and "what a player does" stay separable. Add
  a verb and give `AutoPlayer` an opinion about it, or the lab measures a game
  with that system switched off. This is enforced: list the verb in
  `SimEngine.PLAYER_VERBS`, name its opinion in `AutoPlayer.COVERAGE`, and
  `tests/simulation/test_autoplayer_parity.gd` fails the build until a batch
  is actually seen using it. The market went unplayed by every batch for a
  milestone because nothing checked.
- Every player-facing verb on `SimEngine` is a thin public wrapper around a
  `_do_<verb>` body: the wrapper calls `_enter`/`_leave`, which writes the verb
  to the run's [RunJournal] only when it came from outside the engine. A save
  is that journal plus the seed (`RunSave`), replayed headlessly on load. Add a
  verb the same way, and add it to `RunJournal._apply`, or a save that used it
  stops replaying at that move. Nothing in `RunState` is ever serialised.
- `SimEngine.announce()` tells the viewers where a resumed run stands by
  emitting the facts as events, each payload carrying `"resumed": true`. A
  listener that treats an event as a moment — a chime, a fanfare, a scale-in —
  must check that flag; the audio director ignores everything resumed except
  the run starting.
- From the Casino up every floor has one of the House's people on it
  (`BossDef`, `resources/bosses/`, resolved in `BossEngine`): one rule, drawn
  from the run's own `boss` stream in `begin_floor`, announced in the
  FLOOR_STARTED payload (`boss`, `boss_name`, `boss_intro`, `boss_tell`),
  printed on the ledger for the floor, and torn up in `_close_floor` like a
  contract. Ask `BossEngine` what the boss does to a number exactly where
  that number is used — the reel folds `weight_shifts`, `spin_price` asks
  for the lock multiplier, `_award_nudges` asks whether free nudges stand —
  and never gate on a boss id. `RunOptions.no_bosses` (the lab's
  `--no-bosses`) measures what the staff costs; `boss_rates` in the report
  puts each against the floor's own death rate, which is how a variant that
  out-kills its siblings is found. The basement has nobody.
- The machine can be wider than the last line drawn on it — a reel bought
  mid-floor has no symbols until the next spin. `Probability.drawn()` exists for
  that; do not index a line assuming every reel is standing.
- Contract and count weight shifts are folded in by `RunState.reel()` rather
  than written into `weight_shifts`, so tearing a contract up restores the reel
  without remembering what it changed. Call `mark_reel_dirty()` if you change
  something outside the weight table.

## Input and the draft

Input actions are `bb_*` in `project.godot`; add bindings there, never with
`InputMap` calls at runtime. The draft buys through `SimEngine.buy_offer`, which
is the same call the headless shop policy makes — keep it that way, or the
batch stops measuring the game a person plays.

`ControlDeck` is the whole of the machine's controls, rebuilt from the run every
time the run changes: a control appears on the floor that grants it, and a move
the simulation would refuse is either absent or visibly barred. It emits intent
and never touches `RunState`. Add a verb there and in `CasinoRoom._on_deck_action`
together, or the key and the button drift apart.

`CasinoRoom._advance()` refuses to step while the reels are turning or a draft
is open. Put guards like that in `_advance()` rather than in `_unhandled_input`,
so tools and tests are held to them too.

## Meta-progression

Anything persistent lives in `scripts/meta/` and reaches a run only as
[RunOptions]. Never let the simulation read a profile: the lab passes default
options so its numbers keep describing the full content set. The ladder
(`DifficultyDef`) and the challenges (`ChallengeDef`) are data under
`resources/meta/`, each applied to a `RunOptions`; a new rule is a new field
on `RunOptions`, read by the simulation exactly where the number it changes
is used, and a row in `tests/unit/test_audits.gd` that pins it. The lab
measures a rung with `--difficulty=<id>` and the whole ladder with
`ladder.gd`, so a rung is only shipped once it is shown to be harder than the
one below it.

Saves are plain JSON, and every loader treats a corrupt or newer-version file as
"start fresh" rather than failing. Keep it that way. The run in progress is
saved the same way (`RunSave`, `user://run_in_progress.json`) with a fingerprint
of the content it was played against; a fingerprint mismatch is also "start
fresh", because a journal replayed against different content is a different
run. `CasinoRoom` marks a save on every move and writes once per frame; the
`debug_*` tools drop the journal, because they move the run outside its verbs.

## Visual QA

Framing, scale and lighting cannot be asserted, only looked at. There is no GPU
here, so the scene renders under a software driver:

```
xvfb-run -a godot --rendering-driver opengl3 \
    --script res://tools/visual_qa/screenshot.gd -- --out=res://shots --spins=6
```

That is the Compatibility renderer, not Forward+: no volumetric fog, weaker
glow. Geometry, transforms, scale and framing are exact, and those are what the
tool is for. Look at the PNGs before claiming a scene change works.

## The look

The machine and the room are generated by `MachineFrame` and `RoomSet` at
`_ready`, not authored in a `.tscn`. The character is in the density — rivets,
hoses, joists, conduit — and that is not maintainable as hand-placed nodes. The
scene files keep only what the simulation drives.

Materials are synthesised: `ProcTextures` samples `FastNoiseLite` into `Image`s
at startup and `Materials` assembles them. Nothing is fetched at launch, so
there is no texture library to ship.

Rules that cost real time to learn:

- **Feature size is `(1 / noise frequency) / 256 texels / tiles-per-metre`.**
  Change `uv1_scale` without changing the noise frequency and the wear pattern
  changes physical size — which is how the same surface went from leopard print
  to granite without ever passing through "worn paint". Move both together.
- **`ImageTexture.create_from_image` builds no mip chain.** Every procedural map
  aliases without one, and the result looks exactly like a badly tuned noise
  parameter. `ProcTextures._finish` generates them; materials also ask for
  anisotropic filtering, because nearly every surface here is seen at a grazing
  angle.
- **A wear map belongs only on a surface the world has touched.** The inside of
  the reel housing and the bezel someone wipes are plain, and both were noisy
  until they were.
- Lights live with their fixtures. The key light is built inside the pendant
  `RoomSet` hangs, so what throws the shadows and what you can see throwing them
  cannot drift apart.
- `CameraController` takes an eye and a look-at target, never an authored
  `Transform3D`. See the `Transform3D` note under Style for why.
- Portrait is not a crop of landscape. With a fixed horizontal field the vertical
  field is the horizontal one times the aspect, so a phone sees nearly twice the
  height a monitor does. `_fit_to_screen` narrows the field and backs the camera
  off; the HUD separately scales its type back up, because the canvas stretch
  otherwise draws a 12px caption at 6px.
- A modal panel must swallow every key while it is up. Unhandled input goes in
  reverse tree order, and a panel that only consumes the keys it uses lets the
  rest reach the draft underneath.
- **In an unshaded spatial shader, ALBEDO is the final colour.** EMISSION is
  never read in that mode; writing a screen's picture to it ships a black
  monitor, with no error to say why.
- **Bind a ViewportTexture only after its viewport is in the tree.** Fetched at
  construction it never resolves, and the material samples black forever.
- The reel strip and the window plates are one texture: `ReelPrint` bakes the
  cells once on the GPU, the drum wraps all of them, and a landed plate is the
  same bake addressed one cell at a time. `BAND_ANGLE` is exactly one cell, so
  a plate stays registered with the printing behind it — change either and you
  must change both.
- A glow faked by scaling a crisp text copy doubles its ends and reads as a
  misprint. Nudge same-size copies in each direction instead.
- Compatibility clamps highlights where Forward+ rolls them off. A light tuned
  on desktop can burn the same surface white on the web build; scale the
  offender by `RenderingServer.get_current_rendering_method()` rather than
  splitting the whole rig.

## Audio

Manifest-driven; see `docs/AUDIO.md` for the full design. Rules that matter here:

- Every cue is a `.tres` in `resources/audio/cues/`. Never hard-code a filename,
  a volume or a pitch in code — add or edit a `SoundDef`.
- A cue with no sourced file is synthesised by `ProceduralCues`, so a missing
  asset is audible-but-obviously-temporary rather than silent. Do not "fix" a
  placeholder by deleting the cue.
- Sourced files land at exactly the manifest's `file_name` and need a row in
  `assets/audio/CREDITS.md`. `tools/audio/audit.gd --strict` fails without one,
  and CI runs it: an asset nobody can trace is an asset nobody can clear.
- Buses are `Master / Music / SFX / UI / Ambience` from `default_bus_layout.tres`.
  Route through `SoundDef.bus`; do not set a bus name at a call site.

## Godot MCP surface

Keep the exposed tool set small and high signal:

- Inspect: `inspect_project`, `inspect_scene`, `inspect_node`
- Edit: `modify_node`, `write_script`
- Run: `run_game`, `stop_game`, `get_debug_errors`, `get_runtime_output`
- QA: `take_screenshot`

Screenshots are for UI layout and 3D alignment. Anything about *balance* should
come from the lab's JSON, not from looking at the game.

## Style

- Static types everywhere; `project.godot` promotes untyped declarations to
  errors, so an untyped local will fail the build, not just warn.
- `StringName` (`&"id"`) for identifiers that get compared in loops.
- `Transform3D(...)` with twelve floats takes basis **rows**, while `basis.x/y/z`
  are **columns**. Reasoning in columns silently mis-signs rotations: it aimed
  the room camera at the ceiling, pointed the key light up, and turned the reel
  drums face-on. Author a rotated node, then check it with
  `tools/visual_qa/screenshot.gd` rather than by inspection.
- A `const` cannot be initialised with a packed-array constructor
  (`PackedStringArray([...])`) — it is not a constant expression, the whole
  class silently fails to load, and callers report "nonexistent function". Use
  `const X: Array = [...]`. CI parse-checks every script for this.
- Never name a method after a `@GlobalScope` utility (`randi_range`, `randf`,
  `lerp`, ...). An unqualified internal call binds to the global, not to your
  method, and it fails silently — `RngStream.weighted_index` drew from Godot's
  unseeded global RNG this way, and every external-call test still passed.
- Doc comments (`##`) on every class and on anything whose *why* is not obvious
  from its name. Skip them on self-evident getters.

## Packaging

Builds are self-contained: nothing is fetched at launch. `tools/package/build.sh`
exports Windows, Linux, macOS, Android and Web; `docs/PACKAGING.md` has the
detail. Rules worth keeping:

- Desktop presets embed the PCK. Do not split a build into binary + data.
- `export_presets.cfg` is tracked, against Godot's default ignore. Keep it free
  of credentials: the Android keystore comes from
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD`, and only the
  SDK path lives in editor settings. `--export-release` reads the *release*
  keystore and ignores the debug one.
- Godot downgrades a failed APK signing to a warning and writes the file anyway,
  so "the export succeeded" says nothing about whether it installs. Verify with
  `apksigner verify`, as CI does.
- Every `AudioStreamPlayer` sets `playback_type = PLAYBACK_TYPE_STREAM`. The web
  export defaults to sample playback, which cannot play an `AudioStreamGenerator`
  at all, so the procedural ambience silently fails without it.
- Touch is not a separate build. `TouchBar.is_touch_device()` gates the on-screen
  buttons and `TouchBar.hint()` picks the wording; never hard-code a key name in
  a user-facing string.
- Any input path that only a key can reach is a mobile bug. Every panel needs a
  visible way out.
