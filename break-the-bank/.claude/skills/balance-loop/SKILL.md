---
name: balance-loop
description: Run the Casino Lab Monte Carlo batch, read the JSON telemetry, and adjust balance resources. Use when asked to tune, rebalance, or investigate difficulty, win rate, payout curves, or overpowered artifacts and synergies in Break the Bank.
---

# Balance loop

Close the loop: measure, change one thing, measure again. Never adjust numbers
from intuition alone — the lab is cheap and the intuition is usually wrong about
which floor is actually killing people.

## 1. Measure

```
godot --headless --path . --script res://tools/casino_lab/run_lab.gd -- \
    --runs=10000 --seed=1 --out=res://reports/balance_report.json
```

Use 2,500 runs while iterating (about 70 seconds) and 10,000 before calling a
change done (about four and a half minutes — start it in the background, or
give it a ten-minute timeout). A 100,000 batch is most of an hour: overnight,
not in the loop. Keep `--seed` fixed across a comparison so two reports differ
only by your edit.

## 2. Read

The report carries:

- `win_rate` / `death_rate` — the headline.
- `deaths_by_floor` — where runs actually end. A single dominant floor is a
  wall; deaths spread across floors is the shape to aim for. Note the key `8`
  means the run cleared every floor and then failed to repay its debt.
- `earnings`, `spins_per_run`, `floors_cleared` — mean, min, max, p50, p95, p99.
  A p99 far above p95 means a build that runs away with the game.
- `artifact_win_rates`, `synergy_win_rates` — win rate conditional on owning
  the artifact or having the tag combo active, each with the `baseline` it is
  measured against and a `baseline_note` naming that cohort.
- `anomalies` — entries sitting 25+ points off **their own baseline**, worst
  first. Thin samples (<30 runs) are excluded on purpose.

Read a win rate against its `baseline`, never against the headline `win_rate`.
An artifact that unlocks on floor 5 is only ever owned by runs that reached
floor 5, so its raw win rate mostly measures the player who got there: judged
against the whole batch, every late artifact looks overpowered. The baseline is
therefore the win rate among runs that cleared enough floors to be offered it
(and, for a tag, among runs that owned enough artifacts for a synergy to exist
at all).

## 3. Change one thing

Edit resources, never simulation code:

- Pacing → `resources/rules/floors/*.tres` (`ante`, `spins`, `payout_scale`)
- Global feel → `resources/rules/balance_config.tres`
- One artifact → `resources/artifacts/<id>.tres` (`magnitude`, `cost`, `cap`,
  `min_floor`)

Change one number per iteration. Two changes in one batch means you learn
nothing about either.

## 4. Re-measure and record

Re-run with the same seed and runs. Report the delta in win rate,
`deaths_by_floor`, and the anomaly list — before and after, not just after.

## Sweeping

`tools/casino_lab/sweep.gd` varies one knob across values and prints the curve,
which is how the shipped antes were chosen. Use it before editing a `.tres`:

```
godot --headless --path . --script res://tools/casino_lab/sweep.gd -- \
    --knob=ante --floor=6 --values=3800,4200,4600 --runs=2500
```

Knobs: `ante`, `spins`, `payout_scale` (with `--floor`), `debt`, `service`,
`debt_growth`, `synergy_bonus`.

## Known sensitivities

- Debt compounds at 80% per floor and its vig is charged before the ante, so
  `debt_growth` and `service` move the win rate as hard as any ante. Sweep them
  together with floor 6 rather than one at a time.
- `SimEngine.default_shop_policy` buys the most expensive affordable artifact.
  It is deliberately mediocre. A change that only helps optimal play will not
  show up in the batch — check it with a custom `shop_policy` instead of
  assuming the batch missed it.
- `Probability.Pattern.TRIPLE` cannot occur at three reels. Tuning its
  multiplier does nothing until `reel_count` rises.
