extends GdUnitTestSuite

## The House's counter-offer: a run that clears the debt may stay, and the
## floors go on. These pin what staying is, what it costs, and when it ends.

var _content: ContentDB
var _engine: SimEngine


func before_test() -> void:
	_content = TestFixtures.content_with_shop()
	_content.floors.assign([
		TestFixtures.floor_granting(1, 5, 4, [Systems.CONTRACTS]),
		TestFixtures.floor_def(2, 8, 4),
	])
	for floor_def: FloorDef in _content.floors:
		floor_def.shop_slots = 1
	_content.contracts.assign([_contract(&"terms_a"), _contract(&"terms_b")])
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	_engine = SimEngine.new(_content, bus)
	_engine.clear_policies()


func _contract(id: StringName) -> ContractDef:
	var contract: ContractDef = ContractDef.new()
	contract.id = id
	contract.display_name = String(id)
	contract.min_floor = 1
	contract.boon = ContractDef.Clause.SPINS
	contract.boon_magnitude = 1.0
	return contract


## Rich enough to settle both antes and repay a debt, so the run wins.
func _rich() -> RunOptions:
	var options: RunOptions = RunOptions.new()
	options.bonus_cash = 1000
	options.bonus_debt = 100
	return options


## Steps a run with nobody at the policies: spins, opens and leaves the draft,
## signs the first contract, and wins when the floors run out.
func _play_out(state: RunState) -> void:
	var guard: int = 0
	while not state.is_over() and guard < 400:
		guard += 1
		_engine.step(state)


func _won() -> RunState:
	var state: RunState = _engine.start_run(21, _rich())
	_play_out(state)
	assert_int(state.phase).is_equal(RunState.Phase.WON)
	return state


func test_only_a_won_run_may_stay_and_only_once() -> void:
	var fresh: RunState = _engine.start_run(21, _rich())
	assert_bool(_engine.stay_at_table(fresh)).is_false()
	var state: RunState = _won()
	assert_bool(_engine.stay_at_table(state)).is_true()
	assert_bool(_engine.stay_at_table(state)).is_false()


func test_a_lost_run_is_not_offered_the_chair() -> void:
	var state: RunState = _engine.start_run(21)
	state.economy.cash = 0
	_play_out(state)
	assert_int(state.phase).is_equal(RunState.Phase.LOST)
	assert_bool(_engine.stay_at_table(state)).is_false()


func test_staying_lends_the_debt_back_and_opens_a_floor_past_the_last() -> void:
	var state: RunState = _won()
	assert_int(state.economy.debt).is_equal(0)
	assert_int(state.debt_repaid).is_equal(100)

	_engine.stay_at_table(state)
	assert_bool(state.endless).is_true()
	assert_int(state.phase).is_equal(RunState.Phase.SPINNING)
	assert_int(state.economy.debt).is_equal(100)
	assert_int(state.floor_index).is_equal(3)
	var after_hours: FloorDef = state.current_floor()
	assert_object(after_hours).is_not_null()
	assert_str(after_hours.display_name).is_equal("After Hours 1")
	assert_int(after_hours.ante).is_greater(_content.floors[1].ante)
	assert_int(state.spins_remaining).is_greater(0)
	assert_int(_engine.get_bus().count_of(EffectBus.Event.TABLE_KEPT)).is_equal(1)


func test_the_antes_after_hours_compound() -> void:
	var state: RunState = _won()
	_engine.stay_at_table(state)
	var third: int = state.floor_at(3).ante
	var fourth: int = state.floor_at(4).ante
	var fifth: int = state.floor_at(5).ante
	assert_int(fourth).is_greater(third)
	assert_int(fifth).is_greater(fourth)
	assert_float(float(fifth) / float(fourth)).is_equal_approx(
			_content.balance.endless_ante_growth, 0.02)
	# Made once, handed back the same each time.
	assert_object(state.floor_at(4)).is_same(state.floor_at(4))


func test_a_run_that_has_not_stayed_has_no_floor_past_the_last() -> void:
	var state: RunState = _engine.start_run(21, _rich())
	assert_object(state.floor_at(3)).is_null()


func test_an_endless_run_ends_when_an_ante_is_missed() -> void:
	var state: RunState = _won()
	_engine.stay_at_table(state)
	state.economy.cash = 3
	_play_out(state)
	assert_int(state.phase).is_equal(RunState.Phase.LOST)
	assert_str(String(state.end_reason)).is_equal("ante_unpaid")
	assert_bool(state.endless).is_true()
	assert_bool(bool(state.snapshot()["endless"])).is_true()


func test_the_house_closes_at_dawn() -> void:
	# A build that outgrows the ante would never miss one. The table has an
	# end anyway, and it is a win.
	_content.balance.endless_floors_max = 2
	var state: RunState = _won()
	_engine.stay_at_table(state)
	state.economy.cash = 1000000
	_play_out(state)
	assert_int(state.phase).is_equal(RunState.Phase.WON)
	assert_str(String(state.end_reason)).is_equal("dawn")
	assert_int(state.floors_cleared).is_equal(_content.floors.size() + 2)
	assert_bool(_engine.stay_at_table(state)).is_false()


func test_the_back_office_keeps_signing_after_hours() -> void:
	var state: RunState = _won()
	_engine.stay_at_table(state)
	var guard: int = 0
	while state.phase != RunState.Phase.SHOPPING and not state.is_over() and guard < 60:
		guard += 1
		_engine.step(state)
	assert_int(state.phase).is_equal(RunState.Phase.SHOPPING)
	_engine.leave_shop(state)
	assert_int(state.phase).is_equal(RunState.Phase.SIGNING)
	assert_bool(_engine.sign_contract(state, 0)).is_true()
	assert_int(state.floor_index).is_equal(4)


func test_a_batch_stays_only_when_told() -> void:
	var batch: SimEngine = SimEngine.new(_content, EffectBus.new())
	var ends: RunState = batch.simulate_run(21, _rich())
	assert_int(ends.phase).is_equal(RunState.Phase.WON)
	assert_bool(ends.endless).is_false()

	var told: RunOptions = _rich()
	told.stay_at_table = true
	var stays: RunState = batch.simulate_run(21, told)
	assert_bool(stays.is_over()).is_true()
	assert_bool(stays.endless).is_true()
	assert_int(stays.floors_cleared).is_greater(_content.floors.size())
	assert_int(stays.phase).is_equal(RunState.Phase.LOST)


func test_staying_replays_from_the_journal() -> void:
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = 21
	journal.options = _rich()
	_engine.journal = journal
	var played: RunState = _won()
	_engine.stay_at_table(played)
	_engine.spin(played)
	if played.is_deciding():
		_engine.decline_nudges(played)
		_engine.collect(played)
	_engine.journal = null

	var again: SimEngine = SimEngine.new(_content, EffectBus.new())
	again.clear_policies()
	var replayed: RunState = again.start_run(21, _rich())
	assert_int(RunJournal.replay(again, replayed, journal.entries)).is_equal(-1)
	assert_bool(replayed.endless).is_true()
	assert_dict(replayed.snapshot()).is_equal(played.snapshot())
