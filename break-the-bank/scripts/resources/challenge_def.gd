## A fixed-constraint run: one rule, named, that the whole run is played under.
##
## A challenge is a complete ruleset of its own — the starter and the audit
## are set aside for it — so two players on the same challenge are on the
## same board, and a leaderboard row for one means one thing. Authored as
## data, like everything else that reaches a run through [RunOptions].
class_name ChallengeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("The rule")
## Systems no floor will hand this run. The floor still opens; the verb never
## arrives.
@export var locked_systems: Array[StringName] = []
@export var ante_scale: float = 1.0
@export var spins_delta: int = 0
@export var bonus_cash: int = 0
@export var bonus_debt: int = 0
@export var debt_scale: float = 1.0
@export var debt_service_scale: float = 1.0
@export var interest_delta: float = 0.0
@export var price_scale: float = 1.0
@export var heat_carry: float = 0.0
@export var payout_scale: float = 1.0
## Credits every skull pays instead of costing the penalty. Zero leaves them
## as curses.
@export var curse_pays: float = 0.0
## Systems handed over before the first floor opens.
@export var early_systems: Array[StringName] = []
## The vig is charged from the first floor cleared.
@export var no_grace: bool = false


## The options a run on this challenge starts with. [param allowed] is the
## artifact pool the profile has unlocked; a challenge never widens it.
func options_for(allowed: Array[StringName]) -> RunOptions:
	var options: RunOptions = RunOptions.new()
	options.allowed_artifacts = allowed.duplicate()
	options.starter_id = &"standard"
	options.difficulty_id = &"standard"
	options.challenge_id = id
	options.locked_systems = locked_systems.duplicate()
	options.ante_scale = ante_scale
	options.bonus_spins = spins_delta
	options.bonus_cash = bonus_cash
	options.bonus_debt = bonus_debt
	options.debt_scale = debt_scale
	options.debt_service_scale = debt_service_scale
	options.interest_delta = interest_delta
	options.price_scale = price_scale
	options.heat_carry = heat_carry
	options.payout_scale = payout_scale
	options.curse_pays = curse_pays
	options.early_systems = early_systems.duplicate()
	options.no_grace = no_grace
	return options
