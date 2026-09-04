extends GdUnitTestSuite

## Guardrails against a floor's mechanic quietly becoming scenery.
##
## Every one of these has been broken at least once by a change somewhere else.
## The vault was unreachable for a whole batch because the automated buyer kept
## back a single credit and arrived on every floor with nothing; the works were
## unreachable because they were priced against an ante two floors ahead. Both
## looked exactly like a balanced game from the win rate alone.

## Enough runs to reach floor seven a few times, and few enough to stay quick.
const RUNS: int = 120

var _counts: Dictionary = {}
var _reached: int = 0


func before() -> void:
	_counts.clear()
	_reached = 0
	for run: int in RUNS:
		var engine: SimEngine = SimEngine.new()
		var bus: EffectBus = engine.get_bus()
		bus.recording = true
		var state: RunState = engine.simulate_run(31000 + run)
		if state.floors_cleared >= 6:
			_reached += 1
		for kind: EffectBus.Event in [
			EffectBus.Event.REEL_NUDGED, EffectBus.Event.GAMBLE_RESOLVED,
			EffectBus.Event.VAULT_CHANGED, EffectBus.Event.CONTRACT_SIGNED,
			EffectBus.Event.WORKS_FITTED, EffectBus.Event.HEAT_CHANGED,
			EffectBus.Event.SYSTEM_GRANTED,
		]:
			_counts[kind] = int(_counts.get(kind, 0)) + bus.count_of(kind)


func _fired(kind: EffectBus.Event) -> int:
	return int(_counts.get(kind, 0))


func test_the_late_floors_are_actually_played() -> void:
	# Without this the rest of the suite passes trivially: a system nobody
	# reaches cannot be reported as unreachable.
	assert_int(_reached).is_greater(RUNS / 20)


func test_the_trail_is_walked() -> void:
	assert_int(_fired(EffectBus.Event.REEL_NUDGED)).is_greater(RUNS)


func test_the_ladder_is_climbed() -> void:
	assert_int(_fired(EffectBus.Event.GAMBLE_RESOLVED)).is_greater(RUNS)


func test_the_vault_is_used() -> void:
	assert_int(_fired(EffectBus.Event.VAULT_CHANGED)).is_greater(0)


func test_contracts_are_signed() -> void:
	assert_int(_fired(EffectBus.Event.CONTRACT_SIGNED)).is_greater(0)


func test_the_works_are_fitted() -> void:
	assert_int(_fired(EffectBus.Event.WORKS_FITTED)).is_greater(0)


func test_the_house_starts_counting() -> void:
	assert_int(_fired(EffectBus.Event.HEAT_CHANGED)).is_greater(0)


func test_every_floor_hands_something_over() -> void:
	var content: ContentDB = ContentDB.shared()
	var granted: Dictionary = {}
	for floor_def: FloorDef in content.floors:
		assert_array(floor_def.grants).override_failure_message(
				"floor %d grants nothing" % floor_def.index).is_not_empty()
		for id: StringName in floor_def.grants:
			assert_bool(Systems.ORDER.has(id)).override_failure_message(
					"floor %d grants unknown system %s" % [floor_def.index, id]).is_true()
			assert_bool(granted.has(id)).override_failure_message(
					"%s is granted twice" % id).is_false()
			granted[id] = true
	# Every system in the vocabulary is handed out by some floor. A system with
	# no floor behind it is code nobody can reach.
	for id: StringName in Systems.ORDER:
		assert_bool(granted.has(id)).override_failure_message(
				"no floor grants %s" % id).is_true()
