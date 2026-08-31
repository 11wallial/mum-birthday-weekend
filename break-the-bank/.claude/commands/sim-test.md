---
description: Run the GdUnit4 suites headless and report failures
argument-hint: "[path] (default tests)"
---

```
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue -a ${1:-tests}
```

Report each failing assertion with its suite, test name, and the expected vs
actual values. If a `tests/simulation/` guardrail fails after a balance edit,
say whether the guardrail or the balance is wrong — those suites assert that the
game is playable, not that it hits a particular number.
