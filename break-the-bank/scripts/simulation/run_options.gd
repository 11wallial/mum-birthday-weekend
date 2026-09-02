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
## Added to starting cash, from a starter variant.
var bonus_cash: int = 0
## Added to (or removed from) starting debt.
var bonus_debt: int = 0
## Every floor's ante is scaled by this. Difficulty modifiers move it.
var ante_scale: float = 1.0
## Extra spins on every floor.
var bonus_spins: int = 0
## Labels for telemetry, so a leaderboard row says which ruleset produced it.
var starter_id: StringName = &"standard"
var difficulty_id: StringName = &"standard"


## True when the shop may offer [param artifact].
func allows(artifact: ArtifactDef) -> bool:
	if allowed_artifacts.is_empty():
		return true
	return allowed_artifacts.has(artifact.id)


## A stable description of the ruleset, for leaderboard comparisons: two scores
## are only comparable when this matches.
func ruleset_key() -> String:
	return "%s/%s/%.2f/%d/%d/%d" % [
		String(starter_id), String(difficulty_id), ante_scale,
		bonus_cash, bonus_debt, bonus_spins]


## Everything a save needs to start the same run again. Plain data, so the
## journal that carries it round-trips through JSON.
func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in allowed_artifacts:
		ids.append(String(id))
	return {
		"allowed_artifacts": ids,
		"bonus_cash": bonus_cash,
		"bonus_debt": bonus_debt,
		"ante_scale": ante_scale,
		"bonus_spins": bonus_spins,
		"starter_id": String(starter_id),
		"difficulty_id": String(difficulty_id),
	}


static func from_dict(data: Dictionary) -> RunOptions:
	var options: RunOptions = RunOptions.new()
	var ids: Variant = data.get("allowed_artifacts", [])
	if ids is Array:
		for id: Variant in ids:
			options.allowed_artifacts.append(StringName(String(id)))
	options.bonus_cash = int(data.get("bonus_cash", 0))
	options.bonus_debt = int(data.get("bonus_debt", 0))
	options.ante_scale = float(data.get("ante_scale", 1.0))
	options.bonus_spins = int(data.get("bonus_spins", 0))
	options.starter_id = StringName(String(data.get("starter_id", "standard")))
	options.difficulty_id = StringName(String(data.get("difficulty_id", "standard")))
	return options


func duplicate_options() -> RunOptions:
	var copy: RunOptions = RunOptions.new()
	copy.allowed_artifacts = allowed_artifacts.duplicate()
	copy.bonus_cash = bonus_cash
	copy.bonus_debt = bonus_debt
	copy.ante_scale = ante_scale
	copy.bonus_spins = bonus_spins
	copy.starter_id = starter_id
	copy.difficulty_id = difficulty_id
	return copy
