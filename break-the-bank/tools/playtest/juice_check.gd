## Does the machine react to a spin that pays nothing?
##
## The scoring director hands a dead spin no beats, so for most of this
## project's life the outcome the player sees most often did almost nothing:
## one lamp flicker and a dry cue, against a win's chain, count-up, coins,
## shake and room reaction. The deflate that fixes it is all tweens, which
## means a screenshot cannot see it and no test was watching it — so this
## drives real spins and samples the machine's own lamp while they resolve.
##
## It asserts the shape and not the timing: that a losing spin visibly takes
## the light down and gives it back. A deflate that stopped firing, or one
## that dimmed and never recovered, both fail here.
##
##   godot --headless --path . --script res://tools/playtest/juice_check.gd \
##       -- [--moves=140]
extends SceneTree

const ROOM: String = "res://scenes/3d/casino_room.tscn"
const DEFAULT_MOVES: int = 220
## The lamp's authored resting energy, from SlotView3D.LAMP_REST.
const REST: float = 1.0
## How far under rest the sag has to go before it counts as seen.
##
## Below the paying path's own hold, which parks the lamp at 0.3 while the
## total waits to land. At 0.5 this check passed on the first run by
## catching that hold instead of the deflate — a green light for the exact
## behaviour it was written to protect. The deflate reaches 0.22, so only
## the deflate can satisfy it now.
const DIP: float = 0.25
## And how near rest it has to come back.
const RECOVERED: float = 0.88

var _room: Node
var _light: Light3D
var _moves: int = DEFAULT_MOVES
var _made: int = 0
var _low: float = 999.0
var _seen_dip: bool = false
var _recovered: bool = false
var _wait: float = 0.6
var _done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--moves="):
			_moves = maxi(int(arg.substr(8)), 10)
	_room = (load(ROOM) as PackedScene).instantiate()
	root.add_child(_room)


func _process(delta: float) -> bool:
	if _done:
		return true
	if _light == null:
		_light = _room.get_node_or_null(^"Machine/MachineLight") as Light3D
		if _light == null:
			_light = _find_light(_room)
		if _light == null:
			return _finish(false, "no machine lamp to watch")
	# Sampled every frame, not at the end of a move: the whole sag and its
	# recovery happen inside half a second and a per-move sample walks
	# straight past them.
	_low = minf(_low, _light.light_energy)
	if _seen_dip and _light.light_energy >= RECOVERED:
		_recovered = true
	if _low <= REST * DIP:
		_seen_dip = true
	if _seen_dip and _recovered:
		return _finish(true, "the lamp fell to %.2f on a losing spin and came back" % _low)
	if _wait > 0.0:
		_wait -= delta
		return false
	# The door first, exactly as the room drive does it. Without this the
	# title is still up, every advance goes into the menu instead of the
	# lever, and the check sits watching a lamp at its resting value for
	# two hundred moves reporting that the deflate does not fire.
	if _made == 0 and _room.has_method("debug_close_door"):
		_room.call("debug_close_door")
	var state: RunState = _room.get("state") as RunState
	if state != null and state.is_over():
		return _finish(false,
				("the run ended after %d moves without the lamp ever dipping "
				+ "(low was %.2f, wanted %.2f or under)") % [_made, _low, REST * DIP])
	if _made >= _moves:
		return _finish(false,
				"drove %d moves and never saw the lamp dip: the deflate is not firing (low was %.2f)"
				% [_made, _low])
	# Driven the way the room drive drives it. Advance alone does not leave
	# the draft or the office, so a probe that only advances reaches the
	# first shop and sits in it — which is how this check spent two hundred
	# moves reporting a lamp that never moved, on a run that never spun.
	if state != null and state.phase == RunState.Phase.SIGNING:
		_room.call("debug_sign", 0)
	elif bool(_room.call("debug_shop_open")):
		_room.call("debug_buy_what_it_can")
	else:
		_room.call("debug_advance")
	_made += 1
	# Paced like the room drive. At 0.12 this hammered the lever while the
	# drums were still turning, so moves landed inside a spin the machine
	# had not finished resolving and the run made almost no dead spins to
	# watch — the check failed about half the time for that reason alone.
	_wait = 0.45
	return false


func _find_light(node: Node) -> Light3D:
	for child: Node in node.get_children():
		if child.name == "MachineLight" and child is Light3D:
			return child as Light3D
		var found: Light3D = _find_light(child)
		if found != null:
			return found
	return null


func _finish(passed: bool, why: String) -> bool:
	_done = true
	print("juice_check: %s — %s" % ["PASS" if passed else "FAIL", why])
	quit(0 if passed else 1)
	return true
