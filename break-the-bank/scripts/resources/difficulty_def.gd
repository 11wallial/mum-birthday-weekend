## One rung of the ladder: a named audit of the account, as rule changes.
##
## The tiers are cumulative by authorship, not by code — tier six lists every
## rule tiers two to five added, so each file is the whole ruleset it names
## and the lab can measure one without loading the others. Every field here
## reaches the run only through [RunOptions], which is the rule for anything
## persistent: the simulation never knows an audit exists, only what the
## numbers are.
class_name DifficultyDef
extends Resource

@export var id: StringName = &"standard"
@export var display_name: String = "Standard"
@export_multiline var description: String = ""
## Position on the ladder, 1 being the game as shipped.
@export var tier: int = 1

@export_group("What the audit changes")
## Every floor's ante is scaled by this.
@export var ante_scale: float = 1.0
## Spins added to (or taken off) every floor's allowance.
@export var spins_delta: int = 0
## The vig is scaled by this.
@export var debt_service_scale: float = 1.0
## Every floor's debt interest moves by this many percentage points.
@export var interest_delta: float = 0.0
## The starting debt is scaled by this.
@export var debt_scale: float = 1.0
## Every price in the draft is scaled by this.
@export var price_scale: float = 1.0
## Share of the count the House keeps between floors. Zero forgets it.
@export var heat_carry: float = 0.0
## Every payout is scaled by this.
@export var payout_scale: float = 1.0
## The vig is charged from the first floor cleared.
@export var no_grace: bool = false


## The options a run at this tier starts with, on top of [param base].
func apply_to(base: RunOptions) -> RunOptions:
	var options: RunOptions = base.duplicate_options()
	options.difficulty_id = id
	options.ante_scale = ante_scale
	options.bonus_spins += spins_delta
	options.debt_service_scale = debt_service_scale
	options.interest_delta = interest_delta
	options.debt_scale = debt_scale
	options.price_scale = price_scale
	options.heat_carry = heat_carry
	options.payout_scale = payout_scale
	options.no_grace = no_grace
	return options


## The ruleset key a run at this tier would carry, from a plain start.
func ruleset_key_of() -> String:
	return apply_to(RunOptions.new()).ruleset_key()
