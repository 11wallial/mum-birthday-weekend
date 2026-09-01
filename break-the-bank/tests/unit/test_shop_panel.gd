extends GdUnitTestSuite

## UI-level coverage of the draft: the panel must show what the state says and
## report intent without touching the run itself.

const SCENE: String = "res://scenes/ui/shop_panel.tscn"

var _panel: ShopPanel
var _state: RunState
var _engine: SimEngine


func before_test() -> void:
	var bus: EffectBus = EffectBus.new()
	_engine = SimEngine.new(TestFixtures.content_with_shop(), bus)
	_engine.shop_policy = Callable()
	_state = _engine.start_run(7)
	var guard: int = 0
	while _state.phase != RunState.Phase.SHOPPING and not _state.is_over() and guard < 50:
		_engine.step(_state)
		guard += 1
	_panel = auto_free((load(SCENE) as PackedScene).instantiate()) as ShopPanel
	add_child(_panel)


func _rows() -> Array[Node]:
	var container: VBoxContainer = _panel.get_node("Panel/Rows/Offers") as VBoxContainer
	return container.get_children()


## Every piece of text a row displays, joined.
##
## A row is a laid-out grid of labels rather than one padded string — the price
## has to sit in its own right-aligned column, which a single Button.text cannot
## do in a proportional font. So the assertion is on what the row shows, not on
## which node happens to hold it.
func _row_text(row: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var pending: Array[Node] = [row]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var label: Label = node as Label
		if label != null:
			parts.append(label.text)
		var button: Button = node as Button
		if button != null and not button.text.is_empty():
			parts.append(button.text)
		pending.append_array(node.get_children())
	return " ".join(parts)


func test_the_panel_starts_hidden() -> void:
	assert_bool(_panel.visible).is_false()
	assert_bool(_panel.is_open()).is_false()


func test_opening_lists_one_row_per_offer() -> void:
	_panel.open(_state)
	assert_bool(_panel.is_open()).is_true()
	assert_bool(_panel.visible).is_true()
	assert_int(_rows().size()).is_equal(_state.shop_offers.size())


func test_each_row_names_its_artifact_and_price() -> void:
	_panel.open(_state)
	var rows: Array[Node] = _rows()
	for i: int in rows.size():
		var shown: String = _row_text(rows[i])
		assert_str(shown).contains(_state.shop_offers[i].display_name)
		assert_str(shown).contains(str(_state.shop_prices[i]))
		# The description is what a draft decision is actually made on — but the
		# fixtures carry none, so asserting it unconditionally would be a claim
		# about TestFixtures rather than about the panel.
		if not _state.shop_offers[i].description.is_empty():
			assert_str(shown).contains(_state.shop_offers[i].description)


func test_unaffordable_rows_are_shown_but_disabled() -> void:
	_panel.open(_state)
	var rows: Array[Node] = _rows()
	for i: int in rows.size():
		var button: Button = rows[i] as Button
		# Listed either way — the point is to see what you cannot afford.
		assert_bool(button.visible).is_true()
		assert_bool(button.disabled).is_equal(not _state.can_buy(i))


func test_pressing_a_row_reports_intent_without_changing_the_run() -> void:
	_panel.open(_state)
	var cash: int = _state.economy.cash
	var owned: int = _state.owned.size()
	var reported: Array[int] = []
	_panel.buy_requested.connect(func(index: int) -> void: reported.append(index))
	(_rows()[0] as Button).pressed.emit()
	assert_array(reported).is_equal([0])
	# The panel is a view: only the room may mutate the run.
	assert_int(_state.economy.cash).is_equal(cash)
	assert_int(_state.owned.size()).is_equal(owned)


func test_refreshing_after_a_purchase_drops_the_bought_row() -> void:
	_panel.open(_state)
	var before: int = _rows().size()
	var index: int = -1
	for i: int in _state.shop_offers.size():
		if _state.can_buy(i):
			index = i
			break
	assert_int(index).is_greater_equal(0)
	_engine.buy_offer(_state, index)
	_panel.refresh()
	assert_int(_rows().size()).is_equal(before - 1)


func test_closing_hides_it_again() -> void:
	_panel.open(_state)
	_panel.close()
	assert_bool(_panel.is_open()).is_false()
	assert_bool(_panel.visible).is_false()
