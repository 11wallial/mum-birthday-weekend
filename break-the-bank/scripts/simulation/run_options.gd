## Per-run settings that come from outside the run: meta-progression unlocks,
## the chosen starter, the chosen difficulty.
##
## The simulation stays pure by taking these as an argument rather than reading
## a profile: the lab constructs them directly, and a batch measuring "the whole
## game" simply passes the default, where nothing is restricted.
class_name RunOptions
extends RefCounted

## Artifact ids the shop may offer. Empty means no restriction, which is what
## the balance lab uses so its numbers describe the full content set.
var allowed_artifacts: Array[StringName] = []
## Added to starting cash, from the machine.
var bonus_cash: int = 0
## Added to (or removed from) starting debt.
var bonus_debt: int = 0
## Chips in hand before the first draft, from the machine.
var bonus_chips: int = 0
## Hardware fitted before the first spin, by artifact id, from the machine.
var starting_artifacts: Array[StringName] = []
## The reel as the machine ships it: draw-weight deltas by symbol id or
## family, applied once at the start and kept for the run.
var weight_shifts: Dictionary = {}
## Every floor's ante is scaled by this. Difficulty modifiers move it.
var ante_scale: float = 1.0
## Extra spins on every floor.
var bonus_spins: int = 0
## Labels for telemetry, so a leaderboard row says which ruleset produced it.
var starter_id: StringName = &"standard"
var difficulty_id: StringName = &"standard"
## The rule changes an audit or a challenge makes, on top of the starter's
## numbers. Each is a multiplier or a delta the simulation applies where the
## number it changes is used; none of them is read anywhere else.
var debt_service_scale: float = 1.0
var interest_delta: float = 0.0
var debt_scale: float = 1.0
var price_scale: float = 1.0
## Share of the count the House keeps between floors. Zero forgets it.
var heat_carry: float = 0.0
var payout_scale: float = 1.0
## Credits every skull pays instead of costing. Zero leaves them as curses.
var curse_pays: float = 0.0
## Systems no floor will hand this run. The floor still opens; the verb never
## arrives.
var locked_systems: Array[StringName] = []
## Systems the run is handed before the first floor opens. The count from the
## basement, or the whole kit at once, for a challenge that wants it.
var early_systems: Array[StringName] = []
## The vig is charged from the first floor cleared. The House no longer waits.
var no_grace: bool = false
## The challenge this run is on, or empty for the ordinary game.
var challenge_id: StringName = &""
## Whether an automated run takes the House's offer and stays at the table
## after clearing the debt. A person decides this at the machine; the lab has
## to be told, so a batch can measure the endless floors on purpose and the
## default batch keeps measuring the game that ends.
var stay_at_table: bool = false
## Whether the House sends nobody to any floor. For the lab, to measure what
## the bosses cost, and for tests that need a plain floor; not a rule a
## player picks.
var no_bosses: bool = false


## True when a floor may hand this run [param system].
func allows_system(system: StringName) -> bool:
	return not locked_systems.has(system)


## True when the shop may offer [param artifact].
func allows(artifact: ArtifactDef) -> bool:
	if allowed_artifacts.is_empty():
		return true
	return allowed_artifacts.has(artifact.id)


## A stable description of the ruleset, for leaderboard comparisons: two scores
## are only comparable when this matches.
func ruleset_key() -> String:
	var locked: Array[String] = []
	for system: StringName in locked_systems:
		locked.append(String(system))
	locked.sort()
	var early: Array[String] = []
	for system: StringName in early_systems:
		early.append(String(system))
	early.sort()
	var fitted: Array[String] = []
	for artifact: StringName in starting_artifacts:
		fitted.append(String(artifact))
	fitted.sort()
	var leaned: Array[String] = []
	for key: Variant in weight_shifts:
		leaned.append("%s%+d" % [String(key), int(weight_shifts[key])])
	leaned.sort()
	return "%s/%s/%s/%.2f/%d/%d/%d/%d/%.2f/%.1f/%.2f/%.2f/%.2f/%.2f/%.1f/%s/%s/%s/%s/%s/%s" % [
		String(starter_id), String(difficulty_id), String(challenge_id), ante_scale,
		bonus_cash, bonus_debt, bonus_spins, bonus_chips, debt_service_scale, interest_delta,
		debt_scale, price_scale, heat_carry, payout_scale, curse_pays,
		"+".join(locked), "+".join(early), "nograce" if no_grace else "grace",
		"nobosses" if no_bosses else "bosses", "+".join(fitted), "+".join(leaned)]


## Everything a save needs to start the same run again. Plain data, so the
## journal that carries it round-trips through JSON.
func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in allowed_artifacts:
		ids.append(String(id))
	var fitted: Array[String] = []
	for artifact: StringName in starting_artifacts:
		fitted.append(String(artifact))
	var leaned: Dictionary = {}
	for key: Variant in weight_shifts:
		leaned[String(key)] = int(weight_shifts[key])
	return {
		"allowed_artifacts": ids,
		"bonus_cash": bonus_cash,
		"bonus_debt": bonus_debt,
		"bonus_chips": bonus_chips,
		"starting_artifacts": fitted,
		"weight_shifts": leaned,
		"ante_scale": ante_scale,
		"bonus_spins": bonus_spins,
		"starter_id": String(starter_id),
		"difficulty_id": String(difficulty_id),
		"stay_at_table": stay_at_table,
		"debt_service_scale": debt_service_scale,
		"interest_delta": interest_delta,
		"debt_scale": debt_scale,
		"price_scale": price_scale,
		"heat_carry": heat_carry,
		"payout_scale": payout_scale,
		"curse_pays": curse_pays,
		"locked_systems": locked_systems.map(func(s: StringName) -> String: return String(s)),
		"early_systems": early_systems.map(func(s: StringName) -> String: return String(s)),
		"no_grace": no_grace,
		"challenge_id": String(challenge_id),
		"no_bosses": no_bosses,
	}


static func from_dict(data: Dictionary) -> RunOptions:
	var options: RunOptions = RunOptions.new()
	var ids: Variant = data.get("allowed_artifacts", [])
	if ids is Array:
		for id: Variant in ids:
			options.allowed_artifacts.append(StringName(String(id)))
	options.bonus_cash = int(data.get("bonus_cash", 0))
	options.bonus_debt = int(data.get("bonus_debt", 0))
	options.bonus_chips = int(data.get("bonus_chips", 0))
	var fitted: Variant = data.get("starting_artifacts", [])
	if fitted is Array:
		for artifact: Variant in fitted:
			options.starting_artifacts.append(StringName(String(artifact)))
	var leaned: Variant = data.get("weight_shifts", {})
	if leaned is Dictionary:
		for key: Variant in leaned:
			options.weight_shifts[StringName(String(key))] = int(leaned[key])
	options.ante_scale = float(data.get("ante_scale", 1.0))
	options.bonus_spins = int(data.get("bonus_spins", 0))
	options.starter_id = StringName(String(data.get("starter_id", "standard")))
	options.difficulty_id = StringName(String(data.get("difficulty_id", "standard")))
	options.stay_at_table = bool(data.get("stay_at_table", false))
	options.debt_service_scale = float(data.get("debt_service_scale", 1.0))
	options.interest_delta = float(data.get("interest_delta", 0.0))
	options.debt_scale = float(data.get("debt_scale", 1.0))
	options.price_scale = float(data.get("price_scale", 1.0))
	options.heat_carry = float(data.get("heat_carry", 0.0))
	options.payout_scale = float(data.get("payout_scale", 1.0))
	options.curse_pays = float(data.get("curse_pays", 0.0))
	var locked: Variant = data.get("locked_systems", [])
	if locked is Array:
		for system: Variant in locked:
			options.locked_systems.append(StringName(String(system)))
	var early: Variant = data.get("early_systems", [])
	if early is Array:
		for system: Variant in early:
			options.early_systems.append(StringName(String(system)))
	options.no_grace = bool(data.get("no_grace", false))
	options.challenge_id = StringName(String(data.get("challenge_id", "")))
	options.no_bosses = bool(data.get("no_bosses", false))
	return options


func duplicate_options() -> RunOptions:
	var copy: RunOptions = RunOptions.new()
	copy.allowed_artifacts = allowed_artifacts.duplicate()
	copy.bonus_cash = bonus_cash
	copy.bonus_debt = bonus_debt
	copy.bonus_chips = bonus_chips
	copy.starting_artifacts = starting_artifacts.duplicate()
	copy.weight_shifts = weight_shifts.duplicate()
	copy.ante_scale = ante_scale
	copy.bonus_spins = bonus_spins
	copy.starter_id = starter_id
	copy.difficulty_id = difficulty_id
	copy.stay_at_table = stay_at_table
	copy.debt_service_scale = debt_service_scale
	copy.interest_delta = interest_delta
	copy.debt_scale = debt_scale
	copy.price_scale = price_scale
	copy.heat_carry = heat_carry
	copy.payout_scale = payout_scale
	copy.curse_pays = curse_pays
	copy.locked_systems = locked_systems.duplicate()
	copy.early_systems = early_systems.duplicate()
	copy.no_grace = no_grace
	copy.challenge_id = challenge_id
	copy.no_bosses = no_bosses
	return copy
