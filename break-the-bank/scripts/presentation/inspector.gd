## What is this? — answered by the machine, on the thing itself.
##
## The roadmap's inspection layer: rest the pointer on a counter, a dial, a
## drum or the column and the House prints a card for it — what the number
## is, what it is currently worth, and where it comes from. On a phone the
## same card comes up on a tap.
##
## Presentation only, and deliberately dumb: [CasinoRoom] reads the run and
## hands over finished lines, because working out what a symbol pays is the
## simulation's business and printing it is this file's.
class_name Inspector
extends CanvasLayer

## The card follows the pointer at this offset, flipping to the other side
## when it would run off the screen.
const OFFSET: Vector2 = Vector2(22.0, 18.0)
const MAX_WIDTH: float = 340.0

var _panel: PanelContainer
var _rows: VBoxContainer
var _scale: float = 1.0
var _showing: StringName = &""


func _ready() -> void:
	layer = 4
	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiSkin.sheet(_panel)
	_panel.visible = false
	add_child(_panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rows)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	var window: Window = get_window()
	if window == null or window.size.x <= 0:
		return
	_scale = clampf(RunHUD.DESIGN_WIDTH / float(window.size.x), 1.0, 2.3) * RunHUD.user_scale
	_panel.custom_minimum_size = Vector2(MAX_WIDTH * _scale, 0.0)


## Prints a card. [param title] is the thing; [param lines] are what the
## House has to say about it. Calling with the same id twice is free, so a
## hover that fires every frame costs nothing.
func show_card(id: StringName, title: String, lines: PackedStringArray) -> void:
	if id == _showing and _panel.visible:
		return
	_showing = id
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	# The card is the one place a number on the cabinet becomes a sentence,
	# so it is also where those sentences are translated. A line already
	# folded together by the room arrives finished and passes through.
	_rows.add_child(_line(Copy.upper(title), 13.0, UiSkin.PAPER_STAMP, true))
	for text: String in lines:
		_rows.add_child(_line(Copy.of(text), 12.0, UiSkin.PAPER_INK, false))
	_panel.visible = true
	_place()


func hide_card() -> void:
	_showing = &""
	_panel.visible = false


func is_showing() -> bool:
	return _panel.visible


func _process(_delta: float) -> void:
	if _panel.visible:
		_place()


## Beside the pointer, and never off the edge: a card that has to be chased
## is worse than no card.
func _place() -> void:
	var pointer: Vector2 = _panel.get_global_mouse_position()
	var view: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var size: Vector2 = _panel.size
	var at: Vector2 = pointer + OFFSET * _scale
	if at.x + size.x > view.x:
		at.x = pointer.x - size.x - OFFSET.x * _scale
	if at.y + size.y > view.y:
		at.y = maxf(pointer.y - size.y - OFFSET.y * _scale, 0.0)
	_panel.position = at


func _line(text: String, size: float, tint: Color, bold: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", Type.display() if bold else Type.body())
	label.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
	label.add_theme_color_override(&"font_color", tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(MAX_WIDTH * _scale - 20.0, 0.0)
	return label
