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
godot --headless --script tools/casino_lab/run_lab.gd -- \
    --runs=10000 --seed=1 --out=res://reports/balance_report.json
```

Use 10,000 runs while iterating and 100,000 before calling a change done. Keep
`--seed` fixed across a comparison so two reports differ only by your edit.

## 2. Read

The report carries:

- `win_rate` / `death_rate` — the headline.
- `deaths_by_floor` — where runs actually end. A single dominant floor is a
  wall; deaths spread across floors is the shape to aim for. Note the key `8`
  means the run cleared every floor and then failed to repay its debt.
- `earnings`, `spins_per_run`, `floors_cleared` — mean, min, max, p50, p95, p99.
  A p99 far above p95 means a build that runs away with the game.
- `artifact_win_rates`, `synergy_win_rates` — win rate conditional on owning
  the artifact or having the tag combo active.
- `anomalies` — artifacts and synergies whose win rate sits 25+ points off the
  batch baseline, worst first. Thin samples (<30 runs) are excluded on purpose.

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

## Known sensitivities

- The late-floor antes sit close to a cliff: past floor 5 the naive shop policy
  has bought most of the pool, so income plateaus and a modest ante increase can
  swing the win rate by tens of points. Move floors 6 and 7 in small steps.
- `SimEngine.default_shop_policy` buys the most expensive affordable artifact.
  It is deliberately mediocre. A change that only helps optimal play will not
  show up in the batch — check it with a custom `shop_policy` instead of
  assuming the batch missed it.
- `Probability.Pattern.TRIPLE` cannot occur at three reels. Tuning its
  multiplier does nothing until `reel_count` rises.
