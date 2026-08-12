# FOOTFALL

A roguelike where you run a shop. Customers walk your aisles, fixtures fire as
they pass, and a quarterly target eats you alive.

```
Profit  =  Footfall  ×  Conversion  ×  Basket  ×  Margin  −  Rent
```

Four multiplicative terms and one flat subtractor. Never a fifth.

**[Play it](index.html)** — open the page, or serve the repo and visit the root.

```
python3 -m http.server 8099    # then http://localhost:8099/
```

## What is here

| | |
|---|---|
| `index.html`, `src/` | the playable browser build |
| `sim/` | the headless simulator the design was measured with |
| `data/` | 89 fixtures, customers, economy, targets, bosses, audits — the contract |
| `tools/` | data bundler, headless smoke test, browser screenshotter |
| `REPORT.md` | **what the simulator found.** The main document |
| `docs/GAME.md` | how the browser build is put together |
| `archive/` | an unrelated earlier project that used to live at the root |

## The game and the simulator are the same game

`src/engine.js` re-exports the simulator. No rule lives in `src/`.

- **The projection panel** runs `sim/day.js`, the aggregate resolver. A panel is
  a prediction, so an expectation is exactly the right thing for one.
- **The trading day** runs `sim/walk-one.js` — one customer at a time, their own
  wallet roll, their own coin flip at every slot.
- `sim/verify.js` proves the two agree, which is what makes the panel honest.

That split is the game rather than an implementation detail: you plan against a
number, then trade the day around it.

## Running things

```
node sim/verify.js              # resolver correctness, against 100k walked customers
node sim/cli.js check           # the section 19 health check
node sim/cli.js ablate          # where the skill gap comes from, across seed blocks
node sim/cli.js micro           # what the trading day is worth as a decision layer
node sim/cli.js envelope        # what profit curve a build can actually reach
node sim/cli.js trace           # one run, encounter by encounter

node tools/check-sampling.mjs   # the sampled walk vs the resolver, at every scale

node tools/bundle-data.mjs      # after editing anything in /data
node tools/smoke-game.mjs 30    # plays full runs through the game's code, no browser
node tools/screenshot.mjs shots # drives it in Chromium and captures each phase
```

No dependencies for the game or the simulator. Playwright is only needed for the
screenshotter, and only as a dev tool.

## Where the project actually is

All five of the §19 measures hold together, at 1,200 runs per policy:

| | | |
|---|---|---|
| random | 0.0% | band 0–2 |
| greedy | 20.6% | band 15–25 |
| planner | 62.9% | band 55–70 |
| greedy vs planner | **42.3pp** | milestone wants > 30 |
| queue | 29.5% of early deaths | wants ~25 |

The first time that has happened. Three of them moved into band on one bug fix,
before any tuning — the walkout carry was mixing quantities from opposite sides
of the multiplier chain, and it had been distorting every win rate ever measured
here. Part six of `REPORT.md` has it.

**The ending.** The target ends at £14,083 a day. A winning run's median last day
is **£731,335**, and 42% of wins finish on a day clearing seven figures — about
one run in four overall. Seven figures is the overshoot, not the requirement,
which is the only version of it a 24-encounter run can actually carry.

Where the skill lives, across three disjoint seed blocks — every row below
sign-stable except `stress`, which nothing should be concluded from:

| capability | alone | removed |
|---|---|---|
| tempo | +15.8pp | −19.7pp |
| sign | +5.2pp | −6.2pp |
| lookahead | +4.5pp | −12.1pp |
| reroll | +2.9pp | −8.0pp |
| reorder | +1.9pp | −1.9pp |

Part four **withdrew** the lookahead claim as unstable. Part six reinstates it,
and the compounders are why: every other card is worth the same whenever you buy
it, so lookahead had nothing to look at. A compounder is worth what is left of
the run.

The Audit ladder descends smoothly from 66.3% to 8.3% across its eight rungs,
and the seven characters sit inside **10.3pp** of each other — down from 59.4pp,
which is what happens when nobody has ever measured them.

Still out of band: tier rush at 16% (wants ~30%), and staff counts in winning
builds run 0–11 (wants 0–8, unclustered).

The committed order was **pool → queue verification → tune**, and all three are
now done. `verify-queue.js` runs the fluid queue against a discrete one — every
customer an individual with their own arrival tick and their own place in the
line — across ten scenarios from well under capacity to twelve times overload.
Totals agree exactly; the worst mix shift is 0.88pp of the day. It found a real
off-by-one: customers were expiring a tick early, which cost the short-patience
types about a third of the service they were owed.

Read `REPORT.md` newest-part-first. Each part reverses conclusions in the one
before it; earlier parts are kept as the record rather than edited.
