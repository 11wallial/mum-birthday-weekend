## Run readout: the numbers a player checks between spins.
##
## Reads the bus and the [RunState] snapshot only. It holds no game state of its
## own, so it can be rebuilt mid-run without losing anything.
##
## Deliberately small. Debt lives on the machine's monitor and the floor's name
## on the wall sign, so the overlay is down to cash, ante and spins remaining —
## the three that change every spin and have nowhere in the world to sit.
class_name RunHUD
extends CanvasLayer

@export var cash_value_path: NodePath = ^"Gauges/Cash/Rows/Value"
@export var ante_value_path: NodePath = ^"Gauges/Ante/Rows/Value"
@export var spins_value_path: NodePath = ^"Gauges/Spins/Rows/Value"
@export var line_label_path: NodePath = ^"Line"
@export var log_label_path: NodePath = ^"Log"
@export var prompt_label_path: NodePath = ^"Prompt/Text"
@export var prompt_panel_path: NodePath = ^"Prompt"
@export var hint_label_path: NodePath = ^"Hint"

## Four lines is enough to see what the last floor did without the log becoming
## a wall down the side of the screen.
const LOG_LINES: int = 4
## The viewport width the type sizes were chosen at.
const DESIGN_WIDTH: float = 1152.0

var _cash: Label
var _ante: Label
var _spins: Label
var _line: Label
var _log: Label
var _prompt: Label
var _prompt_panel: Control
var _hint: Label
var _lines: PackedStringArray = PackedStringArray()
var _bus: EffectBus
## Spins left on the current floor, tracked here because no event carries the
## remaining count — only the floor's total and the fact a spin happened.
var _spins_left: int = 0


func _ready() -> void:
	_cash = get_node_or_null(cash_value_path) as Label
	_ante = get_node_or_null(ante_value_path) as Label
	_spins = get_node_or_null(spins_value_path) as Label
	_line = get_node_or_null(line_label_path) as Label
	_log = get_node_or_null(log_label_path) as Label
	_prompt = get_node_or_null(prompt_label_path) as Label
	_prompt_panel = get_node_or_null(prompt_panel_path) as Control
	_hint = get_node_or_null(hint_label_path) as Label
	# The scene carries the desktop wording; a touch build has no such keys.
	if _hint != null and TouchBar.is_touch_device():
		_hint.text = "TAP to spin / advance     buttons top-right"
	_fit_type()
	get_viewport().size_changed.connect(_fit_type)
	set_prompt("")


## Scales the type to the real window rather than the design viewport.
##
## The project stretches canvas items to fit, which on a phone means everything
## is drawn at roughly half size — correct for a layout, wrong for text, because
## a 12px caption becomes 6px and stops being readable at arm's length. This
## divides that scaling back out, so type stays a constant physical size and only
## the layout stretches.
func _fit_type() -> void:
	var window: Window = get_window()
	if window == null:
		return
	var window_width: float = float(window.size.x)
	if window_width <= 0.0:
		return
	var scale_up: float = clampf(DESIGN_WIDTH / window_width, 1.0, 2.3)
	for entry: Array in [
		[_cash, 27.0], [_ante, 27.0], [_spins, 27.0],
		[_line, 17.0], [_log, 13.0], [_hint, 14.0], [_prompt, 21.0],
	]:
		var label: Label = entry[0] as Label
		if label != null:
			label.add_theme_font_size_override(&"font_size",
					int(roundf(float(entry[1]) * scale_up)))
	for caption: Node in get_tree().get_nodes_in_group(&"hud_caption"):
		var label: Label = caption as Label
		if label != null:
			label.add_theme_font_size_override(&"font_size",
					int(roundf(12.0 * scale_up)))
	# The boxes have to grow with what is inside them, or scaled-up type just
	# fills the padding and the gauges read as cramped.
	_scale_gauge_padding(scale_up)


func _scale_gauge_padding(scale_up: float) -> void:
	var gauges: Node = get_node_or_null(^"Gauges")
	if gauges == null:
		return
	for child: Node in gauges.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel == null:
			continue
		var style: StyleBox = panel.get_theme_stylebox(&"panel")
		if style == null:
			continue
		var scaled: StyleBox = style.duplicate() as StyleBox
		scaled.content_margin_left = 12.0 * scale_up
		scaled.content_margin_right = 12.0 * scale_up
		scaled.content_margin_top = 7.0 * scale_up
		scaled.content_margin_bottom = 7.0 * scale_up
		panel.add_theme_stylebox_override(&"panel", scaled)


func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.RUN_STARTED:
			_set_text(_cash, str(int(payload.get("cash", 0))))
			_lines.clear()
			_push("Seed %s" % SeedBook.to_code(int(payload.get("seed", 0))))
		EffectBus.Event.ANTE_SETTLED:
			var paid: bool = bool(payload.get("paid", false))
			_set_text(_line, "ANTE %d %s" % [
				int(payload.get("ante", 0)), "paid" if paid else "UNPAID"])
		EffectBus.Event.CASH_CHANGED:
			_set_text(_cash, str(int(payload.get("cash", 0))))
		EffectBus.Event.FLOOR_STARTED:
			_set_text(_ante, str(int(payload.get("ante", 0))))
			_spins_left = int(payload.get("spins", 0))
			_set_text(_spins, str(_spins_left))
			_push("Entered %s" % String(payload.get("name", "")))
		EffectBus.Event.FLOOR_CLEARED:
			_push("Floor %d cleared" % int(payload.get("floor", 0)))
		EffectBus.Event.SPIN_STARTED:
			_spins_left = maxi(0, _spins_left - 1)
			_set_text(_spins, str(_spins_left))
		EffectBus.Event.PAYOUT_CALCULATED:
			_set_text(_line, "%s  ×%.2f  →  %d" % [
				String(payload.get("pattern", "")), float(payload.get("multiplier", 1.0)),
				int(payload.get("payout", 0)),
			])
		EffectBus.Event.ARTIFACT_ACQUIRED:
			_push("Acquired %s" % String(payload.get("artifact", "")))
		EffectBus.Event.RUN_ENDED:
			_push("Run ended: %s" % String(payload.get("end_reason", "")))
		_:
			pass


## Centre-screen callout for the moments that need a decision or an epitaph.
## An empty string hides it.
func set_prompt(text: String) -> void:
	if _prompt == null:
		return
	_prompt.text = text
	if _prompt_panel != null:
		_prompt_panel.visible = not text.is_empty()


func _push(text: String) -> void:
	_lines.append(text)
	while _lines.size() > LOG_LINES:
		_lines.remove_at(0)
	_set_text(_log, "\n".join(_lines))


func _set_text(label: Label, text: String) -> void:
	if label != null:
		label.text = text
