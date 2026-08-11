# FOOTFALL — Phase 0 findings

What the headless simulator says about the v0.1 ruleset.

Section 19 is explicit that "everything above is a hypothesis and most of it is
wrong". That turned out to be the right posture. The structure survives well;
the numbers do not.

Run it yourself:

```
node sim/verify.js      # resolver correctness
node sim/cli.js panel   # the day-one projection panel
node sim/cli.js check   # the section 19 health check
```

---

## The short version

| | |
|---|---|
| **Biggest problem** | The encounter-24 target is roughly **870x** higher than the best build can reach. |
| **Second biggest** | One boss, **Refund Day**, is an automatic loss, and it appears in 2 runs out of 3. Before fixing it, no build could win more than ~33% regardless of skill. |
| **Root cause of the first** | Two of the four terms are capped at 100%. The whole run's growth has to come from Footfall and Basket alone. |
| **Best news** | The greedy-versus-planner gap is **30.1pp** once the curve is winnable. Milestone 0's gate is met, and the skill headroom the design is betting on is real. |

The structure is sound. Four multiplicative terms and one subtractor is a good
engine, order of operations does carry real skill, and the pick-versus-cash
split does produce two distinct axes. Everything below is about numbers and
about three places where a rule quietly contradicts itself.

---

## Finding 1 — the target curve is unreachable, by about 870x

`node sim/cli.js envelope` plays the planner against a trivial target so nothing
dies, and records the median profit at each encounter. That is the ceiling the
target curve has to sit under.

| | Encounter 1 | Encounter 24 | Climb | Implied growth |
|---|---|---|---|---|
| **Achievable** | £415 | £40,508 | **x98** | **x1.22 / encounter** |
| **Spec targets** | £450 | £3,173,301 | x7,052 | x1.47 / encounter |

The gap compounds: it is 1.5x at encounter 6, 8x at encounter 12, and 78x by
encounter 24.

Day one is worse than the curve suggests. The section 14 starting values
multiply out to `120 × 45% × £18 × 30% = £292`, and rent is £150, so a bare shop
earns **£142** against a £450 target. With the three starting fixtures the sim
measures **£202**. Day one is not "tight rather than free" — it is a guaranteed
loss, and every policy dies on encounter 1.

**Measured replacement:** base **£120**, growth **1.17**.

Coarse sweep of base against growth (n=350 per cell, so ±2.7pp):

| base | growth | enc-24 target | planner | greedy | random |
|---|---|---|---|---|---|
| £120 | 1.16 | £3,645 | 57.4% | 25.4% | 0.0% |
| £120 | 1.20 | £7,950 | 53.7% | 8.0% | 0.0% |
| £120 | 1.24 | £16,900 | 45.7% | 0.6% | 0.0% |
| £120 | 1.28 | £35,076 | 29.7% | 0.0% | 0.0% |
| £150 | 1.16 | £4,556 | 50.6% | 20.6% | 0.0% |

Greedy falls off a cliff between 1.16 and 1.20, so the band is narrow. Refining
at n=900 (±1.7pp):

| base | growth | enc-24 target | planner | greedy | random | gap |
|---|---|---|---|---|---|---|
| £120 | 1.16 | £3,645 | 56.9% | 28.3% | 0.0% | 28.6pp |
| £120 | **1.17** | **£4,441** | **55.2%** | **24.7%** | **0.0%** | **30.6pp** |

`base 120, growth 1.17` is the only setting found that lands inside all three
section 19 bands *and* clears milestone 0's 30pp gate. It sits near the lower
edge of the planner band, so it wants re-checking at a larger sample once the
other tuning steps have moved. It is now the default in `data/run.json`, with
the v0.1 numbers preserved alongside under `targets.$specified`.

The cost is thematic, and it is worth naming: the run now ends at **£3,645**
rather than £3.18M. "Turn over three million by Q8" is a much better fantasy
than "turn over three thousand". If the seven-figure ending matters, the fix is
Finding 3, not the curve.

---

## Finding 1b — the target curve is also the cash faucet, and it cannot be both

A corollary of Finding 1, and it bites as soon as you flatten the curve.

Section 13 makes retained earnings equal to *profit above the target*. So the
target does two unrelated jobs at once: it is the fail condition, and it is the
only source of cash. Those two jobs want opposite numbers.

A curve low enough to survive boss variance is also a curve you overshoot by an
order of magnitude, and the overshoot is your bank balance. Measured on the
tuned curve: winning runs reach **Supplier Tier 5 in 100% of cases**, against
the ~30% tier-rush rate section 20 asks for. A trace shows £905,702 banked
against a £461 target. Supplier Tier stops being a tempo decision and becomes
a formality, and section 10's "cash spent on tier is cash not spent on staff,
tills, structure or marketing" quietly stops being true.

Push the curve up until cash is scarce again and you are back to dying on
encounter 6.

The standard fix is to decouple them, which is what Balatro does: money comes
from a **flat reward per encounter** (scaled by quarter) plus interest, and
overshoot contributes only a **capped** bonus. The target then only has to be a
fail condition, and it can be tuned purely against survivability. Interest
already exists in section 13 and already has a cap, so this is a small change:
add a per-encounter reward, and cap the overshoot contribution the same way.

Until that is decoupled, tuning steps 3 (tier costs) and 6 (staff) cannot be
measured honestly, because both are denominated in a currency whose supply is
set by an unrelated dial.

---

## Finding 2 — Refund Day is an automatic loss, and it capped the whole game

Pin every target at £40 so nothing can die of the curve, and the planner still
only wins **18.7%**. Of the losses, **64% are Refund Day**.

Refund Day spawns Returners and nothing else. With no other type in the pool
there are no sales at all, only refunds and rent, so profit is negative on any
board. Measured: **-96% of a clean day**. Eight of the twelve bosses appear in a
run, so it lands in 2 runs out of 3, and when it lands the run is over.

That single card was holding the ceiling at roughly 33% before build quality
entered the picture.

Blending the pool instead of replacing it — 20% Returners, the rest normal —
puts it at 61% of a clean day, a hard day rather than a dead one. That lifts the
boss-only ceiling from **18.7% to 67.2%**, at which point the target curve
becomes measurable at all.

**This inverts the tuning order.** Section 20 puts boss severity last, at step 7.
It has to be near-first: an unpassable boss makes every earlier step measure
noise. You cannot tune a curve you are not allowed to reach.

---

## Finding 3 — two of the four terms are capped, so growth rides on two

Conversion and Margin cannot exceed 100%. In practice they saturate early: the
trace shows Conversion at 94% and Margin at 88% by encounter 8, and flat from
there. Everything after that has to come from Footfall and Basket.

That is what makes the achievable curve S-shaped — fast while there are empty
slots and headroom in all four terms, flat once two of them are pinned — while
the target curve is a pure exponential. **An S-curve and an exponential can only
agree for a few encounters.**

It is also the real reason the ceiling is x98 rather than x7,052. Every fixture
in the pool has a *bounded* effect: fixed adds and fixed multipliers. Balatro
reaches Ante 8 because Jokers scale without limit — a Joker that gains +Mult
every hand has no ceiling. FOOTFALL has no equivalent.

Three ways out, in order of how much they cost you:

1. **Accept a flatter curve.** Free. Costs the seven-figure ending.
2. **Add unbounded scalers to Footfall and Basket.** "Gains +5 Footfall
   permanently each day", "gains +£1 Basket every time a Luxury customer buys".
   One or two per term is enough. This is the smallest change that buys back the
   original ending, and it is the standard answer.
3. **Uncap Margin.** Coherent if Margin is read as markup rather than share of
   basket, but it changes what the word means on the panel.

Recommendation: (2). It preserves the fantasy, it is squarely inside the genre,
and the discipline rule survives untouched — a growing Footfall bonus is still
Footfall.

---

## Finding 4 — the projection panel cannot multiply pool averages

Section 17 calls the panel the most important UI in the game and says never hide
it. As written it does not add up.

If the four terms are pool averages, `Footfall × Conversion × Basket × Margin`
is not the profit it claims to predict. Conversion and Basket are strongly
negatively correlated across customer types — Luxury converts at 25% and spends
£180, Pensioner converts at 70% and spends £14 — and a product of averages
throws that away. Measured overstatement on a day-one board: **1.06x**, and it
grows as a build specialises.

The fix is to define the terms as chained funnel ratios:

```
Conversion = sales / footfall        Basket = revenue / sales
Margin     = trading profit / revenue
```

Then the product is *identically* the trading profit, for any customer mix, and
it is also how retail actually reports itself. The sim does it this way;
`panel.naive` keeps the broken version so the error stays visible.

Two consequences worth keeping deliberately:

- Walkouts land on **Conversion**, so a drowning till is legible in the panel
  and not only in the walk.
- Loyalty Card returns and Corner Shop re-traverses have to count as
  **Footfall**, or Conversion reads above 100% and the panel stops meaning
  anything. The sim hit exactly this: 189% Conversion in an early trace.

---

## Finding 5 — Shrink is invisible, and it is enormous

Shoplifters at 5% of the pool cost **£210 a day** against **£562** of day-one
trading profit. That is 37% of gross, and it appears nowhere in the four-term
formula. A player reading the panel cannot see the largest single drain on their
shop.

The discipline rule says never add a fifth *term*. Shrink is not a term, it is a
subtractor, exactly like Rent — and Rent is already on the panel. Put it on the
line below with Rent:

```
Footfall 133 × Conversion 52.3% × Basket £28 × Margin 28.6%
= Trading £562    Rent -£150    Shrink -£210    Profit £202
```

Separately: 5% is too high a weight for a flat £30 hit at a 140-footfall shop.
Either drop the weight to ~2%, or scale the loss with shop size so it stays a
constant proportion instead of an early-game execution.

Two related rulings the sim had to make, both worth adopting: a Shoplifter's
loss is **not** multiplied by their wallet roll (they take goods, they do not
spend), and Shoplifters do **not** walk the aisle at all, so Sample Table cannot
make them cheaper.

---

## Finding 6 — signage has a dominant strategy

Nothing in the ruleset punishes funnelling. The till queue is shop-wide, so an
aisle carries no congestion cost, which means **routing every customer down your
most-stocked aisle is strictly correct**, always. The other aisles exist only as
storage for slots and as scope for aisle-conditional fixtures.

This makes section 5's "mis-signed shops send high-wallet customers past
fixtures that do nothing for them" a failure state that a player has to opt into
rather than a live decision.

It also quietly broke a boss: Roadworks closes one aisle, but if two of your
three aisles are empty it is a coin flip that usually does nothing. Measured at
**101% of a clean day** — a boss with no effect.

The cheapest fix is to give an aisle a congestion cost: Patience drains faster
in an aisle carrying more than its share of the day's Footfall. That makes
splitting real, makes Wide Aisle and Cleaner matter, and turns Roadworks back
into a threat. Section 24 asks whether three aisles is the right count — the
count is not the problem, the absence of a cost is.

---

## Finding 7 — the walkout penalty could zero Footfall

A walkout costs 0.5 Footfall tomorrow, uncapped. One Black Friday (Footfall x4)
with a drowning till produced 1,481 walkouts, a -740 Footfall penalty, and a
shop with **zero customers** the next morning. Because the four terms multiply,
a zero anywhere is an unrecoverable run — the design says as much in section 1.

Capped at 25% of base Footfall in `data/economy.json`. A bad day should hurt
tomorrow, not delete the shop.

---

## Finding 8 — five of the twelve bosses are neutral or a bonus

`node sim/cli.js bossimpact` resolves each boss day twice, once with the boss and
once without, on the same board. The ratio is what the boss actually costs.

| Boss | Profit kept | |
|---|---|---|
| Card Terminal Down | 32% | brutal |
| Mystery Shopper | 43% | brutal |
| Competitor Opens | 48% | ok |
| Refund Day | 61% | ok *(after Finding 2)* |
| Rate Review | 67% | ok |
| Supply Shortage | 84% | ok |
| Trading Standards | 100% | no effect |
| Health Inspection | 100% | no effect |
| Roadworks | 101% | no effect |
| Black Friday | 174% | **a bonus** |
| Heatwave | 204% | **a bonus** |
| Bank Holiday | 206% | **a bonus** |

Three bosses are straightforwardly good for you. Footfall x4 against Margin
-25pp is a large net win; Heatwave doubles Basket and the Patience cost only
bites if your tills are already saturated; Bank Holiday triples Footfall for one
disabled till. Two more do nothing to a median board, because it holds no
flagships and staffs everything it can.

The design intent in section 15 — "bosses attack specific funnel terms, so a
lopsided build meets a wall" — is right, and the four brutal ones do exactly
that. The other eight need their numbers moved. Note also that the target curve
rises straight through boss days, which compounds this: a boss day is already
1.16x harder than the day before it *and* carries the boss.

---

## Finding 9 — rent only fades if the curve outruns it

Section 13 says rent is brutal in act 1 and fades to noise by act 5, by design.
It fades only if the target curve grows faster than rent does. Rent rises 40%
per quarter, which is **x1.119 per encounter**. So:

- At the spec's 1.47 growth, rent fades as intended.
- At the measured 1.16 growth, rent fades much more slowly, and Rate Review
  (rent x10) stays a live threat all run — it is the single largest source of
  late deaths in the sim.

If you adopt the flatter curve, drop the quarterly rent multiplier from 1.40 to
about **1.12** to keep the intended shape.

Also: the section 14 starting rent of £150 needs rent to have no flat component.
`£10/slot + £30/till` puts the default 3x4 one-till shop at exactly £150 and
makes Aisle Extension and extra tills carry an honest ongoing cost.

---

## Finding 10 — one trigger must not touch two terms

This one is about the sim, but it constrains the design.

The resolver walks each `(aisle, customer type)` pair once at the mean wallet
and treats slot-skipping as an expectation. That is exact — verified against
400,000 individually-walked customers, agreement within 1.7 standard errors —
**as long as no single trigger modifies two of the four terms**.

When one does, the two terms become correlated through the shared coin flip and
`E[XY] ≠ E[X]E[Y]`. Sample Table's L3 clause (+£16.50 Basket and +5% Conversion
from one trigger) produced a real, non-shrinking 1.16% bias until the clause was
given its own trigger roll.

The design rule that falls out is a good one anyway, and it is section 1's
discipline rule one level down: **a fixture touches one term; a clause that
touches a second rolls separately.** Keep it and the sim stays exact and fast.
Break it and every balance number carries a quiet bias.

---

## Section 19 metrics

`node sim/cli.js check --n=2500` — 2,500 runs per policy, so ±1.0pp.

| Metric | Target | v0.1 numbers | Tuned | |
|---|---|---|---|---|
| Random win rate | under 2% | 0.0% | 0.0% | pass |
| Greedy win rate | 15-25% | 0.0% | 25.9% | marginal |
| Planner win rate | 55-70% | 0.0% | 56.0% | pass |
| **Greedy-vs-planner gap** | **over 30pp** | 0.0pp | **30.1pp** | **pass** |
| Median death, random | 4-7 | 1 | 3 | close |
| High-rarity pick rate at Tier 4 | ~50% | — | 58.6% | close |
| Staff in winning builds | 0-8, spread | — | median 4, range 1-9 | pass |
| Queue share of early losses | ~25% | — | 51.2% | 2x too high |
| Combine rate | ~35% of picks | — | 69-91% | see below |
| Tier rush among winners | ~30% | — | 100% | see Finding 1b |
| Top single-fixture pick rate | under 40% | — | 61.8% | too high |

On the v0.1 numbers every policy dies on encounter 1, so nothing is measurable —
those zeroes are an absence of data, not a difficulty reading.

**Milestone 0's gate is met.** The greedy-versus-planner gap is 30.1pp, which
means the skill headroom the whole design is betting on is really there: knowing
the order of operations, reading term coverage, and timing tempo purchases is
worth about twice a greedy player's win rate. That was the one number that could
have killed the project, and it survived.

Three metrics that are out of band for structural reasons, not tuning reasons:

- **Combine rate (69-91%, wants ~35%).** This cannot be tuned at Phase 0 scale.
  With 18 fixtures and only five commons, a Tier-1 player who owns three of them
  is *offered* duplicates most nights. Combine rate here is a function of pool
  size, not of level payoff. Section 20 puts level payoff first, but it is not
  measurable until the pool is near milestone 3's 90-120 fixtures. Until then,
  sweeping the L2/L3 scalars moves win rate without moving combine rate.
- **Queue share of early losses (51%, wants ~25%).** Tills are doing twice the
  killing they should. `sweep till` moves this cleanly, but it interacts with
  the curve, so it wants doing after the curve settles.
- **Top pick rate (Personal Shopper, 61.8%, wants under 40%).** The flagship
  that multiplies Basket x2.5 for a throughput cap is the strongest card in the
  pool by a distance. This is exactly the degenerate-combination hunt section 20
  step 4 describes, and it found one on the first pass.

---

## Character spread, with a caveat

`node sim/cli.js chars --n=350`

| Character | Win rate | Median death |
|---|---|---|
| The Shop *(base game)* | 57.1% | 9 |
| Superstore | 53.7% | 13 |
| Corner Shop | 46.6% | 21 |
| Discounter | 30.9% | 21 |
| Car Dealership | 21.4% | 15 |
| Market Stall | 14.3% | 15 |
| Estate Agent | 0.3% | 5 |

Spread 56.9pp against a 10pp target — but **most of that is my fault, not the
design's**, and it is worth being precise about which parts.

Section 16 gives each character a rule and a topology. For three of them the
rule changes the economy so fundamentally that the section 14 starting values
no longer apply, and no replacements are given:

- **Estate Agent** has no stock, so Basket is a property price and Margin is a
  commission. I guessed £1,400 and 3.5%. Those two numbers *are* the character,
  and 0.3% says I guessed badly.
- **Car Dealership** has "vast wallets" and 1-3 customers a day. I guessed a
  320x Basket multiplier.
- **Market Stall** rebuilds nightly, which the sim models as free rearrangement
  — a benefit, not a cost — so 14.3% is a floor, not a reading.

Superstore, Corner Shop and Discounter run on the base game's numbers and need
no invention; those three land at 53.7 / 46.6 / 30.9, a 22.8pp spread. That is
the honest measurement of section 16 as written, and Discounter is the one with
a real problem: a five-fixture-type cap is severe when combining is already
forced by a small pool.

**The gap in the spec:** a character that breaks an economic rule needs its own
starting Footfall, Basket, Margin and Rent. Three of the six do, and three of
the six do not have them.

---

## Recommended revision to the section 20 tuning order

Section 20 says to find the numbers in a fixed sequence because later numbers
depend on earlier ones. That is right, and the sequence is wrong in two places.

| | Section 20 | Recommended | Why |
|---|---|---|---|
| 1 | Level payoff | **Boss severity** | An unpassable boss caps the win rate before build quality is involved, so every other measurement is noise until it is fixed (Finding 2). |
| 2 | Target growth | **Decouple cash from the target** | Tier and staff costs are denominated in a currency whose supply is set by the target curve (Finding 1b). |
| 3 | Tier cost curve | **Target growth** | Now measurable. |
| 4 | Rarity EV spread | **Till throughput** | Currently doing 2x its share of early kills, and it distorts what every fixture is worth. |
| 5 | Till throughput | **Tier cost curve** | Needs steps 2 and 3 settled first. |
| 6 | Staff Margin cost | **Rarity EV spread** | Needs a bigger fixture pool to mean anything. |
| 7 | Boss severity | **Staff Margin cost** | Already close: median 4, range 1-9. |
| — | — | **Level payoff, last** | Not measurable below roughly 60 fixtures; combine rate is dominated by pool size, not by the scalars. |

The move that matters most is boss severity going from last to first. The rest
is a consequence of that and of Finding 1b.

---

## What the sim says about the section 24 open questions

**"Does the walk stay watchable at 2,000 Footfall?"** Footfall does reach 2,000+
on Black Friday in mid-run builds, so yes, you will need the abstraction layer.
It is not an edge case.

**"Is three aisles the right count?"** Wrong question — see Finding 6. With no
congestion cost, any number above one is decoration. Add the cost first, then
ask again.

**"Should Returners exist at all?"** They are fine as a pool type. What does not
work is a boss made *entirely* of them (Finding 2). A Returner reversing a full
average sale is roughly twice as strong as a customer making one, because every
Returner refunds but only about half of customers convert. Reverse half a sale,
or make them reverse only if the shop sold anything yesterday.

**"Does Market Stall survive a 24-encounter run?"** The sim cannot answer this.
It models the nightly wipe as free rearrangement, which is a *benefit*. Whether
rebuilding by hand 24 times is interesting or exhausting is a playtest question.

---

## What this does not cover

- **Per-day variance.** Profit is exact in expectation; individual conversion
  rolls are not simulated. That matters for how a run feels and not for whether
  a curve is reachable.
- **Reroll and lock as strategy.** The planner rerolls on a simple threshold and
  never locks. Locking a pair to complete a level next turn is called out in
  section 11 as genuine skill expression, and it is unmeasured.
- **The Audit ladder.** All eight levels are implemented and run
  (`node sim/cli.js ladder`), but none is tuned, and Audit VIII's 8-15% target
  is meaningless until Audit I is settled.
- **Three of the six characters' starting economies**, which the spec does not
  specify and I guessed — see the caveat above.
- **Marketing as deck editing.** Campaigns are implemented and the planner buys
  them, but the interaction between pool editing and fixture conditions —
  section 3's "why the same fixture is broken in one run and dead in another" —
  has not been measured.

---

## Appendix — two design experiments, run after the fact

Both are gated off by default, so the baseline above is unchanged.
`--payout=flat`, `--congestion=0.35 --congmode=patience|conversion`.

### A. Decoupling cash from the target (`--payout=flat`)

Replaces "cash is profit above target" with a flat reward per encounter plus a
capped share of the overshoot. n=700 per cell:

| | planner | greedy | gap | tier rush |
|---|---|---|---|---|
| Baseline | 56.6% | 24.6% | 32.0pp | 100% |
| Flat payout | 59.7% | 24.0% | **35.7pp** | 100% |

**Works, partially.** The skill gap widens by 3.7pp, because a predictable income
turns spending into a plan rather than a consequence of how far you overshot.
Tier rush stays at 100%, which says the flat reward I picked (£260 growing at
1.17) is still too generous — the mechanism is right, the number needs its own
pass. Worth noting the direction: this is the only change tested that *increased*
the skill gap.

### B. Aisle congestion (`--congestion`)

The hypothesis in Finding 6 was that signage is a solved problem because no aisle
carries a crowding cost. Adding one should make routing a real decision and widen
the gap. It does not:

| | planner | greedy | gap |
|---|---|---|---|
| No congestion | 56.6% | 24.6% | 32.0pp |
| Charged to Patience (0.35) | 55.7% | 24.4% | 31.3pp |
| Charged to Conversion (0.25) | 45.3% | 17.0% | 28.3pp |
| Charged to Conversion (0.45) | 34.9% | 11.0% | 23.9pp |

**The hypothesis was wrong, in two different ways.**

Charged against Patience it does nothing measurable, because Patience only
matters once a queue exists — it is a second-order penalty on a first-order
problem, and a shop with enough tills never feels it.

Charged against Conversion it always bites, and it makes things *worse*: the gap
narrows monotonically as the penalty grows. It is a flat difficulty tax, not a
decision. The planner still funnels; it just pays.

The reason is the thing the experiment actually exposed: **there is nothing worth
having in the other aisles.** A 3x4 board is twelve slots, and a mid-run build
holds seven or eight fixtures, so the alternative routes are half-empty. Routing
is not a solved problem because it is uncosted; it is solved because there is
only ever one good answer.

So the fix is not a penalty. It is to make the board full and the aisles
different — fewer slots, more starting fixtures, and aisle identity of the kind
the Mezzanine already gestures at. That is a content change, not a rules change,
and it cannot be tested until the fixture pool is nearer milestone 3's 90-120.
