extends GdUnitTestSuite

## The deck is how seven floors' worth of verbs reach the player's hands, so
## what it offers has to follow the run exactly: a control on the floor that
## grants it, nothing before, and never a move the simulation would refuse.

const SCENE: String = "res://scenes/ui/control_deck.tscn"

var _deck: ControlDeck
var _state: RunState
var _engine: SimEngine


func before_test() -> void:
	var content: ContentDB = TestFixtures.content()
	content.floors.assign([TestFixtures.floor_granting(1, 200, 20, [Systems.HOLD])])
	_engine = SimEngine.new(content, EffectBus.new())
	_engine.clear_policies()
	_state = _engine.start_run(5)
	_state.economy.cash = 500
	_deck = auto_free((load(SCENE) as PackedScene).instantiate()) as ControlDeck
	add_child(_deck)
	_deck.bind(_state)


func _labels(row_path: NodePath) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var pending: Array[Node] = [_deck.get_node(row_path)]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var label: Label = node as Label
		if label != null:
			parts.append(label.text)
		pending.append_array(node.get_children())
	return " | ".join(parts)


func _actions() -> String:
	return _labels(^"Root/Column/Actions") + " | " + _button_text(^"Root/Column/Extras")


## The standing controls carry their caption on the Button itself rather than in
## a child Label, so they are read differently from the primary actions.
func _button_text(row_path: NodePath) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for child: Node in _deck.get_node(row_path).get_children():
		var button: Button = child as Button
		if button != null:
			parts.append(button.text)
	return " | ".join(parts)


func _reels() -> String:
	return _labels(^"Root/Column/Reels")


func _status() -> String:
	return _labels(^"Root/Status")


func test_a_fresh_machine_offers_a_spin_and_a_lock_per_reel() -> void:
	assert_str(_actions()).contains("SPIN")
	assert_str(_reels()).contains("HOLD  1")
	assert_str(_reels()).contains("HOLD  3")


func test_a_verb_the_run_has_not_been_given_is_not_on_the_deck() -> void:
	assert_str(_actions()).not_contains("STAKE")
	assert_str(_actions()).not_contains("BANK")
	assert_str(_status()).not_contains("COUNT")

	_state.grant_system(Systems.STAKE)
	_state.grant_system(Systems.HEAT)
	_deck.refresh()
	assert_str(_actions()).contains("STAKE")
	assert_str(_status()).contains("COUNT")


func test_the_spin_button_prices_the_locks_it_is_carrying() -> void:
	assert_str(_actions()).contains("%d cr" % _state.spin_price())
	_engine.toggle_hold(_state, 0)
	_deck.refresh()
	assert_str(_actions()).contains("%d cr" % _state.spin_price())


func test_nothing_is_offered_while_the_reels_are_still_turning() -> void:
	_deck.set_busy(true)
	assert_str(_actions()).not_contains("SPIN")
	assert_str(_reels()).is_empty()
	_deck.set_busy(false)
	assert_str(_actions()).contains("SPIN")


func test_the_trail_replaces_the_locks_with_nudges() -> void:
	_state.board.nudges = 2
	_state.decision = RunState.Decision.NUDGE
	_deck.refresh()
	assert_str(_reels()).contains("NUDGE  1")
	assert_str(_reels()).not_contains("HOLD")
	assert_str(_actions()).contains("TAKE IT")


func test_the_ladder_shows_the_odds_it_is_actually_asking_for() -> void:
	_state.grant_system(Systems.GAMBLE)
	_state.board.payout = 40
	_state.decision = RunState.Decision.GAMBLE
	_deck.refresh()
	assert_str(_actions()).contains("DOUBLE")
	assert_str(_actions()).contains("COLLECT")
	assert_str(_actions()).contains("40 → 80 at %d%%" % int(round(
			_state.config.gamble_odds[0] * 100.0)))


func test_pressing_a_control_reports_intent_without_changing_the_run() -> void:
	var seen: Array = []
	_deck.action_requested.connect(func(action: StringName, index: int) -> void:
		seen.append([action, index]))
	var spins: int = _state.spins_remaining
	var cash: int = _state.economy.cash
	for button: Node in _deck.get_node(^"Root/Column/Reels").get_children():
		(button as Button).pressed.emit()
	assert_int(seen.size()).is_equal(_state.reel_count())
	assert_str(String(seen[0][0])).is_equal(String(ControlDeck.HOLD))
	assert_int(_state.spins_remaining).is_equal(spins)
	assert_int(_state.economy.cash).is_equal(cash)


func test_a_finished_run_offers_nothing() -> void:
	_state.phase = RunState.Phase.LOST
	_deck.refresh()
	assert_str(_actions()).not_contains("SPIN")
	assert_str(_reels()).is_empty()
	assert_str(_status()).is_empty()
