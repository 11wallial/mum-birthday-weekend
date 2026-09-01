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
@export var leave_button_path: NodePath = ^"Panel/Rows/Leave"

var _rows: VBoxContainer
var _title: Label
var _footer: Label
var _leave: Button
var _state: RunState
var _open: bool = false
## Type scale, matched to the window the same way the HUD's is.
var _scale: float = 1.0


func _ready() -> void:
	_rows = get_node_or_null(rows_path) as VBoxContainer
	_title = get_node_or_null(title_path) as Label
	_footer = get_node_or_null(footer_path) as Label
	# A touch device has no Space key, so leaving has to be reachable by tap.
	# The button is always present rather than touch-only: a visible exit is
	# clearer than a documented one on every device.
	_leave = get_node_or_null(leave_button_path) as Button
	if _leave != null:
		_leave.pressed.connect(_on_leave_pressed)
		UiSkin.dress_button(_leave)
	var panel: PanelContainer = get_node_or_null(^"Panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override(&"panel", UiSkin.panel())
	_fit_type()
	get_viewport().size_changed.connect(_fit_type)
	visible = false


## Keeps the draft legible on a phone. Same reasoning as [RunHUD]: the canvas is
## stretched to fit, so without this the text is drawn at about half size.
func _fit_type() -> void:
	var window: Window = get_window()
	if window == null or window.size.x <= 0:
		return
	_scale = clampf(RunHUD.DESIGN_WIDTH / float(window.size.x), 1.0, 2.3)
	if _title != null:
		_title.add_theme_font_size_override(&"font_size", int(roundf(18.0 * _scale)))
	if _footer != null:
		_footer.add_theme_font_size_override(&"font_size", int(roundf(14.0 * _scale)))
	if _leave != null:
		_leave.add_theme_font_size_override(&"font_size", int(roundf(17.0 * _scale)))
		_leave.custom_minimum_size = Vector2(0.0, 52.0 * _scale)
	if _open:
		_redraw()


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
		_title.text = "THE DRAFT — FLOOR %d CLEARED      CASH %d      DEBT %d" % [
			_state.floors_cleared, _state.economy.cash, _state.economy.debt]
		_title.add_theme_color_override(&"font_color", UiSkin.AMBER)
	for i: int in _state.shop_offers.size():
		_rows.add_child(_build_row(i))
	if _footer != null:
		var offers: int = maxi(_state.shop_offers.size(), 1)
		_footer.text = TouchBar.hint(
				"1-%d or click to buy     SPACE / Q to leave" % offers,
				"Tap an offer to buy")


## One offer, laid out rather than padded into a single string.
##
## The old row was `"%d.  %-18s  %4d cr   %s"`, which only lines up in a
## monospaced font — and the UI font is proportional, so the prices wandered.
## Real columns also let the price sit in amber against a cream name, which is
## the distinction that matters when you are deciding what you can afford.
func _build_row(index: int) -> Control:
	var artifact: ArtifactDef = _state.shop_offers[index]
	var price: int = _state.shop_prices[index]
	var affordable: bool = _state.can_buy(index)

	var button: Button = Button.new()
	button.disabled = not affordable
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = (Control.CURSOR_POINTING_HAND if affordable
			else Control.CURSOR_ARROW)
	button.add_theme_stylebox_override(&"normal", UiSkin.row(affordable))
	button.add_theme_stylebox_override(&"hover", UiSkin.row(affordable, true))
	button.add_theme_stylebox_override(&"pressed", UiSkin.row(affordable, true))
	button.add_theme_stylebox_override(&"disabled", UiSkin.row(affordable))
	button.add_theme_stylebox_override(&"focus", UiSkin.row(affordable, true))
	button.pressed.connect(_on_row_pressed.bind(index))

	# The label grid sits inside the button and ignores the pointer, so the whole
	# row stays one hit target — which on a phone is the only usable size.
	var grid: VBoxContainer = VBoxContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"separation", int(roundf(2.0 * _scale)))
	# Inset by the row stylebox's own padding. A full-rect preset zeroes the
	# offsets, which puts the text under the border and runs the price off the
	# right edge — the stylebox pads the *background*, not the children.
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 20.0 * _scale
	grid.offset_right = -14.0 * _scale
	grid.offset_top = 10.0 * _scale
	grid.offset_bottom = -10.0 * _scale

	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", int(roundf(12.0 * _scale)))
	head.add_child(_cell("%d." % (index + 1), 17.0,
			UiSkin.INK_MUTED if affordable else UiSkin.DENIED))
	var name_cell: Label = _cell(artifact.display_name, 17.0,
			UiSkin.INK if affordable else UiSkin.DENIED)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_cell)
	var price_cell: Label = _cell("%d cr" % price, 17.0,
			UiSkin.AMBER if affordable else UiSkin.DENIED)
	price_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(price_cell)
	grid.add_child(head)

	var body: Label = _cell(artifact.description, 14.0, UiSkin.INK_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(body)

	button.add_child(grid)
	# The button has to be told how tall its own contents are: a Button is not a
	# container, so nothing else will size it around them.
	button.custom_minimum_size = Vector2(0.0, 58.0 * _scale)
	return button


func _cell(text: String, size: float, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
	label.add_theme_color_override(&"font_color", tint)
	return label


func _on_row_pressed(index: int) -> void:
	buy_requested.emit(index)


func _on_leave_pressed() -> void:
	leave_requested.emit()


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
