## The draft: what is on offer, what it costs, and what you can afford.
##
## Emits intent and nothing else — it never touches [RunState] itself. The room
## turns a signal into a [method SimEngine.buy_offer] call, which is the same
## call the headless shop policy makes.
class_name ShopPanel
extends CanvasLayer

signal buy_requested(index: int)
signal leave_requested()

## Number keys past this many offers are ignored; the shop never rolls more.
const MAX_SLOTS: int = 5

@export var rows_path: NodePath = ^"Panel/Rows/Offers"
@export var title_path: NodePath = ^"Panel/Rows/Title"
@export var footer_path: NodePath = ^"Panel/Rows/Footer"

var _rows: VBoxContainer
var _title: Label
var _footer: Label
var _state: RunState
var _open: bool = false


func _ready() -> void:
	_rows = get_node_or_null(rows_path) as VBoxContainer
	_title = get_node_or_null(title_path) as Label
	_footer = get_node_or_null(footer_path) as Label
	visible = false


func is_open() -> bool:
	return _open


## Shows the current offers on [param state]. Call again after a purchase to
## redraw; the panel holds no state of its own beyond what it is handed.
func open(state: RunState) -> void:
	_state = state
	_open = true
	visible = true
	_redraw()


func close() -> void:
	_open = false
	visible = false


func _redraw() -> void:
	if _rows == null or _state == null:
		return
	for child: Node in _rows.get_children():
		# Removed as well as freed: queue_free() defers, so a redraw in the same
		# frame as a purchase would stack a second set of rows on the first.
		_rows.remove_child(child)
		child.queue_free()
	if _title != null:
		_title.text = "THE SHOP — FLOOR %d CLEARED     CASH %d     DEBT %d" % [
			_state.floors_cleared, _state.economy.cash, _state.economy.debt]
	for i: int in _state.shop_offers.size():
		_rows.add_child(_build_row(i))
	if _footer != null:
		_footer.text = "1-%d or click to buy     SPACE / Q to leave" % maxi(
				_state.shop_offers.size(), 1)


func _build_row(index: int) -> Control:
	var artifact: ArtifactDef = _state.shop_offers[index]
	var price: int = _state.shop_prices[index]
	var affordable: bool = _state.can_buy(index)

	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not affordable
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%d.  %-18s  %4d cr   %s" % [
		index + 1, artifact.display_name, price, artifact.description]
	button.tooltip_text = artifact.description
	# Unaffordable rows stay listed: knowing what you cannot afford is most of
	# the decision in a shop.
	button.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 0.6, 0.6, 0.55)
	button.pressed.connect(_on_row_pressed.bind(index))
	return button


func _on_row_pressed(index: int) -> void:
	buy_requested.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"bb_leave_shop"):
		leave_requested.emit()
		get_viewport().set_input_as_handled()
		return
	for slot: int in MAX_SLOTS:
		if event.is_action_pressed(StringName("bb_slot_%d" % (slot + 1))):
			buy_requested.emit(slot)
			get_viewport().set_input_as_handled()
			return


## Redraws after the room has applied a purchase.
func refresh() -> void:
	if _open:
		_redraw()
