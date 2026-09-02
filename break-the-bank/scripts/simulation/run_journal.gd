## Every verb a run was driven by, in order, so the run can be rebuilt from its
## seed by playing the same verbs into a fresh engine.
##
## A save is a seed and this log. The simulation is deterministic — named RNG
## streams, no clock, no input — so replaying the log headlessly lands on the
## exact state the player left, in milliseconds, without serialising a single
## field of [RunState]. That is the whole design: the state has no save format
## to version, because the verbs are the format, and a verb the engine has
## stopped understanding is a save that says so rather than one that loads
## into a run nobody played.
class_name RunJournal
extends RefCounted

const VERSION: int = 1

## The seed and options the run was started with, so a replay begins from the
## same place, and the daily key when the run was that day's challenge.
var seed_value: int = 0
var options: RunOptions = RunOptions.new()
var daily_key: String = ""
## Entries are [verb, args...], the verb a String and every argument an int,
## so JSON round-trips them unchanged.
var entries: Array = []


func record(verb: StringName, args: Array = []) -> void:
	var entry: Array = [String(verb)]
	for arg: Variant in args:
		entry.append(int(arg))
	entries.append(entry)


## Plays [param entries] into [param engine] against [param state].
##
## Returns -1 when the whole log replayed, or the index of the first entry that
## could not be: a verb the engine no longer has, or one that arrived after the
## run had already ended — which is what a balance change looks like from
## inside a save, and the caller's cue to start fresh rather than resume a run
## that is no longer the one the player was playing.
static func replay(engine: SimEngine, state: RunState, entries: Array) -> int:
	for i: int in entries.size():
		var entry: Variant = entries[i]
		if not (entry is Array) or (entry as Array).is_empty():
			return i
		# A won run can still take the House's offer; every other verb needs a
		# live one.
		if state.is_over() and String((entry as Array)[0]) != "stay_at_table":
			return i
		if not _apply(engine, state, entry as Array):
			return i
	return -1


## One verb into the engine. Returns false only for a verb this replayer does
## not know: a refused move is replayed as a refused move, because the player
## made it and the engine said no then too.
static func _apply(engine: SimEngine, state: RunState, entry: Array) -> bool:
	var verb: String = String(entry[0])
	var arg: int = int(entry[1]) if entry.size() > 1 else 0
	match verb:
		"spin":
			if state.phase == RunState.Phase.SPINNING and not state.is_deciding() \
					and state.economy.can_afford(state.spin_price()):
				engine.spin(state)
		"step":
			engine.step(state)
		"toggle_hold":
			engine.toggle_hold(state, arg)
		"nudge":
			engine.nudge(state, arg)
		"decline_nudges":
			engine.decline_nudges(state)
		"gamble":
			engine.gamble(state)
		"collect":
			engine.collect(state)
		"set_stake":
			engine.set_stake(state, arg)
		"deposit":
			engine.deposit(state, arg)
		"withdraw":
			engine.withdraw(state, arg)
		"buy_reel":
			engine.buy_reel(state)
		"buy_row":
			engine.buy_row(state)
		"launder":
			engine.launder(state)
		"buy_offer":
			engine.buy_offer(state, arg)
		"leave_shop":
			engine.leave_shop(state)
		"reroll_shop":
			engine.reroll_shop(state)
		"sell":
			engine.sell(state, arg)
		"buy_on_slate":
			engine.buy_on_slate(state, arg)
		"sign_contract":
			engine.sign_contract(state, arg)
		"stay_at_table":
			engine.stay_at_table(state)
		_:
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"seed": seed_value,
		"daily": daily_key,
		"options": options.to_dict(),
		"entries": entries.duplicate(true),
	}


## Reads a journal back. Returns null for anything that is not one of ours, or
## that a newer build wrote.
static func from_dict(data: Dictionary) -> RunJournal:
	if int(data.get("version", 0)) > VERSION or not data.has("seed"):
		return null
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = int(data.get("seed", 0))
	journal.daily_key = String(data.get("daily", ""))
	var options: Variant = data.get("options", {})
	journal.options = RunOptions.from_dict(options if options is Dictionary else {})
	var entries: Variant = data.get("entries", [])
	if entries is Array:
		for entry: Variant in entries:
			if entry is Array and not (entry as Array).is_empty():
				journal.entries.append(entry)
	return journal
