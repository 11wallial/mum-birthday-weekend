## The statement of account, on the clipboard at the end of a run.
##
## A loss the player cannot diagnose reads as random however much choice
## the run gave them, and the balance guide's bar is four in five naming
## their mistake. So the run does not end on a line of text over the
## machine: the camera walks to the desk and the House's statement is on
## the clipboard — the outcome in its own terms, the account, the moves,
## its findings, and the last spin's receipt. Built in code, mounted on the
## board's viewport like the draft and the office; emits nothing, holds
## nothing but what it was handed.
class_name RecapPanel
extends CanvasLayer

var _sheet: PanelContainer
var _rows: VBoxContainer
var _open: bool = false
var _mounted: bool = false
var _scale: float = 1.0


func _ready() -> void:
	layer = 3
	_sheet = PanelContainer.new()
	_sheet.name = "Panel"
	_sheet.anchor_left = 0.5
	_sheet.anchor_top = 0.5
	_sheet.anchor_right = 0.5
	_sheet.anchor_bottom = 0.5
	_sheet.offset_left = -450.0
	_sheet.offset_top = -240.0
	_sheet.offset_right = 450.0
	_sheet.offset_bottom = 240.0
	_sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	UiSkin.sheet(_sheet)
	_sheet.visible = false
	add_child(_sheet)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	_sheet.add_child(_rows)
	visible = false


func is_open() -> bool:
	return _open


## Moves the sheet onto the clipboard's viewport. See [method ShopPanel.mount].
func mount(board: SubViewport) -> void:
	if _sheet == null or _mounted:
		return
	_sheet.get_parent().remove_child(_sheet)
	board.add_child(_sheet)
	_sheet.visible = _open
	_mounted = true


## Prints [param recap], a [method RunRecap.build], with [param seed_code]
## and the score line the room has already worked out.
func open(recap: Dictionary, seed_code: String, score_line: String) -> void:
	_open = true
	visible = true
	_sheet.visible = true
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var won: bool = bool(recap.get("won", false))
	_rows.add_child(_cell("STATEMENT OF ACCOUNT — %s" % seed_code, 18.0, UiSkin.PAPER_STAMP))
	_rows.add_child(_cell(String(recap.get("outcome", "")), 14.0, UiSkin.PAPER_INK, true))
	_rows.add_child(_rule())
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 2)
	var moves: Dictionary = recap.get("moves", {})
	var account: Array = [
		["FLOORS CLEARED", str(recap.get("floors_cleared", 0))],
		["SPINS", str(recap.get("spins_taken", 0))],
		["EARNED", "%d cr" % int(recap.get("earned", 0))],
		["BEST SPIN", "%d cr" % int(recap.get("best_payout", 0))],
		["CHIPS EARNED", str(recap.get("chips", 0))],
		["HARDWARE", str((recap.get("hardware", []) as PackedStringArray).size())],
		["OWED AT THE CLOSE", "%d cr" % int(recap.get("debt", 0))],
		["IN HAND", "%d cr" % int(recap.get("cash", 0))],
	]
	for pair: Array in account:
		grid.add_child(_cell(String(pair[0]), 11.0, UiSkin.PAPER_INK_MUTED))
		grid.add_child(_cell(String(pair[1]), 13.0, UiSkin.PAPER_INK))
	_rows.add_child(grid)
	var move_line: PackedStringArray = PackedStringArray()
	for pair: Array in [["toggle_hold", "held"], ["nudge", "nudged"], ["decline_nudges", "declined"],
			["gamble", "doubled"], ["set_stake", "staked"], ["deposit", "deposited"],
			["buy_offer", "bought"], ["reroll_shop", "rerolled"], ["sign_slate", "signed the slate"],
			["settle_floor", "settled early"], ["press", "pressed"], ["sign_contract", "contracted"]]:
		var n: int = int(moves.get(String(pair[0]), 0))
		if n > 0:
			move_line.append("%s %d" % [String(pair[1]), n])
	if not move_line.is_empty():
		_rows.add_child(_cell("THE MOVES   " + "   ".join(move_line), 11.0, UiSkin.PAPER_INK_MUTED))
	var findings: PackedStringArray = recap.get("findings", PackedStringArray())
	if not findings.is_empty():
		_rows.add_child(_rule())
		_rows.add_child(_cell("THE HOUSE FINDS" if not won else "THE HOUSE NOTES", 12.0, UiSkin.PAPER_STAMP))
		for finding: String in findings:
			var line: Label = _cell("— " + finding, 13.0, UiSkin.PAPER_INK)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_rows.add_child(line)
	var hardware: PackedStringArray = recap.get("hardware", PackedStringArray())
	if not hardware.is_empty():
		var kit: Label = _cell("FITTED   " + ", ".join(hardware), 11.0, UiSkin.PAPER_INK_MUTED)
		kit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.add_child(kit)
	_rows.add_child(_rule())
	_rows.add_child(_cell(score_line, 12.0, UiSkin.PAPER_INK_MUTED))
	_rows.add_child(_cell(TouchBar.hint("R runs this seed back     F5 for a new run     F2 for the door",
			"New run / Setup — the buttons top right"), 12.0, UiSkin.PAPER_INK_MUTED))


func close() -> void:
	_open = false
	visible = false
	if _sheet != null:
		_sheet.visible = false


func _cell(text: String, size: float, tint: Color, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = tr(text)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
	label.add_theme_color_override(&"font_color", tint)
	if bold:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _rule() -> Control:
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(0.5, 0.45, 0.38, 0.5)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule
