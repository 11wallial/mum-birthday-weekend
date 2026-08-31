---
description: Run the Casino Lab balance batch and summarise the result
argument-hint: "[runs] (default 10000)"
---

Run the headless Monte Carlo batch:

```
godot --headless --path . --script res://tools/casino_lab/run_lab.gd -- \
    --runs=${1:-10000} --seed=1 --out=res://reports/balance_report.json
```

Then read `reports/balance_report.json` and report: win rate, deaths by floor,
earnings p50/p95/p99, and every entry in `anomalies`. If a previous report is
present in the working tree, give the delta against it rather than absolute
numbers alone. Do not change any balance resource unless asked.
