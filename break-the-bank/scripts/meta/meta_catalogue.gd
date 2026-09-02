## Loads everything between runs — unlocks, the ladder, the challenges — and
## turns a profile into [RunOptions].
##
## This is the only place that knows how meta-progression reaches a run; the
## simulation just receives options it cannot tell the origin of.
class_name MetaCatalogue
extends RefCounted

const UNLOCK_DIR: String = "res://resources/meta/unlocks"
const DIFFICULTY_DIR: String = "res://resources/meta/difficulties"
const CHALLENGE_DIR: String = "res://resources/meta/challenges"
const MACHINE_DIR: String = "res://resources/meta/machines"

var unlocks: Array[UnlockDef] = []
## The House's machines, standard first. What a run starts on.
var machines: Array[MachineDef] = []
## The ladder, bottom rung first.
var difficulties: Array[DifficultyDef] = []
var challenges: Array[ChallengeDef] = []


func load_all() -> void:
	unlocks.assign(_load_dir(UNLOCK_DIR))
	difficulties.assign(_load_dir(DIFFICULTY_DIR))
	difficulties.sort_custom(func(a: DifficultyDef, b: DifficultyDef) -> bool: return a.tier < b.tier)
	challenges.assign(_load_dir(CHALLENGE_DIR))
	challenges.sort_custom(func(a: ChallengeDef, b: ChallengeDef) -> bool: return String(a.id) < String(b.id))
	machines.assign(_load_dir(MACHINE_DIR))


func machine_by_id(id: StringName) -> MachineDef:
	for machine: MachineDef in machines:
		if machine.id == id:
			return machine
	return null


func difficulty_by_id(id: StringName) -> DifficultyDef:
	for difficulty: DifficultyDef in difficulties:
		if difficulty.id == id:
			return difficulty
	return null


func challenge_by_id(id: StringName) -> ChallengeDef:
	for challenge: ChallengeDef in challenges:
		if challenge.id == id:
			return challenge
	return null


## Builds the options a run should start with for [param profile].
##
## A challenge is a whole ruleset of its own, so the starter and the audit are
## set aside for it; otherwise the starter's numbers go on first and the
## audit's rules on top.
func options_for(profile: PlayerProfile, content: ContentDB) -> RunOptions:
	var allowed: Array[StringName] = profile.unlocked_artifacts(unlocks, content.artifacts)
	if profile.selected_challenge != &"":
		var challenge: ChallengeDef = challenge_by_id(profile.selected_challenge)
		if challenge != null:
			return challenge.options_for(allowed)
	var options: RunOptions = RunOptions.new()
	options.allowed_artifacts = allowed
	var machine: MachineDef = machine_by_id(profile.selected_starter)
	if machine == null:
		machine = machine_by_id(&"standard")
	if machine != null:
		options = machine.apply_to(options)
	var difficulty: DifficultyDef = difficulty_by_id(profile.selected_difficulty)
	if difficulty == null:
		options.difficulty_id = &"standard"
		return options
	return difficulty.apply_to(options)


## The options for one rung of the ladder with nothing else restricted, which
## is what the lab measures a tier with.
func options_for_difficulty(id: StringName) -> RunOptions:
	var difficulty: DifficultyDef = difficulty_by_id(id)
	if difficulty == null:
		return RunOptions.new()
	return difficulty.apply_to(RunOptions.new())


## The options for one machine with nothing else changed, which is what the
## lab measures a machine with.
func options_for_machine(id: StringName) -> RunOptions:
	var machine: MachineDef = machine_by_id(id)
	if machine == null:
		return RunOptions.new()
	return machine.apply_to(RunOptions.new())


## The options for one challenge with the whole content set allowed.
func options_for_challenge(id: StringName) -> RunOptions:
	var challenge: ChallengeDef = challenge_by_id(id)
	if challenge == null:
		return RunOptions.new()
	return challenge.options_for([])


## Machine ids the profile may choose: the standard, plus any an unlock has
## opened, in the catalogue's order.
func available_starters(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	for machine: MachineDef in machines:
		if machine.id == &"standard" or _unlocked_target(profile, UnlockDef.Kind.STARTER, machine.id):
			out.append(machine.id)
	if out.is_empty():
		out.append(&"standard")
	return out


## Rungs of the ladder the profile may choose, bottom first: the first rung,
## plus every one an unlock has opened.
func available_difficulties(profile: PlayerProfile) -> Array[StringName]:
	var ids: Array = []
	for difficulty: DifficultyDef in difficulties:
		ids.append(difficulty.id)
	var out: Array[StringName] = []
	for id: Variant in ids:
		var rung: DifficultyDef = difficulty_by_id(id)
		if rung.tier <= 1 or _unlocked_target(profile, UnlockDef.Kind.DIFFICULTY, id):
			out.append(id)
	if out.is_empty():
		out.append(&"standard")
	return out


## Challenges the profile has opened, by id.
func available_challenges(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	for challenge: ChallengeDef in challenges:
		if _unlocked_target(profile, UnlockDef.Kind.CHALLENGE, challenge.id):
			out.append(challenge.id)
	return out


func _available(profile: PlayerProfile, kind: UnlockDef.Kind, known: Array) -> Array[StringName]:
	var out: Array[StringName] = [&"standard"]
	for unlock: UnlockDef in unlocks:
		if unlock.kind != kind or not profile.has_unlock(unlock.id):
			continue
		if known.has(unlock.target_id) and not out.has(unlock.target_id):
			out.append(unlock.target_id)
	return out


func _unlocked_target(profile: PlayerProfile, kind: UnlockDef.Kind, target: StringName) -> bool:
	for unlock: UnlockDef in unlocks:
		if unlock.kind == kind and unlock.target_id == target and profile.has_unlock(unlock.id):
			return true
	return false


## Every resource in [param dir_path], sorted by filename for load-order
## determinism, the same way [ContentDB] reads its directories.
func _load_dir(dir_path: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("MetaCatalogue: missing %s" % dir_path)
		return out
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var resource: Resource = load("%s/%s" % [dir_path, clean])
		if resource != null:
			out.append(resource)
	return out
