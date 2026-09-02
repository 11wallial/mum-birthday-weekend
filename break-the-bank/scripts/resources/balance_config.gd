## Top-level tuning knobs for a run.
##
## This is the resource the balance loop edits: every number that shapes pacing
## lives here or on a [FloorDef], never inline in the simulation code.
class_name BalanceConfig
extends Resource

## Reel count. Patterns are evaluated across the whole line.
@export var reel_count: int = 3
## Credits the player starts with.
@export var starting_cash: int = 10
## Debt the player starts the run carrying.
@export var starting_debt: int = 50
## Credits charged per spin.
@export var spin_cost: int = 1
## Multiplier every line starts from, before its pattern bonus. At zero, a line
## that matches nothing pays nothing.
@export var base_multiplier: float = 1.0
## Multiplier granted by each pattern, indexed by [enum Probability.Pattern].
@export var pattern_multipliers: PackedFloat32Array = PackedFloat32Array([0.0, 0.4, 1.2, 3.0, 0.6])
## A landed curse symbol subtracts this many credits.
@export var curse_penalty: int = 2
## Synergy bonus multiplier granted per tag once the threshold is met.
@export var synergy_bonus: float = 0.5
## Owned artifacts sharing a tag needed before the synergy bonus applies.
@export var synergy_threshold: int = 3
## Chips the run starts with. The House's scrip: it buys hardware in the
## draft and settles nothing, and the only ways to earn it are to clear a
## floor, to clear it early, to hold some over, and to land the bank.
##
## Credits used to buy the draft too, and priced against the ante the draft
## was free from floor three: a purse that had just cleared the ante could
## always afford every offer. Two currencies is the fix Balatro and CloverPit
## both arrived at — points to survive, money to build — and the tension is
## the same here: spins spent chasing credits are chips not earned.
@export var starting_chips: int = 0
## Chips paid per spin left on the clock when a floor is settled before its
## allowance runs out, and the most that can be earned that way on one floor.
@export var chips_per_spin_left: int = 2
@export var chips_spin_left_cap: int = 8
## Chips held over at a floor's close earn one more per this many, up to the
## cap. Saving is a decision only when it pays.
@export var chip_interest_per: int = 5
@export var chip_interest_cap: int = 3
## Credits one chip is worth to the House, as a percent of the floor's ante:
## the rate the slate converts a chip price into debt at, and the number
## telemetry values a chip at. Priced off the ante so a chip on floor six is
## worth floor six's money.
@export var chip_credit_rate_percent: float = 3.0
## Percent of outstanding debt demanded in cash when a floor is cleared. This is
## the vig: it is charged before the ante, so debt competes with survival every
## floor rather than being a single bill at the end of the run.
@export var debt_service_percent: float = 20.0
## Penalty added to the principal, as a percent of the shortfall, when the
## service payment cannot be met in full.
@export var debt_default_penalty_percent: float = 50.0
## Highest multiple of [member spin_cost] a single spin may be wagered at.
@export var max_stake: int = 5
## What every stake level above the first costs on top of the spin, per spin,
## as a percent of the floor's ante. Without it the wager was a free multiple:
## a spin cost one credit against payouts in the hundreds, so playing at the
## top of the stake was right whenever the purse could stand it, and the
## automated player found that out the moment it was given a reason to look.
## Priced off the ante, raising pays only for a machine paying better than
## the premium — and costs a machine that is not exactly the ante it needs.
@export var stake_ante_percent: float = 0.0
## Most nudges one board can be owed, however they were earned.
@export var max_nudges: int = 3
## Chance of winning each rung of the gamble ladder, in 0.0..1.0. The first rung
## is an even coin flip and every rung after it is worse: the ladder is where the
## player is taught what a house edge feels like, by paying for it.
@export var gamble_odds: PackedFloat32Array = PackedFloat32Array([0.5, 0.45, 0.4, 0.35])

## Chips the first reroll of a draft costs. Each further reroll in the same
## draft costs the previous one multiplied by [member reroll_growth].
@export var reroll_base_cost: int = 2
@export var reroll_growth: float = 2.0
## Share of an artifact's chip price returned when it is sold back. Half at
## most: a build has to be able to change its mind, but not for free.
@export var sellback_percent: float = 50.0
## Markup added to anything bought on the slate, on top of it becoming debt
## at the House's exchange rate ([member chip_credit_rate_percent]).
@export var slate_markup_percent: float = 40.0

## Dividend the vault pays into the purse every time a floor is cleared, as a
## percent of the principal. The principal stays locked and comes back at the
## end of the run, so a deposit is cash now traded for income later — and the
## rate has to beat the floors remaining, which is what makes it a decision.
@export var vault_interest_percent: float = 30.0
## Vault balance, in multiples of the floor's ante, that buys +1.0 on every
## payout. The vault's real draw is not the dividend: it is collateral. A house
## lets a player with a reserve play deeper, which is the exact mirror of the
## leverage a player gets for being in debt — and priced off the ante so it
## means the same thing on floor four as on floor seven.
@export var vault_collateral_antes: float = 0.55
## Ceiling on that multiplier, so a hoard can never become the whole build.
@export var vault_collateral_cap: float = 3.0
## Share of a withdrawal kept by the house when the vault is broken into
## mid-floor rather than opened between floors.
@export var vault_break_percent: float = 25.0

## Reels and scoring rows the machine can be grown by, beyond what it ships
## with. Two of each: a five-reel, three-row machine is a monster, and a monster
## is where the growth should stop rather than a number that keeps going.
@export var max_extra_reels: int = 2
@export var max_extra_rows: int = 2
## Cost of the first extra reel and the first extra row, as a percent of the
## ante of the floor just cleared. Priced off the ante so the works stay a
## serious decision on floor six and on floor seven alike.
@export var reel_cost_percent: float = 24.0
@export var row_cost_percent: float = 38.0

## Count the House reaches before it starts skimming, before it cools the reels,
## and before it sends someone over. The count rises with what you win and falls
## with every spin you do not.
@export_group("The draft's offers")
## Weight multiplier on an offer whose build the run has already started —
## light, by the balance guide: enough to keep offers relevant, not enough
## to funnel every run down the same lane.
@export var offer_build_weight: float = 1.5
## Most offers of one build in a single draft: anti-flood.
@export var offer_build_cap: int = 2
## A symbol an offer is keyed to has to land at least this often for the
## offer to be usable; below it the offer is dead and is not put out.
@export var offer_symbol_floor: float = 0.01

@export_group("The notice")
## A single spin paying this many pars — the ante over the spins allowed —
## is loud enough for the House to notice. It answers by sending one more
## of its people to the next floor, announced the moment it is decided.
@export var notice_par_multiple: float = 10.0
## Percent on every ante for every time the House has noticed: its
## attention, once caught, is never quite lost.
@export var notice_ante_percent: float = 5.0

## The doorman: chips to have the House send nobody after a notice, and
## how much dearer each time. A word with the doorman is the player's one
## answer to the House noticing — two poor options, the guide's shape for
## keeping ownership through an event — and it never touches the ante
## markup, which is the House's memory.
@export var doorman_chips: int = 6
@export var doorman_step: int = 3

@export_group("The count")
@export var heat_skim_at: float = 35.0
@export var heat_cold_at: float = 65.0
@export var heat_boss_at: float = 100.0
## Count added per multiple of par won, and taken off per spin regardless.
@export var heat_per_par: float = 9.0
@export var heat_decay: float = 3.0
## Share the skim takes once it starts, and the share of the ante the pit boss
## adds when it sends someone over.
@export var heat_skim_percent: float = 15.0
@export var heat_boss_ante_percent: float = 20.0
## Credits per point of count charged to launder, and the points it buys off.
@export var launder_cost: float = 1.4
@export var launder_relief: float = 40.0

## Floors cleared before the vig starts. The first floor is the tutorial; a
## debt payment on top of the opening ante just ends runs before they begin.
@export var debt_grace_floors: int = 1

## How much each floor past the last authored one raises the ante on the one
## before it, for a run that stays at the table. The floors are made, not
## authored — see [Endless] — so this is the whole difficulty curve of the
## endless game, and the number the leaderboard is really measuring.
@export var endless_ante_growth: float = 2.0
## Spins added to every endless floor's allowance. Zero keeps the last floor's.
@export var endless_spins_bonus: int = 0
## Floors after hours before the House closes. A build that outgrows the
## ante's growth would otherwise never miss one, and a run that cannot end is
## not a run; at dawn the doors open and the run is a win. This is also the
## top of the leaderboard's scale.
@export var endless_floors_max: int = 24
