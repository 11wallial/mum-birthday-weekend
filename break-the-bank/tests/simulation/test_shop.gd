extends GdUnitTestSuite

## The draft is the one place a human and the batch policy touch the same
## simulation calls, so it is worth pinning both paths down.

var _engine: SimEngine
var _state: RunState


func before_test() -> void:
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	_engine = SimEngine.new(TestFixtures.content_with_shop(), bus)
	# No policy: the shop stays open, exactly as it does for a player.
	_engine.shop_policy = Callable()
	_state = _engine.start_run(7)
	_reach_shop()


## Spins until the first floor closes and the shop opens.
func _reach_shop() -> void:
	var guard: int = 0
	while _state.phase != RunState.Phase.SHOPPING and not _state.is_over() and guard < 50:
		_engine.step(_state)
		guard += 1


func test_clearing_a_floor_opens_a_stocked_shop() -> void:
	assert_int(_state.phase).is_equal(RunState.Phase.SHOPPING)
	assert_array(_state.shop_offers).is_not_empty()
	assert_int(_state.shop_prices.size()).is_equal(_state.shop_offers.size())


func test_buying_takes_the_credits_and_the_artifact() -> void:
	var index: int = _affordable_index()
	assert_int(index).is_greater_equal(0)
	var price: int = _state.shop_prices[index]
	var cash: int = _state.economy.cash
	var artifact_id: StringName = _state.shop_offers[index].id
	var offers: int = _state.shop_offers.size()

	assert_bool(_engine.buy_offer(_state, index)).is_true()
	assert_int(_state.economy.cash).is_equal(cash - price)
	assert_bool(_state.owns(artifact_id)).is_true()
	assert_int(_state.shop_offers.size()).is_equal(offers - 1)


func test_an_unaffordable_offer_cannot_be_bought() -> void:
	var index: int = _unaffordable_index()
	if index < 0:
		return
	assert_bool(_state.can_buy(index)).is_false()
	assert_bool(_engine.buy_offer(_state, index)).is_false()
	assert_bool(_state.owns(_state.shop_offers[index].id)).is_false()


func test_out_of_range_and_closed_shop_purchases_are_refused() -> void:
	assert_bool(_engine.buy_offer(_state, -1)).is_false()
	assert_bool(_engine.buy_offer(_state, 99)).is_false()
	_engine.leave_shop(_state)
	assert_bool(_engine.buy_offer(_state, 0)).is_false()


func test_leaving_the_shop_clears_it_and_starts_the_next_floor() -> void:
	_engine.leave_shop(_state)
	assert_array(_state.shop_offers).is_empty()
	assert_array(_state.shop_prices).is_empty()
	assert_int(_state.floor_index).is_equal(2)
	assert_int(_state.phase).is_equal(RunState.Phase.SPINNING)


func test_the_shop_stays_open_until_it_is_left() -> void:
	# A player must not be able to lose the draft by pressing spin.
	var offers: int = _state.shop_offers.size()
	assert_int(_state.phase).is_equal(RunState.Phase.SHOPPING)
	assert_int(_state.shop_offers.size()).is_equal(offers)


func test_the_batch_policy_drives_the_same_public_calls() -> void:
	# The headless path must go through buy_offer too, or the two drift apart.
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var engine: SimEngine = SimEngine.new(TestFixtures.content_with_shop(), bus)
	var state: RunState = engine.simulate_run(7)
	assert_bool(state.is_over()).is_true()
	# The cheap charm is affordable on any run that clears a floor.
	if state.floors_cleared > 0:
		assert_bool(state.owns(&"cheap_charm")).is_true()
		assert_bool(state.owns(&"dear_engine")).is_false()


func _affordable_index() -> int:
	for i: int in _state.shop_offers.size():
		if _state.can_buy(i):
			return i
	return -1


func _unaffordable_index() -> int:
	for i: int in _state.shop_offers.size():
		if not _state.can_buy(i):
			return i
	return -1
