extends GdUnitTestSuite

## The spin loop is no longer "press the button, read the number". A board can
## owe the player nudges and a paying board can be doubled, so nothing is banked
## until the decision is back to NONE. These pin down that contract.

var _engine: SimEngine
var _state: RunState


func before_test() -> void:
	var content: ContentDB = TestFixtures.content()
	var grants: Array[StringName] = [Systems.HOLD, Systems.STAKE, Systems.GAMBLE]
	content.floors.assign([
		TestFixtures.floor_granting(1, 500, 40, grants),
	])
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	_engine = SimEngine.new(content, bus)
	# Nothing automated: these tests drive the same calls a player's hands do.
	_engine.nudge_policy = Callable()
	_engine.gamble_policy = Callable()
	_engine.stake_policy = Callable()
	_engine.hold_policy = Callable()
	_state = _engine.start_run(11)
	_state.economy.cash = 5000


## Stands a chosen line on the payline with a chosen band above it.
func _stand(line: Array[StringName], above: Array[StringName]) -> void:
	var board: SpinBoard = _state.board
	board.resize(line.size())
	for i: int in line.size():
		board.set_column(i,
				_state.content.symbol_by_id(above[i]),
				_state.content.symbol_by_id(line[i]),
				_state.content.symbol_by_id(line[i]))


## Takes whatever the machine is offering and banks it, so a test that cares
## about the next spin can get to one.
func _settle() -> void:
	var guard: int = 0
	while _state.is_deciding() and guard < 20:
		guard += 1
		if _state.decision == RunState.Decision.NUDGE:
			_engine.decline_nudges(_state)
		else:
			_engine.collect(_state)


func test_a_spin_with_no_systems_in_play_banks_immediately() -> void:
	_state.systems.clear()
	var cash: int = _state.economy.cash
	_engine.spin(_state)
	assert_int(_state.decision).is_equal(RunState.Decision.NONE)
	assert_int(_state.economy.cash).is_equal(
			cash - _state.spin_price() + _state.last_payout)


func test_a_pair_opens_the_nudge_trail_and_holds_the_payout_back() -> void:
	var guard: int = 0
	while _state.decision != RunState.Decision.NUDGE and guard < 200:
		guard += 1
		_engine.spin(_state)
	assert_int(_state.decision).is_equal(RunState.Decision.NUDGE)
	assert_int(_state.board.nudges).is_greater(0)
	# Nothing has been credited: the spin is not over until the trail is.
	assert_int(_engine.get_bus().count_of(EffectBus.Event.PAYOUT_CALCULATED)) \
			.is_less(_state.spins_taken)


func test_a_nudge_drops_the_band_onto_the_payline() -> void:
	_stand([&"cherry", &"cherry", &"skull"], [&"seven", &"seven", &"cherry"])
	_state.board.nudges = 1
	_state.board.free_nudges = 1
	_state.decision = RunState.Decision.NUDGE

	assert_bool(_engine.nudge(_state, 2)).is_true()
	assert_str(String(_state.board.line[2].id)).is_equal("cherry")
	assert_str(String(_state.board.below[2].id)).is_equal("skull")


func test_a_paid_nudge_costs_a_spin_and_a_free_one_does_not() -> void:
	_stand([&"cherry", &"cherry", &"skull"], [&"cherry", &"cherry", &"cherry"])
	_state.board.nudges = 2
	_state.board.free_nudges = 1
	_state.decision = RunState.Decision.NUDGE
	var spins: int = _state.spins_remaining

	_engine.nudge(_state, 0)
	assert_int(_state.spins_remaining).is_equal(spins)
	_engine.nudge(_state, 1)
	assert_int(_state.spins_remaining).is_equal(spins - 1)


func test_declining_the_trail_banks_what_is_already_standing() -> void:
	# Without the ladder in play, declining is the end of the spin.
	_state.systems.erase(Systems.GAMBLE)
	_stand([&"cherry", &"cherry", &"skull"], [&"seven", &"seven", &"seven"])
	_engine._resolve_board(_state, false)
	var owed: int = _state.board.payout
	var cash: int = _state.economy.cash
	_state.board.nudges = 3
	_state.decision = RunState.Decision.NUDGE

	_engine.decline_nudges(_state)
	assert_int(_state.decision).is_equal(RunState.Decision.NONE)
	assert_int(_state.economy.cash).is_equal(cash + owed)


func test_a_hold_keeps_its_whole_column_and_the_rest_redraws() -> void:
	_engine.spin(_state)
	_settle()
	var kept: Array[SymbolDef] = _state.board.column(0)
	assert_bool(_engine.toggle_hold(_state, 0)).is_true()

	_engine.spin(_state)
	assert_object(_state.board.above[0]).is_same(kept[0])
	assert_object(_state.board.line[0]).is_same(kept[1])
	assert_object(_state.board.below[0]).is_same(kept[2])
	# And the lock is spent by the spin it bought.
	assert_int(_state.board.held_count()).is_equal(0)


func test_the_whole_line_can_never_be_held() -> void:
	assert_bool(_engine.toggle_hold(_state, 0)).is_true()
	assert_bool(_engine.toggle_hold(_state, 1)).is_true()
	assert_bool(_engine.toggle_hold(_state, 2)).is_false()


func test_a_lock_is_charged_for() -> void:
	var bare: int = _state.spin_price()
	_engine.toggle_hold(_state, 0)
	assert_int(_state.spin_price()).is_equal(bare * 2)


func test_the_stake_costs_its_multiple_and_pays_it_back() -> void:
	_stand([&"seven", &"seven", &"seven"], [&"cherry", &"cherry", &"cherry"])
	_engine._resolve_board(_state, false)
	var single: int = _state.board.payout
	_engine.set_stake(_state, 4)
	_engine._resolve_board(_state, false)
	assert_int(_state.board.payout).is_equal(single * 4)
	assert_int(_state.spin_price()).is_equal(_state.config.spin_cost * 4)


func test_the_stake_is_refused_before_the_floor_that_grants_it() -> void:
	_state.systems.erase(Systems.STAKE)
	assert_bool(_engine.set_stake(_state, 3)).is_false()
	assert_int(_state.stake).is_equal(1)


func test_a_won_rung_doubles_the_board_and_offers_the_next() -> void:
	_stand([&"seven", &"seven", &"seven"], [&"cherry", &"cherry", &"cherry"])
	_engine._resolve_board(_state, false)
	var owed: int = _state.board.payout
	_state.decision = RunState.Decision.GAMBLE
	# A stream forced short of the first rung's odds always wins it.
	_state.gamble_rng = TestFixtures.always_wins()

	assert_bool(_engine.gamble(_state)).is_true()
	assert_int(_state.board.payout).is_equal(owed * 2)
	assert_int(_state.decision).is_equal(RunState.Decision.GAMBLE)


func test_a_lost_rung_takes_the_whole_board_and_settles() -> void:
	_stand([&"seven", &"seven", &"seven"], [&"cherry", &"cherry", &"cherry"])
	_engine._resolve_board(_state, false)
	var cash: int = _state.economy.cash
	_state.decision = RunState.Decision.GAMBLE
	_state.gamble_rng = TestFixtures.always_loses()

	assert_bool(_engine.gamble(_state)).is_false()
	assert_int(_state.board.payout).is_equal(0)
	assert_int(_state.decision).is_equal(RunState.Decision.NONE)
	assert_int(_state.economy.cash).is_equal(cash)


func test_the_ladder_ends_at_the_top_rung_and_pays_out() -> void:
	_stand([&"seven", &"seven", &"seven"], [&"cherry", &"cherry", &"cherry"])
	_engine._resolve_board(_state, false)
	var owed: int = _state.board.payout
	var cash: int = _state.economy.cash
	_state.decision = RunState.Decision.GAMBLE
	_state.gamble_rng = TestFixtures.always_wins()

	var guard: int = 0
	while _state.decision == RunState.Decision.GAMBLE and guard < 10:
		guard += 1
		_engine.gamble(_state)
	var rungs: int = _state.config.gamble_odds.size()
	assert_int(_state.board.gamble_rung).is_equal(rungs)
	assert_int(_state.economy.cash).is_equal(cash + owed * int(pow(2, rungs)))


func test_a_floor_hands_over_its_systems_once() -> void:
	var granted: Array[Dictionary] = _engine.get_bus().events_of(
			EffectBus.Event.SYSTEM_GRANTED)
	assert_int(granted.size()).is_equal(3)
	assert_bool(_state.has_system(Systems.HOLD)).is_true()
	assert_bool(_state.grant_system(Systems.HOLD)).is_false()
