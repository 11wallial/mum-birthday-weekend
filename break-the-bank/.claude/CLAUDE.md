# Break the Bank — working notes

A systems-heavy slot machine roguelike. Godot 4.4, Forward+, statically typed
GDScript. The game is a headless simulation with a 3D face bolted on; keeping
those two apart is the single most important rule in this repo.

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
composed, and handle it in `ArtifactEngine._apply_one` plus its own helper.

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

## Input and the draft

Input actions are `bb_*` in `project.godot`; add bindings there, never with
`InputMap` calls at runtime. The draft buys through `SimEngine.buy_offer`, which
is the same call the headless shop policy makes — keep it that way, or the
batch stops measuring the game a person plays.

`CasinoRoom._advance()` refuses to step while the reels are turning or a draft
is open. Put guards like that in `_advance()` rather than in `_unhandled_input`,
so tools and tests are held to them too.

## Meta-progression

Anything persistent lives in `scripts/meta/` and reaches a run only as
[RunOptions]. Never let the simulation read a profile: the lab passes default
options so its numbers keep describing the full content set.

Saves are plain JSON, and every loader treats a corrupt or newer-version file as
"start fresh" rather than failing. Keep it that way.

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
