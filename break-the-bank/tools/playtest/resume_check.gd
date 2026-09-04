## Plays the real scene, closes it, opens it again, and checks the run came
## back exactly where it was left.
##
##   godot --headless --path . --script res://tools/playtest/resume_check.gd -- \
##       --moves=24 --settle=0.9
##
## The journal's replay is pinned by unit tests; this is the other half — that
## CasinoRoom writes the save on every move, resumes from it on boot, and that
## the room it rebuilds carries the same state as the one that was closed. It
## drives the room through the same debug entry points the storyboard uses,
## so what it exercises is the presentation's own save path, not a shortcut.
## Runs headless: the tweens still take real time, so each move waits.
extends SceneTree

enum Stage { PLAYING, FLUSHING, RESUMING, CHECKING, DONE }

const DEFAULT_MOVES: int = 24
const DEFAULT_SETTLE: float = 0.9

var _room: Node = null
var _stage: Stage = Stage.PLAYING
var _moves: int = DEFAULT_MOVES
var _made: int = 0
var _settle: float = DEFAULT_SETTLE
var _wait: float = 0.0
var _expected: Dictionary = {}
var _packed: PackedScene


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	_moves = int(args.get("moves", DEFAULT_MOVES))
	_settle = float(args.get("settle", DEFAULT_SETTLE))
	# Nothing left over from a previous check, or from a real run on this
	# machine, decides what this one resumes.
	RunSave.clear()
	_packed = load("res://scenes/3d/casino_room.tscn") as PackedScene
	if _packed == null:
		push_error("resume_check: cannot load the room")
		quit(2)
		return
	_open_room()
	_wait = _settle


func _open_room() -> void:
	_room = _packed.instantiate()
	root.add_child(_room)


func _process(delta: float) -> bool:
	if _wait > 0.0:
		_wait -= delta
		return false
	match _stage:
		Stage.PLAYING:
			_play_one()
		Stage.FLUSHING:
			# The deferred write has had a frame. Remember what was on the table,
			# then close the room the way quitting would.
			_expected = _describe(_room)
			var saved: RunJournal = RunSave.read(ContentDB.shared())
			if saved == null:
				_finish(false, "no save was written after %d moves" % _made)
				return true
			print("saved: seed %d, %d journaled moves, floor %d, phase %s" % [
				saved.seed_value, saved.entries.size(),
				int(_expected["floor"]), String(_expected["phase"])])
			root.remove_child(_room)
			_room.free()
			_room = null
			_stage = Stage.RESUMING
			_wait = _settle
		Stage.RESUMING:
			_open_room()
			_stage = Stage.CHECKING
			_wait = _settle
		Stage.CHECKING:
			var actual: Dictionary = _describe(_room)
			var mismatched: PackedStringArray = PackedStringArray()
			for key: String in _expected:
				if str(actual.get(key, null)) != str(_expected[key]):
					mismatched.append("%s: saved %s, resumed %s" % [
						key, str(_expected[key]), str(actual.get(key, null))])
			if mismatched.is_empty():
				_finish(true, "the room came back as it was left: floor %d, %d moves, phase %s, decision %s" % [
					int(actual["floor"]), int(actual["moves"]),
					String(actual["phase"]), String(actual["decision"])])
			else:
				_finish(false, "\n  ".join(mismatched))
			return true
		Stage.DONE:
			return true
	return false


## One move through the room's own entry points, the way the storyboard drives
## it: buy through an open draft, otherwise advance. A run that ends is
## replaced, because a dead run forgets its save and there is nothing to check.
func _play_one() -> void:
	if _room == null:
		return
	var state: RunState = _room.get("state") as RunState
	if state != null and state.is_over():
		print("run ended after %d moves; starting another" % _made)
		_room.call("new_run", 0)
		_made = 0
		_wait = _settle
		return
	if bool(_room.call("debug_shop_open")):
		_room.call("debug_buy_what_it_can")
	else:
		_room.call("debug_advance")
	_made += 1
	_wait = _settle
	if _made >= _moves:
		_stage = Stage.FLUSHING


## Everything about the run the resume has to reproduce.
func _describe(room: Node) -> Dictionary:
	var state: RunState = room.get("state") as RunState
	var engine: SimEngine = room.get("engine") as SimEngine
	if state == null or engine == null:
		return {"phase": "no run"}
	var line: Array[String] = []
	for symbol: SymbolDef in state.board.line:
		line.append(String(symbol.id) if symbol != null else "")
	var snapshot: Dictionary = state.snapshot()
	return {
		"seed": state.seed_value,
		"floor": state.floor_index,
		"phase": snapshot["phase"],
		"decision": String(RunState.Decision.keys()[state.decision]),
		"spins_remaining": state.spins_remaining,
		"cash": state.economy.cash,
		"debt": state.economy.debt,
		"vault": state.economy.vault,
		"owned": snapshot["owned"],
		"reel_draws": snapshot["reel_draws"],
		"line": line,
		"payout": state.board.payout,
		"stake": state.stake,
		"held": state.board.held_count(),
		"offers": state.shop_offers.size(),
		"moves": engine.journal.entries.size() if engine.journal != null else -1,
	}


func _finish(ok: bool, message: String) -> void:
	_stage = Stage.DONE
	print("resume_check: %s — %s" % ["PASS" if ok else "FAIL", message])
	# Never leave a run on the table for the real game to pick up.
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
