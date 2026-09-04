extends GdUnitTestSuite

## The House notices. A spin loud enough — ten pars in one — sends one more
## of its people to the next floor, announced the moment it is decided, and
## every ante after it is dearer. The House acts against success, not on a
## schedule.

var _engine: SimEngine
var _state: RunState
var _bus: EffectBus


func before_test() -> void:
	var content: ContentDB = TestFixtures.content_with_shop()
	content.floors.assign([
		TestFixtures.floor_def(1, 60, 6),
		TestFixtures.floor_def(2, 120, 6),
		TestFixtures.floor_def(3, 240, 6),
	])
	for index: int in [2, 3]:
		var person: BossDef = BossDef.new()
		person.id = StringName("watcher_%d" % index)
		person.display_name = "The Watcher %d" % index
		person.tell = "Every lock costs double."
		person.floor = index
		person.rule = BossDef.Rule.HOLDS_COST_MORE
		person.magnitude = 2.0
		content.bosses.append(person)
		var other: BossDef = BossDef.new()
		other.id = StringName("other_%d" % index)
		other.display_name = "The Other %d" % index
		other.floor = index
		other.rule = BossDef.Rule.SHORT_FLOOR
		other.magnitude = 1.0
		content.bosses.append(other)
	_bus = EffectBus.new()
	_bus.recording = true
	_engine = SimEngine.new(content, _bus)
	_engine.clear_policies()
	_state = _engine.start_run(5)


func _bank(payout: int) -> void:
	_state.board.payout = payout
	_state.board.breakdown = {"steps": []}
	_engine.collect(_state)


func test_a_quiet_spin_is_not_noticed() -> void:
	_bank(30)
	assert_object(_state.notice_pending).is_null()
	assert_int(_state.notices).is_equal(0)
	assert_int(_bus.count_of(EffectBus.Event.HOUSE_NOTICED)).is_equal(0)


func test_a_loud_spin_is_noticed_and_announced_at_once() -> void:
	# Par is ten a spin; ten pars is a hundred.
	_bank(120)
	assert_object(_state.notice_pending).is_not_null()
	assert_int(_state.notices).is_equal(1)
	assert_int(_state.noticed_payout).is_equal(120)
	var noticed: Array[Dictionary] = _bus.events_of(EffectBus.Event.HOUSE_NOTICED)
	assert_int(noticed.size()).is_equal(1)
	assert_int(int(noticed[0]["floor"])).is_equal(2)
	assert_str(String(noticed[0]["name"])).is_not_empty()


func test_one_notice_at_a_time() -> void:
	_bank(120)
	_bank(500)
	assert_int(_state.notices).is_equal(1)


func test_the_watcher_arrives_on_the_next_floor_and_the_rule_holds() -> void:
	_bank(120)
	var promised: BossDef = _state.notice_pending
	_state.economy.cash = 1000
	_state.spins_remaining = 0
	_engine.step(_state)
	_engine.leave_shop(_state)
	assert_int(_state.floor_index).is_equal(2)
	assert_object(_state.watcher).is_same(promised)
	assert_object(_state.notice_pending).is_null()
	# Two people, never the same one twice.
	if _state.boss != null:
		assert_str(String(_state.boss.id)).is_not_equal(String(promised.id))
	var payload: Dictionary = _bus.events_of(EffectBus.Event.FLOOR_STARTED).back()
	assert_str(String(payload["watcher_name"])).is_equal(promised.display_name)
	assert_bool(BossEngine.people(_state).has(promised)).is_true()
	if promised.rule == BossDef.Rule.HOLDS_COST_MORE:
		assert_float(BossEngine.lock_multiplier(_state)).is_greater_equal(2.0)


func test_the_watcher_leaves_with_the_floor() -> void:
	_bank(120)
	_state.economy.cash = 5000
	_state.spins_remaining = 0
	_engine.step(_state)
	_engine.leave_shop(_state)
	assert_object(_state.watcher).is_not_null()
	_state.spins_remaining = 0
	_engine.step(_state)
	assert_object(_state.watcher).is_null()


func test_every_ante_is_dearer_once_noticed() -> void:
	var before: int = _state.ante_due()
	_bank(120)
	assert_int(_state.ante_due()).is_greater(before)
	assert_int(_state.ante_due()).is_equal(int(round(float(before) * 1.05)))


func test_nobody_is_sent_when_the_house_sends_nobody() -> void:
	var options: RunOptions = RunOptions.new()
	options.no_bosses = true
	_state = _engine.start_run(5, options)
	_bank(120)
	assert_object(_state.notice_pending).is_null()
	assert_int(_state.notices).is_equal(0)


func test_the_last_floor_has_nowhere_to_send_anyone() -> void:
	_state.floor_index = 3
	_bank(5000)
	assert_object(_state.notice_pending).is_null()


func test_the_doorman_is_only_spoken_to_at_the_desk_with_a_notice_in_hand() -> void:
	_state.economy.chips = 50
	assert_bool(_state.can_pay_doorman()).is_false()
	assert_bool(_engine.pay_doorman(_state)).is_false()
	_bank(120)
	assert_bool(_state.can_pay_doorman()).is_false()
	_state.economy.cash = 1000
	_state.spins_remaining = 0
	_engine.step(_state)
	assert_int(_state.phase).is_equal(RunState.Phase.SHOPPING)
	assert_bool(_state.can_pay_doorman()).is_true()


func test_paying_the_doorman_sends_nobody_and_costs_more_next_time() -> void:
	_bank(120)
	_state.economy.cash = 1000
	_state.spins_remaining = 0
	_engine.step(_state)
	_state.economy.chips = 20
	var price: int = _state.doorman_price()
	assert_bool(_engine.pay_doorman(_state)).is_true()
	assert_object(_state.notice_pending).is_null()
	assert_int(_state.economy.chips).is_equal(20 - price)
	assert_int(_state.doorman_price()).is_greater(price)
	assert_int(_bus.count_of(EffectBus.Event.DOORMAN_PAID)).is_equal(1)
	# The notice stands on the ante: the doorman is not the House's memory.
	assert_int(_state.notices).is_equal(1)
	_engine.leave_shop(_state)
	assert_object(_state.watcher).is_null()


func test_the_doorman_wants_chips_the_purse_may_not_have() -> void:
	_bank(120)
	_state.economy.cash = 1000
	_state.spins_remaining = 0
	_engine.step(_state)
	_state.economy.chips = 0
	assert_bool(_state.can_pay_doorman()).is_false()
	assert_bool(_engine.pay_doorman(_state)).is_false()
	assert_object(_state.notice_pending).is_not_null()
