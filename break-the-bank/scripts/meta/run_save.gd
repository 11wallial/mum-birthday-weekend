## The run in progress, on disk, so closing the game does not lose it.
##
## Stored as a [RunJournal]: the seed, the options, and every verb the player
## has used, replayed headlessly on load. Plain JSON, like the profile, for the
## same reasons — readable, hand-editable, and unable to execute anything. A
## file that cannot be read, that a newer build wrote, or that was played
## against a different content set is not resumed; it is set aside and the
## game starts fresh, which is the rule every loader here follows.
class_name RunSave
extends RefCounted

const SAVE_PATH: String = "user://run_in_progress.json"
const VERSION: int = 1


## Writes [param journal] as the run to resume. Returns false when it could not.
static func write(journal: RunJournal, content: ContentDB, path: String = SAVE_PATH) -> bool:
	var data: Dictionary = journal.to_dict()
	data["save_version"] = VERSION
	data["content"] = fingerprint(content)
	data["saved_at"] = Time.get_datetime_string_from_system(true, true)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("RunSave: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true


## The saved run, or null when there is nothing worth resuming: no file, a file
## that is not ours, one from a newer build, or one played against content
## that has since changed — a replayed log against different content is a
## different run, and quietly handing the player that would be worse than a
## fresh start.
static func read(content: ContentDB, path: String = SAVE_PATH) -> RunJournal:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("RunSave: %s is not readable, starting fresh" % path)
		return null
	var data: Dictionary = parsed
	var version: Variant = data.get("save_version", 0)
	if not (version is int or version is float) or int(version) > VERSION:
		push_warning("RunSave: %s is from a newer build, starting fresh" % path)
		return null
	var stamp: Variant = data.get("content", "")
	if not (stamp is String) or String(stamp) != fingerprint(content):
		push_warning("RunSave: %s was played against different content, starting fresh" % path)
		return null
	return RunJournal.from_dict(data)


## Forgets the run in progress. Called when it ends, or is abandoned.
static func clear(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## A short signature of the content a run is played against: every id, and
## the numbers that change what a replayed verb does. Two builds with the same
## fingerprint replay the same log to the same run.
static func fingerprint(content: ContentDB) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for symbol: SymbolDef in content.symbols:
		parts.append("%s:%d:%d" % [symbol.id, symbol.base_value, symbol.base_weight])
	for artifact: ArtifactDef in content.artifacts:
		parts.append("%s:%d:%s:%s:%d" % [artifact.id, artifact.effect,
				artifact.magnitude, artifact.cap, artifact.min_floor])
	for contract: ContractDef in content.contracts:
		parts.append("%s:%d:%s:%d:%s" % [contract.id, contract.boon,
				contract.boon_magnitude, contract.toll, contract.toll_magnitude])
	for floor_def: FloorDef in content.floors:
		parts.append("%d:%d:%d" % [floor_def.index, floor_def.ante, floor_def.spins])
	for boss: BossDef in content.bosses:
		parts.append("%s:%d:%d:%s" % [boss.id, boss.floor, boss.rule, boss.magnitude])
	parts.append("%d:%d:%d:%d" % [content.balance.reel_count, content.balance.starting_cash,
			content.balance.starting_debt, content.balance.spin_cost])
	return "%x" % ("|".join(parts)).hash()
