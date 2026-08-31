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

Cues are synthesised by `tools/audio/make_cues.py` into `assets/audio/`. Change
the generator, not the WAVs, and re-run it. `AudioDirector` degrades to silence
if a cue is missing, so a stripped asset folder is not a crash.

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
- Never name a method after a `@GlobalScope` utility (`randi_range`, `randf`,
  `lerp`, ...). An unqualified internal call binds to the global, not to your
  method, and it fails silently — `RngStream.weighted_index` drew from Godot's
  unseeded global RNG this way, and every external-call test still passed.
- Doc comments (`##`) on every class and on anything whose *why* is not obvious
  from its name. Skip them on self-evident getters.
