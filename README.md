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

Everything the ruleset asks for now holds at once.

| | | |
|---|---|---|
| random | 0.0% | band 0–2 |
| greedy | 15.2% | band 15–25 |
| planner | 61.2% | band 55–70 |
| greedy vs planner | **46.0pp** | milestone wants > 30 |
| high-rarity picks at Tier 4+ | 48.7% | wants ~50 |
| Audit I → VIII | 61.4% → 8.4% | wants 55–70 → 8–15 |
| character spread | **10.7pp** | wants within 10 |
| queue | 32.8% of early deaths | wants ~25 |

Three of the win-rate bands moved into range on one bug fix, before any tuning —
the walkout carry was mixing quantities from opposite sides of the multiplier
chain, and it had been distorting every win rate ever measured here. Part six of
`REPORT.md` has it; part seven has the queue, the ladder and the characters.

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

## What is verified

Three independent checks, because three different things could be wrong:

| | |
|---|---|
| `sim/verify.js` | the aggregate resolver against **individually walked customers**, on all seven characters |
| `sim/verify-queue.js` | the fluid queue against a **discrete queue of individuals**, in total and per type |
| `tools/check-sampling.mjs` | the **sampled** trading day against the resolver, from 138 to 84,240 Footfall |

Each of them found something the others could not see. The queue verifier found
customers expiring a tick early, which cost the short-patience types a third of
the service they were owed. Extending the walk verifier to every character found
that `walk-one.js` implemented one of the eleven trigger conditions — so in the
game people would actually play, every adjacency card fired from anywhere, and
order of operations was decorative while the panel promised it mattered.

Still out of band: the queue at 32.8% of early deaths (wants ~25), tier rush at
14% (wants ~30), and staff counts in winning builds run 0–11 (wants 0–8,
unclustered). Four of the twelve bosses still sit under the 5% loss-share
band — but see part seven on why that band is close to unmeasurable for a deck
the player chooses from.

Read `REPORT.md` newest-part-first. Each part reverses conclusions in the one
before it; earlier parts are kept as the record rather than edited.
