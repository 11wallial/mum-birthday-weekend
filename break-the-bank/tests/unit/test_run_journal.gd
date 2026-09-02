extends GdUnitTestSuite

## A save is a seed and a log of verbs. These pin the property the design
## rests on: playing the same verbs into a fresh engine lands on the same run,
## whoever was holding the handle.

var _content: ContentDB


func before_test() -> void:
	_content = TestFixtures.content_with_shop()
	var everything: Array[StringName] = [
		Systems.HOLD, Systems.MARKET, Systems.STAKE, Systems.GAMBLE,
		Systems.VAULT, Systems.CONTRACTS, Systems.EXPANSION, Systems.HEAT,
	]
	_content.floors.assign([
		TestFixtures.floor_granting(1, 20, 6, everything),
		TestFixtures.floor_granting(2, 40, 6, []),
		TestFixtures.floor_granting(3, 60, 6, []),
	])
	for floor_def: FloorDef in _content.floors:
		floor_def.shop_slots = 2
	_content.contracts.assign([_contract(&"terms_a"), _contract(&"terms_b")])


func _contract(id: StringName) -> ContractDef:
	var contract: ContractDef = ContractDef.new()
	contract.id = id
	contract.display_name = String(id)
	contract.min_floor = 1
	contract.boon = ContractDef.Clause.SPINS
	contract.boon_magnitude = 1.0
	return contract


## An engine with a person at the machine: no policies, a journal attached.
func _human_engine(journal: RunJournal) -> SimEngine:
	var engine: SimEngine = SimEngine.new(_content, EffectBus.new())
	engine.clear_policies()
	engine.journal = journal
	return engine


func _rich() -> RunOptions:
	var options: RunOptions = RunOptions.new()
	options.bonus_cash = 400
	options.starter_id = &"flush"
	return options


func _line_ids(state: RunState) -> Array[String]:
	var out: Array[String] = []
	for symbol: SymbolDef in state.board.line:
		out.append(String(symbol.id) if symbol != null else "")
	return out


func _same_run(expected: RunState, actual: RunState) -> void:
	assert_dict(actual.snapshot()).is_equal(expected.snapshot())
	assert_int(actual.reel_rng.draws).is_equal(expected.reel_rng.draws)
	assert_int(actual.band_rng.draws).is_equal(expected.band_rng.draws)
	assert_int(actual.shop_rng.draws).is_equal(expected.shop_rng.draws)
	assert_int(actual.gamble_rng.draws).is_equal(expected.gamble_rng.draws)
	assert_array(_line_ids(actual)).is_equal(_line_ids(expected))
	assert_int(actual.decision).is_equal(expected.decision)
	assert_int(actual.board.payout).is_equal(expected.board.payout)
	assert_int(actual.stake).is_equal(expected.stake)
	assert_int(actual.board.held_count()).is_equal(expected.board.held_count())


## Plays a floor and a bit the way hands do: holds, a raised stake, the trail,
## the ladder, the vault, the works, then the whole market and the back office.
func _play_by_hand(engine: SimEngine, state: RunState) -> void:
	var guard: int = 0
	while state.phase == RunState.Phase.SPINNING and state.spins_remaining > 0 and guard < 40:
		guard += 1
		engine.toggle_hold(state, 0)
		engine.set_stake(state, 2)
		if guard == 2:
			engine.deposit(state, 30)
		if guard == 3:
			engine.buy_row(state)
		if not state.economy.can_afford(state.spin_price()):
			break
		engine.spin(state)
		if state.decision == RunState.Decision.NUDGE:
			engine.nudge(state, 1)
			engine.decline_nudges(state)
		if state.decision == RunState.Decision.GAMBLE:
			engine.gamble(state)
			if state.decision == RunState.Decision.GAMBLE:
				engine.collect(state)
	if state.phase == RunState.Phase.SPINNING:
		engine.step(state)
	if state.phase == RunState.Phase.SHOPPING:
		engine.reroll_shop(state)
		engine.buy_offer(state, 0)
		engine.sell(state, 0)
		engine.buy_on_slate(state, 0)
		engine.withdraw(state, 10)
		engine.leave_shop(state)
	if state.phase == RunState.Phase.SIGNING:
		engine.sign_contract(state, 1)
	if state.phase == RunState.Phase.SPINNING and state.economy.can_afford(state.spin_price()):
		engine.spin(state)
		if state.is_deciding():
			engine.decline_nudges(state)
			engine.collect(state)


func test_a_hand_played_run_replays_to_the_same_state() -> void:
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = 7
	journal.options = _rich()
	var engine: SimEngine = _human_engine(journal)
	var played: RunState = engine.start_run(7, _rich())
	_play_by_hand(engine, played)
	assert_int(journal.entries.size()).is_greater(10)

	var again: SimEngine = _human_engine(null)
	var replayed: RunState = again.start_run(journal.seed_value, journal.options)
	assert_int(RunJournal.replay(again, replayed, journal.entries)).is_equal(-1)
	_same_run(played, replayed)


func test_the_engine_journals_only_what_came_from_outside() -> void:
	# A spin banks itself when nothing is owed; that inner collect is the
	# engine's own business and must not appear as a second verb.
	var journal: RunJournal = RunJournal.new()
	var engine: SimEngine = _human_engine(journal)
	var state: RunState = engine.start_run(3, _rich())
	state.systems.clear()
	engine.spin(state)
	assert_int(journal.entries.size()).is_equal(1)
	assert_str(String((journal.entries[0] as Array)[0])).is_equal("spin")


func test_an_automated_run_is_a_log_of_steps_and_replays_from_them() -> void:
	var journal: RunJournal = RunJournal.new()
	var engine: SimEngine = SimEngine.new(_content, EffectBus.new())
	engine.journal = journal
	var played: RunState = engine.simulate_run(11, _rich())
	for entry: Variant in journal.entries:
		assert_str(String((entry as Array)[0])).is_equal("step")

	var again: SimEngine = SimEngine.new(_content, EffectBus.new())
	var replayed: RunState = again.start_run(11, _rich())
	assert_int(RunJournal.replay(again, replayed, journal.entries)).is_equal(-1)
	_same_run(played, replayed)


func test_the_journal_survives_json() -> void:
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = 7
	journal.options = _rich()
	journal.daily_key = "2026-09-02"
	var engine: SimEngine = _human_engine(journal)
	var played: RunState = engine.start_run(7, _rich())
	_play_by_hand(engine, played)

	var text: String = JSON.stringify(journal.to_dict())
	var back: RunJournal = RunJournal.from_dict(JSON.parse_string(text))
	assert_object(back).is_not_null()
	assert_int(back.seed_value).is_equal(7)
	assert_str(back.daily_key).is_equal("2026-09-02")
	assert_int(back.options.bonus_cash).is_equal(400)
	assert_str(String(back.options.starter_id)).is_equal("flush")
	assert_int(back.entries.size()).is_equal(journal.entries.size())

	var again: SimEngine = _human_engine(null)
	var replayed: RunState = again.start_run(back.seed_value, back.options)
	assert_int(RunJournal.replay(again, replayed, back.entries)).is_equal(-1)
	_same_run(played, replayed)


func test_replay_stops_where_the_run_ends() -> void:
	# A log longer than the run is what a balance change looks like from inside
	# a save: the verbs are the same, the run no longer survives them.
	var journal: RunJournal = RunJournal.new()
	var engine: SimEngine = SimEngine.new(_content, EffectBus.new())
	engine.journal = journal
	engine.simulate_run(11, _rich())
	var length: int = journal.entries.size()
	for i: int in 5:
		journal.record(&"step")

	var again: SimEngine = SimEngine.new(_content, EffectBus.new())
	var replayed: RunState = again.start_run(11, _rich())
	assert_int(RunJournal.replay(again, replayed, journal.entries)).is_equal(length)


func test_a_verb_the_engine_does_not_know_stops_the_replay_where_it_is() -> void:
	var journal: RunJournal = RunJournal.new()
	journal.record(&"spin")
	journal.record(&"summon_the_manager", [3])
	journal.record(&"spin")
	var engine: SimEngine = _human_engine(null)
	var state: RunState = engine.start_run(5, _rich())
	assert_int(RunJournal.replay(engine, state, journal.entries)).is_equal(1)


func test_a_newer_journal_is_not_misread() -> void:
	assert_object(RunJournal.from_dict({"version": RunJournal.VERSION + 1, "seed": 1})).is_null()
	assert_object(RunJournal.from_dict({"version": 1})).is_null()
