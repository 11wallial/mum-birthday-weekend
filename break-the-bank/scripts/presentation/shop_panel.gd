## The draft: what is on offer, what it costs, and what you can afford.
##
## Emits intent and nothing else — it never touches [RunState] itself. The room
## turns a signal into a [method SimEngine.buy_offer] call, which is the same
## call the headless shop policy makes.
class_name ShopPanel
extends CanvasLayer

signal buy_requested(index: int)
signal leave_requested()
## Emitted for the market's own moves, once the floor that opens it is past.
signal market_requested(action: StringName, index: int)
## A press job was asked for, by index into the state's press offers.
signal press_requested(index: int)
## The doorman: a word, and the House sends nobody after the notice.
signal doorman_requested()
## The pocket: the draft's chit, bought.
signal chit_requested()

const REROLL: StringName = &"reroll"
const SLATE: StringName = &"slate"
const SELL: StringName = &"sell"

## Number keys past this many offers are ignored; the shop never rolls more.
const MAX_SLOTS: int = 5

@export var rows_path: NodePath = ^"Panel/Rows/Offers"
@export var title_path: NodePath = ^"Panel/Rows/Title"
@export var footer_path: NodePath = ^"Panel/Rows/Footer"
@export var leave_button_path: NodePath = ^"Panel/Rows/Leave"
## The market's own row. A run can own twenty artifacts by floor six and every
## one of them is sellable, so the row scrolls rather than overflowing the panel.
@export var market_path: NodePath = ^"Panel/Rows/MarketScroll/Market"

var _rows: VBoxContainer
var _title: Label
var _footer: Label
var _leave: Button
var _market: HBoxContainer
var _state: RunState
var _open: bool = false
## The row a pad or the arrows have picked, for a hand with no number keys.
var _cursor: int = 0
## The form itself, when it has been mounted on the clipboard in the room:
## the Panel, moved into the board's viewport. Visibility follows it.
var _sheet: Control
var _mounted: bool = false
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
	_market = get_node_or_null(market_path) as HBoxContainer
	if _leave != null:
		_leave.pressed.connect(_on_leave_pressed)
		UiSkin.dress_paper_button(_leave)
	var panel: PanelContainer = get_node_or_null(^"Panel") as PanelContainer
	if panel != null:
		UiSkin.sheet(panel)
		_sheet = panel
	_fit_type()
	get_viewport().size_changed.connect(_fit_type)
	visible = false


## Keeps the draft legible on a phone. Same reasoning as [RunHUD]: the canvas is
## stretched to fit, so without this the text is drawn at about half size.
func _fit_type() -> void:
	var window: Window = get_window()
	if window == null or window.size.x <= 0:
		return
	# On the clipboard the form is a fixed sheet of texels the camera reads
	# at a texel a pixel; only the overlay copy scales with the window.
	_scale = 1.0 if _mounted else clampf(RunHUD.DESIGN_WIDTH / float(window.size.x), 1.0, 2.3)
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
	if _sheet != null:
		_sheet.visible = true
	_redraw()


func close() -> void:
	_open = false
	visible = false
	if _sheet != null:
		_sheet.visible = false


## Moves the form onto the clipboard: its Panel into [param board], the
## viewport the room draws onto the paper in the room. Keys still arrive
## here, on the layer; the pointer arrives through the board's pick area.
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
		# Removed as well as freed: queue_free() defers, so a redraw in the same
		# frame as a purchase would stack a second set of rows on the first.
		_rows.remove_child(child)
		child.queue_free()
	if _title != null:
		_title.text = "THE DRAFT — FLOOR %d CLEARED      CHIPS %d      CASH %d      DEBT %d" % [
			_state.floors_cleared, _state.economy.chips, _state.economy.cash,
			_state.economy.debt]
		_title.add_theme_color_override(&"font_color", UiSkin.PAPER_STAMP)
	_cursor = clampi(_cursor, 0, maxi(_state.shop_offers.size() - 1, 0))
	for i: int in _state.shop_offers.size():
		_rows.add_child(_build_row(i))
	_draw_press()
	_draw_pocket()
	_draw_doorman()
	_draw_market()
	if _footer != null:
		var offers: int = maxi(_state.shop_offers.size(), 1)
		_footer.text = TouchBar.hint(
				"1-%d or click to buy     arrows and ENTER on a pad     SPACE / Q to leave" % offers,
				"Tap an offer to buy")


## The press: the two jobs on the reel this draft offers, each named for
## what it does and what it costs, with the symbol it does it to. The reel
## is the player's to edit, and this is where the editing is bought.
func _draw_press() -> void:
	# Its own row under the offers, never among them: the offers container is
	# one row per artifact, and the number keys index it.
	var parent: Control = _rows.get_parent() as Control
	if parent == null:
		return
	var old: Node = parent.get_node_or_null(^"Press")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	if _state.press_offers.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Press"
	row.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	var head: Label = _cell("THE PRESS", 13.0, UiSkin.PAPER_INK_MUTED)
	head.custom_minimum_size = Vector2(96.0 * _scale, 0.0)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	for i: int in _state.press_offers.size():
		var job: Dictionary = _state.press_offers[i]
		var symbol: SymbolDef = ContentDB.shared().symbol_by_id(
				StringName(String(job.get("symbol", ""))))
		var name: String = symbol.display_name if symbol != null \
				else String(job.get("symbol", "")).capitalize()
		var text: String = ""
		match String(job.get("kind", "")):
			"strike":
				text = "STRIKE the %s  −%d weight" % [name.to_lower(), int(job.get("magnitude", 0))]
			"print":
				text = "PRINT more %s  +%d weight" % [name.to_lower(), int(job.get("magnitude", 0))]
			"gild":
				text = "GILD the %s  +%d a symbol" % [name.to_lower(), int(job.get("magnitude", 0))]
		var index: int = i
		var badge: TextureRect = _symbol_badge(symbol.id if symbol != null else &"",
				_state.can_press(i))
		# Room for the badge at the left of the caption: a Button lays out its
		# own text, so the icon sits in a margin of spaces.
		var caption: String = "%s%s   %d chips" % [
			"       " if badge != null else "", text, int(job.get("price", 0))]
		var chip: Button = _chip(caption, _state.can_press(i), UiSkin.PAPER_INK,
				func() -> void: press_requested.emit(index))
		if badge != null:
			chip.add_child(badge)
			badge.position = Vector2(12.0, 8.0) * _scale
		row.add_child(chip)
	parent.add_child(row)
	parent.move_child(row, _rows.get_index() + 1)


## The pocket's line on the form: the chit on the table and what is already
## carried. Paper, not hardware — a decision bought in advance.
func _draw_pocket() -> void:
	var parent: Control = _rows.get_parent() as Control
	if parent == null:
		return
	var old: Node = parent.get_node_or_null(^"Pocket")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	if _state.chit_offer == null and _state.pocket.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Pocket"
	row.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	var head: Label = _cell("THE POCKET", 13.0, UiSkin.PAPER_INK_MUTED)
	head.custom_minimum_size = Vector2(96.0 * _scale, 0.0)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	if _state.chit_offer != null:
		var chit: ChitDef = _state.chit_offer
		row.add_child(_chip("%s   %s   %d chips" % [chit.display_name.to_upper(),
				chit.description, chit.cost], _state.can_buy_chit(), UiSkin.PAPER_INK,
				func() -> void: chit_requested.emit()))
	var carried: PackedStringArray = PackedStringArray()
	for held: ChitDef in _state.pocket:
		carried.append(held.display_name)
	var note: Label = _cell("carrying: %s" % (", ".join(carried) if not carried.is_empty() else "nothing")
			+ "   (%d of %d)" % [_state.pocket.size(), RunState.POCKET], 11.0, UiSkin.PAPER_INK_MUTED)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)
	parent.add_child(row)
	var press: Node = parent.get_node_or_null(^"Press")
	parent.move_child(row, (press.get_index() + 1) if press != null else (_rows.get_index() + 1))


## The doorman's line on the form, only while someone is on their way: who
## the House noticed you for, who is coming, and what a word costs.
func _draw_doorman() -> void:
	var parent: Control = _rows.get_parent() as Control
	if parent == null:
		return
	var old: Node = parent.get_node_or_null(^"Doorman")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	if _state.notice_pending == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Doorman"
	row.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	var head: Label = _cell("THE DOORMAN", 13.0, UiSkin.PAPER_INK_MUTED)
	head.custom_minimum_size = Vector2(96.0 * _scale, 0.0)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	var note: Label = _cell("The House noticed %d in one spin. %s is coming to floor %d: %s" % [
			_state.noticed_payout, _state.notice_pending.display_name,
			_state.floor_index + 1, _state.notice_pending.tell.to_lower()], 12.0, UiSkin.PAPER_INK)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)
	row.add_child(_chip("A WORD   %d chips, and nobody comes" % _state.doorman_price(),
			_state.can_pay_doorman(), UiSkin.PAPER_STAMP,
			func() -> void: doorman_requested.emit()))
	parent.add_child(row)
	var press: Node = parent.get_node_or_null(^"Press")
	parent.move_child(row, (press.get_index() + 1) if press != null else (_rows.get_index() + 1))


## The market's own row: a reroll, and everything the player already owns,
## priced to sell. Absent entirely before the floor that opens the market, so
## the draft on floor one is still just a draft.
func _draw_market() -> void:
	if _market == null:
		return
	for child: Node in _market.get_children():
		_market.remove_child(child)
		child.queue_free()
	var open_for_business: bool = _state.has_system(Systems.MARKET)
	var scroller: Control = _market.get_parent() as Control
	if scroller != null:
		scroller.visible = open_for_business
	if not open_for_business:
		return
	var reroll_price: int = _state.reroll_price()
	_market.add_child(_chip("REROLL  %d chips" % reroll_price,
			_state.economy.can_afford_chips(reroll_price), UiSkin.PAPER_STAMP,
			func() -> void: market_requested.emit(REROLL, 0)))
	for i: int in _state.owned.size():
		var artifact: ArtifactDef = _state.owned[i]
		var refund: int = _state.sellback_of(artifact)
		var index: int = i
		_market.add_child(_chip("SELL %s  +%d" % [artifact.display_name, refund],
				true, UiSkin.PAPER_INK_MUTED,
				func() -> void: market_requested.emit(SELL, index)))


func _chip(text: String, enabled: bool, tint: Color, pressed: Callable) -> Button:
	var button: Button = Button.new()
	UiSkin.dress_paper_button(button)
	button.text = tr(text)
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", int(roundf(13.0 * _scale)))
	button.add_theme_color_override(&"font_color", tint if enabled else UiSkin.PAPER_DENIED)
	button.custom_minimum_size = Vector2(0.0, 40.0 * _scale)
	button.pressed.connect(pressed)
	return button


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
	# The mark: the row a pad has picked wears the hover face.
	button.add_theme_stylebox_override(&"normal", UiSkin.paper_row(affordable, index == _cursor))
	button.add_theme_stylebox_override(&"hover", UiSkin.paper_row(affordable, true))
	button.add_theme_stylebox_override(&"pressed", UiSkin.paper_row(affordable, true))
	button.add_theme_stylebox_override(&"disabled", UiSkin.paper_row(affordable))
	button.add_theme_stylebox_override(&"focus", UiSkin.paper_row(affordable, true))
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
			UiSkin.PAPER_INK_MUTED if affordable else UiSkin.PAPER_DENIED))
	# An artifact that only affects one symbol shows that symbol. "+4 draw
	# weight on Lucky Seven" is a sentence; the seven itself is the thing the
	# player is about to go looking for on the reels.
	var badge: TextureRect = _symbol_badge(artifact.symbol_filter, affordable)
	if badge != null:
		head.add_child(badge)
	var name_cell: Label = _cell(artifact.display_name, 17.0,
			UiSkin.PAPER_INK if affordable else UiSkin.PAPER_DENIED)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_cell)
	# The build it belongs to, as a small plate beside the name: a player
	# chasing the clamp should be able to see the clamp coming.
	var build: ArchetypeDef = ContentDB.shared().archetype_by_id(artifact.archetype)
	if build != null:
		head.add_child(_cell(build.display_name.to_upper(), 11.0,
				UiSkin.PAPER_INK_MUTED if affordable else UiSkin.PAPER_DENIED))
	var price_cell: Label = _cell("%d chips" % price, 17.0,
			UiSkin.PAPER_STAMP if affordable else UiSkin.PAPER_DENIED)
	price_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(price_cell)
	grid.add_child(head)

	var body: Label = _cell(artifact.description, 14.0, UiSkin.PAPER_INK_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(body)

	button.add_child(grid)
	# The button has to be told how tall its own contents are: a Button is not a
	# container, so nothing else will size it around them.
	button.custom_minimum_size = Vector2(0.0, 58.0 * _scale)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _state.has_system(Systems.MARKET):
		return button

	# The slate sits beside the price, not inside the buy button: putting a
	# second control inside the first is how a tap to buy ends up signing for
	# something instead.
	var pair: HBoxContainer = HBoxContainer.new()
	pair.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	pair.add_child(button)
	var owed: int = _state.slate_price(index)
	var slate: Button = _chip("SLATE\n%d cr owed" % owed, true, UiSkin.PAPER_DENIED,
			func() -> void: market_requested.emit(SLATE, index))
	slate.custom_minimum_size = Vector2(112.0, 58.0) * _scale
	pair.add_child(slate)
	return pair


## The icon for the symbol an artifact singles out, or null if it applies to
## every symbol — which most do, and a badge on all of them would say nothing.
func _symbol_badge(symbol_id: StringName, affordable: bool) -> TextureRect:
	if symbol_id == &"":
		return null
	var symbol: SymbolDef = ContentDB.shared().symbol_by_id(symbol_id)
	if symbol == null:
		return null
	var art: ImageTexture = SymbolArt.texture_for(symbol.id, symbol.color,
					symbol.second_color())
	if art == null:
		return null
	var badge: TextureRect = TextureRect.new()
	badge.texture = art
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(24.0, 24.0) * _scale
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 1, 1, 0.5)
	badge.tooltip_text = symbol.display_name
	return badge


func _cell(text: String, size: float, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = tr(text)
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
	# A pad, or the arrows: walk the offers and take the one under the mark.
	if _move_cursor(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"bb_confirm") and _state != null \
			and _cursor >= 0 and _cursor < _state.shop_offers.size():
		buy_requested.emit(_cursor)
		get_viewport().set_input_as_handled()


## Moves the mark with the arrows or the pad. Returns true when it moved.
func _move_cursor(event: InputEvent) -> bool:
	if _state == null or _state.shop_offers.is_empty():
		return false
	var count: int = _state.shop_offers.size()
	if event.is_action_pressed(&"bb_view_prev") or event.is_action_pressed(&"ui_up"):
		_cursor = posmod(_cursor - 1, count)
	elif event.is_action_pressed(&"bb_view_next") or event.is_action_pressed(&"ui_down"):
		_cursor = posmod(_cursor + 1, count)
	else:
		return false
	_redraw()
	return true


## Redraws after the room has applied a purchase.
func refresh() -> void:
	if _open:
		_redraw()
