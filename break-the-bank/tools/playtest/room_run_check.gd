## Plays a whole run through the real room, headless, and checks it ended
## where a run should: on the statement, at the desk.
##
##   godot --headless --path . --script res://tools/playtest/room_run_check.gd -- \
##       --moves=600 --settle=0.7
##
## The simulation's runs are tested ten thousand at a time; the room's are
## not, and the room is where an event arm once shadowed the end of every
## run for hours without a test noticing. This drives the room through the
## same debug entry points the storyboard uses — spinning, buying at the
## draft, signing at the office — until the run is over or the moves run
## out, and fails on a script error, a run that never ends, or a run that
## ends without the statement of account on the clipboard.
extends SceneTree

const DEFAULT_MOVES: int = 600
const DEFAULT_SETTLE: float = 0.7

var _room: Node
var _moves: int = DEFAULT_MOVES
var _made: int = 0
var _settle: float = DEFAULT_SETTLE
var _wait: float = 0.0
var _done: bool = false


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	_moves = int(args.get("moves", DEFAULT_MOVES))
	_settle = float(args.get("settle", DEFAULT_SETTLE))
	RunSave.clear()
	var packed: PackedScene = load("res://scenes/3d/casino_room.tscn") as PackedScene
	if packed == null:
		push_error("room_run_check: cannot load the room")
		quit(2)
		return
	_room = packed.instantiate()
	root.add_child(_room)
	_wait = _settle


func _process(delta: float) -> bool:
	if _done:
		return true
	if _wait > 0.0:
		_wait -= delta
		return false
	if _made == 0 and _room.has_method("debug_close_door"):
		_room.call("debug_close_door")
	var state: RunState = _room.get("state") as RunState
	if state == null:
		_finish(false, "no run on the table")
		return true
	if state.is_over():
		var summary: Dictionary = _room.call("debug_run_summary")
		if not bool(summary["recap_open"]):
			_finish(false, "the run ended (%s on floor %d) without the statement on the clipboard" % [
					summary["phase"], int(summary["floor"])])
			return true
		if int(summary["view"]) != CameraController.View.DESK:
			_finish(false, "the run ended but the camera did not go to the desk")
			return true
		_finish(true, "%s on floor %d after %d moves, the statement on the clipboard" % [
				summary["phase"], int(summary["floor"]), _made])
		return true
	if state.phase == RunState.Phase.SIGNING:
		_room.call("debug_sign", 0)
	elif bool(_room.call("debug_shop_open")):
		_room.call("debug_buy_what_it_can")
	else:
		_room.call("debug_advance")
	_made += 1
	_wait = _settle
	if _made >= _moves:
		_finish(false, "the run had not ended after %d moves (floor %d, %s)" % [
				_moves, state.floor_index, String(RunState.Phase.keys()[state.phase])])
		return true
	return false


func _finish(ok: bool, message: String) -> void:
	_done = true
	print("room_run_check: %s — %s" % ["PASS" if ok else "FAIL", message])
	RunSave.clear()
	quit(0 if ok else 1)


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
