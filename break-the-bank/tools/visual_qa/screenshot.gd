## Headless-ish visual QA: boots a scene, drives it, and saves PNGs.
##
## The simulation can be checked by assertion; framing, scale and lighting can
## only be checked by looking. This runs the real scene under a software GL
## driver so a screenshot can be taken without a GPU or an editor:
##
##   xvfb-run -a godot --rendering-driver opengl3 \
##       --script res://tools/visual_qa/screenshot.gd -- \
##       --scene=res://scenes/3d/casino_room.tscn --out=user://shots --spins=6
##
## Note the Compatibility renderer is not Forward+: volumetric fog and glow are
## absent from these shots. Geometry, transforms, scale and framing are exact,
## and those are what this tool exists to check.
extends SceneTree

## Seconds to let tweens, particles and camera transitions finish before a shot.
## Frame counts are the wrong unit here: under a software driver a frame can be
## 30ms, and the camera transition alone is 0.7s.
const DEFAULT_SETTLE: float = 1.1

var _root_node: Node = null
var _shots: Array[Dictionary] = []
var _index: int = 0
var _wait: float = 0.0
var _applied: bool = false
var _settle: float = DEFAULT_SETTLE
var _out_dir: String = "user://shots"


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var scene_path: String = String(args.get("scene", "res://scenes/3d/casino_room.tscn"))
	_out_dir = String(args.get("out", "user://shots"))
	var spins: int = int(args.get("spins", 6))
	_settle = float(args.get("settle", DEFAULT_SETTLE))
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("screenshot: cannot load %s" % scene_path)
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)

	# A storyboard rather than one frame: the room has to be checked in both
	# camera framings, and after the machine has accumulated some modules.
	_shots.append({"name": "01_machine_view", "action": "none"})
	_shots.append({"name": "02_room_view", "action": "room"})
	_shots.append({"name": "03_machine_view_back", "action": "machine"})
	for i: int in spins:
		_shots.append({"name": "04_spin_%d" % (i + 1), "action": "spin"})
	_shots.append({"name": "05_after_spins_room", "action": "room"})
	_shots.append({"name": "06_run_setup", "action": "setup"})


func _process(delta: float) -> bool:
	if _index >= _shots.size():
		return true
	if _wait > 0.0:
		_wait -= delta
		return false

	var shot: Dictionary = _shots[_index]
	if not _applied:
		_apply(String(shot["action"]))
		_applied = true
		# Tweens and particles need time to reach the state worth looking at.
		_wait = _settle
		return false

	_capture(String(shot["name"]))
	_index += 1
	_applied = false
	return false


func _apply(action: String) -> void:
	if _root_node == null:
		return
	match action:
		"spin":
			# A draft blocks the run until it is answered, so drive through it.
			if _root_node.has_method("debug_shop_open") and _root_node.call("debug_shop_open"):
				_root_node.call("debug_leave_shop")
			elif _root_node.has_method("debug_advance"):
				_root_node.call("debug_advance")
		"room":
			if _root_node.has_method("debug_set_view"):
				_root_node.call("debug_set_view", 1)
		"machine":
			if _root_node.has_method("debug_set_view"):
				_root_node.call("debug_set_view", 0)
		"setup":
			if _root_node.has_method("debug_open_setup"):
				_root_node.call("debug_open_setup")
		_:
			pass


func _capture(shot_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("screenshot: no viewport image for %s" % shot_name)
		return
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	if cam != null:
		print("  cam pos=%v  basis_z=%v  fov=%.0f" % [
			cam.global_position, cam.global_transform.basis.z, cam.fov])
	var path: String = "%s/%s.png" % [_out_dir, shot_name]
	var err: int = image.save_png(path)
	if err != OK:
		push_error("screenshot: save failed for %s (%d)" % [path, err])
	else:
		print("shot → %s" % path)


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
