## What survives between runs: totals, unlocks, and the chosen ruleset.
##
## Saved as plain JSON rather than a Resource, because a save file that can be
## opened, read and hand-edited is easier to support and cannot execute anything
## on load — a .tres can carry a script path.
class_name PlayerProfile
extends RefCounted

const SAVE_PATH: String = "user://profile.json"
const VERSION: int = 1

var runs_played: int = 0
var wins: int = 0
var best_floor: int = 0
var lifetime_earned: int = 0
var debt_cleared: int = 0
## Ids of unlocks already earned, so a message is only shown once.
var unlocked: Array[StringName] = []
var selected_starter: StringName = &"standard"
var selected_difficulty: StringName = &"standard"
## Best score per ruleset key, keyed by "<ruleset>|<seed>" for daily comparison.
var records: Dictionary = {}


func stats() -> Dictionary:
	return {
		"runs_played": runs_played,
		"wins": wins,
		"best_floor": best_floor,
		"lifetime_earned": lifetime_earned,
		"debt_cleared": debt_cleared,
	}


## Folds a finished run into the profile. Returns the unlocks newly earned.
func record_run(state: RunState, catalogue: Array[UnlockDef]) -> Array[UnlockDef]:
	runs_played += 1
	if state.phase == RunState.Phase.WON:
		wins += 1
	best_floor = maxi(best_floor, state.floors_cleared)
	lifetime_earned += state.economy.lifetime_earned
	debt_cleared += maxi(0, state.config.starting_debt - state.economy.debt)
	_remember_score(state)
	return evaluate(catalogue)


## Grants every unlock whose condition is now met, and returns the new ones.
func evaluate(catalogue: Array[UnlockDef]) -> Array[UnlockDef]:
	var earned: Array[UnlockDef] = []
	var current: Dictionary = stats()
	for unlock: UnlockDef in catalogue:
		if unlocked.has(unlock.id) or not unlock.is_met(current):
			continue
		unlocked.append(unlock.id)
		earned.append(unlock)
	return earned


func has_unlock(unlock_id: StringName) -> bool:
	return unlocked.has(unlock_id)


## Artifact ids unlocked so far. Artifacts with no unlock gating them are always
## available; only the ones a catalogue entry names start locked.
func unlocked_artifacts(catalogue: Array[UnlockDef], all_artifacts: Array[ArtifactDef]) -> Array[StringName]:
	var gated: Dictionary = {}
	for unlock: UnlockDef in catalogue:
		if unlock.kind == UnlockDef.Kind.ARTIFACT:
			gated[unlock.target_id] = unlock.id
	var out: Array[StringName] = []
	for artifact: ArtifactDef in all_artifacts:
		if not gated.has(artifact.id) or unlocked.has(gated[artifact.id]):
			out.append(artifact.id)
	return out


func _remember_score(state: RunState) -> void:
	var key: String = "%s|%d" % [state.options.ruleset_key(), state.seed_value]
	var score: int = state.economy.lifetime_earned
	if not records.has(key) or int(records[key]) < score:
		records[key] = score


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for unlock_id: StringName in unlocked:
		ids.append(String(unlock_id))
	return {
		"version": VERSION,
		"runs_played": runs_played,
		"wins": wins,
		"best_floor": best_floor,
		"lifetime_earned": lifetime_earned,
		"debt_cleared": debt_cleared,
		"unlocked": ids,
		"selected_starter": String(selected_starter),
		"selected_difficulty": String(selected_difficulty),
		"records": records,
	}


static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.runs_played = int(data.get("runs_played", 0))
	profile.wins = int(data.get("wins", 0))
	profile.best_floor = int(data.get("best_floor", 0))
	profile.lifetime_earned = int(data.get("lifetime_earned", 0))
	profile.debt_cleared = int(data.get("debt_cleared", 0))
	profile.selected_starter = StringName(data.get("selected_starter", "standard"))
	profile.selected_difficulty = StringName(data.get("selected_difficulty", "standard"))
	var records: Variant = data.get("records", {})
	if records is Dictionary:
		profile.records = records
	for entry: Variant in data.get("unlocked", []):
		profile.unlocked.append(StringName(entry))
	return profile


func save(path: String = SAVE_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("PlayerProfile: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()
	return true


## Loads the profile, or returns a fresh one. A corrupt or future-version file
## is never fatal: a save that cannot be read is replaced by a new profile
## rather than taking the game down with it.
static func load_or_new(path: String = SAVE_PATH) -> PlayerProfile:
	if not FileAccess.file_exists(path):
		return PlayerProfile.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("PlayerProfile: %s is not readable, starting fresh" % path)
		return PlayerProfile.new()
	var data: Dictionary = parsed
	if int(data.get("version", 0)) > VERSION:
		push_warning("PlayerProfile: %s is from a newer build, starting fresh" % path)
		return PlayerProfile.new()
	return from_dict(data)
