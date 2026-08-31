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
## Floors cleared before the vig starts. The first floor is the tutorial; a
## debt payment on top of the opening ante just ends runs before they begin.
@export var debt_grace_floors: int = 1
