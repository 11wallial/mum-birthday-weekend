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
## Long enough for a spin's whole scoring performance — the chain, the count,
## the pause and the total — to have landed before the next frame drives on;
## the room refuses to advance through it.
const DEFAULT_SETTLE: float = 2.6

var _root_node: Node = null
var _shots: Array[Dictionary] = []
var _index: int = 0
var _wait: float = 0.0
var _applied: bool = false
var _settle: float = DEFAULT_SETTLE
var _out_dir: String = "user://shots"
var _only: Array[String] = []


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var scene_path: String = String(args.get("scene", "res://scenes/3d/casino_room.tscn"))
	_out_dir = String(args.get("out", "user://shots"))
	var spins: int = int(args.get("spins", 6))
	_settle = float(args.get("settle", DEFAULT_SETTLE))
	# --shots=a,b keeps only the named frames' captures. The drive through
	# the run still happens; what is skipped is the wait and the write, so a
	# single frame can be checked in a fraction of the storyboard's time.
	var only: String = String(args.get("shots", ""))
	if not only.is_empty():
		_only.assign(Array(only.split(",", false)))

	DirAccess.make_dir_recursive_absolute(_out_dir)

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("screenshot: cannot load %s" % scene_path)
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)

	# A storyboard rather than one frame: the door first, as a session opens,
	# then the room in both camera framings, and after the machine has
	# accumulated some modules.
	_shots.append({"name": "00_title", "action": "none"})
	_shots.append({"name": "01_machine_view", "action": "door"})
	_shots.append({"name": "02_room_view", "action": "room"})
	_shots.append({"name": "03_machine_view_back", "action": "machine"})
	for i: int in spins:
		_shots.append({"name": "04_spin_%d" % (i + 1), "action": "spin"})
	# The draft is a screen a player spends real time reading, so it gets its own
	# frame. "spin" drives through it; this one stops on it.
	for i: int in 14:
		_shots.append({"name": "04b_to_draft_%d" % i, "action": "until_draft"})
	# And the draft on purpose, ante covered: the frames above reach it only
	# when the blind run happens to cover the first ante, which it rarely does.
	for i: int in 4:
		_shots.append({"name": "04c_draft_%d" % i, "action": "draft"})
	_shots.append({"name": "05_after_spins_room", "action": "room"})
	_shots.append({"name": "06_run_setup", "action": "setup"})
	_shots.append({"name": "06b_settings", "action": "settings"})
	_shots.append({"name": "06c_keys", "action": "keys"})
	# Six of the seven systems live on floors a real run takes minutes to reach.
	# A storyboard that stopped at floor one was checking the game with most of
	# its mechanics switched off, so the rest are jumped to directly.
	_shots.append({"name": "07_stake_floor", "action": "floor:3"})
	_shots.append({"name": "07b_stake_spin", "action": "spin"})
	_shots.append({"name": "08_vault_floor", "action": "floor:4"})
	_shots.append({"name": "09_back_office", "action": "contracts"})
	_shots.append({"name": "10_engine_room", "action": "floor:6"})
	_shots.append({"name": "10b_works_fitted", "action": "works"})
	_shots.append({"name": "10c_wide_machine_spin", "action": "spin"})
	_shots.append({"name": "11_the_house", "action": "floor:7"})
	_shots.append({"name": "11b_counted", "action": "spin"})
	_shots.append({"name": "11c_inspect", "action": "inspect"})
	_shots.append({"name": "12_statement", "action": "lose"})
	_shots.append({"name": "13_settled", "action": "win"})


func _process(delta: float) -> bool:
	if _index >= _shots.size():
		return true
	if _wait > 0.0:
		_wait -= delta
		return false

	var shot: Dictionary = _shots[_index]
	var wanted: bool = _only.is_empty() or _only.has(String(shot["name"])) \
			or (String(shot["name"]).begins_with("04b_") and _only.has("04b_draft")) \
			or (String(shot["name"]).begins_with("04c_") and _only.has("04c_draft"))
	if not _applied:
		var action: String = String(shot["action"])
		_apply(action)
		_applied = true
		# Tweens and particles need time to reach the state worth looking at —
		# and a frame that drives the run has to wait for the reels whether
		# or not it is captured, or the run never gets past the first spin.
		var drives: bool = action == "spin" or action == "until_draft" or action == "draft"
		_wait = _settle if wanted or drives else 0.05
		return false
	if not wanted:
		_index += 1
		_applied = false
		return false

	var name: String = String(shot["name"])
	var draft_open: bool = _root_node != null \
			and _root_node.has_method("debug_shop_open") \
			and bool(_root_node.call("debug_shop_open"))
	if name.begins_with("04c_"):
		if draft_open:
			_capture("04c_draft")
	elif not name.begins_with("04b_") or draft_open:
		_capture("04b_draft" if name.begins_with("04b_") else name)
	_index += 1
	_applied = false
	return false


func _apply(action: String) -> void:
	if _root_node == null:
		return
	if action.begins_with("floor:"):
		if _root_node.has_method("debug_jump_to_floor"):
			_root_node.call("debug_jump_to_floor", int(action.split(":")[1]), 4000)
		return
	match action:
		"draft":
			# Asked again each frame until the reels have stopped and it opens.
			if _root_node.has_method("debug_shop_open") \
					and bool(_root_node.call("debug_shop_open")):
				return
			if _root_node.has_method("debug_open_draft"):
				_root_node.call("debug_open_draft")
		"until_draft":
			# Advance only while the draft is closed; once it opens, hold.
			if _root_node.has_method("debug_shop_open") \
					and bool(_root_node.call("debug_shop_open")):
				return
			if _root_node.has_method("debug_advance"):
				_root_node.call("debug_advance")
		"spin":
			# A draft blocks the run until it is answered, so answer it — by
			# buying. A machine that has bought nothing is the one state a real
			# run spends the least time in, and it is what every earlier
			# screenshot was showing.
			if _root_node.has_method("debug_shop_open") and _root_node.call("debug_shop_open"):
				if _root_node.has_method("debug_buy_what_it_can"):
					_root_node.call("debug_buy_what_it_can")
				else:
					_root_node.call("debug_leave_shop")
			elif _root_node.has_method("debug_advance"):
				_root_node.call("debug_advance")
		"room":
			if _root_node.has_method("debug_set_view"):
				_root_node.call("debug_set_view", 1)
		"machine":
			if _root_node.has_method("debug_set_view"):
				_root_node.call("debug_set_view", 0)
		"door":
			if _root_node.has_method("debug_close_door"):
				_root_node.call("debug_close_door")
			if _root_node.has_method("debug_set_view"):
				_root_node.call("debug_set_view", 0)
		"setup":
			if _root_node.has_method("debug_open_setup"):
				_root_node.call("debug_open_setup")
		"settings":
			if _root_node.has_method("debug_open_settings"):
				_root_node.call("debug_open_settings", false)
		"keys":
			if _root_node.has_method("debug_open_settings"):
				_root_node.call("debug_open_settings", true)
		"contracts":
			if _root_node.has_method("debug_open_contracts"):
				_root_node.call("debug_open_contracts")
		"works":
			if _root_node.has_method("debug_fit_works"):
				_root_node.call("debug_fit_works", 2, 2, 3000)
		"inspect":
			if _root_node.has_method("debug_inspect"):
				_root_node.call("debug_inspect", "counter:ante")
		"lose":
			if _root_node.has_method("debug_lose"):
				_root_node.call("debug_lose")
		"win":
			if _root_node.has_method("debug_win"):
				_root_node.call("debug_win")
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
