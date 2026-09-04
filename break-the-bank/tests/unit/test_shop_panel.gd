extends GdUnitTestSuite

## UI-level coverage of the form the draft is signed on.
##
## The offers themselves are cards on the desk and are covered by
## test_draft_cards; what stays here is the panel's own life — it opens, it
## closes, and it carries the paperwork beside the goods.

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


func test_closing_hides_it_again() -> void:
	_panel.open(_state)
	_panel.close()
	assert_bool(_panel.is_open()).is_false()
	assert_bool(_panel.visible).is_false()
