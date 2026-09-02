extends GdUnitTestSuite

## The surety: how much of the player the House holds, read off the run on
## every spin. Zero while covered, one when unreachable, and it moves the
## right way on a wasted spin and on a paying one.

var _engine: SimEngine
var _state: RunState


func before_test() -> void:
	var content: ContentDB = TestFixtures.content_with_shop()
	content.floors.assign([
		TestFixtures.floor_def(1, 60, 6),
		TestFixtures.floor_def(2, 120, 6),
	])
	_engine = SimEngine.new(content, EffectBus.new())
	_engine.clear_policies()
	_state = _engine.start_run(3)


func test_a_covered_floor_holds_nothing() -> void:
	_state.economy.cash = 500
	assert_float(_state.surety()).is_equal(0.0)


func test_a_short_floor_holds_some_and_no_spins_holds_all() -> void:
	_state.economy.cash = 10
	_state.spins_remaining = 6
	var held: float = _state.surety()
	assert_float(held).is_greater(0.0)
	assert_float(held).is_less(1.0)
	_state.spins_remaining = 0
	assert_float(_state.surety()).is_equal(1.0)


func test_a_wasted_spin_moves_it_up_and_a_paying_one_moves_it_down() -> void:
	_state.economy.cash = 10
	_state.spins_remaining = 6
	var before: float = _state.surety()
	_state.spins_remaining = 5
	var after_a_loss: float = _state.surety()
	assert_float(after_a_loss).is_greater(before)
	_state.economy.cash = 30
	assert_float(_state.surety()).is_less(after_a_loss)


func test_it_is_bounded_and_reads_full_when_a_spin_would_need_three_pars() -> void:
	# Par is ten a spin here; a shortfall of thirty with one spin left is
	# exactly the reach, and anything past it is still one.
	_state.spins_remaining = 1
	_state.economy.cash = _state.ante_due() - 30
	assert_float(_state.surety()).is_equal_approx(1.0, 0.001)
	_state.economy.cash = _state.ante_due() - 300
	assert_float(_state.surety()).is_equal(1.0)


func test_between_floors_the_house_holds_nothing_and_a_lost_run_is_held_entirely() -> void:
	_state.phase = RunState.Phase.SHOPPING
	assert_float(_state.surety()).is_equal(0.0)
	_state.phase = RunState.Phase.LOST
	assert_float(_state.surety()).is_equal(1.0)
