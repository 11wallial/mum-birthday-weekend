# The builds

Eight named builds a player can discover and chase. Each is an
[`ArchetypeDef`](../resources/archetypes/) — an id, a name, a brief in the
House's voice, and the thing that pushes back — and every artifact that
belongs to one names it in its `archetype` field. Nothing in the simulation
reads an archetype: it is the label the lab measures a build by, the lean the
automated player follows once it has started one, and the plate the draft
shows beside the name.

## The shape every build is held to

The content suite (`tests/simulation/test_shipped_archetypes.gd`) fails the
build unless every archetype has:

- **an enabler** on floor 1 or 2 — something cheap that makes the build
  visible early enough to commit to;
- **an amplifier** on floors 3 to 5 — the part that pays for the commitment;
- **a capstone** from floor 6 — the reason to have stayed with it;
- **a counter** — a sentence naming what pushes back, because a build with
  nothing pushing back is a shopping list.

Role is read off `min_floor` (`ArtifactDef.role()`), not authored: the shape
of a build is a fact about where its parts unlock.

## The eleven effects the builds are made of

The first eighteen effects read the line and the economy. These eleven read
the run and the board, and every one of them is resolved in
`ArtifactEngine._scaling_gain`:

| Effect | Reads | Notes |
| --- | --- | --- |
| `MULT_PER_SEEN` | a tally of symbols matching the filter that have landed on the payline since purchase | capped; the tally moves only on a settled spin and is wiped when sold |
| `AWAKENED_MULT` | a tally of spins settled since purchase | nothing until `cap` spins, then `magnitude` on every line for good |
| `MULT_PER_TRIGGER` | every other artifact that triggered on the line | resolved last; two of them count each other |
| `PARTNER_MULT` | whether `partner` is owned | nothing at all alone |
| `MULT_PER_TAG` | owned artifacts carrying `tag_filter` | the synergy bonus counted one device at a time |
| `MULT_PER_CURSE` | skulls standing on the line | warded or not |
| `MULT_PER_HOLD` | reels locked when the board was drawn | `SpinBoard.holds_used` |
| `MULT_PER_NUDGE` | nudges spent on the board | a preview prices the nudge being considered |
| `MULT_PER_STAKE` | stake levels above the first | the stake already multiplies; this makes it superlinear |
| `MULT_PER_STREAK` | paying spins in a row before this one | capped; a dud resets |
| `MULT_PER_SPIN_LEFT` | spins still on the floor | capped; decays as the floor runs on |

Two older effects learnt something on the way: `symbol_filter` now names a
family (`fruit`, `bar`) as readily as a symbol, everywhere it is read, and
`RETRIGGER` honours `pattern_filter`.

## The builds

Roles by floor: **E** enabler (1–2) · **A** amplifier (3–5) · **C** capstone (6–7).

### The Payroll (`skulls`)

Skulls on the reel, skulls on the payroll, and a book that pays more the more
of them stand.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | Gallows Humour | 2 | skulls pay 3 instead of costing |
| E | Bone Orchard | 2 | +6 draw weight on Skull |
| A | Skull Tally | 3 | +0.6x per skull standing |
| A | Ossuary | 4 | +0.04x per skull landed this run, to +3.0x |
| A | Grave Digger | 4 | +2.0x beside the Bone Orchard |
| A | Hazard Pay | 5 | skulls pay 6 |
| C | Death Benefit | 6 | +1.6x per skull standing |

*Counter:* without a ward every skull costs the penalty and takes the pattern
bonus with it, and a jackpot is a line the skulls are not on. Bone Saw is the
anti-build.

### The Clamp (`clamp`)

Every reel locked is a reel that pays.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | Reel Clamp | 1 | +0.6x per reel held |
| A | Brake Shoe | 3 | +1.2x per reel held |
| A | Lockstep | 4 | +1.8x per reel held |
| C | Dead Man's Grip | 6 | +3.0x per reel held |

*Counter:* a lock is charged for on every spin, and the last reel can never be
held. The automated player holds cheap fruit only once it owns clamp hardware.

### The Trail (`trail`)

The drums are stopped where they are told to stop, and the hardware pays by
the step.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | Fine Adjuster | 1 | +0.5x per nudge spent |
| E | Nudge Bar | 1 | one free nudge an award |
| A | Second Lever | 3 | +1.5x beside the Nudge Bar |
| A | Micrometer | 4 | +1.2x per nudge spent |
| A | Ratchet Pawl | 4 | two free nudges an award |
| C | Master Key | 6 | +2.4x per nudge spent |

*Counter:* a paid nudge is a spin off the floor, and a board owes three at
most.

### The Marker (`marker`)

The debt is the build.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | IOU | 1 | +0.06x per 100 owed, to +0.6x |
| A | Marker Note | 3 | +0.15x per 100 owed, to +1.2x |
| A | Creditors' Ledger | 4 | +0.35x per bank device |
| A | Loan Shark | 4 | +2.0x beside the Marker Note |
| A | Leverage Desk | 5 | +0.32x per 100 owed, to +2.8x |
| C | Margin Call | 6 | +0.55x per 100 owed, to +4.5x |
| C | Usurer's Wheel | 7 | +0.7x per bank device |

*Counter:* the vig every floor, the interest every floor after the grace, and
the bill at the end that has to be paid in full.

### The Whale (`whale`)

Play at the top of the stake and let the hardware make the wager pay more than
it costs.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | Hot Hand | 2 | +0.25x per paying spin in a row, to +2.5x |
| A | Whale Ticket | 3 | +0.5x per stake level above the first |
| A | High Rollers' Cage | 5 | +1.0x per stake level |
| A | Winning Streak | 5 | +0.5x per paying spin in a row, to +5.0x |
| C | Quiet Room | 6 | the count notices 35% less |
| C | False Ceiling | 7 | the count notices 55% less |
| C | The Whale | 7 | +2.0x per stake level |

*Counter:* the spin costs the stake — every level above the first costs a
share of the floor's ante per spin (`BalanceConfig.stake_ante_percent`) — and
the count rises with what you win.

### The Clock (`clock`)

Spins bought, spins refunded, and boilers that pay nothing until they light.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | Overtime Clock | 1 | +2 spins a floor |
| E | Loose Screw | 1 | 8% of spins free |
| E | Pressure Gauge | 2 | +0.06x per spin left, to +1.0x |
| E | Cold Boiler | 2 | lights after 40 spins: +1.6x |
| A | Night Shift | 3 | +2 spins a floor |
| A | Rabbit Run | 3 | 12% of spins free |
| A | Long Fuse | 4 | lights after 70 spins: +3.5x |
| A | Boiler Room | 5 | +0.14x per spin left, to +2.5x |
| A | Graveyard Shift | 5 | 20% of spins free |
| C | Pressure Valve | 6 | +4 spins a floor |
| C | Twin Boilers | 6 | +2.5x beside the Pressure Valve |

*Counter:* the gauge falls as the floor runs on, and a boiler bought late
lights after the run is over.

### The Exchange (`exchange`)

Many small devices, each firing on every line, and a switchboard that pays by
the trigger.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | Lucky Charm, Cherry Bomb, Three Bar Salute, Pair Broker, Brass Multiplier, Mirror Shard | 1–2 | cheap triggers |
| E | Relay Bank | 2 | +0.25x per other artifact that triggered |
| A | Foreman | 3 | +0.3x per mechanical device |
| A | Counting Room | 5 | +0.12x per artifact owned |
| A | Switchboard | 5 | +0.6x per other artifact that triggered |
| C | Power Coupling | 6 | +0.2x per artifact owned |
| C | The Ledger | 7 | +0.25x per artifact owned |
| C | The Exchange | 7 | +1.2x per other artifact that triggered |

*Counter:* the draft is paid in chips, and a machine of trinkets has to keep buying
them. One big device beats six small ones until the exchange is wired in.

### The Orchard (`orchard`)

The ledger of everything that has ever landed.

| | Artifact | Floor | Does |
| --- | --- | --- | --- |
| E | Fruit Ledger | 1 | +0.012x per fruit landed, to +1.5x |
| E | Cider Press | 1 | every fruit pays 2 more |
| E | Orchard Wall | 2 | +5 draw weight on every fruit |
| E | Golden Reel, Magnet Coil | 2 | sevens pay more, sevens land more |
| A | Seven Counter | 3 | +0.15x per seven landed, to +4.0x |
| A | Bar Tab | 4 | +0.1x per Bar landed, to +4.0x |
| A | Cider House | 5 | +0.03x per fruit landed, to +6.0x |
| C | Harvest Festival | 6 | +0.06x per symbol landed, to +9.0x |

*Counter:* fruit pays two, every tally is capped, and the cold deck takes the
sevens off the reel exactly when the counter wants them.

## What the lab says

`archetype_win_rates` in the report is each build measured as a build: a run
counts once it owns two of the build's artifacts, and its win rate is put
beside the batch's win rate among runs at the same market depth, in the same
proportions. The bot chases whichever build it has most of, so these are the
builds a person would actually assemble, played by a mediocre player.

Measured on 2 September 2026, 10,000 runs from seed 1 with the House's
people on every floor (batch win rate 17.1%):

| Build | Runs playing it | Win rate | Cohort | Lift |
| --- | --- | --- | --- | --- |
| The Whale | 2,030 | 56.7% | 51.2% | +5.5 |
| The Marker | 2,791 | 42.7% | 40.4% | +2.3 |
| The Clamp | 1,747 | 36.9% | 35.6% | +1.3 |
| The Payroll | 3,390 | 31.9% | 30.8% | +1.1 |
| The Trail | 3,824 | 31.1% | 30.3% | +0.9 |
| The Clock | 6,208 | 25.9% | 25.3% | +0.5 |
| The Orchard | 6,315 | 23.4% | 23.0% | +0.3 |
| The Exchange | 7,635 | 22.2% | 22.1% | +0.1 |

Read the lift, not the win rate: a build's win rate mostly says how deep its
parts unlock. The Whale's lift is the one to watch — it was +45 points before
the stake was priced off the ante, which is how the stake premium came to
exist. The Exchange and the Orchard are the builds the bot falls into by
accident (their enablers are the cheap floor-one stock), so their cohorts are
nearly the whole batch and their lifts are nearly nothing; a person chasing
either on purpose is the measurement still missing.

None of this is human data. The pick-rate scatter (`pick_rates`) is the
instrument built for when it is: each artifact's pick rate beside its lift
over the pack's median lift, with the four corners named — trap, auto,
sleeper, dead.
