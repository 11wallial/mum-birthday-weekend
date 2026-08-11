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
| `data/` | fixtures, customers, economy, targets, bosses, audits — the contract |
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
node sim/verify.js              # resolver correctness, against 300k walked customers
node sim/cli.js check           # the section 19 health check
node sim/cli.js ablate          # where the skill gap comes from, across seed blocks
node sim/cli.js micro           # what the trading day is worth as a decision layer
node sim/cli.js envelope        # what profit curve a build can actually reach
node sim/cli.js trace           # one run, encounter by encounter

node tools/bundle-data.mjs      # after editing anything in /data
node tools/smoke-game.mjs 30    # plays full runs through the game's code, no browser
node tools/screenshot.mjs shots # drives it in Chromium and captures each phase
```

No dependencies for the game or the simulator. Playwright is only needed for the
screenshotter, and only as a dev tool.

## Where the project actually is

Phase 0 is done and then some: the engine is verified, the design has been
measured, two rounds of external review have been acted on, and there is a
playable build. What is *not* done is the balance.

Three findings all said "cannot be tested at 23 cards", so the pool went to 40
and order-of-operations went from measuring **0.0pp** to **+3.4pp** — §2's
central claim, vindicated by writing the content that expresses it.

The committed order for what remains is **pool → queue verification → tune, and
no tuning before both**. Every win-rate number in parts two and three of
`REPORT.md` predates the current pool and needs re-running. Two decisions are
open and on the critical path: whether the run ends in four figures or seven,
and whether rent should stay a fixed cost at all.

Read `REPORT.md` newest-part-first. Parts four and five reverse conclusions in
parts two and three, which are kept as the record rather than edited.
