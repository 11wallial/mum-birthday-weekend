extends GdUnitTestSuite

## Replayability is the property the whole balance pipeline rests on: a seed has
## to produce the same run today and after an unrelated system changes.


func _engine() -> SimEngine:
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	return SimEngine.new(TestFixtures.content(), bus)


func test_the_same_seed_produces_the_same_run() -> void:
	var first: RunState = _engine().simulate_run(2024)
	var second: RunState = _engine().simulate_run(2024)
	assert_dict(first.snapshot()).is_equal(second.snapshot())


func test_different_seeds_diverge() -> void:
	var seen: Dictionary = {}
	for run_seed: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		seen[JSON.stringify(_engine().simulate_run(run_seed).snapshot())] = true
	assert_int(seen.size()).is_greater(1)


func test_every_run_terminates_in_a_final_phase() -> void:
	for run_seed: int in range(1, 60):
		var state: RunState = _engine().simulate_run(run_seed)
		assert_bool(state.is_over()).is_true()
		assert_str(String(state.end_reason)).is_not_equal("nonterminating")


func test_spins_consume_the_seeded_reel_stream() -> void:
	# A run whose reels never touch reel_rng is drawing from somewhere else, and
	# nothing above this line would notice: the snapshots would still match in
	# shape while the money diverged.
	var state: RunState = _engine().simulate_run(7)
	assert_int(state.spins_taken).is_greater(0)
	assert_int(state.reel_rng.draws).is_greater_equal(state.spins_taken)


func test_a_muted_bus_records_nothing() -> void:
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	bus.recording = true
	SimEngine.new(TestFixtures.content(), bus).simulate_run(11)
	assert_array(bus.event_log).is_empty()


func test_a_recording_bus_sees_the_whole_run() -> void:
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	var state: RunState = SimEngine.new(TestFixtures.content(), bus).simulate_run(11)
	assert_int(bus.count_of(EffectBus.Event.RUN_STARTED)).is_equal(1)
	assert_int(bus.count_of(EffectBus.Event.RUN_ENDED)).is_equal(1)
	assert_int(bus.count_of(EffectBus.Event.SPIN_STARTED)).is_equal(state.spins_taken)
	assert_int(bus.count_of(EffectBus.Event.PAYOUT_CALCULATED)).is_equal(state.spins_taken)


func test_shipped_content_loads_and_plays() -> void:
	var content: ContentDB = ContentDB.shared()
	assert_array(content.symbols).is_not_empty()
	assert_array(content.artifacts).is_not_empty()
	assert_int(content.floors.size()).is_equal(7)
	assert_object(content.floor_at(1)).is_not_null()

	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var state: RunState = SimEngine.new(content, bus).simulate_run(1)
	assert_bool(state.is_over()).is_true()
	assert_int(state.spins_taken).is_greater(0)
