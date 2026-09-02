## The House's people, one rule each, on fixture content: what each does to
## the floor, that the collector comes once, that the same seed meets the
## same people, and that a run told nobody is coming draws nothing.
extends GdUnitTestSuite

var _state: RunState
var _cherry: SymbolDef
var _seven: SymbolDef
var _pair: Array[SymbolDef] = []


func before_test() -> void:
	_state = TestFixtures.run_state()
	_cherry = _state.content.symbol_by_id(&"cherry")
	_seven = _state.content.symbol_by_id(&"seven")
	_pair.assign([_cherry, _cherry, _seven])


func _send(rule: BossDef.Rule, magnitude: float = 0.0, symbol: StringName = &"",
		pattern: int = -1) -> BossDef:
	var boss: BossDef = BossDef.new()
	boss.id = &"someone"
	boss.display_name = "Someone"
	boss.floor = 1
	boss.rule = rule
	boss.magnitude = magnitude
	boss.symbol = symbol
	boss.pattern = pattern
	_state.boss = boss
	_state.mark_reel_dirty()
	return boss


func _mult(line: Array[SymbolDef]) -> float:
	return ArtifactEngine.evaluate_spin(_state, line, Probability.detect_pattern(line), false).multiplier


func test_a_banned_symbol_leaves_the_reel_and_comes_back_when_they_go() -> void:
	var before: float = Probability.symbol_chance(_state.reel(), &"seven")
	assert_float(before).is_greater(0.0)
	_send(BossDef.Rule.SYMBOL_BANNED, 0.0, &"seven")
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_equal(0.0)
	_state.boss = null
	_state.mark_reel_dirty()
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_equal_approx(before, 0.0001)


func test_a_heavy_symbol_lands_more() -> void:
	var before: float = Probability.symbol_chance(_state.reel(), &"cherry")
	_send(BossDef.Rule.SYMBOL_HEAVY, 20.0, &"cherry")
	assert_float(Probability.symbol_chance(_state.reel(), &"cherry")).is_greater(before)


func test_the_cooler_halves_the_good_symbols() -> void:
	var before: float = Probability.symbol_chance(_state.reel(), &"seven")
	_send(BossDef.Rule.COLD_REELS)
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_less(before)


func test_locks_cost_more_under_the_bouncer() -> void:
	_state.board.resize(3)
	_state.board.held[0] = true
	assert_int(_state.spin_price()).is_equal(2)
	_send(BossDef.Rule.HOLDS_COST_MORE, 3.0)
	assert_int(_state.spin_price()).is_equal(4)


func test_no_nudge_is_free_under_the_inspector() -> void:
	_state.acquire(TestFixtures.artifact(&"bar", ArtifactDef.Effect.NUDGE_BONUS, 2.0))
	var board: SpinBoard = _state.board
	board.resize(3)
	board.pattern = Probability.Pattern.PAIR
	SimEngine._award_nudges(_state, board)
	assert_int(board.free_nudges).is_equal(2)
	_send(BossDef.Rule.NO_FREE_NUDGES)
	SimEngine._award_nudges(_state, board)
	assert_int(board.free_nudges).is_equal(0)


func test_the_collector_charges_the_vig_halfway_and_only_once() -> void:
	var engine: SimEngine = SimEngine.new(_state.content, _state.bus)
	engine.clear_policies()
	var state: RunState = engine.start_run(3)
	# Floor one of the fixture has four spins: the collector comes on the second.
	state.economy.debt = 100
	state.economy.cash = 50
	var boss: BossDef = BossDef.new()
	boss.id = &"collector"
	boss.rule = BossDef.Rule.VIG_MID_FLOOR
	state.boss = boss
	engine.spin(state)
	assert_int(state.economy.debt_serviced).is_equal(0)
	engine.spin(state)
	assert_int(state.economy.debt_serviced).is_equal(20)
	assert_bool(state.boss_collected).is_true()
	engine.spin(state)
	assert_int(state.economy.debt_serviced).is_equal(20)
	assert_int(state.bus.count_of(EffectBus.Event.BOSS_ACTED)).is_equal(1)


func test_a_taxed_pattern_pays_its_share_and_others_pay_whole() -> void:
	_send(BossDef.Rule.PATTERN_TAXED, 0.5, &"", int(Probability.Pattern.JACKPOT))
	var jackpot: Array[SymbolDef] = []
	jackpot.assign([_cherry, _cherry, _cherry])
	assert_float(_mult(jackpot)).is_equal_approx(2.5, 0.001)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)


func test_the_meter_raises_the_ante_with_every_spin_taken() -> void:
	var engine: SimEngine = SimEngine.new(_state.content, _state.bus)
	assert_int(engine.ante_for(_state)).is_equal(5)
	_send(BossDef.Rule.ANTE_CREEPS, 10.0)
	_state.floor_spins = 2
	assert_int(engine.ante_for(_state)).is_equal(6)


func test_the_cashier_freezes_the_stake() -> void:
	_state.grant_system(Systems.STAKE)
	var engine: SimEngine = SimEngine.new(_state.content, _state.bus)
	assert_bool(engine.set_stake(_state, 3)).is_true()
	engine.set_stake(_state, 1)
	_send(BossDef.Rule.STAKE_FROZEN)
	assert_bool(engine.set_stake(_state, 3)).is_false()
	assert_int(_state.stake).is_equal(1)


func test_the_manager_skims_every_line() -> void:
	_send(BossDef.Rule.SKIMMED, 20.0)
	assert_float(_mult(_pair)).is_equal_approx(1.2, 0.001)


func _staffed_content() -> ContentDB:
	var db: ContentDB = TestFixtures.content()
	for spec: Array in [[&"a", 1, BossDef.Rule.SHORT_FLOOR, 2.0], [&"b", 1, BossDef.Rule.NO_FREE_NUDGES, 0.0],
			[&"c", 2, BossDef.Rule.SKIMMED, 10.0], [&"d", 2, BossDef.Rule.STAKE_FROZEN, 0.0]]:
		var boss: BossDef = BossDef.new()
		boss.id = spec[0]
		boss.display_name = String(spec[0])
		boss.floor = int(spec[1])
		boss.rule = spec[2]
		boss.magnitude = float(spec[3])
		db.bosses.append(boss)
	return db


func test_a_short_floor_opens_with_fewer_spins_and_names_who_took_them() -> void:
	var db: ContentDB = _staffed_content()
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	var engine: SimEngine = SimEngine.new(db, bus)
	# Find a seed whose first floor draws the timekeeper.
	var state: RunState = null
	for run_seed: int in range(1, 40):
		state = engine.start_run(run_seed)
		if state.boss != null and state.boss.id == &"a":
			break
	assert_object(state.boss).is_not_null()
	assert_str(String(state.boss.id)).is_equal("a")
	assert_int(state.spins_remaining).is_equal(2)
	assert_int(state.floor_spins_total).is_equal(2)
	var opened: Dictionary = bus.events_of(EffectBus.Event.FLOOR_STARTED).back()
	assert_str(String(opened["boss"])).is_equal("a")


func test_the_same_seed_meets_the_same_people_and_the_floor_forgets_them() -> void:
	var db: ContentDB = _staffed_content()
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var engine: SimEngine = SimEngine.new(db, bus)
	var first: RunState = engine.simulate_run(11)
	var second: RunState = engine.simulate_run(11)
	assert_array(second.bosses_faced).contains_exactly(first.bosses_faced)
	assert_int(first.bosses_faced.size()).is_greater_equal(1)
	assert_object(first.boss).is_null()


func test_told_nobody_is_coming_the_run_draws_nothing_from_the_stream() -> void:
	var db: ContentDB = _staffed_content()
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var engine: SimEngine = SimEngine.new(db, bus)
	var options: RunOptions = RunOptions.new()
	options.no_bosses = true
	var state: RunState = engine.simulate_run(11, options)
	assert_int(state.boss_rng.draws).is_equal(0)
	for id: StringName in state.bosses_faced:
		assert_str(String(id)).is_empty()
