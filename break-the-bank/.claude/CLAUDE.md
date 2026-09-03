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
- A seed replays exactly. RNG is drawn from named `RngStream`s (reels, band,
  shop, tempo, gamble, boss, lean) so adding a die roll in the shop cannot
  shift the reels. The `lean` stream is drawn exactly twice, at the start:
  the reel as it ships today (`SimEngine._lean_reel_for_the_day`, one
  symbol `ship_lean_weight` heavier and one lighter, never the skull or
  the wild), announced with the first floor. The guide's restart novelty.
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
- Two currencies, kept apart in `CoreEconomy`: `cash` pays the spin, the
  ante and the vig and is what the reels pay; `chips` buy the draft, the
  reroll and nothing else, and move only through `credit_chips` /
  `debit_chips`. `RunState.can_buy`, `price_of`, `sellback_of` and
  `slate_price` are the draft's arithmetic; the slate is the one place the
  two meet, converting a chip price to debt at `CoreEconomy.chip_value`.
  Chips arrive in `_close_floor`: the floor's `chips` stipend, the settle
  bonus for `spins_left_at_settle`, and interest. The bank symbol carries
  `chip_value`, summed in `_resolve_board` onto `board.chips` and paid in
  `collect`. Never price anything for the draft in cash again: priced off
  the ante the draft was free from floor three.
- `settle_floor` is the verb that ends a floor early: legal only when
  `RunState.can_settle_early()` — spinning, no decision owed, and cash
  covering `vig_due() + ante_due()`. `ante_due` is the one place the ante is
  computed; the engine's `ante_for` delegates to it. `AutoPlayer.settle`
  takes the trade only when the House pays more per spin than the machine
  has been — the first policy settled whenever covered and cost twenty
  points, because a built machine's spins are worth more than the scrip.
- The lab reports `chips`, `hardware`, `draft_take_rate` and
  `settled_early`; the chip supply is the sharpest knob in the game (the
  `chips` sweep runs 1.7% → 24% across ×1 → ×2). Sweep knobs `chips`,
  `chip_prices`, `spin_left_chips`, `late_antes` and `settle_reserve`
  exist, and `--also=knob:value` holds a second one under a sweep.
- `press` is the verb that edits the reel: `RunState.press_offers` are
  stocked with the draft in `_stock_shop` (`_roll_press`), a strike or
  print goes through `add_weight_shift`, a gilding into
  `symbol_value_shifts`, which `evaluate_spin` reads through
  `RunState.symbol_bonus` and nowhere else. Paid in chips, permanent for
  the run, journaled as `press <index>`. `AutoPlayer.press_jobs` takes one
  job a draft. There is one reel for every drum; per-reel editing is a
  bigger change and is on the roadmap, not in the sim.
- Machines are `MachineDef` data under `resources/meta/machines/` and reach
  a run only through `RunOptions` (`bonus_chips`, `starting_artifacts`,
  `weight_shifts`, plus the scales and `early_systems` the audits already
  used). Three ship — the Standard, the Overdraft, the Strongbox — by the
  balance guide's rule of three deep starts over eight shallow ones; the
  suite pins the count. The four cut are in git at `58b5fc5`. `SimEngine.start_run` fits the hardware through `acquire` and leans
  the reel before the first floor opens. The ruleset key carries all of it,
  so a machine's daily is its own board. `unlock_def`'s `STARTER` kind now
  opens a machine; the enum value stays, it is written into profiles.
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
- The offer generator is `SimEngine._roll_offers`, and the balance guide's
  four requirements live there and nowhere else: a dead offer (keyed to a
  symbol the reel cannot land, `_offer_is_dead`) is not dealt; a draft the
  purse can buy nothing from is re-dealt one affordable slot; a started
  build is leaned toward by `offer_build_weight` (light, on purpose); no
  more than `offer_build_cap` of one build in a draft; and with
  `offer_build_balance` an artifact's weight is divided by its build's
  share of the pool, so a build with thirteen members is dealt no more
  than one with five — the Exchange was the primary build of 69% of wins
  on availability alone until it was. All off the shop stream. `tests/unit/test_offer_generation.gd` holds each; the lab's
  `top_build_share` is the solved-metagame tell (the guide wants it under
  a quarter of wins).
- The quick clear is `RunState.is_quick_clear` — a settle with at least
  `quick_clear_share` of the floor's spins left doubles `settle_bonus`.
  Tests that assert a settle bonus set `floor_spins_total` long enough that
  the spins left are not a quick clear, or they assert the doubled number.
- Chits are `ChitDef` data under `resources/chits/`, five kinds resolved in
  `SimEngine._do_use_chit` and nowhere else; `RunState.can_use_chit` is the
  one place a kind's moment is defined. A marker is honoured in
  `_draw_board` after the stream has drawn (the seed's reels stay the
  seed's); a peek reads the stream through `RngStream.peek`, which puts it
  back; a deferral is settled in `_close_floor`. `_roll_chit` deals one a
  draft off the shop stream, none when the pocket is full.
- The House notices: `SimEngine._observe_notice` on every banked spin, at
  `BalanceConfig.notice_par_multiple` pars, sets `RunState.notice_pending`
  (a `BossDef` from the next floor's pool, off the `boss` stream) and emits
  HOUSE_NOTICED; `begin_floor` seats it as `RunState.watcher` beside the
  boss. Ask `BossEngine.people(state)` for everyone on the floor — never
  `state.boss` alone — and put the ante's `notices` markup only in
  `ante_due_for`. The notice itself is no verb; the answer to it is —
  `pay_doorman`, legal only while `RunState.can_pay_doorman()` (the draft
  open, a notice in hand, the chips), journaled, with `AutoPlayer.doorman`
  as its opinion and a parity proof on DOORMAN_PAID. The lab reports
  `notices` and the win rate is tuned with both in.
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
  must change both. `ReelPrint.CELLS` is the symbol count (fourteen), so
  every symbol has a plate; add a symbol and raise it, and check the drum
  still fits the window. The drum's V runs 0..1 over the full turn
  (`1.0 / TAU` in `_drum_tube`): it ran over a tenth of it once, and the
  window showed cells cut through the middle until the first spin.
- A symbol is drawn in two inks plus the press's black: `SymbolDef.color`,
  `color2` (read through `second_color()`), and `SymbolArt.PAINT_*` on each
  op. Adds paint in order, later on top; carves cut everything. Lettering
  on a plate (`captions_for`) is a Label the bake overlays, so the CPU icon
  has no lettering — a symbol must read without it. Both interpreters,
  `SymbolArt._sample` and `reel_plate.gdshader`'s `symbol_sample`, fold the
  same way; change one and change the other.
- Nothing lit on the reels goes past the environment's 1.1 bloom threshold:
  a plate that bloomed bleached its own print. The window lamp is nearly
  all diffuse for the same reason.
- **The cabinet's body is a loft through `PROFILE`**, not a box: four
  rings of (height, half width, face z) — the base kicks forward, the glass
  band is plumb, the brow leans back, the head narrows. Anything bolted to
  the front asks `_face_z(y)` where the face is at its own height;
  `CHASSIS` is still the reference box every counter, key, drum and mount
  is placed against, and it does not move.
- **The rest of the cabinet is recast around that box, never by moving it.** Every
  counter, key, drum, mount and gauge is positioned against `CHASSIS`, so
  the classic silhouette — the cheeks, the shoulders, the rail, the tray,
  the step, in `MachineFrame._recast` — is cut around that box. Adding to
  it is safe; changing `CHASSIS` is not.
- **The value structure is one bulb.** The key in the pendant is the only
  bright thing; the wall and ceiling washes are under 1.0, the cold tube is
  the one fill, the ambient is 0.14, and `FloorMood` scales every floor's
  ambient and cold fill down with them. Raising any of these to "see the
  room" flattens the frame into one orange midtone — the art handover's
  first finding. The palette and the accent rule are `docs/PALETTE.md`:
  `Materials.SCORE` lights a plate because it paid, flashes the payline on
  a win, flares a tube as the total lands, and nothing decorative uses it.
- The machine view is a long lens, low and close (`machine_fov` 42, the eye
  below centre, the box fitted to the chassis, crown and gearbox). The
  spool and the lever's tip crop; the machine looms. Widening the field to
  fit more puts the floor back in the shot.
- The surety column on the right flank reads `RunState.surety()` through
  `SlotView3D.set_surety`, held through a spin like the cash counter and
  released on the beat the total lands. `FilmOverlay.set_strain` takes the
  same number for the render's tearing and grain; the room hands both out
  in `_settle_surety`, so the column and the picture can never disagree.
- Three headless drives exist and CI runs two: `resume_check.gd` (save and
  resume), `room_run_check.gd` (a whole run to the statement — add any
  new end-of-run surface to its summary), and `record.gd` (a spin as
  frames; `--paid` waits for one that pays par). `RoomDressing` furnishes
  the room a floor at a time on FLOOR_STARTED, additive, keyed by
  environment id; a new floor needs a `_dress_floor` arm or it leaves
  nothing. `PlayerProfile.seen` is the collection; `note_seen` returns
  true on a first sighting, which is the only time the log says so.
- The run ends on the clipboard: `RunRecap.build` (pure, tested) makes the
  statement from the state and the journal's entries, `RecapPanel` prints it
  on the board's viewport, and `CasinoRoom._show_statement` walks the camera
  to the desk and steadies the strain so it can be read. The draft, the
  office and the statement share one viewport and one `mount` pattern.
- `CasinoRoom._on_event` is a `match`: an arm that lists an event kind
  shadows every later arm for it. A surety arm that named RUN_ENDED once
  skipped the end of the run entirely; anything that must run for several
  kinds goes after the match, not in it.
- The door (`TitleScreen`) hides the HUD while it is up and owns Esc; the
  Clerk (`TutorialDirector`) owns the callout while the lesson runs and gates
  the machine to the move it is teaching through `CasinoRoom._allowed`. The
  `debug_*` tools skip both. `screenshot.gd --shots=a,b` captures only the
  named frames, which is how a single frame is checked in seconds.
- **Type is `Type`**: Bebas Neue for anything stamped into metal (the
  wordmark, the sign, plates and captions), IBM Plex Sans for anything read
  at length (the forms, the callouts — the project theme's default), IBM
  Plex Mono for what a machine printed (the receipt, the statement, the
  ledger's tube, the Nixie digits). `Type.face(label, &"display"|&"body"|
  &"mono")` dresses a `Label3D`; Controls take the theme unless they
  override. All three are OFL 1.1 with the licences in `assets/fonts/`.
  Bebas is narrow: a caption moved to it needs roughly 1.3x the size the
  engine default used, and the floor sign wraps at `width` 430 so a long
  floor name does not run off a 16:10 crop.
- A glow faked by scaling a crisp text copy doubles its ends and reads as a
  misprint. Nudge same-size copies in each direction instead.
- Compatibility clamps highlights where Forward+ rolls them off. A light tuned
  on desktop can burn the same surface white on the web build; scale the
  offender by `RenderingServer.get_current_rendering_method()` rather than
  splitting the whole rig.

## The performance

A spin is not an event that produces a number. The simulation still resolves
it in one frame; `ScoreDirector.plan` turns the receipt's steps into a
timetable and `SlotView3D._perform` keeps to it. Rules:

- The plan is pure and tested (`tests/unit/test_score_director.gd`): the
  tempo starts at 180 ms and floors at 60, the ladder climbs a semitone a
  beat and caps at twelve, a device breaks the rhythm, the count-up scales
  with magnitude and is capped, and the pause never drops below
  `PAUSE_FLOOR` at any pace. Change a number there, not in the view.
- The machine stays `_busy` from the lever to the total. `CasinoRoom._advance`
  refuses to step while it is; `_awaiting` holds the cash counter and the
  surety from the spin's start until `_land`, so a payout never appears on
  the tubes before the chain has counted it up. `_finish_spin` does not
  flush the counters on a banked spin; `_land` does.
- The receipt prints in time with the plan (`print_board(..., over_seconds,
  tier)`), its total on the beat the number lands. A standing board (a
  decision owed) still prints at once.
- Devices' cues play on their beat through `AudioDirector.tier_cue`; the
  director deliberately ignores ARTIFACT_TRIGGERED, which arrives before a
  reel has turned. `hush` and `overload` are the pause and tier five.
- Six tiers (`ScoreDirector.Tier`, mirrored one to one by
  `SlotView3D.Result`) judged against par: dead, scraping, paid, strong,
  heavy, overload. The machine's package is `_package`; the room's —
  shake, push-in, the lamp swinging, the lights flickering, the clip — is
  `_on_result_judged`. Add to both or the feel splits.
- Hold-to-hurry is `Engine.time_scale` while `bb_advance` is held and the
  machine is busy: the whole sequence scales, nothing is cut. Pace is three
  steps (`SlotView3D.PACES`); the profile stores the multiplier.
- Steps carry `reel` on a symbol and `id` on a device (`SpinContext.step`'s
  extra). The receipt and the chain both read them; keep them.

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
