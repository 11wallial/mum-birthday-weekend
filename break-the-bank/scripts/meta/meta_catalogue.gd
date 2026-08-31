## Loads the unlock catalogue and turns a profile into [RunOptions].
##
## This is the only place that knows how meta-progression reaches a run; the
## simulation just receives options it cannot tell the origin of.
class_name MetaCatalogue
extends RefCounted

const UNLOCK_DIR: String = "res://resources/meta/unlocks"

## Starter variants. The standard one is always available.
const STARTERS: Dictionary = {
	&"standard": {"name": "Standard", "cash": 0, "debt": 0, "spins": 0},
	&"flush": {"name": "Flush Start", "cash": 25, "debt": 60, "spins": 0},
	&"lean": {"name": "Lean Start", "cash": -6, "debt": -60, "spins": 1},
}
## Difficulty modifiers, as ante scale.
const DIFFICULTIES: Dictionary = {
	&"standard": {"name": "Standard", "ante_scale": 1.0},
	&"marked_deck": {"name": "Marked Deck", "ante_scale": 1.25},
	&"house_rules": {"name": "House Rules", "ante_scale": 1.6},
}

var unlocks: Array[UnlockDef] = []


func load_all() -> void:
	unlocks.clear()
	var dir: DirAccess = DirAccess.open(UNLOCK_DIR)
	if dir == null:
		push_warning("MetaCatalogue: missing %s" % UNLOCK_DIR)
		return
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var unlock: UnlockDef = load("%s/%s" % [UNLOCK_DIR, clean]) as UnlockDef
		if unlock != null:
			unlocks.append(unlock)


## Builds the options a run should start with for [param profile].
func options_for(profile: PlayerProfile, content: ContentDB) -> RunOptions:
	var options: RunOptions = RunOptions.new()
	options.allowed_artifacts = profile.unlocked_artifacts(unlocks, content.artifacts)
	var starter: Dictionary = STARTERS.get(profile.selected_starter, STARTERS[&"standard"])
	options.bonus_cash = int(starter["cash"])
	options.bonus_debt = int(starter["debt"])
	options.bonus_spins = int(starter["spins"])
	options.starter_id = profile.selected_starter
	var difficulty: Dictionary = DIFFICULTIES.get(
			profile.selected_difficulty, DIFFICULTIES[&"standard"])
	options.ante_scale = float(difficulty["ante_scale"])
	options.difficulty_id = profile.selected_difficulty
	return options


## Starter ids the profile may choose: standard, plus any it has unlocked.
func available_starters(profile: PlayerProfile) -> Array[StringName]:
	return _available(profile, UnlockDef.Kind.STARTER, STARTERS)


func available_difficulties(profile: PlayerProfile) -> Array[StringName]:
	return _available(profile, UnlockDef.Kind.DIFFICULTY, DIFFICULTIES)


func _available(profile: PlayerProfile, kind: UnlockDef.Kind, table: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = [&"standard"]
	for unlock: UnlockDef in unlocks:
		if unlock.kind != kind or not profile.has_unlock(unlock.id):
			continue
		if table.has(unlock.target_id) and not out.has(unlock.target_id):
			out.append(unlock.target_id)
	return out
