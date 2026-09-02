# The seven floors

Each floor hands the player one new verb, and the verb stays for the rest of the
run. The game is not seven variations on a slot machine; it is a slot machine
that becomes six other games while you are still playing the first one.

Every mechanic below has to hold up on its own. If a floor's verb would not
carry a whole small game by itself, it is not finished.

The names live in `Systems`; a floor claims one with `FloorDef.grants`, and
`RunState.has_system()` is the only gate. Nothing checks a floor index.

---

## 1 — The Basement · **HOLD & NUDGE**

The core loop, made into a decision.

**Hold.** Lock any reels but the last and only redraw what is not already
working. Every lock is charged for — a spin's price is
`spin_cost × stake × (1 + locks)`, plus the stake's premium once there is one
(floor 3). Without that, holding a pair is strictly
better than not holding one, and a move with no cost is not a decision; it is a
thing the player learns to do without thinking about it.

**Nudge.** A board one symbol short of the whole thing — on three reels, exactly
a pair — opens the trail. A nudge drops the band above onto the payline, and the
band is right there in the window, so the player can see whether it is worth
taking. **It costs a spin off the floor's allowance.** Hardware and a raised
stake put some of the trail on the house.

This is what finally makes the three-row window a mechanic instead of a
decoration. The near miss the player is looking at is one they can do something
about, at a price.

## 2 — The Casino · **THE MARKET**

The draft becomes a shop you can work.

- **Reroll** the offers. The price doubles with every reroll in the same draft.
- **Sell** owned hardware back at well under half of what it is worth today.
  Selling is exactly the inverse of acquiring, so a permanent reel change cannot
  be laundered through the market for cash.
- **The slate.** Take an offer without paying and put the bill on the debt with
  a markup. The only way in the game to turn future trouble into present power.

Stock is weighted towards what the floor has just unlocked. A flat draw from
everything meant that by floor six the shop was mostly floor-one trinkets.

## 3 — The High Roller Room · **THE STAKE AND THE LADDER**

**Stake.** Wager one to five credits a spin. It pays that multiple back on the
multiplier, and every level above the first costs a share of the floor's ante
per spin on top of the spin (`BalanceConfig.stake_ante_percent`, a tenth). It
used to cost only the multiple — one credit a level against payouts in the
hundreds — which made the top of the stake right whenever the purse could stand
it, and a wager that is always right is not a wager. Priced off the ante, a
level pays for itself only on a machine paying better than the premium, and
costs a machine that is not exactly the ante it needs; hardware that pays per
stake level (the Whale) is what makes the premium worth paying anyway. At stake
three or more the machine also runs hot enough to put a nudge on the house.

**The ladder.** A win can be doubled instead of banked, up to four times. The
odds get worse every rung — 50%, 45%, 40%, 35% — so the first rung is an even
coin flip and every rung after it is a mistake you want to make. This is where a
player is taught what a house edge feels like, by paying for it.

## 4 — The Vault · **CAPITAL**

Cash locked in the vault does two things: it pays a dividend into the purse
every time a floor clears, and it stands as **collateral** — a reserve is worth a
multiplier on every spin, capped, and priced against the ante so it means the
same thing on floor four as on floor seven. It is the exact mirror of the
leverage a player already gets for being in debt.

What it costs is liquidity. Collateral cannot settle an ante, and the ante is
the only thing that ever has to be settled. Breaking the vault mid-floor gets
the money back minus a quarter.

The decision is not "what shall I do with my spare cash" — there is never any
spare cash. It is what to do with the ante float: the money that would otherwise
sit in the purse doing nothing between being won and being paid.

## 5 — The Back Office · **CONTRACTS**

Nobody goes up the stairs without signing. Three of the house's standing offers,
each with a real boon and a real toll: spins for payout, ante for interest, the
skulls on the payroll and the sevens off it. The terms hold for one floor and
are torn up when it ends.

Contracts are data (`ContractDef`), resolved in `ContractEngine`, with a
deliberately small clause vocabulary. A contract that only gave would be a
shopping list; the second half is the floor.

The office opens on the way *into* floor five, not out of it. Waiting for the
system to be granted first cost the mechanic a third of the run it gets to
exist for.

## 6 — The Engine Room · **THE WORKS**

Reels and scoring rows bolt on permanently, and they can be fitted **between
spins** as readily as between floors. The engine room is every machine on the
floor wired to yours, and stripping one for parts with the ante still to find is
the decision that floor is made of. Confined to the draft it would have been a
mechanic the player got to use exactly once.

A bought row makes the band pay, which is the second job that window has now —
and it means a nudge is moving symbols between scoring lines, not just onto one.

Priced as a share of the ante in play, so the works stay a serious decision
however deep the run has got.

## 7 — The House · **THE COUNT**

The only system in the game that plays against the player.

The count rises with what you win, measured against par, and falls with every
spin that does not. It answers at three thresholds:

| Count | Measure | What happens |
| --- | --- | --- |
| 35 | **The Skim** | A share of every payout goes back over the bar. |
| 65 | **The Cold Deck** | Sevens, diamonds, double bars and wilds lose half their draw weight. |
| 100 | **The Pit Boss** | Someone comes over. The ante rises for the rest of the floor and the count drops back to just under the line. |

Two answers: play cold, or pay for a quiet word. Hardware can absorb some of the
attention.

The count resets with the floor. It is a floor's worth of attention, not a
run's.

## After hours · **STAYING AT THE TABLE**

Clearing the seventh floor and repaying the debt is the win, and it is
recorded as one. Then the House makes its counter-offer: the debt back, and a
chair. A run that stays gets its repaid debt lent again — so the vig resumes
and the clock keeps running — and the floors go on past the last. There is no
floor eight in the content; the floors after hours are made by `Endless` from
the last authored one, each ante `endless_ante_growth` times the one before,
the draft still open, the back office still signing, until an ante is missed.
Then the House keeps you. Or until dawn: after `endless_floors_max` floors the
House closes, and a run still standing walks out with the win the table could
not take back — because a build that has outgrown the ante would never miss
one, and a run that cannot end is not a run.

What the leaderboard measures for a run that stayed is how many floors it
lasted at a table that gets dearer every time. The ante doubles a floor after
hours: swept against the automated player, 35% a floor let every winner reach
dawn, 50% let most of them get close, and doubling lands a typical stayer
around ten floors with dawn exceptional — which is the shape a leaderboard
wants, and a number to revisit against human data like every other. The default lab batch does not
stay — it measures the game that ends — and a batch told to
(`RunOptions.stay_at_table`) measures the curve after it.

The offer is answered with the spin key, at the moment it is made, and never
by a lost run.

---

## Balance

Every dial is in `resources/rules/balance_config.tres`; nothing above is a
constant in the simulation.

`AutoPlayer` drives the same public calls a player's hands do — `toggle_hold`,
`nudge`, `gamble`, `deposit`, `buy_row`, `launder`, `sign_contract`, and the
market's `reroll_shop`, `sell` and `buy_on_slate` — so the lab measures the
game people play rather than a stripped-down version of it.
`SimEngine.clear_policies()` hands all of them back when a human is at the
machine. `SimEngine.PLAYER_VERBS` is the list, `AutoPlayer.COVERAGE` names the
opinion behind each, and the parity suite fails the build when either falls
behind the other or a batch is never seen using a verb.

At the time of writing the batch lands around a 19% win rate with deaths
climbing floor by floor, plus a further fifth of runs that clear the House and
still cannot clear the debt.
