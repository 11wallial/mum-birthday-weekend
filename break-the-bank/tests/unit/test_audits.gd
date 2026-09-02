extends GdUnitTestSuite

## The rule changes an audit or a challenge can make, each pinned on its own:
## a knob that reaches the run through RunOptions and changes exactly the
## number it names, and nothing else.

var _content: ContentDB


func before_test() -> void:
	_content = TestFixtures.content_with_shop()
	_content.floors.assign([
		TestFixtures.floor_granting(1, 20, 6, [Systems.HOLD, Systems.HEAT]),
		TestFixtures.floor_def(2, 40, 6),
	])
	for floor_def: FloorDef in _content.floors:
		floor_def.shop_slots = 2
		floor_def.debt_interest_percent = 10.0


func _engine() -> SimEngine:
	var engine: SimEngine = SimEngine.new(_content, EffectBus.new())
	engine.get_bus().recording = true
	engine.clear_policies()
	return engine


func _options() -> RunOptions:
	var options: RunOptions = RunOptions.new()
	options.bonus_cash = 500
	options.bonus_debt = 100
	return options


## Plays the first floor out and settles it, so the numbers a floor's end
## touches — the vig, the interest, the count — have been touched.
func _clear_first_floor(engine: SimEngine, state: RunState) -> void:
	var guard: int = 0
	while state.phase == RunState.Phase.SPINNING and guard < 60:
		guard += 1
		engine.step(state)


func test_the_debt_scale_multiplies_what_is_owed_before_the_starter_adds_to_it() -> void:
	_content.balance.starting_debt = 50
	var scaled: RunOptions = _options()
	scaled.debt_scale = 3.0
	var state: RunState = _engine().start_run(4, scaled)
	assert_int(state.economy.debt).is_equal(50 * 3 + 100)


func test_a_locked_system_is_never_handed_over() -> void:
	var bare: RunOptions = _options()
	bare.locked_systems = [Systems.HOLD]
	var engine: SimEngine = _engine()
	var state: RunState = engine.start_run(4, bare)
	assert_bool(state.has_system(Systems.HOLD)).is_false()
	assert_bool(state.has_system(Systems.HEAT)).is_true()
	for granted: Dictionary in engine.get_bus().events_of(EffectBus.Event.SYSTEM_GRANTED):
		assert_str(String(granted.get("system", ""))).is_not_equal("hold")
	assert_bool(engine.toggle_hold(state, 0)).is_false()


func test_the_service_scale_changes_the_vig_and_nothing_else() -> void:
	_content.balance.debt_grace_floors = 0
	var plain: RunState = _engine().start_run(4, _options())
	var engine: SimEngine = _engine()
	var dear: RunOptions = _options()
	dear.debt_service_scale = 2.0
	var heavy: RunState = engine.start_run(4, dear)
	_clear_first_floor(_engine(), plain)
	_clear_first_floor(engine, heavy)
	assert_int(heavy.economy.debt_serviced).is_equal(plain.economy.debt_serviced * 2)


func test_the_interest_delta_raises_what_the_debt_grows_by() -> void:
	var plain: RunState = _engine().start_run(4, _options())
	var steep: RunOptions = _options()
	steep.interest_delta = 40.0
	var engine: SimEngine = _engine()
	var pressed: RunState = engine.start_run(4, steep)
	_clear_first_floor(_engine(), plain)
	_clear_first_floor(engine, pressed)
	assert_int(pressed.economy.debt).is_greater(plain.economy.debt)


func test_the_price_scale_marks_up_the_draft_and_the_sellback_alike() -> void:
	var engine: SimEngine = _engine()
	var plain: RunState = engine.start_run(4, _options())
	_clear_first_floor(engine, plain)
	assert_int(plain.phase).is_equal(RunState.Phase.SHOPPING)
	var dear: RunOptions = _options()
	dear.price_scale = 2.0
	var other: SimEngine = _engine()
	var marked: RunState = other.start_run(4, dear)
	_clear_first_floor(other, marked)
	assert_int(marked.shop_prices[0]).is_equal(plain.shop_prices[0] * 2)
	var artifact: ArtifactDef = plain.shop_offers[0]
	assert_int(other.price_for(marked, artifact)).is_equal(engine.price_for(plain, artifact) * 2)


func test_the_count_is_kept_between_floors_when_the_audit_says_so() -> void:
	var remembering: RunOptions = _options()
	remembering.heat_carry = 0.5
	var engine: SimEngine = _engine()
	var state: RunState = engine.start_run(4, remembering)
	state.heat = 80.0
	state.spins_remaining = 0
	engine.step(state)
	assert_int(state.floors_cleared).is_equal(1)
	assert_float(state.heat).is_equal(40.0)


func test_the_count_is_forgotten_between_floors_by_default() -> void:
	var engine: SimEngine = _engine()
	var state: RunState = engine.start_run(4, _options())
	state.heat = 80.0
	state.spins_remaining = 0
	engine.step(state)
	assert_float(state.heat).is_equal(0.0)


func test_skulls_on_the_payroll_pay_instead_of_costing() -> void:
	var state: RunState = _engine().start_run(4, _options())
	var line: Array[SymbolDef] = [
		_content.symbol_by_id(&"skull"),
		_content.symbol_by_id(&"cherry"),
		_content.symbol_by_id(&"seven"),
	]
	var cursed: int = ArtifactEngine.score_line(state, line)
	state.options.curse_pays = 6.0
	assert_int(ArtifactEngine.score_line(state, line)).is_greater(cursed)


func test_the_payout_scale_comes_off_every_line() -> void:
	var state: RunState = _engine().start_run(4, _options())
	var line: Array[SymbolDef] = [
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
	]
	var full: int = ArtifactEngine.score_line(state, line)
	state.options.payout_scale = 0.5
	assert_int(ArtifactEngine.score_line(state, line)).is_equal(full / 2)


func test_no_grace_charges_the_vig_from_the_first_floor() -> void:
	_content.balance.debt_grace_floors = 1
	var plain: RunState = _engine().start_run(4, _options())
	_clear_first_floor(_engine(), plain)
	assert_int(plain.economy.debt_serviced).is_equal(0)
	var strict: RunOptions = _options()
	strict.no_grace = true
	var engine: SimEngine = _engine()
	var pressed: RunState = engine.start_run(4, strict)
	_clear_first_floor(engine, pressed)
	assert_int(pressed.economy.debt_serviced).is_greater(0)


func test_an_early_system_arrives_before_the_first_floor_and_is_announced() -> void:
	var watched: RunOptions = _options()
	watched.early_systems = [Systems.STAKE]
	var engine: SimEngine = _engine()
	var state: RunState = engine.start_run(4, watched)
	assert_bool(state.has_system(Systems.STAKE)).is_true()
	assert_bool(engine.set_stake(state, 2)).is_true()
	var announced: Array[Dictionary] = engine.get_bus().events_of(EffectBus.Event.SYSTEM_GRANTED)
	assert_str(String(announced[0].get("system", ""))).is_equal("stake")
	# Locked still beats early: a challenge cannot hand over what it withholds.
	watched.locked_systems = [Systems.STAKE]
	var other: RunState = _engine().start_run(4, watched)
	assert_bool(other.has_system(Systems.STAKE)).is_false()


func test_every_knob_survives_a_round_trip_and_changes_the_ruleset_key() -> void:
	var options: RunOptions = _options()
	options.difficulty_id = &"house_rules"
	options.challenge_id = &"bare_reels"
	options.locked_systems = [Systems.HOLD, Systems.MARKET]
	options.debt_service_scale = 1.5
	options.interest_delta = 40.0
	options.debt_scale = 2.0
	options.price_scale = 1.25
	options.heat_carry = 0.5
	options.payout_scale = 0.8
	options.curse_pays = 6.0
	options.early_systems = [Systems.HEAT]
	options.no_grace = true
	var back: RunOptions = RunOptions.from_dict(JSON.parse_string(JSON.stringify(options.to_dict())))
	assert_str(back.ruleset_key()).is_equal(options.ruleset_key())
	assert_array(back.locked_systems).contains_exactly([Systems.HOLD, Systems.MARKET])
	assert_array(back.early_systems).contains_exactly([Systems.HEAT])
	assert_bool(back.no_grace).is_true()
	assert_str(back.ruleset_key()).is_not_equal(RunOptions.new().ruleset_key())
	var copy: RunOptions = options.duplicate_options()
	assert_str(copy.ruleset_key()).is_equal(options.ruleset_key())
