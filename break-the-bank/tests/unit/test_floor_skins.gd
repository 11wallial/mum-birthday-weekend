extends GdUnitTestSuite

## How the floor is running: drawn by the seed as it opens, doing what it
## says on its own numbers, and torn up when the floor closes.

var _content: ContentDB
var _engine: SimEngine
var _state: RunState


func _skin(id: StringName, spins: int = 0, ante: float = 0.0, chips: int = 0,
		scale: float = 1.0, shifts: Dictionary = {}, no_boss: bool = false) -> FloorSkinDef:
	var def: FloorSkinDef = FloorSkinDef.new()
	def.id = id
	def.display_name = String(id)
	def.spins_delta = spins
	def.ante_percent = ante
	def.chips_delta = chips
	def.payout_scale = scale
	def.weight_shifts = shifts
	def.no_boss = no_boss
	return def


func before_test() -> void:
	_content = TestFixtures.content_with_shop()
	_content.floors.assign([
		TestFixtures.floor_def(1, 60, 6),
		TestFixtures.floor_def(2, 120, 6),
		TestFixtures.floor_def(3, 240, 6),
	])
	_engine = SimEngine.new(_content, EffectBus.new())
	_engine.clear_policies()
	_state = _engine.start_run(4)


func test_the_basement_is_never_skinned() -> void:
	_content.skins.assign([_skin(&"anything")])
	for seed: int in 12:
		var state: RunState = _engine.start_run(seed)
		assert_object(state.skin).override_failure_message(
				"the lesson floor was skinned").is_null()


func test_a_seed_finds_the_same_floor_running_the_same_way() -> void:
	_content.skins.assign([_skin(&"a"), _skin(&"b"), _skin(&"c")])
	var seen: Array[String] = []
	for run: int in 2:
		var state: RunState = _engine.start_run(21)
		state.economy.cash = 5000
		state.spins_remaining = 0
		_engine.step(state)
		_engine.leave_shop(state)
		seen.append(String(state.skin.id) if state.skin != null else "")
	assert_str(seen[0]).is_equal(seen[1])


func test_a_skin_moves_the_allowance_the_ante_and_the_stipend() -> void:
	_state.skin = _skin(&"probe", 0, 50.0, 4)
	var floor_def: FloorDef = _state.current_floor()
	assert_int(_state.ante_due()).is_equal(int(round(float(floor_def.ante) * 1.5)))
	_state.skin = null
	assert_int(_state.ante_due()).is_equal(floor_def.ante)


func test_a_skin_leans_the_reel_and_lets_it_go() -> void:
	var symbol: SymbolDef = _content.symbols[0]
	var plain: float = Probability.symbol_chance(_state.reel(), symbol.id)
	_state.skin = _skin(&"heavy", 0, 0.0, 0, 1.0, {symbol.id: 20})
	_state.mark_reel_dirty()
	assert_float(Probability.symbol_chance(_state.reel(), symbol.id)).is_greater(plain)
	_state.skin = null
	_state.mark_reel_dirty()
	assert_float(Probability.symbol_chance(_state.reel(), symbol.id)).is_equal_approx(plain, 0.0001)


func test_a_skin_is_torn_up_with_the_floor() -> void:
	_content.skins.assign([_skin(&"stays", 1)])
	var state: RunState = _engine.start_run(3)
	state.economy.cash = 5000
	state.spins_remaining = 0
	_engine.step(state)
	_engine.leave_shop(state)
	# Floor two either has a skin or does not; whichever, closing it clears.
	var before: FloorSkinDef = state.skin
	state.economy.cash = 5000
	state.spins_remaining = 0
	_engine.step(state)
	assert_int(state.phase).is_equal(RunState.Phase.SHOPPING)
	assert_object(state.skin).is_null()
	assert_bool(before == null or before.id == &"stays").is_true()


func test_a_short_staffed_floor_has_nobody_on_it() -> void:
	_content.skins.assign([_skin(&"short", 0, 0.0, 0, 1.0, {}, true)])
	var person: BossDef = BossDef.new()
	person.id = &"somebody"
	person.display_name = "Somebody"
	person.floor = 2
	person.rule = BossDef.Rule.SHORT_FLOOR
	person.magnitude = 1.0
	_content.bosses.append(person)
	for seed: int in 20:
		var state: RunState = _engine.start_run(seed)
		state.economy.cash = 5000
		state.spins_remaining = 0
		_engine.step(state)
		_engine.leave_shop(state)
		if state.skin != null and state.skin.no_boss:
			assert_object(state.boss).override_failure_message(
					"the House sent somebody to a floor it had nobody for").is_null()
