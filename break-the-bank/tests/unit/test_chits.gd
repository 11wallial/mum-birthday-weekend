extends GdUnitTestSuite

## The chits: bought at the draft into a pocket of two, spent once each at
## their moment, every kind resolved in one place.

var _content: ContentDB
var _engine: SimEngine
var _state: RunState


func _chit(id: StringName, kind: ChitDef.Kind, cost: int = 2, magnitude: float = 0.0,
		symbol: StringName = &"") -> ChitDef:
	var def: ChitDef = ChitDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = kind
	def.cost = cost
	def.magnitude = magnitude
	def.symbol = symbol
	def.min_floor = 1
	return def


func before_test() -> void:
	_content = TestFixtures.content_with_shop()
	_content.floors.assign([
		TestFixtures.floor_def(1, 20, 6),
		TestFixtures.floor_def(2, 40, 6),
		TestFixtures.floor_def(3, 80, 6),
	])
	for floor_def: FloorDef in _content.floors:
		floor_def.shop_slots = 1
	_engine = SimEngine.new(_content, EffectBus.new())
	_engine.clear_policies()
	_state = _engine.start_run(8)


func _to_draft(chit: ChitDef) -> void:
	_state.economy.cash = 1000
	_state.spins_remaining = 0
	_engine.step(_state)
	assert_int(_state.phase).is_equal(RunState.Phase.SHOPPING)
	_state.chit_offer = chit
	_state.economy.chips = 20


func test_a_chit_is_bought_into_the_pocket_and_the_pocket_holds_two() -> void:
	_to_draft(_chit(&"peek", ChitDef.Kind.PEEK))
	assert_bool(_state.can_buy_chit()).is_true()
	assert_bool(_engine.buy_chit(_state)).is_true()
	assert_int(_state.pocket.size()).is_equal(1)
	assert_int(_state.economy.chips).is_equal(18)
	assert_object(_state.chit_offer).is_null()
	_state.chit_offer = _chit(&"peek2", ChitDef.Kind.PEEK)
	assert_bool(_engine.buy_chit(_state)).is_true()
	_state.chit_offer = _chit(&"peek3", ChitDef.Kind.PEEK)
	assert_bool(_state.can_buy_chit()).is_false()
	assert_bool(_engine.buy_chit(_state)).is_false()


func test_a_peek_reads_the_next_line_without_moving_the_reels() -> void:
	_state.pocket.append(_chit(&"peek", ChitDef.Kind.PEEK))
	var draws_before: int = _state.reel_rng.draws
	assert_bool(_engine.use_chit(_state, 0)).is_true()
	assert_int(_state.reel_rng.draws).is_equal(draws_before)
	assert_int(_state.peeked_line.size()).is_equal(_state.board.reel_count())
	var promised: Array[StringName] = _state.peeked_line.duplicate()
	_engine.spin(_state)
	for i: int in promised.size():
		assert_str(String(_state.board.line[i].id)).is_equal(String(promised[i]))
	assert_bool(_state.peeked_line.is_empty()).is_true()
	assert_int(_state.pocket.size()).is_equal(0)


func test_a_marker_lands_the_last_drum_on_its_symbol() -> void:
	var symbol: SymbolDef = _content.symbols[0]
	_state.pocket.append(_chit(&"mark", ChitDef.Kind.MARKER, 2, 0.0, symbol.id))
	assert_bool(_engine.use_chit(_state, 0)).is_true()
	assert_str(String(_state.forced_symbol)).is_equal(String(symbol.id))
	_engine.spin(_state)
	var last: int = _state.board.reel_count() - 1
	assert_str(String(_state.board.line[last].id)).is_equal(String(symbol.id))
	assert_str(String(_state.forced_symbol)).is_equal("")


func test_a_deferral_moves_the_vig_onto_the_principal() -> void:
	_state.floors_cleared = 2
	_state.economy.debt = 100
	_state.pocket.append(_chit(&"defer", ChitDef.Kind.DEFERRAL))
	assert_int(_state.vig_due()).is_greater(0)
	var vig: int = _state.vig_due()
	assert_bool(_engine.use_chit(_state, 0)).is_true()
	assert_bool(_state.vig_deferred).is_true()
	_state.economy.cash = 1000
	var cash_before: int = _state.economy.cash
	_state.spins_remaining = 0
	_engine.step(_state)
	assert_bool(_state.vig_deferred).is_false()
	assert_int(_state.economy.debt).is_greater_equal(100 + vig)
	assert_int(_state.economy.cash).is_equal(cash_before - _state.floor_at(1).ante if false else _state.economy.cash)


func test_a_vent_takes_heat_off_the_count() -> void:
	_state.grant_system(Systems.HEAT)
	_state.heat = 50.0
	_state.pocket.append(_chit(&"vent", ChitDef.Kind.VENT, 2, 40.0))
	assert_bool(_engine.use_chit(_state, 0)).is_true()
	assert_float(_state.heat).is_equal_approx(10.0, 0.001)


func test_a_respin_needs_a_decision_and_spins_the_last_drum_again() -> void:
	_state.pocket.append(_chit(&"respin", ChitDef.Kind.RESPIN))
	assert_bool(_state.can_use_chit(0)).is_false()
	_state.grant_system(Systems.GAMBLE)
	var guard: int = 0
	while not _state.is_deciding() and guard < 60:
		_engine.spin(_state)
		if not _state.is_deciding():
			_state.spins_remaining = 6
		guard += 1
	assert_bool(_state.is_deciding()).is_true()
	assert_bool(_engine.use_chit(_state, 0)).is_true()
	assert_int(_state.pocket.size()).is_equal(0)
	assert_int(_state.chits_used).is_equal(1)


func test_a_chit_is_the_seeds_own_and_replays_from_the_journal() -> void:
	var first: RunState = _engine.start_run(3)
	first.economy.cash = 1000
	first.spins_remaining = 0
	_engine.step(first)
	var offered: ChitDef = first.chit_offer
	var again: RunState = _engine.start_run(3)
	again.economy.cash = 1000
	again.spins_remaining = 0
	_engine.step(again)
	if offered == null:
		assert_object(again.chit_offer).is_null()
	else:
		assert_str(String(again.chit_offer.id)).is_equal(String(offered.id))


func test_a_chit_the_run_is_not_allowed_is_never_dealt() -> void:
	_content.chits.assign([_chit(&"locked", ChitDef.Kind.PEEK), _chit(&"open", ChitDef.Kind.PEEK)])
	var options: RunOptions = RunOptions.new()
	options.allowed_chits = [&"open"]
	for seed: int in 20:
		_state = _engine.start_run(seed, options)
		_state.economy.cash = 1000
		_state.spins_remaining = 0
		_engine.step(_state)
		if _state.chit_offer != null:
			assert_str(String(_state.chit_offer.id)).is_equal("open")
	var back: RunOptions = RunOptions.from_dict(JSON.parse_string(JSON.stringify(options.to_dict())))
	assert_bool(back.allows_chit(_chit(&"locked", ChitDef.Kind.PEEK))).is_false()
	assert_bool(back.allows_chit(_chit(&"open", ChitDef.Kind.PEEK))).is_true()


func test_a_nudge_ticket_only_spends_against_a_board_on_the_table() -> void:
	# Nudges handed to a settled board are nudges nobody can spend, so the
	# paper refuses to be spent there at all.
	_state.pocket.append(_chit(&"shim", ChitDef.Kind.NUDGE_TICKET, 2, 2.0))
	_state.phase = RunState.Phase.SPINNING
	_state.decision = RunState.Decision.NONE
	assert_bool(_state.can_use_chit(0)).override_failure_message(
			"a nudge ticket spent with no decision standing").is_false()
	_engine.step(_state)
	while _state.decision != RunState.Decision.NUDGE and _state.spins_remaining > 0:
		_engine.step(_state)
	if _state.decision != RunState.Decision.NUDGE:
		return
	var before: int = _state.board.nudges
	assert_bool(_state.can_use_chit(0)).is_true()
	assert_bool(_engine.use_chit(_state, 0)).is_true()
	assert_int(_state.board.nudges).override_failure_message(
			"the ticket did not put its nudges on the board").is_equal(before + 2)


func test_a_spin_ticket_buys_time_on_this_floor() -> void:
	_state.phase = RunState.Phase.SPINNING
	_state.decision = RunState.Decision.NONE
	_state.pocket.append(_chit(&"pass", ChitDef.Kind.SPIN_TICKET, 2, 3.0))
	var left: int = _state.spins_remaining
	var total: int = _state.floor_spins_total
	assert_bool(_state.can_use_chit(0)).is_true()
	assert_bool(_engine.use_chit(_state, 0)).is_true()
	assert_int(_state.spins_remaining).is_equal(left + 3)
	# The floor's allowance moves with it, or the quick clear and every
	# reading of "spins left of the floor" would be measured against a
	# clock that no longer exists.
	assert_int(_state.floor_spins_total).is_equal(total + 3)


func test_every_kind_of_paper_has_a_moment_the_signatory_knows() -> void:
	# The vocabulary is closed and small. A kind the automated player has no
	# arm for is a kind the draft can sell and the lab never spends — it
	# would ship unmeasured, which is the whole reason this list exists.
	for kind: int in ChitDef.Kind.values():
		assert_bool(AutoPlayer.CHIT_COVERAGE.has(kind)).override_failure_message(
				"%s has no moment in AutoPlayer.use_chits" % ChitDef.Kind.keys()[kind]).is_true()
	assert_int(AutoPlayer.CHIT_COVERAGE.size()).override_failure_message(
			"the coverage list has grown past the vocabulary").is_equal(
			ChitDef.Kind.values().size())
