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
6. **Rent has no flat component**: £10 per slot and £30 per till, which makes
   the default 3x4 shop with one till pay the £150 the spec quotes.
7. **Market Stall's nightly wipe is modelled as free rearrangement**, which is
   a benefit rather than a cost. Whether rebuilding by hand is interesting or
   exhausting is a playtest question, not a sim question.
8. **An L3 clause that touches a second term rolls its own trigger.** Sharing
   one pass roll across two terms correlates them, and correlated terms cannot
   be resolved by expectation — see Finding 10 in `REPORT.md`. Keeping each
   trigger to one term is section 1's discipline rule one level down, and it is
   what lets the resolver stay both exact and fast.

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

## What the sim does not model

- Individual conversion rolls. Profit is exact in expectation; per-day variance
  from binomial conversion is not simulated. It matters for how a run *feels*
  and not for whether the curve is reachable.
- Signage as a genuine tradeoff. The till queue is shop-wide, so no aisle
  carries a congestion cost and routing everyone down the busiest aisle is
  strictly correct. See the report — this is a live design hole, not a sim
  shortcut.
- Reroll and lock as deep strategy. The planner rerolls on a simple threshold
  and never locks.
