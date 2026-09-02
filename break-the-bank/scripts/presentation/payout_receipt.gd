## The receipt: what the spin paid, and how the number was reached, printed a
## line at a time as the machine's printer would print it.
##
## The first playtest read a nudge that paid nine for no new match and called
## the logic a bug. The logic was right — the skull had left the line and the
## pair paid again — and nothing on the screen said so. This is what says so:
## every symbol's value, the pattern, every device that fired and what it
## added, the House's cuts, the stake, the total. The simulation writes the
## arithmetic as it does it ([member SpinBoard.breakdown]'s steps); this only
## prints it, so it can never disagree with the number.
##
## Presentation only. It reads the bus for the spin's start, to clear, and is
## handed the settled board by the room once the reels have landed. On a
## banked spin the lines print in time with the scoring chain — the receipt is
## visibly the physical output of what is happening, not a summary that
## appears afterwards — and the total prints as the total lands.
class_name PayoutReceipt
extends CanvasLayer

## The viewport width the type sizes were chosen at.
const DESIGN_WIDTH: float = 1152.0
## Seconds between lines as they print, at pace 1.
const LINE_TIME: float = 0.05
## Most device lines printed before the rest are folded into one.
const MAX_DEVICE_LINES: int = 5

const PAPER: Color = Color(0.9, 0.87, 0.8, 0.97)
const INK: Color = Color(0.12, 0.1, 0.08)
const INK_FAINT: Color = Color(0.36, 0.32, 0.27)
const INK_RED: Color = Color(0.62, 0.16, 0.12)
## The total, in the accent: the one line on the paper that is a score.
const INK_SCORE: Color = Color(0.62, 0.4, 0.06)
## How much of the performance the lines above the total print across; the
## total itself prints when the number lands.
const LINES_SHARE: float = 0.72

var _panel: PanelContainer
var _rows: VBoxContainer
var _bus: EffectBus
var _scale: float = 1.0
var _printing: Tween
## Cue player, handed in by the room: the dot-matrix whirr as lines print.
var _audio: AudioDirector


func _ready() -> void:
	layer = 2
	_panel = PanelContainer.new()
	_panel.name = "Paper"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 6
	style.border_width_bottom = 6
	style.border_color = Color(0.78, 0.74, 0.66, 1.0)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 1)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rows)
	_fit()
	get_viewport().size_changed.connect(_fit)


func set_audio(audio: AudioDirector) -> void:
	_audio = audio


func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)


func _fit() -> void:
	var window: Window = get_window()
	if window == null or window.size.x <= 0:
		return
	_scale = clampf(DESIGN_WIDTH / float(window.size.x), 1.0, 2.3)
	# Bottom right, above the key hint, beside the machine's own printer.
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -(300.0 + 22.0) * _scale
	_panel.offset_right = -22.0 * _scale
	_panel.offset_bottom = -44.0 * _scale
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _on_event(kind: EffectBus.Event, _payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.SPIN_STARTED, EffectBus.Event.RUN_STARTED, \
		EffectBus.Event.SHOP_OPENED, EffectBus.Event.FLOOR_STARTED:
			clear()
		_:
			pass


func clear() -> void:
	if _printing != null and _printing.is_valid():
		_printing.kill()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_panel.visible = false


## Prints [param breakdown] — a [member SpinBoard.breakdown] — for a board
## worth [param payout]. [param settled] false prints it as the board standing
## mid-decision, which is what a player deciding a nudge needs in front of them.
## [param over_seconds] paces the print to a scoring performance of that
## length; negative prints at the printer's own rate. [param tier] is the
## spin's [enum ScoreDirector.Tier]: a dead spin gets a curt receipt, a heavy
## one a printer running fast and loud.
func print_board(breakdown: Dictionary, payout: int, chips: int, settled: bool,
		title: String = "", over_seconds: float = -1.0, tier: int = -1) -> void:
	clear()
	var steps: Array = breakdown.get("steps", [])
	var lines: Array[Control] = []
	lines.append(_line(title if not title.is_empty()
			else ("RECEIPT" if settled else "STANDING — not yet banked"), "", 12.0,
			INK_FAINT, true))
	lines.append(_rule())
	if settled and tier == ScoreDirector.Tier.DEAD:
		# Curt. The symbols, and what they came to. A loss is not an absence,
		# but it is not an itemised account either.
		var dead: Array[String] = []
		for entry: Variant in steps:
			var step: Dictionary = entry as Dictionary
			if String(step.get("kind", "")) == "symbol":
				dead.append("%s %s" % [step.get("label", ""), step.get("text", "")])
		if not dead.is_empty():
			lines.append(_line(" + ".join(dead), "", 12.0, INK_FAINT))
		lines.append(_rule())
		lines.append(_line("NOTHING PAID" if payout <= 0 else "PAYS",
				"%d cr" % payout if payout > 0 else "", 16.0, INK_RED, true))
		_print_lines(lines, over_seconds, tier)
		return
	var symbols: Array[String] = []
	var symbol_total: int = 0
	var device_lines: int = 0
	var folded: int = 0
	for entry: Variant in steps:
		var step: Dictionary = entry as Dictionary
		var kind: String = String(step.get("kind", ""))
		var label: String = String(step.get("label", ""))
		var text: String = String(step.get("text", ""))
		match kind:
			"symbol":
				symbols.append("%s %s" % [label, text])
				symbol_total += int(text)
			"artifact":
				if device_lines < MAX_DEVICE_LINES:
					lines.append(_line(label, text, 13.0, INK))
					device_lines += 1
				else:
					folded += 1
			"pattern":
				lines.append(_line(label, text, 13.0,
						INK_RED if text.begins_with("x0") else INK))
			_:
				lines.append(_line(label, text, 13.0, INK_FAINT))
	if not symbols.is_empty():
		# The symbols go first, as one line, then their sum: the reels are the
		# thing the player just watched, and the rest is what the machine did.
		lines.insert(2, _line(" + ".join(symbols), "= %d" % symbol_total, 12.0, INK))
	if folded > 0:
		lines.append(_line("%d more devices" % folded, "", 12.0, INK_FAINT))
	lines.append(_rule())
	var multiplier: float = float(breakdown.get("multiplier", 1.0))
	lines.append(_line("MULTIPLIER", "x%.2f" % multiplier, 13.0, INK))
	lines.append(_line("PAYS" if settled else "WOULD PAY", "%d cr" % payout, 18.0,
			(INK_SCORE if settled else INK) if payout > 0 else INK_RED, true))
	if chips > 0:
		lines.append(_line("THE BANK", "+%d chip%s" % [chips, "" if chips == 1 else "s"],
				13.0, INK))
	_print_lines(lines, over_seconds, tier)


## Puts [param lines] on the paper one at a time. Paced to a performance when
## [param over_seconds] is given: everything above the total across the first
## part of it, the total on the beat the number lands.
func _print_lines(lines: Array[Control], over_seconds: float, tier: int) -> void:
	_panel.visible = true
	for line: Control in lines:
		line.modulate.a = 0.0
		_rows.add_child(line)
	_printing = create_tween()
	var heavy: bool = tier >= ScoreDirector.Tier.HEAVY
	if over_seconds > 0.0 and lines.size() > 1:
		var total_index: int = lines.size() - 1
		for i: int in lines.size():
			var line: Control = lines[i]
			var at: float = over_seconds if i == total_index \
					else over_seconds * LINES_SHARE * float(i) / float(total_index)
			_printing.parallel().tween_callback(func() -> void:
				line.modulate.a = 1.0).set_delay(at)
	else:
		var gap: float = LINE_TIME * SlotView3D.pace * (0.5 if heavy else 1.0)
		for i: int in lines.size():
			var line: Control = lines[i]
			_printing.tween_callback(func() -> void: line.modulate.a = 1.0).set_delay(gap)
	if _audio != null:
		# Fast and loud on a heavy spin: the printer is straining with the rest
		# of the machine.
		_audio.play(&"receipt_print", 1.25 if heavy else 1.0)
		if heavy:
			var again: Tween = create_tween()
			again.tween_callback(func() -> void:
				_audio.play(&"receipt_print", 1.3)).set_delay(0.3)


func _line(left: String, right: String, size: float, tint: Color,
		bold: bool = false) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	var a: Label = Label.new()
	a.text = left
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
	a.add_theme_color_override(&"font_color", tint)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.clip_text = false
	row.add_child(a)
	if not right.is_empty():
		var b: Label = Label.new()
		b.text = right
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
		b.add_theme_color_override(&"font_color", tint)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(b)
	if bold:
		a.add_theme_color_override(&"font_color", tint)
	return row


func _rule() -> Control:
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(0.5, 0.45, 0.38, 0.5)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule
