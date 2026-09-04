## Drives the room in a language that does not exist, and reports every word
## that came out in English anyway.
##
##   godot --headless --path . --script res://tools/text/pseudo_check.gd -- \
##       [--moves=200] [--settle=0.4] [--list]
##
## The extractor can only find a string where it is written. A caption built
## somewhere unexpected, a label filled from a dictionary, a sentence folded
## together before anyone thought about it — those are invisible to it and
## perfectly visible to a player in French. So: every row in the table is
## given a translation that is the English wrapped in ⟦brackets⟧, the locale
## is set to one no shipping build has, and the room is played. Anything the
## screen ends up holding that has letters and no brackets was never looked
## up.
##
## It is the only check here that reads what was actually drawn rather than
## what was written, which is why it drives the real room rather than a
## fixture. Exit is non-zero when something got through.
extends SceneTree

const TABLE: String = "res://resources/locale/strings.csv"
const PSEUDO: String = "xx"
const DEFAULT_MOVES: int = 220
const DEFAULT_SETTLE: float = 0.4
var _room: Node
var _moves: int = DEFAULT_MOVES
var _made: int = 0
var _settle: float = DEFAULT_SETTLE
var _wait: float = 0.0
var _done: bool = false
var _list: bool = false
var _loose: Dictionary = {}
var _seen: int = 0


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	_moves = int(args.get("moves", DEFAULT_MOVES))
	_settle = float(args.get("settle", DEFAULT_SETTLE))
	_list = args.has("list")
	var rows: int = _install_pseudo()
	if rows == 0:
		push_error("pseudo_check: the table is empty")
		quit(2)
		return
	print("pseudo_check: %d rows wrapped, locale %s" % [rows, PSEUDO])
	RunSave.clear()
	var packed: PackedScene = load("res://scenes/3d/casino_room.tscn") as PackedScene
	if packed == null:
		push_error("pseudo_check: cannot load the room")
		quit(2)
		return
	_room = packed.instantiate()
	root.add_child(_room)
	_wait = _settle


## Every row in the table, translated to itself in brackets.
func _install_pseudo() -> int:
	var file: FileAccess = FileAccess.open(TABLE, FileAccess.READ)
	if file == null:
		return 0
	var pseudo: Translation = Translation.new()
	pseudo.locale = PSEUDO
	var rows: int = 0
	var first: bool = true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		if first:
			first = false
			continue
		pseudo.add_message(row[0], "⟦%s⟧" % row[0])
		rows += 1
	file.close()
	TranslationServer.add_translation(pseudo)
	TranslationServer.set_locale(PSEUDO)
	return rows


func _process(delta: float) -> bool:
	if _done:
		return true
	if _wait > 0.0:
		_wait -= delta
		return false
	_read(root)
	if _made == 0 and _room.has_method("debug_close_door"):
		_room.call("debug_close_door")
	var state: RunState = _room.get("state") as RunState
	if state == null:
		_finish("no run on the table")
		return true
	if state.is_over():
		_read(root)
		_finish("")
		return true
	if state.phase == RunState.Phase.SIGNING:
		_room.call("debug_sign", 0)
	elif bool(_room.call("debug_shop_open")):
		_room.call("debug_buy_what_it_can")
	else:
		_room.call("debug_advance")
	# Every panel the player can open is a place a caption can hide, and a
	# run that only spins never opens most of them.
	if _made % 17 == 3:
		_room.call("debug_inspect", &"counter:cash")
	if _made % 17 == 9:
		_room.call("debug_inspect", &"heat")
	# The door, its settings and its keys, which no run reaches on its own.
	if _made == 12 and _room.has_method("debug_open_settings"):
		_room.call("debug_open_settings", false)
	elif _made == 14 and _room.has_method("debug_open_settings"):
		_room.call("debug_open_settings", true)
	elif _made == 16 and _room.has_method("debug_close_door"):
		_read(root)
		_room.call("debug_close_door")
	_made += 1
	_wait = _settle
	if _made >= _moves:
		_read(root)
		_finish("")
		return true
	return false


## Everything with text on it, anywhere in the tree.
func _read(node: Node) -> void:
	var text: String = ""
	# A Control translates its own text as it draws it, so a caption set in
	# English is fine there as long as the table has a row for it. A Label3D
	# does not: the cabinet's own words are drawn exactly as they are set,
	# which is why they have to arrive translated.
	var drawn: bool = node is Label3D
	if node is Label or node is Button or node is Label3D or node is RichTextLabel:
		text = String(node.get("text"))
	if text != "" and not _mid_reveal(text):
		_seen += 1
		for line: String in text.split("\n"):
			if _is_loose(line, drawn):
				_loose[line] = int(_loose.get(line, 0)) + 1
	for child: Node in node.get_children():
		_read(child)


## True while a label is still typing a translated string out. The memo
## readout reveals a character at a time, so a frame caught mid-reveal holds
## a prefix — and a prefix of a translated paragraph has lost its closing
## bracket, which is the only mark this check has to go on. The second line
## of "⟦We have your number.\nWe do not need a name.⟧" arrives as "We do no"
## and looks exactly like a caption nobody translated.
##
## A finished string always carries both brackets, so counting them tells the
## two apart without this needing to know a typewriter exists. Judging the
## whole label rather than the line is what makes that work: the opening
## bracket is on the first line and the missing closing one on the last.
func _mid_reveal(text: String) -> bool:
	return text.count("⟦") != text.count("⟧")


## True when a line of drawn text will reach the player in English. A line
## the table translated carries brackets; a line a Control will translate
## for itself passes if the table has a row for it; a line of numbers,
## punctuation or a seed code carries no words and belongs to nobody.
func _is_loose(line: String, drawn_as_set: bool) -> bool:
	var trimmed: String = line.strip_edges()
	# Either bracket: a line the room split out of a translated paragraph
	# carries only one of them.
	if trimmed.contains("⟦") or trimmed.contains("⟧") or trimmed.length() < 4:
		return false
	if not drawn_as_set and TranslationServer.translate(trimmed).contains("⟦"):
		return false
	var letters: int = 0
	for i: int in trimmed.length():
		if trimmed[i].to_lower() != trimmed[i].to_upper():
			letters += 1
	if letters < 4:
		return false
	# A seed code is three words of capitals joined by hyphens, and a name a
	# player typed is not the table's business either.
	return not trimmed.is_valid_identifier() and trimmed.count("-") < 2


func _finish(problem: String) -> void:
	_done = true
	RunSave.clear()
	if problem != "":
		print("pseudo_check: FAIL — %s" % problem)
		quit(1)
		return
	var lines: Array = _loose.keys()
	lines.sort_custom(func(a: String, b: String) -> bool:
		return int(_loose[b]) < int(_loose[a]))
	print("pseudo_check: read %d labels over %d moves" % [_seen, _made])
	if lines.is_empty():
		print("pseudo_check: PASS — every word on the screen came out of the table")
		quit(0)
		return
	print("pseudo_check: FAIL — %d line%s never went through the table:" % [
			lines.size(), "" if lines.size() == 1 else "s"])
	for line: String in lines if _list else lines.slice(0, mini(25, lines.size())):
		print("  x%-4d %s" % [int(_loose[line]), line])
	if not _list and lines.size() > 25:
		print("  ... and %d more (--list for all)" % (lines.size() - 25))
	quit(1)


func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg: String in argv:
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var split: int = body.find("=")
		if split < 0:
			out[body] = true
		else:
			out[body.substr(0, split)] = body.substr(split + 1)
	return out
