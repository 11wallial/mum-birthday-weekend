## One of the House's machines: what a run starts on.
##
## The first playtest asked for distinct starting machines — a high-roller
## against a defensive one — as the meta's second axis after the ladder, the
## way Balatro's decks are. A machine is a set of starting numbers, hardware
## already bolted on, a reel already leaned, and sometimes a verb handed over
## before the floor that teaches it. Every field reaches the run only through
## [RunOptions], which is the rule for anything persistent: the simulation
## never knows a machine exists, only what the numbers are — and the lab can
## measure any machine with [code]--machine=<id>[/code].
class_name MachineDef
extends Resource

@export var id: StringName = &"standard"
@export var display_name: String = "The Standard"
## One line, in the House's register, for the door.
@export_multiline var brief: String = ""

@export_group("What the machine starts with")
## Added to starting cash and debt; spins added to every floor's allowance.
@export var bonus_cash: int = 0
@export var bonus_debt: int = 0
@export var bonus_spins: int = 0
## Chips in hand before the first draft.
@export var bonus_chips: int = 0
## Hardware already fitted, by artifact id.
@export var starting_artifacts: Array[StringName] = []
## The reel as it ships: draw-weight deltas keyed by symbol id or family.
@export var weight_shifts: Dictionary = {}
## Every payout and every ante scaled by these.
@export var payout_scale: float = 1.0
@export var ante_scale: float = 1.0
## Credits each skull pays instead of costing. Zero leaves them as curses.
@export var curse_pays: float = 0.0
## Systems handed over before the first floor, by [Systems] name.
@export var early_systems: Array[StringName] = []


## The options a run on this machine starts with, on top of [param base].
func apply_to(base: RunOptions) -> RunOptions:
	var options: RunOptions = base.duplicate_options()
	options.starter_id = id
	options.bonus_cash += bonus_cash
	options.bonus_debt += bonus_debt
	options.bonus_spins += bonus_spins
	options.bonus_chips += bonus_chips
	for artifact: StringName in starting_artifacts:
		if not options.starting_artifacts.has(artifact):
			options.starting_artifacts.append(artifact)
	for key: Variant in weight_shifts:
		var symbol: StringName = StringName(String(key))
		options.weight_shifts[symbol] = int(options.weight_shifts.get(symbol, 0)) \
				+ int(weight_shifts[key])
	options.payout_scale *= payout_scale
	options.ante_scale *= ante_scale
	options.curse_pays = maxf(options.curse_pays, curse_pays)
	for system: StringName in early_systems:
		if not options.early_systems.has(system):
			options.early_systems.append(system)
	return options
