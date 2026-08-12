# FOOTFALL — headless simulator (Phase 0)

Everything in the ruleset is a hypothesis. This runs it a few hundred thousand
times and reports which parts survive.

No dependencies, no build step. Node 18+.

```
node sim/cli.js panel        # the day-one projection panel
node sim/cli.js check        # the section 19 health check
node sim/cli.js envelope     # what profit curve a build can actually reach
node sim/cli.js fit          # fit a target curve to that envelope
node sim/cli.js bossimpact   # what each boss actually costs
node sim/cli.js bosses       # loss share per boss
node sim/cli.js chars        # win rate spread across the six shop types
node sim/cli.js ladder       # planner win rate per Audit level
node sim/cli.js trace        # one run, encounter by encounter
node sim/cli.js bench        # runs per second
node sim/cli.js sweep <knob> # the tuning sweeps from section 20
```

Global overrides work on every command: `--growth=1.3 --base=150 --ticks=180
--pass=0.75 --rent=1.2 --character=discounter --audit=3 --n=2000`.

Sweep knobs, in the order section 20 demands: `level`, `growth`, `tier`,
`rarity`, `till`, `staff`, `slots`.

## Layout

| File | What it holds |
|---|---|
| `content.js` | Loads `/data`, indexes it, applies tuning overrides |
| `shop.js` | Topology, placed fixtures, staff, tills, signage, rent |
| `day.js` | The walk, the queue, the till, the projection panel |
| `offers.js` | Supplier Tier weights, offers, rerolls |
| `policies.js` | random / greedy / planner |
| `run.js` | The 24-encounter loop, purchases, boss and audit application |
| `harness.js` | Batch runner and the section 19 metrics |
| `envelope.js` | Achievable-profit measurement and target-curve fitting |
| `sweep.js` | The section 20 tuning sweeps |
| `verify.js` | Checks the fast resolution against an individual-customer walk |

`/data` is the contract with the game. Nothing in `/sim` invents content.

## Resolution model

The ruleset describes customers entering one at a time. Simulating them
individually is far too slow for 100k runs, and it is also unnecessary: every
value a customer ends the walk with is a pure function of `(type, aisle,
wallet)`, and Basket is **linear** in wallet. So the mean wallet gives exactly
the right expected profit, and the walk is resolved once per `(aisle, type)`
pair — 27 walks a day instead of thousands.

`verify.js` walks individuals and confirms the two agree.

This holds as long as no fixture *conditions* on wallet. If one is ever added,
the resolver has to enumerate the ten wallet ranks per type; `conditionsHold`
returns `false` for `wallet_at_least` today rather than silently lying.

The till queue is a per-tick FIFO with fractional cohort counts, with a fast
path that skips the loop entirely when arrivals never exceed throughput.

### Throughput, honestly

`node sim/cli.js bench` — roughly 1,700 runs/sec for random, 110 for greedy,
20 for the planner. Section 19 asks for 100k runs in under a minute; random
makes it, the planner needs about 80 minutes, so headline numbers are taken at
n=1500-2500 (±1.0pp) rather than 100k.

The cost is almost entirely the queue. Profiled: `resolveDay` is **9.6µs** when
throughput covers demand and **42.5µs** once the queue overloads and the tick
loop runs, and a planner run makes roughly 860 `resolveDay` calls. Reusing the
scratch buffer and skipping absent customer types helped a little; the real fix
is to replace the tick loop with the closed form, which uniform arrivals make
tractable — each type has a single arrival-time threshold after which it always
abandons, and those thresholds solve as a small fixed point.

That rewrite was deliberately not done here. `verify.js` covers the walk and
explicitly excludes the queue, so an analytic queue would be the one unverified
component in the simulator, and correctness matters more than speed at Phase 0.

## Rulings the spec left open

These are decisions, not discoveries. Each one is a place the design could
legitimately go the other way.

1. **`next_slots` amplifies, it does not just multiply.** End Cap multiplies
   *Basket effects in the following slots*, rather than multiplying the
   customer's Basket as they walk past. Only the amplifier reading makes
   "levelling scales breadth, never the multiplier" mean anything.
2. **Customers may skip slots.** One-Way Barriers says "customers cannot skip
   slots", which implies they can by default. Base pass chance is 0.75, tunable
   via `--pass`. At 1.0, Maze and One-Way Barriers become dead cards.
3. **A customer type's Conversion and Basket are their starting values.** The
   Footfall 120 / Conversion 45% / Basket £18 / Margin 30% line in section 14
   is what the *pool* averages out to, not a separate baseline stacked on top.
4. **Wallet does not scale a Shoplifter's loss**, and Shoplifters do not walk
   the aisle at all. They are not shopping.
5. **Staff cost no cash**, only Margin, exactly as written. The limiter is that
   Margin is one of four multiplicative terms.
6. **Rent is a declining fraction of the target**, scaled by the footprint you
   have bought — 62% of target in Q1 falling to 5% by Q8. Section 13 wants rent
   brutal in act 1 and noise by act 5; pegging it to the curve makes that true
   by construction instead of by coincidence. The original per-slot formula is
   kept in `data/economy.json` under `rent.legacy`.
7. **Market Stall's nightly wipe is modelled as free rearrangement**, which is
   a benefit rather than a cost. Whether rebuilding by hand is interesting or
   exhausting is a playtest question, not a sim question.
8. **An L3 clause that touches a second term rolls its own trigger.** Sharing
   one pass roll across two terms correlates them, and correlated terms cannot
   be resolved by expectation — see Finding 10 in `REPORT.md`. Keeping each
   trigger to one term is section 1's discipline rule one level down, and it is
   what lets the resolver stay both exact and fast.
9. **Ratchets grow once per real trading day, never during evaluation.** A
   policy resolves the day hundreds of times a night; if that advanced run
   state the game would play itself. `projectRatchets` exists so a policy can
   look ahead on a throwaway clone.
10. **A declined boss goes back in the deck.** Two are drawn per boss day and
    only the taken one is spent, so a run still meets eight of the twelve but
    chooses which eight.

## The projection panel is a funnel, not four averages

Section 17 makes the panel the most important UI in the game. If it multiplies
**pool averages** of the four terms, it does not equal the profit it claims to
predict: Conversion and Basket are strongly negatively correlated across
customer types (Luxury converts at 25% and spends £180; Pensioner converts at
70% and spends £14), and a product of averages ignores that.

The fix is to define the four terms as chained funnel ratios:

```
Conversion = sales / footfall
Basket     = revenue / sales
Margin     = trading profit / revenue
```

Then `Footfall × Conversion × Basket × Margin` is *identically* the trading
profit, for any customer mix. It is also how retail actually reports itself.
`panel.naive` carries the average-of-pool version so the error stays visible.

Two consequences worth keeping:

- Walkouts show up as a **Conversion** collapse, which makes a drowning till
  legible in the panel rather than only in the walk.
- Loyalty Card returns and Corner Shop re-traverses count as **Footfall**,
  because otherwise Conversion reads above 100% and the panel stops meaning
  anything.

## Conversion and Margin are capped, and that costs a little accuracy

`data/economy.json` caps Conversion at 90% and Margin at 70%. Clamping is
non-linear, so `E[min(X, cap)] < min(E[X], cap)`: a build pressed hard against a
cap earns slightly less on an individual walk than the expectation-based
resolver credits it with. Measured at **0.44%** on a board deliberately built to
sit on the Conversion cap, and it does not shrink with sample size.

`verify.js` tests for this explicitly — statistical agreement in standard errors
for everything else, and a separate 0.75% bound for cap-induced bias — rather
than hiding it inside a loose tolerance.

## What the sim does not model

- Individual conversion rolls. Profit is exact in expectation; per-day variance
  from binomial conversion is not simulated. It matters for how a run *feels*
  and not for whether the curve is reachable.
- Aisle congestion. Tested and abandoned: charged against Patience it does
  nothing, because Patience only bites once a queue exists; charged against
  Conversion it is a flat difficulty tax that narrows the skill gap. See the
  appendix in `REPORT.md`. Routing still matters enormously, for a different
  reason — a customer walks exactly one aisle, so most of the board is invisible
  to them unless different types take different routes.
- Reroll and lock as deep strategy. The planner rerolls on a simple threshold
  and never locks.
