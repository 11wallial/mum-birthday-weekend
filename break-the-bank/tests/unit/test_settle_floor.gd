extends GdUnitTestSuite

## Settling a floor early: the one move that ends a floor on purpose, paid in
## the House's scrip. The ante's money and the draft's money stay apart.

var _engine: SimEngine
var _state: RunState


func before_test() -> void:
	var content: ContentDB = TestFixtures.content_with_shop()
	content.floors.assign([
		TestFixtures.floor_def(1, 20, 6),
		TestFixtures.floor_def(2, 40, 6),
	])
	for floor_def: FloorDef in content.floors:
		floor_def.shop_slots = 2
		floor_def.chips = 4
	_engine = SimEngine.new(content, EffectBus.new())
	_engine.get_bus().recording = true
	_engine.clear_policies()
	_state = _engine.start_run(9)


func test_a_floor_cannot_be_settled_until_the_ante_is_covered() -> void:
	_state.economy.cash = 5
	assert_bool(_state.can_settle_early()).is_false()
	assert_bool(_engine.settle_floor(_state)).is_false()
	assert_int(_state.phase).is_equal(RunState.Phase.SPINNING)
	assert_int(_state.floors_cleared).is_equal(0)


func test_settling_pays_the_stipend_and_a_chip_per_spin_left() -> void:
	_state.economy.cash = 60
	_state.spins_remaining = 4
	# A long floor, so four spins left is a settle and not a quick clear.
	_state.floor_spins_total = 20
	assert_bool(_state.can_settle_early()).is_true()
	assert_int(_state.settle_bonus(4)).is_equal(4)
	assert_bool(_engine.settle_floor(_state)).is_true()
	assert_int(_state.floors_cleared).is_equal(1)
	assert_int(_state.phase).is_equal(RunState.Phase.SHOPPING)
	# Four for the floor, four for the spins, and interest on the eight.
	assert_int(_state.economy.chips_from_floors).is_equal(4)
	assert_int(_state.economy.chips_from_settling).is_equal(4)
	assert_int(_state.economy.chips).is_equal(8 + _state.economy.chips_from_interest)
	assert_int(_state.economy.cash).is_equal(40)
	var early: Array[Dictionary] = _engine.get_bus().events_of(
			EffectBus.Event.FLOOR_SETTLED_EARLY)
	assert_int(early.size()).is_equal(1)
	assert_int(int(early[0]["spins_left"])).is_equal(4)


func test_the_spins_left_bonus_is_capped() -> void:
	_state.config.chips_spin_left_cap = 2
	_state.floor_spins_total = 20
	assert_int(_state.settle_bonus(6)).is_equal(2)


func test_a_floor_played_out_earns_no_settle_bonus() -> void:
	_state.economy.cash = 60
	_state.spins_remaining = 0
	assert_bool(_state.can_settle_early()).is_false()
	_engine.step(_state)
	assert_int(_state.floors_cleared).is_equal(1)
	assert_int(_state.economy.chips_from_settling).is_equal(0)
	assert_int(_state.economy.chips_from_floors).is_equal(4)


func test_settling_is_refused_mid_decision() -> void:
	_state.economy.cash = 60
	_state.decision = RunState.Decision.GAMBLE
	assert_bool(_state.can_settle_early()).is_false()
	assert_bool(_engine.settle_floor(_state)).is_false()


func test_settling_replays_from_the_journal() -> void:
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = 9
	_engine.journal = journal
	_state.economy.cash = 60
	_engine.settle_floor(_state)
	assert_array(journal.entries).contains([["settle_floor"]])
	var again: SimEngine = SimEngine.new(TestFixtures.content_with_shop(), EffectBus.new())
	again.clear_policies()
	var replayed: RunState = again.start_run(9)
	replayed.economy.cash = 60
	assert_int(RunJournal.replay(again, replayed, journal.entries)).is_equal(-1)
	assert_int(replayed.floors_cleared).is_equal(1)


func test_the_bank_symbol_pays_chips_on_the_line() -> void:
	var bank: SymbolDef = TestFixtures.symbol(&"bank", 5, 1)
	bank.chip_value = 1
	_state.board.resize(3)
	_state.board.set_column(0, null, bank, null)
	_state.board.set_column(1, null, bank, null)
	_state.board.set_column(2, null, TestFixtures.symbol(&"cherry", 2, 1, &"fruit"), null)
	_engine._resolve_board(_state, false)
	assert_int(_state.board.chips).is_equal(2)
	var before: int = _state.economy.chips
	_engine.collect(_state)
	assert_int(_state.economy.chips).is_equal(before + 2)
	assert_int(_state.economy.chips_from_symbols).is_equal(2)


func test_a_quick_clear_pays_its_bonus_twice() -> void:
	_state.economy.cash = 60
	_state.floor_spins_total = 6
	assert_bool(_state.is_quick_clear(3)).is_true()
	assert_bool(_state.is_quick_clear(2)).is_false()
	assert_int(_state.settle_bonus(2)).is_equal(2)
	assert_int(_state.settle_bonus(3)).is_equal(6)
