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
@export var line_label_path: NodePath = ^"LineRow/Line"
@export var line_icons_path: NodePath = ^"LineRow/Icons"
@export var log_label_path: NodePath = ^"Log"
@export var prompt_label_path: NodePath = ^"Prompt/Text"
@export var prompt_panel_path: NodePath = ^"Prompt"
@export var hint_label_path: NodePath = ^"Hint"

## Four lines is enough to see what the last floor did without the log becoming
## a wall down the side of the screen.
const LOG_LINES: int = 4
## The viewport width the type sizes were chosen at.
const DESIGN_WIDTH: float = 1152.0
## Height the callout allows per line of text, and for its own padding.
const PROMPT_LINE: float = 26.0
const PROMPT_PADDING: float = 26.0

var _cash: Label
var _ante: Label
var _spins: Label
var _line: Label
var _icons: HBoxContainer
var _log: Label
var _prompt: Label
var _prompt_panel: Control
var _hint: Label
var _lines: PackedStringArray = PackedStringArray()
var _bus: EffectBus
## Spins left on the current floor, tracked here because no event carries the
## remaining count — only the floor's total and the fact a spin happened.
var _spins_left: int = 0
## The symbols of the spin in progress, in reel order, as they land.
var _landed: Array[Dictionary] = []
## The finished spin, held back until the reels have shown it.
var _result: Dictionary = {}
## Type scale, matched to the window rather than the design viewport.
var _scale: float = 1.0


func _ready() -> void:
	_cash = get_node_or_null(cash_value_path) as Label
	_ante = get_node_or_null(ante_value_path) as Label
	_spins = get_node_or_null(spins_value_path) as Label
	_line = get_node_or_null(line_label_path) as Label
	_icons = get_node_or_null(line_icons_path) as HBoxContainer
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
	_scale = clampf(DESIGN_WIDTH / window_width, 1.0, 2.3)
	var scale_up: float = _scale
	for entry: Array in [
		[_cash, 27.0], [_ante, 27.0], [_spins, 27.0],
		[_line, 17.0], [_log, 13.0], [_hint, 14.0], [_prompt, 18.0],
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
	_place_rows(scale_up)


## Moves the stacked rows down in step with the type.
##
## The offsets in the scene are authored against 27px gauge values. Scaling the
## type up without moving anything leaves the payline row where a much shorter
## gauge box used to end, and on a phone it lands on top of them.
func _place_rows(scale_up: float) -> void:
	var line_row: Control = get_node_or_null(^"LineRow") as Control
	if line_row != null:
		line_row.offset_top = 90.0 * scale_up
		line_row.offset_bottom = 126.0 * scale_up
		line_row.offset_left = 22.0 * scale_up
	var log_label: Control = _log as Control
	if log_label != null:
		log_label.offset_top = -96.0 * scale_up
		log_label.offset_bottom = -34.0 * scale_up
		log_label.offset_left = 22.0 * scale_up
	var hint: Control = _hint as Control
	if hint != null:
		hint.offset_top = -30.0 * scale_up
		hint.offset_bottom = -10.0 * scale_up
		hint.offset_left = -560.0 * scale_up
	# A marquee under the gauges rather than a banner across the machine. It
	# used to sit dead centre, which is exactly where the reels are, so every
	# callout hid the thing it was talking about.
	# Top right, opposite the gauges and clear of the payline readout under
	# them. Centred it sat on the reels; under the gauges it sat on the verdict.
	var prompt: Control = _prompt_panel
	if prompt != null and prompt.anchor_top == 0.0:
		prompt.offset_left = -700.0 * scale_up
	# Re-laying the callout at the new scale is set_prompt's job, and it holds
	# the text; re-running it keeps the height in step with the type.
	if _prompt != null:
		set_prompt(_prompt.text, _prompt_panel != null and _prompt_panel.anchor_top > 0.0)
	var gauges: Control = get_node_or_null(^"Gauges") as Control
	if gauges != null:
		gauges.offset_left = 22.0 * scale_up
		gauges.offset_top = 18.0 * scale_up


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
			var boss_name: String = String(payload.get("boss_name", ""))
			_push("Entered %s" % String(payload.get("name", "")) if boss_name == ""
					else "Entered %s — %s is on the floor" % [
							String(payload.get("name", "")), boss_name])
		EffectBus.Event.BOSS_ACTED:
			# The collector's round: the vig, mid-floor. Said where the ante
			# is said, because it comes out of the same purse.
			_set_text(_line, "%s: the vig, again — %d paid" % [
					String(payload.get("name", "")).to_upper(), int(payload.get("serviced", 0))])
			_push("%s took %d" % [String(payload.get("name", "")), int(payload.get("serviced", 0))])
		EffectBus.Event.FLOOR_CLEARED:
			_push("Floor %d cleared" % int(payload.get("floor", 0)))
		EffectBus.Event.SPIN_STARTED:
			_spins_left = maxi(0, _spins_left - 1)
			_set_text(_spins, str(_spins_left))
			_landed.clear()
			_result.clear()
			# Cleared as the handle goes down, so the previous spin's verdict is
			# not still sitting there while these reels turn.
			_set_text(_line, "")
			if _icons != null:
				for child: Node in _icons.get_children():
					_icons.remove_child(child)
					child.queue_free()
		EffectBus.Event.SYMBOL_LANDED:
			_landed.append(payload)
		EffectBus.Event.SPIN_RESOLVED:
			# Held, not shown. This event arrives in the same frame as the spin
			# request, so displaying it here printed the pattern and the payout
			# before a single reel had stopped — the readout spoiled every spin
			# the machine was still in the middle of showing.
			#
			# The board as it stands is what the reels are landing on, and it is
			# all there is until the player has answered whatever the machine is
			# asking: a board owing nudges is never banked, so waiting for the
			# payout left the readout describing nothing at all.
			_result = payload
		EffectBus.Event.REEL_NUDGED:
			# A nudge repaints one reel and rescores the line, so the icon row
			# and the number both have to follow it.
			var moved: int = int(payload.get("reel", -1))
			var column: Dictionary = payload.get("column", {}) as Dictionary
			if moved >= 0 and moved < _landed.size() and not column.is_empty():
				_landed[moved] = column
			_result["payout"] = payload.get("payout", 0)
			_result["pattern"] = payload.get("pattern", "")
			_spins_left = int(payload.get("spins_remaining", _spins_left))
			_set_text(_spins, str(_spins_left))
			_show_line(_result)
		EffectBus.Event.SYSTEM_GRANTED:
			_push("Unlocked %s" % String(payload.get("title", "")))
		EffectBus.Event.CONTRACT_SIGNED:
			_push("Signed %s" % String(payload.get("name", "")))
		EffectBus.Event.HEAT_CHANGED:
			# The pit boss raises the ante in the middle of a floor, so the
			# gauge has to follow it rather than keep quoting the price the
			# floor opened at.
			_set_text(_ante, str(int(payload.get("ante", 0))))
			if bool(payload.get("changed", false)):
				var measure: String = String(payload.get("name", ""))
				if not measure.is_empty():
					_push("The House: %s" % measure)
		EffectBus.Event.PAYOUT_CALCULATED:
			_result = payload
		EffectBus.Event.ARTIFACT_ACQUIRED:
			_push("Acquired %s" % String(payload.get("artifact", "")))
		EffectBus.Event.RUN_ENDED:
			_push("Run ended: %s" % String(payload.get("end_reason", "")))
		_:
			pass


## Draws the spin's result once the reels have landed and the view has judged it.
##
## Everything the player learns about a spin arrives at the same moment: the
## symbols stop, the coins fall, the sound plays and the readout fills in.
##
## Showing the symbols rather than naming the pattern is what lets a player
## check the machine against the readout without translating between them —
## the same three drawings appear in both places.
func _show_line(payload: Dictionary) -> void:
	_set_text(_line, "%s   ×%.2f   →  %d" % [
		String(payload.get("pattern", "")).capitalize(),
		float(payload.get("multiplier", 1.0)), int(payload.get("payout", 0)),
	])
	if _icons == null:
		return
	for child: Node in _icons.get_children():
		_icons.remove_child(child)
		child.queue_free()
	var size: float = 26.0 * _scale
	for landed: Dictionary in _landed:
		var tint: Color = landed.get("color", Color.WHITE)
		var art: ImageTexture = SymbolArt.texture_for(
				StringName(landed.get("symbol", &"")), tint)
		if art == null:
			continue
		var icon: TextureRect = TextureRect.new()
		icon.texture = art
		icon.custom_minimum_size = Vector2(size, size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = String(landed.get("symbol", ""))
		_icons.add_child(icon)


## Says how the spin went, in words and colour, once the reels have landed.
##
## The readout used to print the pattern and the number and leave the player to
## work out whether that was good. It is judged against what the floor needs per
## spin, so the same verdict means the same thing on floor 1 and floor 7.
func mark_result(result: SlotView3D.Result, _payout: int, settled: bool = true) -> void:
	if _line == null:
		return
	_show_line(_result)
	# A board the machine still owes a decision on has not been judged yet. It
	# used to be called dead while the player was looking at a nudge worth forty
	# credits, which is the readout arguing with the buttons underneath it.
	var verdict: String = ("STANDING" if not settled
			else ["DEAD", "THIN", "PAID", "JACKPOT"][int(result)])
	var tint: Color = (UiSkin.INK_MUTED if not settled else [
		Color(0.63, 0.42, 0.40), Color(0.76, 0.71, 0.60),
		Color(1.0, 0.82, 0.44), Color(1.0, 0.62, 0.24),
	][int(result)])
	_line.text = "%s     %s" % [verdict, _line.text]
	_line.add_theme_color_override(&"font_color", tint)
	_line.modulate = Color(1, 1, 1, 1)
	if settled and result >= SlotView3D.Result.GOOD:
		# A win is worth a beat of movement; a dead spin is worth stillness.
		var pulse: Tween = create_tween()
		_line.pivot_offset = Vector2.ZERO
		pulse.tween_property(_line, "scale", Vector2(1.12, 1.12), 0.08)
		pulse.tween_property(_line, "scale", Vector2.ONE, 0.32) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Callout for the moments that need a decision or an epitaph. An empty string
## hides it.
##
## Normally a marquee under the gauges: it used to sit dead centre, which is
## exactly where the reels are, so every callout hid the thing it was talking
## about. [param centred] puts it back in the middle for the one message where
## the machine no longer matters — the end of the run.
func set_prompt(text: String, centred: bool = false) -> void:
	if _prompt == null:
		return
	_prompt.text = text
	if _prompt_panel == null:
		return
	_prompt_panel.visible = not text.is_empty()
	_prompt_panel.anchor_left = 0.5 if centred else 1.0
	_prompt_panel.anchor_right = 0.5 if centred else 1.0
	_prompt_panel.anchor_top = 0.5 if centred else 0.0
	_prompt_panel.anchor_bottom = 0.5 if centred else 0.0
	_prompt_panel.offset_left = (-380.0 if centred else -700.0) * _scale
	_prompt_panel.offset_right = (380.0 if centred else -22.0) * _scale
	# Height from the content rather than a fixed box. Anchored to the top, a
	# panel whose text outgrows its offsets grows the wrong way and the first
	# line ends up above the screen — which is where the run's last warning was
	# going, on the one floor that most needed reading.
	var rows: int = maxi(text.split("\n").size(), 1)
	var height: float = PROMPT_PADDING + PROMPT_LINE * float(rows)
	_prompt_panel.offset_top = (-height * 0.5 if centred else 18.0) * _scale
	_prompt_panel.offset_bottom = (height * 0.5 if centred else 18.0 + height) * _scale


func _push(text: String) -> void:
	_lines.append(text)
	while _lines.size() > LOG_LINES:
		_lines.remove_at(0)
	_set_text(_log, "\n".join(_lines))


func _set_text(label: Label, text: String) -> void:
	if label != null:
		label.text = text
