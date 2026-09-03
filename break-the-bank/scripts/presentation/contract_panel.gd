## The back office: three of the house's standing offers, and a pen.
##
## Sits between the draft and the stairs from floor five on. Emits intent only —
## the room turns a signal into [method SimEngine.sign_contract], which is the
## same call the automated policy makes.
##
## Every contract shows both halves. A panel that led with the boon and buried
## the toll would be the casino's own marketing, and the whole point of the
## floor is that the player reads the terms.
class_name ContractPanel
extends CanvasLayer

signal sign_requested(index: int)

## Number keys past this many offers are ignored; the office never puts out more.
const MAX_SLOTS: int = 3

@export var rows_path: NodePath = ^"Panel/Rows/Offers"
@export var title_path: NodePath = ^"Panel/Rows/Title"
@export var footer_path: NodePath = ^"Panel/Rows/Footer"

var _rows: VBoxContainer
var _title: Label
var _footer: Label
var _state: RunState
var _open: bool = false
## The row a pad or the arrows have picked, for a hand with no number keys.
var _cursor: int = 0
## The form, when mounted on the clipboard. See [method ShopPanel.mount].
var _sheet: Control
var _mounted: bool = false
var _scale: float = 1.0


func _ready() -> void:
	_rows = get_node_or_null(rows_path) as VBoxContainer
	_title = get_node_or_null(title_path) as Label
	_footer = get_node_or_null(footer_path) as Label
	var panel: PanelContainer = get_node_or_null(^"Panel") as PanelContainer
	if panel != null:
		UiSkin.sheet(panel)
		_sheet = panel
	_fit_type()
	get_viewport().size_changed.connect(_fit_type)
	visible = false


func _fit_type() -> void:
	var window: Window = get_window()
	if window == null or window.size.x <= 0:
		return
	_scale = 1.0 if _mounted else clampf(RunHUD.DESIGN_WIDTH / float(window.size.x), 1.0, 2.3)
	if _title != null:
		_title.add_theme_font_size_override(&"font_size", int(roundf(18.0 * _scale)))
	if _footer != null:
		_footer.add_theme_font_size_override(&"font_size", int(roundf(14.0 * _scale)))
	if _open:
		_redraw()


func is_open() -> bool:
	return _open


func open(state: RunState) -> void:
	_state = state
	_open = true
	visible = true
	if _sheet != null:
		_sheet.visible = true
	_redraw()


func close() -> void:
	_open = false
	visible = false
	if _sheet != null:
		_sheet.visible = false


func mount(board: SubViewport) -> void:
	if _sheet == null or _mounted:
		return
	_sheet.get_parent().remove_child(_sheet)
	board.add_child(_sheet)
	_sheet.visible = _open
	_mounted = true
	_fit_type()


func _redraw() -> void:
	if _rows == null or _state == null:
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var next_floor: FloorDef = _state.content.floor_at(_state.floor_index + 1)
	if _title != null:
		_title.text = "THE BACK OFFICE — SIGN FOR %s" % (
				Copy.upper(next_floor.display_name) if next_floor != null else "THE NEXT FLOOR")
		_title.add_theme_color_override(&"font_color", UiSkin.PAPER_STAMP)
	_cursor = clampi(_cursor, 0, maxi(_state.contract_offers.size() - 1, 0))
	for i: int in _state.contract_offers.size():
		_rows.add_child(_build_row(i))
	if _footer != null:
		_footer.text = TouchBar.hint(
				"1-%d or click to sign     the terms hold for one floor"
						% maxi(_state.contract_offers.size(), 1),
				"Tap a contract to sign     the terms hold for one floor")


func _build_row(index: int) -> Control:
	var contract: ContractDef = _state.contract_offers[index]
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		button.add_theme_stylebox_override(state_name,
				UiSkin.paper_row(true, state_name == &"hover" or state_name == &"pressed"
				or index == _cursor))
	button.pressed.connect(func() -> void: sign_requested.emit(index))

	var grid: VBoxContainer = VBoxContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"separation", int(roundf(3.0 * _scale)))
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 20.0 * _scale
	grid.offset_right = -14.0 * _scale
	grid.offset_top = 10.0 * _scale
	grid.offset_bottom = -10.0 * _scale

	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", int(roundf(12.0 * _scale)))
	head.add_child(_cell("%d." % (index + 1), 17.0, UiSkin.PAPER_INK_MUTED))
	var name_cell: Label = _cell(Copy.of(contract.display_name), 17.0, UiSkin.PAPER_INK)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_cell)
	grid.add_child(head)

	var flavour: Label = _cell(Copy.of(contract.description), 13.0, UiSkin.PAPER_INK_MUTED)
	flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(flavour)

	# The two halves, in the two colours the rest of the game already uses for
	# "this is yours" and "this is the house's".
	var terms: HBoxContainer = HBoxContainer.new()
	terms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terms.add_theme_constant_override(&"separation", int(roundf(22.0 * _scale)))
	for entry: Dictionary in contract.clauses():
		var gives: bool = bool(entry["gives"])
		terms.add_child(_cell(ContractDef.phrase(entry), 14.0,
				UiSkin.PAPER_STAMP if gives else UiSkin.PAPER_DENIED))
	grid.add_child(terms)

	button.add_child(grid)
	button.custom_minimum_size = Vector2(0.0, 92.0 * _scale)
	return button


func _cell(text: String, size: float, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = tr(text)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
	label.add_theme_color_override(&"font_color", tint)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	for slot: int in MAX_SLOTS:
		if event.is_action_pressed(StringName("bb_slot_%d" % (slot + 1))):
			sign_requested.emit(slot)
			get_viewport().set_input_as_handled()
			return
	if _state != null and not _state.contract_offers.is_empty():
		var count: int = _state.contract_offers.size()
		if event.is_action_pressed(&"bb_view_prev") or event.is_action_pressed(&"ui_up"):
			_cursor = posmod(_cursor - 1, count)
			_redraw()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"bb_view_next") or event.is_action_pressed(&"ui_down"):
			_cursor = posmod(_cursor + 1, count)
			_redraw()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"bb_confirm"):
			sign_requested.emit(clampi(_cursor, 0, count - 1))
			get_viewport().set_input_as_handled()
			return
	# Nothing else gets through. Signing is not optional, and a key meant for a
	# panel underneath must not reach the machine while the office is waiting.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
