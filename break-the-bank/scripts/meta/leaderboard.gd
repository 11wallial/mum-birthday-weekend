## Local leaderboard telemetry.
##
## Scores are written to a local JSON file. There is no server here and this
## does not talk to one: submit() is the single seam a backend would replace,
## and everything above it already carries what a remote board would need — the
## seed, the ruleset key, and whether the run was that day's challenge.
class_name Leaderboard
extends RefCounted

const SAVE_PATH: String = "user://leaderboard.json"
## Rows kept per ruleset. Local boards are for comparing with yourself.
const KEEP_PER_RULESET: int = 50

var entries: Array[Dictionary] = []


## Adds a finished run. Returns the entry as stored.
func submit(state: RunState, daily_key: String = "") -> Dictionary:
	var entry: Dictionary = {
		"seed": state.seed_value,
		"code": SeedBook.to_code(state.seed_value),
		"ruleset": state.options.ruleset_key(),
		"score": state.economy.lifetime_earned,
		"floors": state.floors_cleared,
		"spins": state.spins_taken,
		"won": state.phase == RunState.Phase.WON or state.endless,
		"endless": state.endless,
		"reason": String(state.end_reason),
		"date": Time.get_datetime_string_from_system(true, true),
		"daily": daily_key,
	}
	entries.append(entry)
	_trim()
	return entry


## Best rows first, optionally filtered to one ruleset and/or one daily key.
func top(count: int = 10, ruleset: String = "", daily_key: String = "") -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if not ruleset.is_empty() and String(entry.get("ruleset", "")) != ruleset:
			continue
		if not daily_key.is_empty() and String(entry.get("daily", "")) != daily_key:
			continue
		rows.append(entry)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return rows.slice(0, mini(count, rows.size()))


## Rank of [param score] within a ruleset, 1-based. Zero when the board is empty.
func rank_of(score: int, ruleset: String) -> int:
	var rows: Array[Dictionary] = top(KEEP_PER_RULESET, ruleset)
	for i: int in rows.size():
		if int(rows[i]["score"]) <= score:
			return i + 1
	return rows.size() + 1


func _trim() -> void:
	var by_ruleset: Dictionary = {}
	for entry: Dictionary in entries:
		var key: String = String(entry.get("ruleset", ""))
		if not by_ruleset.has(key):
			by_ruleset[key] = []
		(by_ruleset[key] as Array).append(entry)
	var kept: Array[Dictionary] = []
	for key: String in by_ruleset:
		var rows: Array = by_ruleset[key]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
		for entry: Variant in rows.slice(0, mini(KEEP_PER_RULESET, rows.size())):
			kept.append(entry)
	entries = kept


func save(path: String = SAVE_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Leaderboard: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify({"entries": entries}, "  "))
	file.close()
	return true


static func load_or_new(path: String = SAVE_PATH) -> Leaderboard:
	var board: Leaderboard = Leaderboard.new()
	if not FileAccess.file_exists(path):
		return board
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return board
	for entry: Variant in (parsed as Dictionary).get("entries", []):
		if entry is Dictionary:
			board.entries.append(entry)
	return board
