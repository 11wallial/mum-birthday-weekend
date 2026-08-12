# FOOTFALL — Phase 0

Seven parts, newest first. **Part one** is what the headless simulator found in
the v0.1 ruleset; each later part is what the one before it got wrong.

**Read parts seven and six first.** Six finds a units bug that had been
distorting every win rate in this document; seven verifies the queue and finds
that two of the hard-mode dials were making the game easier. The numbers in
parts two to four are the record of what was measured at the time rather than
statements about the game as it now stands.

Section 19 is explicit that "everything above is a hypothesis and most of it is
wrong". That turned out to be the right posture. The engine survived intact;
almost every number did not, and three rules quietly contradicted themselves.

Run it yourself:

```
node sim/verify.js      # resolver correctness
node sim/cli.js panel   # the day-one projection panel
node sim/cli.js check   # the section 19 health check
node sim/cli.js trace   # one run, encounter by encounter
```

---

## The short version

**Diagnosis.** On the numbers as written, day one earns about £200 against a
£450 target, so all three policies die on encounter 1 and nothing is
measurable. Underneath that, the encounter-24 target is about **870x** higher
than the best build can reach — because Conversion and Margin cap at 100% and
saturate by encounter 8, leaving two of the four terms to carry the whole run.
And one boss, Refund Day, was an automatic loss appearing in two runs out of
three, holding the win rate near 33% before build quality entered the picture.

**Response.** Ratchet fixtures to carry unbounded growth, caps made explicit so
Conversion and Margin become rates you defend rather than axes you grow, cash
decoupled from the target, player-chosen bosses, rent pegged to the curve, a
fuller board, flagship drawbacks that stop melting, Returners cut, and marketing
turned into a committed identity.

**Result.** All five section 19 measures hold together — random 0.0%, greedy
20.6%, planner 62.9%, queue 29.5% of early deaths — and the greedy-versus-planner
gap, the single number that could have killed the project, is **42.3pp**. A
winning run's median last day is £731,335 against a £14,083 target, and 42% of
wins finish on a seven-figure day.

Getting there took finding a units bug that had been distorting every win rate
in this document. See part six.

The engine is sound. Four multiplicative terms and one subtractor is a good
machine, order of operations does carry real skill, and the pick-versus-cash
split does produce two distinct axes.

---

# Part seven — the queue, the ladder, and the game around them

Part four committed to **pool -> queue verification -> tune**, and part six added
two items in front of it. All of them are now done.

## The queue, verified at last

`verify.js` has proved the resolver's fixture arithmetic against individually
walked customers since part one — and it sets tills to 40 specifically to
*remove* the queue from the comparison. The queue does 30% of the early killing,
triage makes it a mechanic the player reaches into, and the whole late game is
an equilibrium between Footfall and throughput. It had been the committed next
item twice.

`verify-queue.js` runs the fluid model against a **discrete** queue: every
customer an individual with their own arrival tick, their own place in the line,
their own patience. The discrete side matches how the browser build spawns —
uniform arrival times, each arrival's type drawn from the pool — so the count of
each type is multinomial rather than fixed, which is the thing a fluid model is
least likely to get right.

Ten scenarios, from well under capacity to twelve times overload. **Totals agree
exactly on every one**: served and walkouts both 0.00%.

It found a real bug. A cohort expired when its wait *equalled* its patience,
where the individual walk expires on `waited > patience`. One tick early. Only
the impatient types could tell — one tick out of forty is invisible, one tick out
of two is half the type — and it was costing the short-patience types about a
third of the service they were owed. Since the four terms differ hugely by type,
a mix error is a profit error even when the headcount matches.

The verifier had a bug of its own first, and it is worth recording because it
looked exactly like a catastrophic failure in `runQueue` — 86% disagreement. My
discrete queue expired and served in two separate loops, so the till stalled
behind a customer who had already walked out. Types interleave and have different
patience, so the moment an expired one surfaced mid-tick the till stopped for the
rest of the tick.

Per-type agreement is judged as a share of the **whole day**, not as a share of
the type's own count. Nine served where eleven were owed is a 0.2pp shift in who
came through the till; reading it as an 18% error on that type says the opposite
of what is true.

## Two hard-mode dials that made the game easier

The Audit ladder had never been measured against the current pool. Each modifier,
alone, against a 59.8% baseline:

| modifier | alone |
|---|---|
| an aisle shut every quarter | **−29.5pp** |
| targets ×1.55 | −25.3pp |
| rent ×3.0 | −24.3pp |
| targets ×1.20 | −10.0pp |
| rent ×1.5 | −3.7pp |
| an inspection every 2 days | −2.8pp |
| the flagship two-day condition | +0.7pp |
| **rerolls ×2** | **+2.7pp** |
| **supplier tiers at full price** | **+3.7pp** |

Two of them made the game *easier*. A dial that helps by making a purchase more
expensive is not a hard mode — it is a purchase the policy is wrong about.

It was. The supplier tier valuation read:

```js
gain = cost * 0.5 * (left / 18)
```

Proportional to the **price**. The dearer the upgrade, the more the planner
wanted it, so it bought tier at every opportunity it could afford — which is why
tier rush sat at 74% of winners against a target of 30% and had been out of band
for the entire project.

Replaced with a measurement: sample what the next tier actually offers, price the
best of a hand against the board you have, compare with the same hand at the tier
you are on. That overshot to 2.7%, for a familiar reason — the first version
priced the sampled cards on *today's* profit, and what a higher tier sells you is
rarity, whose whole point is cards that pay later. Judged over a twelve-day
horizon instead:

```
tier rush among winners     74%  ->  16.3%   (wants ~30)
high-rarity picks at T4+  58.4%  ->  49.6%   (wants ~50)
planner                   61.8%  ->  65.3%
gap                       44.2pp ->  47.7pp
```

That is the **third** time this project has found the same mistake in a different
place: valuing a thing whose payoff is later by what it does today. It cost the
planner the compounders, then the tier upgrades, and it is exactly what
`profitAhead` exists to prevent.

## The ladder was flat, then a cliff

Old: 61.6, 56.8, 43.6, 42.0, 39.6, 39.8, 38.8, **7.6**. Four indistinguishable
rungs and then the floor falls away — because three modifiers did nothing and one
did everything.

Rebuilt so the descent rides on rent and targets, which are continuous and
tunable, with the rule modifiers layered on for texture rather than being asked
to carry the difficulty.

The last rung needed two more changes, and both are the same lesson. The aisle
closure was worth −29.5pp alone and far more stacked, because closing one of
three aisles is a *multiplicative* loss while the dials it stacks on are additive.
Stepping VIII's numbers back barely moved it: 4.0% to 4.3%. What worked was
changing the rule rather than the number — the closure now lands on **one day of
the quarter rather than the whole quarter**, and not before quarter three, since
closing a third of the board in act 1 is a coin flip before the player has made
a decision.

```
Audit    I     II    III   IV    V     VI    VII   VIII
old    61.6  56.8  43.6  42.0  39.6  39.8  38.8   7.6
new    66.3  57.6  48.9  40.3  30.0  25.4  20.6   8.0
```

## The game around it

None of the above is a game on its own. The browser build was one run repeated:
it always played Audit I and forgot everything when the tab closed.

- **The ladder is in the game.** Audit n+1 unlocks when a character clears n, so
  progress is per shop — the Discounter's run is a different game from the Estate
  Agent's and clearing one says nothing about the other. Each rung reads out what
  it changes, generated from the modifiers so the description cannot drift from
  what the run does.
- **A real end-of-run summary.** The target is only the fail condition; the number
  a run is remembered by is its best day, and a good run overshoots its last
  target fifty times over. So that number gets the size.
- **"How it works"** — the formula is the whole game and the build had never once
  explained it, including the things a player cannot infer: that Conversion and
  Margin cap, what a compounder is worth against a ratchet, and that Footfall past
  what your tills can serve is a crowd you turn away rather than growth.
- **Seeds, records, persistence.**

---

# Part six — the ending, and the three things that were actually stopping it

The brief was: go big on content, and make the seven-figure ending reachable.
The content came first and it was the wrong instinct — twenty-eight new cards
moved the median build's total climb from **x43 to x66** against a curve that
wants **x7,000**. Writing more cards was not going to close a gap of that size,
so I stopped writing them and measured what was binding instead.

Three things were, in ascending order of how much they mattered and descending
order of how obvious they seemed. The third had been quietly deciding the win
rate for the whole project.

## Nothing in the pool grew faster than linearly

There were two accumulating ops and I had been treating them as "the scaling
cards" as a single category. They are not the same shape:

| op | what accumulates | shape over 24 days |
|---|---|---|
| `ratchet` | an addend | **linear** — 24 days of +5 is +120 |
| `ratchet_mult` | a multiplier, by addition | **linear** — 24 days of +0.055 is x2.3 |

Both linear. A target curve that multiplies by 1.47 per encounter is
exponential, and no quantity of linear cards sums to an exponential. The
comment in `day.js` calling `ratchet_mult` "the only genuinely exponential
thing in the pool" was simply false, and had been since the day it was written.

Compounding needs a growth rate proportional to what you already have. So
there is now a third op:

```
compound      the multiplier is MULTIPLIED each day, not added to
```

Twelve cards use it, across every rarity and both unbounded terms. It brings a
property no other card in the pool has: **a compounder is worth what is left of
the run.** At encounter 2 a +9%/day card is x8.9 by the end; at encounter 20 the
same card is x1.5 and the flat one was better. Nothing else in the pool changes
value with the clock, and that single property is the clearest expression of the
brief — long-term payoff bought with short-term strain — that any mechanic here
has managed.

Their upkeep is billed on a separate line that **ramps** where a linear
ratchet's decays — the same curve, reversed. A linear ratchet is worth most,
relative to its own ceiling, on the day you install it, so its charge starts
full and falls away. A compounder is worth almost nothing for its first week and
then carries the run. Billed flat from birth it punished the player twice for
one card, in the act where two thirds of runs already die.

## The planner's horizon was not the problem, and I checked before assuming

The obvious suspect for "the median never buys the compounders" is that the
planner cannot see far enough — its lookahead was 10 days, and a compounder's
whole value sits past it. That is a good story. It is also wrong:

| horizon / future weight | survived | p25 | p50 | p75 | p90 |
|---|---|---|---|---|---|
| 10 / 0.30 | 145/200 | x22 | **x42** | x163 | x580 |
| 20 / 0.30 | 144/200 | x16 | **x42** | x152 | x498 |
| 24 / 0.30 | 146/200 | x17 | **x45** | x151 | x456 |
| 24 / 0.60 | 149/200 | x17 | **x43** | x124 | x410 |
| 24 / 1.00 | 153/200 | x21 | **x42** | x127 | x391 |

Flat. Letting the planner see the entire remaining run moved the median by
nothing. Worth recording as a negative result, because it is exactly the change
I would have shipped on intuition.

## The board was the constraint

The measurement that found it, per run, across 184 full runs:

```
mean picks made:                24.0
mean fixtures standing at end:   9.2
```

A run makes twenty-four picks into nine slots. **The board is finished by
encounter nine and the next fifteen offers are decoration.** Compounders drafted
in act 3 were going to the bench, where they compound nothing — one run had
taken seven of them and was standing zero.

Naming an occupied slot now clears it out. That is not a convenience feature; it
is the decision the entire back half of the run was missing. Declining the pick
also becomes a real option, because taking one now costs you whatever it lands
on.

```
median total climb    x42  ->  x2,173
```

Fifty times, from one rule. Every card I wrote before finding this was being
graded on a board that could not accept it.

## And then the actual answer: a units bug that had been eating the run

Neither of those was the thing. With the board unlocked I went looking for a
target curve and found that the planner's win rate had collapsed to 28%. A
worktree at the previous commit put the blame squarely on the 68-card pool
rather than on the compounding work — and then a traced run showed what was
really happening:

```
 enc  target      profit     footfall   conv   walkout  boss
  12    £741    £119,750         5703  22.1%    72.8%   bank_holiday
  13    £875     £-1,075            0   0.0%     0.0%
```

A run sitting **160x over its target** dies the next morning with zero
Footfall.

Footfall is a **product**: a base of about 120 multiplied up through every
ratchet and compounder on the board. The walkout carry was an absolute count of
people, computed from post-multiplier quantities and then added back to the
pre-multiplier base. At a 73% walkout rate that is a penalty of 1,700 against a
pool of 120. The run does not lose 30% of tomorrow — it ceases to exist, and
nothing in the ruleset can bring it back.

I wrote that bug earlier in this same session, fixing a different one. The
previous version capped the penalty against the *starting* Footfall, which made
the brake weightless at scale; capping it against *today's* Footfall made it
lethal. Both are the same mistake — mixing a quantity from one side of the
multiplier chain with a quantity from the other — and the same mistake was in
two more places once I knew to look:

- **Warehouse Club** fed post-multiplier walkouts back into the pre-multiplier
  base, where they compounded.
- **Anchor Tenant** summed the ratchet of every Footfall scaler into Basket.
  For `ratchet` that is a number of people and the card is fine. For `compound`
  it is a dimensionless multiplier excess, and adding it to a basket produced a
  basket of four quadrillion pounds at a 0% conversion rate.

Everything that carries into tomorrow is now a **share of the day**.

## Bounding a product takes more than a share

A share is a single constant factor, and a single constant factor cannot brake a
growing product. 0.22 once, against compounders multiplying 1.4x every day, is
not a brake. Footfall ran to 1.1e22.

So the carry became a state that persists and multiplies, with the shop's
reputation drifting back up on days the queue behaves. That still was not enough,
because the penalty was quoted against the walkout **share**, which saturates at
1 — so the penalty saturated too, and a saturated penalty is a constant factor
again. Footfall found 3.5e12.

It is now quoted against **overload**, which does not saturate: serve one in
twenty-five and it is 25.

```
tomorrow  =  allowedOverload x (the fraction you actually served)
```

At equilibrium that equals 1 / (your daily growth), so Footfall settles a little
above what the tills can take, and the only thing that moves the equilibrium is
buying throughput. That is the shape the Footfall build was always supposed to
have, and it took three attempts to write it.

Plus a hard ceiling at twelve times what the tills could physically serve,
because the brake's per-day authority is finite and a stack of compounders under
two rate multipliers is not — Manager's Office and Stocktake each multiply a
compounder's growth *factor*, and they multiply each other. The ceiling costs
the player nothing they wanted: Footfall past what you can serve is walkouts, and
a walkout is a lost sale and a quieter tomorrow.

| Footfall, 6,844 trading days | p50 | p90 | p99 | max |
|---|---|---|---|---|
| before | 492 | 23,954 | 2.9e10 | 1.6e27 |
| after | 492 | 23,940 | 84,107 | 107,779 |

## All five bands, at once

At 1,200 runs per policy, on base 88 x 1.24:

| | | |
|---|---|---|
| random | 0.0% | band 0–2 |
| greedy | 20.6% | band 15–25 |
| planner | 62.9% | band 55–70 |
| gap | **42.3pp** | milestone wants > 30 |
| queue | 29.5% of early deaths | wants ~25 |

The first time in the project that all of them have held together. Three of them
moved into band on the units fix alone, before any tuning at all — which is the
measure of how much that bug had been distorting. Every conclusion drawn from a
win rate earlier in this document was drawn through it.

## The ending

The target ends at **£14,083** a day. A winning run does not:

| winning runs | p10 | p50 | p90 | p99 | max |
|---|---|---|---|---|---|
| last day profit | £67,807 | **£731,335** | £8,576,342 | £35,978,115 | £153,315,201 |
| climb, day 1 to 24 | x184 | x1,880 | x18,046 | x101,442 | x347,211 |

**42% of winning runs finish on a day clearing seven figures** — about one run in
four overall. The median win overshoots its final target by 52x.

That is the resolution of the ending problem, and it is not the one I was
chasing. Asking the *target* to reach seven figures meant multiplying by 1.47 for
twenty-four straight encounters, which no pool of 89 cards drawn three at a time
can carry from a standing start. Asking a good run to overshoot a reachable
target by fifty times produces the same screenshot with a game underneath it.

One more thing had to be fixed before that was even measurable. `payout.flatGrowth`
was still 1.47 while the curve had been refitted to 1.24, so the faucet paid
£150 x 1.47^23 = £1.06m for the final encounter alone, and **100% of winning runs
finished holding seven figures whether they had played well or not**. The ending
was being handed out by the payout formula. Matched to the curve, banked cash is
dominated by overshoot, which is skill.

## Lookahead is a skill after all, and the compounders are why

Part four **withdrew** the claim that lookahead carries skill. It had come from
the least stable cell in the ablation, and the honest reading at the time was
that lookahead was a complement to tempo rather than an axis of its own.

Re-run on the current pool, across three disjoint seed blocks:

```
capability      alone                      removed                    stable
lookahead      +4.5pp [3.5 to 5.2]        -12.1pp [-15.7 to -9.3]    yes
tempo         +15.8pp [13.8 to 17.0]      -19.7pp [-22.0 to -16.2]   yes
sign           +5.2pp [4.7 to 5.8]         -6.2pp [-8.0 to -5.0]     yes
reroll         +2.9pp [2.2 to 3.5]         -8.0pp [-12.2 to -5.8]    yes
reorder        +1.9pp [0.8 to 3.0]         -1.9pp [-2.7 to -0.2]     yes
balance        -0.8pp [-2.0 to 0.0]        -0.2pp [-0.7 to 0.3]      yes
stress         -0.2pp [-2.3 to 1.2]        +0.1pp [-0.5 to 0.5]      NO
```

Sign-stable, and removing it is the second largest loss on the board. The
withdrawal is itself withdrawn.

The cause is the compounding class, and it is worth being precise about why,
because it is the strongest argument in this document that the ops were the
right thing to add. Every other card in the pool is worth the same whenever you
buy it, so a player who can see ten encounters ahead learns nothing a player who
can see one does not already know. A compounder is worth **what is left of the
run**. That is the only quantity in the game that lookahead is *for*, and until
there was a card whose value depended on it, the ablation was right to say the
axis did not exist.

§2's claim about lookahead was not wrong. It was unexpressed, in exactly the way
order-of-operations was unexpressed at 23 fixtures — and it was fixed the same
way, by writing content that has something for the skill to grip.

`stress` remains unstable and nothing should be concluded from it.

## What that says about the order of work

Part four committed to **pool -> queue verification -> tune**. The pool work was
correct and it did move things, but this part says the ordering had two missing
items in front of it:

1. *Check that the shop can hold what you are writing.* Twenty-eight cards were
   authored, balanced and verified against a board with room for nine of them.
2. *Check your units.* Four separate places mixed pre- and post-multiplier
   quantities, and between them they had been silently deciding the win rate,
   the ending, and which builds were viable.

Neither is a tuning problem and neither would have been found by tuning. The
queue is still unverified, and it is still next.

---

# Part five — micro: does the trading day need decisions?

The trading day contained none. You set the shop up at night, the walk resolved,
you watched. That was tolerable while the resolver was deterministic. It stopped
being tolerable once variance went in, because the failure mode became *you set
up correctly, the day rolled against you, and you watched it happen* — which is
the least satisfying death in the genre. Slay the Spire's appeal is the
opposite: you rarely die to a bad draw, you die to misplaying one.

So two candidate mechanics were built and measured before being committed to.

**Till triage.** A few interventions per trading day pull customers out of the
queue before their patience runs out. The budget is a fraction of Footfall with
a floor, so one tap is a burst rather than one person and the lever stays
relevant as the shop grows. Which customers you pull is the entire decision.

**The SALE sign.** More people through the door and more of them buy, at a worse
Margin — and the extra Footfall lands on the same tills, which is what makes it
a decision rather than a margin threshold.

`node sim/cli.js micro --n=300 --blocks=3`, added to the full planner:

| Variant | Win rate | Per block | Delta |
|---|---|---|---|
| none | 33.2% | 34.0 / 31.3 / 34.3 | — |
| triage, naive | 38.1% | 42.0 / 36.0 / 36.3 | **+4.9pp** |
| **triage, smart** | **42.8%** | 45.3 / 40.3 / 42.7 | **+9.6pp** |
| sale only | 36.7% | 37.0 / 33.0 / 40.0 | +3.4pp |
| triage smart + sale | 43.1% | 44.3 / 42.7 / 42.3 | +9.9pp |

Every row is sign-stable across all three blocks.

## Triage is a third pillar. Build it.

**9.6pp** puts it alongside the two things that already carry this game — tempo
at 11.2pp and signage at 11.2pp. It is not decoration.

Better than the headline: **it has a skill gradient**. Naive triage — serve
whoever is nearest — is worth 4.9pp. Smart triage — serve by what that customer
is actually worth — is worth another 4.7pp on top. So roughly half the value
comes from engaging with the mechanic at all, and half from engaging with it
well. That is exactly the shape micro should have: a novice is rewarded for
touching it, and an expert is rewarded again for reading it properly.

It also acts directly on the subsystem that was already deciding runs. The queue
does 33-42% of the early killing and the player previously could not touch it.

## The SALE sign is marginal, and redundant with triage. Do not build it.

3.4pp alone, and the widest spread of any row. Worse, adding it on top of triage
buys **+0.3pp**.

The reason is worth keeping: both mechanics push on the same bottleneck. The
sale raises Footfall, which worsens the queue; triage relieves the queue. Once
you can triage, the sale's cost is partly absorbed and so is its benefit. Two
levers on one bottleneck is one lever.

If a second micro mechanic is wanted, it has to act somewhere else — on Basket
or Margin directly, not on throughput.

One caveat that cuts in the mechanic's favour: the sale was modelled as a
**plan** made at night, not a mid-day reaction. A player reading the day as it
runs would do better than 3.4pp. That is the lower bound, not the ceiling.

## What this changes

The vertical slice now has three skill pillars rather than two, and one of them
lives in the trading day, which is where all the art and audio budget goes. The
frenzy parameter, the beep ladder and the cutaway now have something to be
feedback *for* rather than decoration over.

It also answers the rent question from part four, at least partly. Rent is 42%
of early deaths and is a fixed number against income that rolls. Triage is the
counterplay: a bad roll is now something you can partly rescue rather than
something you watch. Whether that is enough, or whether rent should also stop
being a deterministic nut, is still open.

---

# Part four — second review, and the pool

The reviewer pulled the branch again, reproduced the variance numbers, and made
three criticisms. Two were about my instruments rather than the design, and both
were right. The third was a better resolution of the commitment brief than mine.

## The ablation had no error bars, and one conclusion did not survive them

They re-ran `ablate` on two disjoint seed blocks and found `lookahead-removed`
ranging from −2.5pp to −12.5pp across four measurements — the full width of the
claim I drew from it. "Lookahead is a complement, not a skill" came from the
least stable cell in the table.

`ablate` now runs three disjoint seed blocks, prints the range, and marks each
row stable or not. Only rows whose sign holds on every block are safe to
conclude from. On their measurements that is **tempo, sign-alone and reorder** —
which is still enough to make the section 2 point, so the important argument
survives.

Two corrections to part three:

- **The lookahead conclusion is withdrawn.** It is unresolved, not settled.
  *(Part six settles it: on the current pool lookahead is +4.5pp alone and
  -12.1pp removed, sign-stable across three seed blocks. It was unexpressed
  rather than absent — nothing in the pool was worth a different amount
  depending on how much of the run was left, until the compounders were.)*
- **Reroll was omitted from the writeup** and is a bigger removal effect than
  lookahead on every draw they took. That was a selection error on my part.

## The verifier could not detect the bias it was named for — so I removed the bias

Their sharper point: the pass rule granted 3σ **plus 0.75% of profit** to every
case unconditionally, so no systematic bias below 0.75% was detectable anywhere
in the walk maths at any sample size. They demonstrated it — the levelled-stack
case goes from 2.7σ at 200k to 12.0σ at 1.6M while relative error grows 0.48% →
0.75%, and the test says PASS at both. σ growing with n is bias, not noise.

They suggested gating the allowance on whether the case actually clamps. Done —
`verify.js` counts clamped walkers and only spends the allowance where clamping
really happens, and prints σ at two sample sizes so the signature is visible.

But their diagnosis pointed at something better than a smarter test. They noted
the planner evaluates candidate boards with the same aggregate resolver, so it
**systematically overvalues cap-pressing builds**. That is a bias in the game's
decision-making, not just in the harness, and gating a test does not fix it.

So the bias is gone at source. The resolver now carries the **variance** of each
capped term alongside its mean and integrates the clamp — `E[min(X, cap)]` under
a normal approximation — instead of computing `min(E[X], cap)`. X is a sum of
independent per-slot Bernoulli contributions, so the approximation is good well
before the handful of fixtures an aisle holds.

| levelled stack | 200k | 800k | signature |
|---|---|---|---|
| Before (their measurement) | 0.48% | 0.75% at 1.6M | error **grows** — bias |
| After | 0.49% | **0.30%** | error **shrinks** — noise |

The clamp allowance is still in the criterion for the residual, but it is now
gated and the thing it was covering for has mostly gone.

## The pool was the blocker, and the proof is that reorder moved

Three findings — combine rate, order of operations, and the commitment
mechanics — all said "cannot be tested at 23 cards". The reviewer called that
convergent enough to be the answer: the next work item is the fixture pool, not
more simulation, and the ablation had already written its spec.

The pool is now **40 fixtures**, up from 23, authored against that spec:

- **A position and adjacency vocabulary**: `slot_is_first`, `slot_is_last`,
  `slot_index_min`, `prev_slot_class`, `prev_slot_term`, `aisle_holds_no_class`.
- **Adjacency content**: amplifiers on Conversion and Margin as well as Basket,
  and fixtures that read their neighbour — Impulse Shelf multiplies Basket only
  if the previous slot holds an additive; Upsell Counter only if the previous
  slot is a Basket fixture; Window Dressing and Queue Bait pay only at the front
  and back of an aisle.
- **Ratchets 5 → 10**, weighted toward common and uncommon so a build can
  realistically be offered four.
- **Purity keystones**: `aisle_all_share_tag` and `shop_holds_at_least_tag`,
  paying superlinearly for a committed identity.

Then the measurement that matters, three disjoint seed blocks, n=300:

| Order of operations | Alone | Removed |
|---|---|---|
| At 23 fixtures | 0.0pp | −0.2pp |
| **At 40 fixtures** | **+3.4pp** [+4.0 / +2.7 / +3.7] | **−4.6pp** [−2.7 / −5.7 / −5.3] |

Sign-stable on every block, both directions. **Section 2's claim that order of
operations is the primary skill expression is now supported by measurement.** It
was never wrong as a principle — the catalogue simply did not express it, and
an optimiser reordering an empty board correctly found nothing.

That is also the cleanest possible confirmation of the reviewer's read: the
blocker was content, and the simulator had already told us exactly what content
to write.

## Their resolution of the commitment brief is better than mine

I argued the brief was self-contradictory on one axis. They pointed out it is
two axes being conflated:

- **Tempo budget** — spend everything on scaling and you die before it pays.
  This *should* be concave, and a middle optimum is correct.
- **Build identity** — a shop that does a bit of everything should not win.
  This should be bimodal, and needs keystones paying superlinearly for purity.

Balatro runs both at once for exactly this reason: you commit hard to one hand
type because scaling jokers reward purity, while money and reroll spend stays a
balanced-is-better problem. Separate the axes and both halves are satisfiable.

The keystones are authored. The two-axis measurement is not yet built, and the
commitment curves in part three should be read as measuring the tempo axis only.

## What I have not done, deliberately

- **Not re-run the full ablation table on the new pool.** Only the reorder rows.
  Every other number in parts two and three was measured on 23 fixtures and is
  now stale. The table wants re-running before anything is concluded from it.
- **Not re-tuned the curve.** The reviewer backed that call and warned about its
  one risk: that there is always one more structural change and the bands
  quietly become decoration. So the order is now committed, in writing:
  **pool, then queue verification, then tune — and no tuning before both.**
- **Not addressed rent.** They are right that I buried it. 42% of early deaths
  under variance trace to a single scalar, and because rent is pegged to the
  target curve it is a deterministic nut against stochastic revenue: you did not
  misplay, you rolled badly against a fixed number. Planner median death also
  moved 15 → 9, so the midgame got substantially deadlier rather than
  marginally. The open question is whether early difficulty should be a fixed
  cost at all, or something a player can act against.
- **The queue is still unverified**, and is now second in the committed order.

---

# Part three — external review, and what it found

An indie dev cloned the branch and ran it rather than reading part two on trust.
Their verdict was that Phase 0 validated the engine and not a single number, and
that in several places it could not yet. Every checkable claim they made was
correct. This part is what happened when I acted on it.

## The headline: the bands do not survive variance

Their first objection was that no variance was modelled, so "planner 63.5%" was
a win rate in a game where no day ever rolls badly. Conversion is now sampled
binomially, arrivals are drawn rather than quota'd, and basket carries wallet
noise — applied **only when a day is really played**, never when a policy
evaluates a candidate board. That split is deliberate and it is also the right
game design: the player plans against the projection panel's expectation, and
the day rolls around it.

`node sim/cli.js check --n=900 --variance=0|1`

| | Random | Greedy | Planner | Gap |
|---|---|---|---|---|
| Deterministic | 0.0% | 22.9% | 53.2% | 30.3pp |
| **With variance** | **0.0%** | **21.2%** | **48.8%** | **27.6pp** |

Variance costs the planner 4.4pp and the gap 2.7pp, and **the planner band is
now missed in both columns**. Part two's 63.5% did not survive the other fixes
in this part either — chiefly the starting-kit correction below.

Early deaths also change character: rent goes from 27% to **42%** of early
losses once days can roll badly, overtaking the queue. A deterministic resolver
was hiding the game's actual killer.

**I have deliberately not re-tuned the curve to put the bands back.** Every
structural change in this project has moved these numbers, three of the Phase 1
gate items are still open, and tuning against an unverified queue and a 23-card
pool would bake in noise and call it balance. The numbers above are what the
build currently does.

## The skill gap was partly a strawman, and the ruleset has a false claim in it

Their sharpest point: the gap was bot versus bot, both bots written by the same
author, and greedy had no model of tomorrow *by construction* — which is exactly
the axis ratchets were added to reward. Close to circular.

So greedy and planner are now two settings of one parameterised policy, and
`ablate` switches each capability on alone and off from the full planner.
Greedy also stopped throwing picks away on dead fourth copies, which is why its
baseline rose from 23.7% to 32.3%: part of the old gap was a strawman, exactly
as alleged.

`node sim/cli.js ablate --n=400` — greedy 32.3%, planner 65.8%, gap 33.5pp:

| Capability | Alone | Removed |
|---|---|---|
| **tempo** (purchase policy) | **+11.2pp** | **-21.7pp** |
| **sign** (routing) | **+11.2pp** | **-11.7pp** |
| lookahead | +1.3pp | **-12.5pp** |
| reroll | -7.3pp | -6.5pp |
| stress (robustness) | -1.5pp | **+0.8pp** |
| balance (term coverage) | -0.3pp | -0.7pp |
| **reorder (order of operations)** | **0.0pp** | **-0.2pp** |

Three things fall out, and the third is the most important finding in the whole
project.

**Lookahead is a complement, not a skill.** Worth +1.3pp on its own, but -12.5pp
when removed from a full planner. It only pays once you can afford to act on it.
The dev was half right: it is not carrying the gap alone, but it is not
worthless either.

**Tempo and routing are the game.** The purchase policy and the signage are
worth 11pp each alone and are the two most expensive things to remove. Whatever
else FOOTFALL is about, the skill currently lives in *what you buy* and *where
you send people*.

**"Order of operations is the primary skill expression" is false.** Section 2
puts that claim at the centre of the design. Measured: **0.0pp alone, -0.2pp
removed.** An optimiser that reorders the entire board finds nothing. The reason
is content, not principle — End Cap is the only adjacency effect in the pool,
and on a three-slot aisle holding one amplifier there is almost never a
profitable swap. The principle is sound and the pool does not express it. If
that claim is to be true, the game needs many more position-conditional and
same-term amplifier fixtures, and it needs them before anyone tunes anything
else against it.

**Stress-testing was actively harmful** and has been left in the planner config
only so the ablation keeps a control; removing it *improves* the planner by
0.8pp.

## The starting kit had deleted a finding rather than solved it

They spotted that `startingFixtures` was 5 against a pool of 6 commons, so every
run opened holding 5 of 6 and Security Tag — which neutralises shoplifters —
was present in **83%** of runs. Part two's day-one panel read `Shrink £0` for
exactly that reason. Finding 5 was not fixed, it was accidentally erased.

Back to 3. Shrink is £210 on day one again, and the rule is now written into
`data/economy.json`: the starting kit must stay well under the size of the
common pool.

Their combine-rate observation was right too. It fell from 88.5% to 63.6% just
from this change, so pool size is the dominant term but it is not the only
lever, and part two overstated the case by calling it unfixable.

## Content has moved out of code

`day.js` branched on five fixture ids and `run.js` on a sixth; `verify.js`
hand-mirrored three of them and had **silently dropped Greeter's clause**. That
is exactly the drift the dev predicted, already happening at 23 fixtures.

Levelled clauses are now data — `{ minLevel, term, op, value, conditions }` in
`fixtures.json` — and there are no fixture ids left in `day.js` or `run.js`.
The verifier reads the same clause data.

The split that matters: `verify.js` still implements the *engine* independently,
because that is what makes it a check. Duplicating the *content* was never
independence, it was just drift.

## The verifier had a bug of its own

It took the worst sigma and the worst relative error across *different* cases
and failed if either maximum breached, so it could fail on noise at low sample
counts — it failed at n=120,000 and passed at n=300,000 on identical code. Now
judged per case, against a threshold that adds sampling noise and the known
clamp bias together, and it is stable from n=100k to n=400k.

A verifier that fails randomly is worse than no verifier.

## Commitment: mechanics built, design goal not yet met

The brief was: greedy purchases should still pay off long-term, long-term
purchases should strain you now, over-committing either way should kill you, and
a flat blend should be merely mediocre.

Built: ratchet upkeep charged as a **fraction of today's target** so the strain
stays real at every scale, decaying as a fixture matures; economies of scale so
per-fixture upkeep falls as you hold more; a commitment threshold that
strengthens every ratchet past four held; and interest that compounds at 8%
capped at 1.2x target so tempo has a long tail worth over-committing to.

Measured, and it does not do what the brief asks:

| | Result |
|---|---|
| Over-commitment punished | **Yes** — extremes 48-50% against 55% for a blend |
| Blend merely mediocre | **No** — the blend is the *optimum* |
| Timing beats any fixed mix | **No** — best pivot is 2.6pp *worse* than the best static mix |

There is a structural reason for the middle one and it is worth stating plainly:
**"over-committing either way kills you" makes the payoff concave in the mix,
and a concave payoff has its optimum in the middle by definition.** Those two
halves of the brief cannot both hold on a single axis by tuning. Making the
middle bad needs a mechanism that *pays for commitment* — thresholds, economies
of scale, or mutually exclusive keystones. Two of those are now built.

Why they cannot yet be tested: there are five ratchet fixtures in a 23-card
pool, mostly above common, so at low Supplier Tier the offer usually contains
none. Forcing a build to hold four is not possible when four are never offered.
Win rate against ratchets held is flat within 0.9pp, and that flatness measures
the content, not the mechanism. This needs the larger pool before it means
anything — the same gate as combine rate and rarity spread.

I went through three wrong measurement axes before this was clear: a scoring
bias that did not control holdings, and then a quota that was a ceiling rather
than a target and so was a no-op above the natural level. Both are fixed;
`node sim/cli.js quota` is the honest test once the pool can support it.

## Still open from their gate list

- **The queue is still unverified** and does 33-42% of the early killing.
  `verify.js` excludes it by giving the shop infinite throughput. This is the
  single most valuable remaining piece of work.
- **Characters are untuned and part two's table was stale.** Not re-run here.
- **The escalation fantasy is still gone** — encounter 24 is £5,401. Ratchets
  went in and the curve stayed flat, so the seven-figure ending never came back.
  That is a decision nobody has actually taken.
- **The repo.** FOOTFALL is living in `mum-birthday-weekend` next to an
  unrelated `index.html`. That is the user's call to make, not mine, but they
  are right that it wants its own repo.

---

# Part two — the redesign

The findings below were the diagnosis. This is what was built in response, and
what it measured. Everything here is in `/data` and `/sim` and reproducible with
`node sim/cli.js check`.

## The result

| Metric | Target | v0.1 | After Part One tuning | **After the redesign** |
|---|---|---|---|---|
| Random win rate | under 2% | 0.0%* | 0.0% | **0.0%** |
| Greedy win rate | 15-25% | 0.0%* | 25.9% | **23.7%** |
| Planner win rate | 55-70% | 0.0%* | 56.0% | **63.5%** |
| **Greedy-vs-planner gap** | over 30pp | 0.0pp* | 30.1pp | **39.7pp** |
| High-rarity pick rate at Tier 4 | ~50% | — | 58.6% | **47.6%** |
| Staff in winning builds | 0-8, spread | — | median 4, 1-9 | **median 4, 0-9** |
| Tier rush among winners | ~30% | — | 100% | **21.8%** |

\* every policy died on encounter 1, so the v0.1 zeroes are an absence of data.

All three win-rate bands are hit simultaneously for the first time, and the
skill gap is **9.6pp wider** than the tuned-but-unchanged ruleset. The design
changes did not just make the game winnable; they made skill matter more.

## What changed, and why

**1. The four terms were given different jobs.** Footfall and Basket are
quantities and scale forever; Conversion and Margin are rates and cap out. So
the caps are now explicit (90% and 70%), and all unbounded growth moved into
five new **ratchet** fixtures — Regulars Book, Word of Mouth, Range Extension,
Trade Account, Second Branch — which accumulate permanently every trading day.

This is what fixes the collapsed midgame. A ratchet is weak on the day you take
it and the best card in the pool by encounter 20, so the board keeps
transforming instead of flattening at encounter 8. It is also the change that
did most of the work on the skill gap: the planner projects ratchets forward
before valuing an offer, and greedy — which has no model of tomorrow — cannot.
That is the skill the design wanted to reward, made mechanical.

**2. Cash was decoupled from the target.** Retained earnings are now a flat
reward per encounter plus interest plus a *capped* share of overshoot, so the
target is purely a fail condition. Tier rush fell from 100% to 21.8% and
Supplier Tier became a decision again. A skip-the-pick-for-cash option was
added alongside.

**3. The player chooses the boss.** Two are offered, one is taken, revealed two
encounters ahead. Every boss attacks a term, so choosing which term to be
attacked on is a direct read of your own funnel — and it converts the variance
that used to decide runs into a decision. The planner weighs both against the
board it expects to *have* by then; greedy judges them on the board it has now.

**4. Rent is pegged to the target.** A declining fraction — 62% of target in Q1
down to 5% by Q8 — scaled by the footprint you have actually bought. Section
13's "brutal in act 1, noise by act 5" is now true by construction and survives
any later retune of the curve.

**5. The board was filled.** The default shop is 3x3 rather than 3x4 and starts
with five fixtures rather than three. This is what replaced the aisle-congestion
idea that failed in the appendix, and it exposed something sharper: a customer
walks exactly one aisle, so on a 3x3 board six of your nine slots do nothing for
them. The whole board only earns if different types take different routes. When
the planner was changed to route *every* type rather than the top four, win
rates jumped by more than 20pp. **Signage is not a minor system — it is worth
about a third of your shop.**

**6. Flagship drawbacks stop melting.** Levelling a rule-breaking fixture
shrinks its drawback, which on a flagship removed the commitment entirely and
left pure upside. Flagship drawbacks are now authored per level and barely move.
Personal Shopper — picked 62-81% of the time it appeared — went from x2.5 Basket
to x1.9, and its throughput cap from 1/2/3 to 1/1/2.

**7. Returners were cut.** Reversing a previous day's sale is unreadable during
the walk, and a Returner reverses a full average sale while only half of
customers convert — which is why the all-Returner boss was unwinnable. Refund
Day now reverses 55% of yesterday's trading profit directly, and measures at
49% of a clean day.

**8. Marketing became a committed identity.** Six large, expensive campaigns
with big pool swings, and you may hold only three. Choosing who shops here now
costs you the alternative, which is what makes Concierge broken in one run and
dead in another.

## Still out of band

Three items, all understood, none blocking:

- **Queue share of early losses: 44.6%, wants ~25%.** Tills are still doing
  nearly twice their share of the killing. `sweep till` moves this cleanly; it
  was left alone because it interacts with the curve and the curve moved twice.
- **Top single-fixture pick rate: Loyalty Card at 50%, wants under 40%.** Two
  rounds of weakening its drawback took it from 55% to 50%. It wants a
  structural change rather than another number.
- **Combine rate: 68-95%, wants ~35%.** Unchanged and unfixable at this scale —
  with 23 fixtures and six commons, a Tier-1 player is offered duplicates most
  nights. This is a function of pool size, not level payoff, and it cannot be
  tuned until the pool nears milestone 3's 90-120.

One measurement caveat worth stating plainly: `bossimpact` now reports the
bosses players *chose*, and a player offered two will take the softer one. The
four bosses that still bite cluster tightly at 48-52% of a clean day, which is a
good band; the other eight read as harmless partly because they are the ones
being declined. Boss severity should be re-measured with choice disabled before
step 7 is called done.

---

# Part one — the diagnosis

What the simulator said about the v0.1 ruleset, which is what motivated all of
the above.

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
