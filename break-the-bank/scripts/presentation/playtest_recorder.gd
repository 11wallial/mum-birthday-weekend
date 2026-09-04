## Records what a human actually did, so it can be compared with what the
## automated shop policy does on the same seed.
##
## Milestone 3 asks where player decisions diverge from simulated ones. The
## simulation already replays exactly from a seed, so the only missing half is a
## log of the human's choices: this writes one per run, and
## tools/playtest/compare.gd replays the same seed with the built-in policy and
## diffs the two.
class_name PlaytestRecorder
extends Node

const OUT_DIR: String = "user://playtests"

var _seed: int = 0
var _choices: Array[Dictionary] = []
var _started_ms: int = 0
var _last_ms: int = 0


func begin(run_seed: int) -> void:
	_seed = run_seed
	_choices.clear()
	_started_ms = Time.get_ticks_msec()
	_last_ms = _started_ms


## Deliberation time is the interesting signal in a shop: a slow purchase is a
## considered one, and that is exactly what the policy cannot model.
func _take_dwell() -> int:
	var now: int = Time.get_ticks_msec()
	var dwell: int = now - _last_ms
	_last_ms = now
	return dwell


func record_spin(state: RunState) -> void:
	_choices.append({
		"kind": "spin",
		"floor": state.floor_index,
		"spins_remaining": state.spins_remaining,
		"cash": state.economy.cash,
		"dwell_ms": _take_dwell(),
	})


func record_purchase(state: RunState, artifact: ArtifactDef, price: int) -> void:
	_choices.append({
		"kind": "buy",
		"floor": state.floor_index,
		"artifact": String(artifact.id),
		"price": price,
		"cash_after": state.economy.cash,
		"dwell_ms": _take_dwell(),
	})


## One of the new verbs, with enough context to read the decision back.
##
## A spin log was the whole record when a spin was the whole game. Now a floor
## can be lost to a nudge nobody should have paid for, a rung climbed once too
## often, or a contract signed without reading the second half — and none of
## that shows up in a list of spins.
func record_move(state: RunState, kind: StringName, detail: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"kind": String(kind),
		"floor": state.floor_index,
		"spins_remaining": state.spins_remaining,
		"cash": state.economy.cash,
		"dwell_ms": _take_dwell(),
	}
	entry.merge(detail)
	_choices.append(entry)


## What was left on the table matters as much as what was taken.
func record_leave_shop(state: RunState) -> void:
	var passed: Array[String] = []
	for i: int in state.shop_offers.size():
		passed.append("%s@%d%s" % [
			String(state.shop_offers[i].id), state.shop_prices[i],
			"" if state.can_buy(i) else " (unaffordable)"])
	_choices.append({
		"kind": "leave_shop",
		"floor": state.floor_index,
		"cash": state.economy.cash,
		"passed": passed,
		"dwell_ms": _take_dwell(),
	})


## Writes the run to user://playtests/. Returns the path, or "" on failure.
func finish(state: RunState, reason: StringName) -> String:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var record: Dictionary = {
		"seed": _seed,
		"reason": String(reason),
		"duration_ms": Time.get_ticks_msec() - _started_ms,
		"choices": _choices,
	}
	if state != null:
		record["final"] = state.snapshot()
	var path: String = "%s/run_%d_%d.json" % [OUT_DIR, _seed, Time.get_unix_time_from_system()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("PlaytestRecorder: cannot write %s" % path)
		return ""
	file.store_string(JSON.stringify(record, "  "))
	file.close()
	return path
