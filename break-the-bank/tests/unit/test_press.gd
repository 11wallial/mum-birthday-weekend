extends GdUnitTestSuite

## The press: the reel is the player's to edit, and every edit is a verb —
## paid in chips, permanent for the run, journaled, and read exactly where
## the number it changes is used.

var _engine: SimEngine
var _state: RunState


func before_test() -> void:
	var content: ContentDB = TestFixtures.content_with_shop()
	for floor_def: FloorDef in content.floors:
		floor_def.chips = 20
	_engine = SimEngine.new(content, EffectBus.new())
	_engine.get_bus().recording = true
	_engine.clear_policies()
	_state = _engine.start_run(11)
	var guard: int = 0
	while _state.phase != RunState.Phase.SHOPPING and not _state.is_over() and guard < 50:
		_engine.step(_state)
		guard += 1
	assert_int(_state.phase).is_equal(RunState.Phase.SHOPPING)


func _job(kind: String, symbol: String, magnitude: int, price: int) -> int:
	_state.press_offers.append({"kind": kind, "symbol": symbol,
			"magnitude": magnitude, "price": price})
	return _state.press_offers.size() - 1


func test_the_draft_opens_with_jobs_on_the_press() -> void:
	assert_int(_state.press_offers.size()).is_between(1, SimEngine.PRESS_JOBS)
	for job: Dictionary in _state.press_offers:
		assert_bool(["strike", "print", "gild"].has(String(job["kind"]))).is_true()
		assert_int(int(job["price"])).is_greater(0)


func test_a_strike_takes_weight_off_the_reel_for_the_run() -> void:
	var before: float = Probability.symbol_chance(_state.reel(), &"skull")
	var index: int = _job("strike", "skull", 4, 3)
	var chips: int = _state.economy.chips
	assert_bool(_engine.press(_state, index)).is_true()
	assert_float(Probability.symbol_chance(_state.reel(), &"skull")).is_less(before)
	assert_int(_state.economy.chips).is_equal(chips - 3)
	assert_int(_state.press_jobs).is_equal(1)
	# Permanent: the next floor spins the edited reel.
	_engine.leave_shop(_state)
	assert_float(Probability.symbol_chance(_state.reel(), &"skull")).is_less(before)


func test_a_print_adds_weight() -> void:
	var before: float = Probability.symbol_chance(_state.reel(), &"seven")
	assert_bool(_engine.press(_state, _job("print", "seven", 4, 3))).is_true()
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_greater(before)


func test_gilding_pays_on_the_line_and_says_so_on_the_receipt() -> void:
	assert_bool(_engine.press(_state, _job("gild", "fruit", 2, 4))).is_true()
	var cherry: SymbolDef = _state.content.symbol_by_id(&"cherry")
	assert_int(_state.symbol_bonus(cherry)).is_equal(2)
	var line: Array[SymbolDef] = [cherry, cherry, cherry]
	var ctx: ArtifactEngine.SpinContext = ArtifactEngine.evaluate_spin(
			_state, line, Probability.detect_pattern(line), false)
	assert_int(ctx.base_payout).is_equal((cherry.base_value + 2) * 3)
	assert_str(String(ctx.steps[0]["label"])).contains("gilt")


func test_the_press_wants_chips_not_cash() -> void:
	_state.economy.chips = 0
	_state.economy.cash = 9999
	var index: int = _job("strike", "skull", 4, 3)
	assert_bool(_state.can_press(index)).is_false()
	assert_bool(_engine.press(_state, index)).is_false()


func test_a_job_replays_from_the_journal() -> void:
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = 11
	_engine.journal = journal
	_state.economy.chips = 20
	assert_int(_state.press_offers.size()).is_greater(0)
	assert_bool(_engine.press(_state, 0)).is_true()
	assert_array(journal.entries).contains([["press", 0]])
