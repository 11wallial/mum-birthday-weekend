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
## Shop price inflation per cleared floor, as a percent of base cost.
@export var shop_inflation_percent: float = 15.0
## Percent of outstanding debt demanded in cash when a floor is cleared. This is
## the vig: it is charged before the ante, so debt competes with survival every
## floor rather than being a single bill at the end of the run.
@export var debt_service_percent: float = 20.0
## Penalty added to the principal, as a percent of the shortfall, when the
## service payment cannot be met in full.
@export var debt_default_penalty_percent: float = 50.0
## Highest multiple of [member spin_cost] a single spin may be wagered at.
@export var max_stake: int = 5
## Most nudges one board can be owed, however they were earned.
@export var max_nudges: int = 3
## Chance of winning each rung of the gamble ladder, in 0.0..1.0. The first rung
## is an even coin flip and every rung after it is worse: the ladder is where the
## player is taught what a house edge feels like, by paying for it.
@export var gamble_odds: PackedFloat32Array = PackedFloat32Array([0.5, 0.45, 0.4, 0.35])

## Credits the first reroll of a draft costs. Each further reroll in the same
## draft costs the previous one multiplied by [member reroll_growth].
@export var reroll_base_cost: int = 4
@export var reroll_growth: float = 2.0
## Share of an artifact's current price returned when it is sold back. Well
## under half: a build has to be able to change its mind, but not for free.
@export var sellback_percent: float = 45.0
## Markup added to anything bought on the slate, on top of it becoming debt.
@export var slate_markup_percent: float = 40.0

## Floors cleared before the vig starts. The first floor is the tutorial; a
## debt payment on top of the opening ante just ends runs before they begin.
@export var debt_grace_floors: int = 1
