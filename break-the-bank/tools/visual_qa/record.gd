## Records a spin as a frame sequence: the performance in motion.
##
##   godot --path . --script res://tools/visual_qa/record.gd -- \
##       --out=/tmp/spin --seconds=3.0 --fps=20
##
## The storyboard photographs states; this photographs time. It closes the
## door, spins once, and writes a PNG every 1/fps of real time for the
## length asked — the reels, the chain, the count, the pause and the total,
## which no still can show and the trailer's opening shot needs. Frames are
## numbered, so `ffmpeg -i frame_%04d.png` assembles them.
extends SceneTree

var _room: Node
var _out: String = "user://spin"
var _seconds: float = 3.0
var _interval: float = 1.0 / 20.0
var _clock: float = 0.0
var _next_frame: float = 0.0
var _frame: int = 0
var _stage: int = 0
var _wait: float = 1.2


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	_out = String(args.get("out", "user://spin"))
	_seconds = float(args.get("seconds", 3.0))
	_interval = 1.0 / maxf(float(args.get("fps", 20.0)), 1.0)
	DirAccess.make_dir_recursive_absolute(_out)
	var packed: PackedScene = load("res://scenes/3d/casino_room.tscn") as PackedScene
	_room = packed.instantiate()
	root.add_child(_room)


func _process(delta: float) -> bool:
	match _stage:
		0:
			_wait -= delta
			if _wait <= 0.0:
				if _room.has_method("debug_close_door"):
					_room.call("debug_close_door")
				_stage = 1
				_wait = 0.8
		1:
			_wait -= delta
			if _wait <= 0.0:
				_room.call("debug_advance")
				_stage = 2
		2:
			_clock += delta
			if _clock >= _next_frame:
				var image: Image = root.get_texture().get_image()
				if image != null:
					image.save_png("%s/frame_%04d.png" % [_out, _frame])
				_frame += 1
				_next_frame += _interval
			if _clock >= _seconds:
				print("record: %d frames over %.1f s → %s" % [_frame, _seconds, _out])
				quit(0)
				return true
	return false


func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg: String in argv:
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var split: int = body.find("=")
		out[body.substr(0, split) if split >= 0 else body] = body.substr(split + 1) if split >= 0 else true
	return out
