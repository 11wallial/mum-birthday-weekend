## Fits one artifact per effect to the machine and photographs the result.
##
## Twenty-six artifacts share thirteen effects, and [ModuleFactory] builds from
## the effect — so thirteen well-chosen purchases show every piece of hardware
## the game can make. A real run reaches a stocked machine slowly and rarely,
## which is exactly the state that most needs looking at, so this fits them
## directly rather than playing for them.
##
##   xvfb-run -a godot --rendering-driver opengl3 \
##       --script res://tools/visual_qa/module_sheet.gd -- --out=/tmp/modules
extends SceneTree

const SCENE: String = "res://scenes/3d/casino_room.tscn"
## Long enough for the fitting tween and the camera to settle.
const SETTLE: float = 1.4

var _root_node: Node = null
var _out_dir: String = "user://modules"
var _wait: float = 0.0
var _stage: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var packed: PackedScene = load(SCENE) as PackedScene
	if packed == null:
		push_error("module_sheet: cannot load %s" % SCENE)
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	_wait = 0.6


## One artifact per effect, preferring the ones whose finish differs, so the
## sheet shows the range of both form and material rather than a rack of brass.
func _choices() -> PackedStringArray:
	return PackedStringArray([
		"lucky_charm",       # FLAT_BONUS, luck
		"brass_multiplier",  # MULT_BONUS, mechanical
		"golden_reel",       # SYMBOL_BONUS, greed
		"pair_broker",       # PATTERN_MULT, contract
		"vault_key",         # INTEREST, bank
		"overtime_clock",    # EXTRA_SPINS, mechanical
		"magnet_coil",       # WEIGHT_SHIFT, mechanical
		"house_contract",    # ANTE_DISCOUNT, contract
		"parallel_drums",    # RETRIGGER, chaos
		"hazard_pay",        # CURSE_WARD, luck
		"flywheel",          # MULT_PER_FLOOR, mechanical
		"power_coupling",    # MULT_PER_ARTIFACT, chaos
		"overdraft_clause",  # DEBT_PAYDOWN, bank
		"marker_note",       # DEBT_LEVERAGE, bank
		"loose_screw",       # SPIN_REFUND, mechanical
	])


func _process(delta: float) -> bool:
	if _wait > 0.0:
		_wait -= delta
		return false
	match _stage:
		0:
			if _root_node.has_method("debug_fit_modules"):
				_root_node.call("debug_fit_modules", _choices())
			# Four floors down, a few hundred banked, and lit as the vault. The
			# empty room has been looked at plenty; this is the one a player
			# spends the back half of a run in.
			if _root_node.has_method("debug_dress_room"):
				_root_node.call("debug_dress_room", 4, 620, &"vault")
			_wait = SETTLE + FloorMood.TRANSITION
			_stage = 1
		1:
			_capture("modules_machine")
			if _root_node.has_method("debug_set_view"):
				_root_node.call("debug_set_view", 1)
			_wait = SETTLE
			_stage = 2
		2:
			_capture("modules_room")
			return true
		_:
			return true
	return false


func _capture(shot_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("module_sheet: no viewport image")
		return
	var path: String = "%s/%s.png" % [_out_dir, shot_name]
	if image.save_png(path) == OK:
		print("shot → %s" % path)
