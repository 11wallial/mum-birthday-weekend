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
## Floors cleared past the last, on the run that stayed at the table longest.
var deepest_after_hours: int = 0
## The lifetime ledger: what a player has done to the House, in numbers meant
## to be looked at and, in the vig's case, shared.
var total_spins: int = 0
var biggest_spin: int = 0
var vig_paid: int = 0
## Runs and wins per rung of the ladder, keyed by difficulty id. Challenge
## runs are kept out of it: a win under a rule of its own is not a win on the
## ladder, in either direction.
var runs_by_difficulty: Dictionary = {}
var wins_by_difficulty: Dictionary = {}
## Times each artifact has been owned at the end of a run, keyed by id.
var artifact_picks: Dictionary = {}
## Ids of unlocks already earned, so a message is only shown once.
var unlocked: Array[StringName] = []
var selected_starter: StringName = &"standard"
var selected_difficulty: StringName = &"standard"
## The challenge chosen for the next run, or empty for the ordinary game.
var selected_challenge: StringName = &""
## Best score per ruleset key, keyed by "<ruleset>|<seed>" for daily comparison.
var records: Dictionary = {}
## Volume per bus in dB and the pace of the reels, as the title's settings
## panel keeps them. Presentation reads these; the simulation never does.
var settings: Dictionary = {}
## Whether the guided first run has been played through or skipped, so the
## Clerk only walks a debtor through the basement once unless asked.
var tutorial_seen: bool = false
## The collection: everything this profile has met, by kind then id —
## hardware offered or owned, the House's people faced, contracts signed.
## A codex of silhouettes fills in from this; nothing else reads it.
var seen: Dictionary = {"artifacts": {}, "bosses": {}, "contracts": {}, "chits": {}, "skins": {}}


func stats() -> Dictionary:
	var out: Dictionary = {
		"runs_played": runs_played,
		"wins": wins,
		"best_floor": best_floor,
		"lifetime_earned": lifetime_earned,
		"debt_cleared": debt_cleared,
		"deepest_after_hours": deepest_after_hours,
	}
	for id: Variant in wins_by_difficulty:
		out["wins_at:%s" % String(id)] = int(wins_by_difficulty[id])
	return out


## The artifact owned at the end of more runs than any other, or empty.
func favourite_artifact() -> StringName:
	var best: StringName = &""
	var most: int = 0
	for id: Variant in artifact_picks:
		if int(artifact_picks[id]) > most:
			most = int(artifact_picks[id])
			best = StringName(String(id))
	return best


## Folds a finished run into the profile. Returns the unlocks newly earned.
func record_run(state: RunState, catalogue: Array[UnlockDef]) -> Array[UnlockDef]:
	runs_played += 1
	if state.phase == RunState.Phase.WON:
		wins += 1
	best_floor = maxi(best_floor, state.floors_cleared)
	lifetime_earned += state.economy.lifetime_earned
	debt_cleared += maxi(0, state.config.starting_debt - state.economy.debt)
	total_spins += state.spins_taken
	biggest_spin = maxi(biggest_spin, state.best_payout)
	vig_paid += state.economy.debt_serviced
	for artifact: ArtifactDef in state.owned:
		var key: String = String(artifact.id)
		artifact_picks[key] = int(artifact_picks.get(key, 0)) + 1
	note_seen_run(state)
	if state.options.challenge_id == &"":
		var rung: String = String(state.options.difficulty_id)
		runs_by_difficulty[rung] = int(runs_by_difficulty.get(rung, 0)) + 1
		if state.phase == RunState.Phase.WON:
			wins_by_difficulty[rung] = int(wins_by_difficulty.get(rung, 0)) + 1
	_remember_score(state)
	return evaluate(catalogue)


## Folds a run's sightings into the collection: what was on the draft or
## the machine, who was on the floors, what was signed for.
func note_seen_run(state: RunState) -> void:
	for offered: StringName in state.offers_seen:
		note_seen("artifacts", offered)
	for artifact: ArtifactDef in state.owned:
		note_seen("artifacts", artifact.id)
	for boss_id: StringName in state.bosses_faced:
		if boss_id != &"":
			note_seen("bosses", boss_id)
	for contract_id: StringName in state.contracts_signed:
		note_seen("contracts", contract_id)
	for chit: ChitDef in state.pocket:
		note_seen("chits", chit.id)
	for skin_id: StringName in state.skins_seen:
		note_seen("skins", skin_id)


## Records one sighting. Returns true the first time, so the room can say so.
func note_seen(kind: String, id: StringName) -> bool:
	if not seen.has(kind):
		seen[kind] = {}
	var table: Dictionary = seen[kind]
	if table.has(String(id)):
		return false
	table[String(id)] = true
	return true


func has_seen(kind: String, id: StringName) -> bool:
	return seen.has(kind) and (seen[kind] as Dictionary).has(String(id))


func seen_count(kind: String) -> int:
	return (seen[kind] as Dictionary).size() if seen.has(kind) else 0


## Folds in what a run earned after it won and stayed at the table. The win
## was recorded when it happened; this is only what came after, so nothing is
## counted twice.
func record_stayed(state: RunState, content_floors: int) -> void:
	lifetime_earned += maxi(0, state.economy.lifetime_earned - state.earned_at_win)
	best_floor = maxi(best_floor, state.floors_cleared)
	deepest_after_hours = maxi(deepest_after_hours, state.floors_cleared - content_floors)
	_remember_score(state)


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


## Chit ids unlocked so far, the same way: ungated paper is always dealt.
func unlocked_chits(catalogue: Array[UnlockDef], all_chits: Array[ChitDef]) -> Array[StringName]:
	var gated: Dictionary = {}
	for unlock: UnlockDef in catalogue:
		if unlock.kind == UnlockDef.Kind.CHIT:
			gated[unlock.target_id] = unlock.id
	var out: Array[StringName] = []
	for chit: ChitDef in all_chits:
		if not gated.has(chit.id) or unlocked.has(gated[chit.id]):
			out.append(chit.id)
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
		"deepest_after_hours": deepest_after_hours,
		"total_spins": total_spins,
		"biggest_spin": biggest_spin,
		"vig_paid": vig_paid,
		"runs_by_difficulty": runs_by_difficulty,
		"wins_by_difficulty": wins_by_difficulty,
		"artifact_picks": artifact_picks,
		"unlocked": ids,
		"selected_starter": String(selected_starter),
		"selected_difficulty": String(selected_difficulty),
		"selected_challenge": String(selected_challenge),
		"records": records,
		"settings": settings,
		"tutorial_seen": tutorial_seen,
		"seen": seen,
	}


## A number out of a save that may not contain one. A profile written by
## an older build, a half-flushed disk or a text editor can hold a string,
## a list or nothing at all where a count belongs, and casting that with
## int() takes the game down — which the torture suite proved before this
## existed.
static func _number(data: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = data.get(key, fallback)
	if value is int or value is float:
		return int(clampf(float(value), -9.0e15, 9.0e15))
	if value is String and (value as String).is_valid_int():
		return int(value)
	return fallback


static func _flag(data: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = data.get(key, fallback)
	return bool(value) if (value is bool or value is int or value is float) else fallback


static func _text(data: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = data.get(key, fallback)
	return String(value) if value is String else fallback


static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.runs_played = _number(data, "runs_played")
	profile.wins = _number(data, "wins")
	profile.best_floor = _number(data, "best_floor")
	profile.lifetime_earned = _number(data, "lifetime_earned")
	profile.debt_cleared = _number(data, "debt_cleared")
	profile.deepest_after_hours = _number(data, "deepest_after_hours")
	profile.total_spins = _number(data, "total_spins")
	profile.biggest_spin = _number(data, "biggest_spin")
	profile.vig_paid = _number(data, "vig_paid")
	profile.selected_starter = StringName(_text(data, "selected_starter", "standard"))
	profile.selected_difficulty = StringName(_text(data, "selected_difficulty", "standard"))
	profile.selected_challenge = StringName(_text(data, "selected_challenge", ""))
	for key: String in ["runs_by_difficulty", "wins_by_difficulty", "artifact_picks",
			"records", "settings", "seen"]:
		var table: Variant = data.get(key, {})
		if table is Dictionary:
			profile.set(key, table)
	profile.tutorial_seen = _flag(data, "tutorial_seen")
	var unlocked: Variant = data.get("unlocked", [])
	if unlocked is Array:
		for entry: Variant in unlocked:
			if entry is String:
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
	if _number(data, "version") > VERSION:
		push_warning("PlayerProfile: %s is from a newer build, starting fresh" % path)
		return PlayerProfile.new()
	return from_dict(data)
