## The room fills up as the run goes on.
##
## Spec calls for the starting room to accumulate over a run rather than swap
## between floors, so everything here is additive: cash stacks grow, and each
## cleared floor leaves a marker behind.
class_name RoomDressing
extends Node3D

## Where the first plaque hangs and how far apart the row is spaced. On the back
## wall above the dado rail, well clear of the floor sign and the door.
const PLAQUE_ORIGIN: Vector3 = Vector3(-1.45, 2.2, -3.24)
const PLAQUE_SPACING: float = 0.42

## Credits represented by one stack block.
const CREDITS_PER_BLOCK: int = 25
const MAX_BLOCKS: int = 60
const BLOCK_SIZE: Vector3 = Vector3(0.16, 0.035, 0.24)

## On the floor to the right of the plinth, clear of the machine's own spool.
@export var stack_origin: Vector3 = Vector3(1.95, 0.0, 1.45)
@export var stack_spacing: float = 0.24

var _blocks: int = 0
var _bus: EffectBus
var _cash_mesh: BoxMesh
var _cash_material: StandardMaterial3D
var _marker_material: StandardMaterial3D
## The floors whose dressing is already in the room, by environment id.
var _dressed: Dictionary = {}


func _ready() -> void:
	_cash_mesh = BoxMesh.new()
	_cash_mesh.size = BLOCK_SIZE
	# Banded paper rather than flat green: the stacks sit on the same floor as
	# the machine, so they have to take the same grade to look like they belong.
	_cash_material = Materials.enamel(Color(0.451, 0.475, 0.353), 73)
	_marker_material = Materials.glowing(Materials.SIGN, 1.2)


func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)
	clear()


## Removes every accumulated prop. Called when a new run starts.
func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	_blocks = 0
	_dressed.clear()


## What each floor leaves in the room, once, the first time the run reaches
## it: the roadmap's per-floor art direction, done as the spec asked — the
## same basement, furnished a little more each floor down, along the left
## wall and the back where nothing else stands. Each is a few primitives
## and a thing someone brought down: the Casino's carpet and neon, the High
## Roller Room's rope, the Vault's deposit boxes, the Back Office's cabinet,
## the Engine Room's generator, the House's portrait.
func _dress_floor(environment_id: StringName) -> void:
	if environment_id == &"" or _dressed.has(environment_id):
		return
	_dressed[environment_id] = true
	var set_root: Node3D = Node3D.new()
	set_root.name = "Dressing_%s" % environment_id
	set_root.set_meta(&"kind", &"dressing")
	add_child(set_root)
	match environment_id:
		&"casino":
			# A runner of red carpet from the door, and a neon tube on the wall.
			var carpet: MeshInstance3D = Prims.box(set_root, Vector3(1.4, 0.008, 3.2),
					Vector3(-2.3, 0.006, 3.2), Materials.rubber(Color(0.36, 0.08, 0.07), 111))
			carpet.name = "Carpet"
			Prims.box(set_root, Vector3(1.5, 0.004, 3.3), Vector3(-2.3, 0.002, 3.2),
					Materials.enamel(Color(0.55, 0.45, 0.2), 112))
			var neon: MeshInstance3D = Prims.cylinder(set_root, 0.014, 1.2,
					Vector3(-4.52, 2.15, 0.6), Vector3(0.0, 0.0, PI * 0.5),
					Materials.glowing(Color(1.0, 0.3, 0.45), 1.05), 8)
			neon.name = "Neon"
			var glow: OmniLight3D = OmniLight3D.new()
			glow.light_color = Color(1.0, 0.3, 0.45)
			glow.light_energy = 0.8
			glow.omni_range = 2.2
			glow.shadow_enabled = false
			glow.position = Vector3(-4.3, 2.15, 0.6)
			set_root.add_child(glow)
		&"high_roller":
			# A velvet rope on brass posts along the left, and baize on the barrels.
			for z: float in [2.3, 3.4]:
				Prims.cylinder(set_root, 0.035, 0.95, Vector3(-2.7, 0.475, z), Vector3.ZERO,
						Materials.brass(113), 10)
				Prims.sphere(set_root, 0.05, Vector3(-2.7, 0.98, z), Materials.brass(113))
				Prims.cylinder(set_root, 0.16, 0.03, Vector3(-2.7, 0.015, z), Vector3.ZERO,
						Materials.brass(113), 14)
			Prims.segment(set_root, Vector3(-2.7, 0.9, 2.3), Vector3(-2.7, 0.78, 2.85), 0.02,
					Materials.rubber(Color(0.3, 0.06, 0.08), 114))
			Prims.segment(set_root, Vector3(-2.7, 0.78, 2.85), Vector3(-2.7, 0.9, 3.4), 0.02,
					Materials.rubber(Color(0.3, 0.06, 0.08), 114))
			Prims.box(set_root, Vector3(0.9, 0.02, 0.9), Vector3(-3.4, 0.91, -1.5),
					Materials.enamel(Color(0.12, 0.32, 0.18), 115))
			_practical(set_root, Vector3(-3.0, 1.9, 1.4), Color(1.0, 0.86, 0.55), 1.1, 3.0)
		&"vault":
			# Deposit boxes, racked on the left wall.
			for row: int in 4:
				for col: int in 5:
					var door: MeshInstance3D = Prims.box(set_root, Vector3(0.05, 0.22, 0.26),
							Vector3(-4.46, 0.5 + float(row) * 0.26, -0.8 + float(col) * 0.3),
							Materials.machined(Color(0.44, 0.45, 0.47), 116 + row))
					Prims.cylinder(door, 0.02, 0.012, Vector3(0.03, 0.0, 0.06),
							Vector3(0.0, 0.0, PI * 0.5), Materials.brass(120), 8)
			Prims.box(set_root, Vector3(0.06, 1.16, 1.6), Vector3(-4.5, 0.9, -0.2),
					Materials.machined(Color(0.3, 0.31, 0.32), 121))
			_practical(set_root, Vector3(-3.9, 1.8, -0.2), Color(0.72, 0.84, 1.0), 1.2, 3.2)
		&"back_office":
			# A filing cabinet with a drawer left open, and a tray of forms.
			Prims.box(set_root, Vector3(0.5, 1.3, 0.6), Vector3(-3.3, 0.65, 0.5),
					Materials.painted(Color(0.35, 0.36, 0.33), 122))
			for i: int in 4:
				Prims.box(set_root, Vector3(0.44, 0.02, 0.02), Vector3(-3.3, 0.3 + float(i) * 0.3, 0.81),
						Materials.machined(Materials.STEEL, 123))
			Prims.box(set_root, Vector3(0.44, 0.26, 0.3), Vector3(-3.3, 0.75, 0.95),
					Materials.painted(Color(0.35, 0.36, 0.33), 122))
			Prims.box(set_root, Vector3(0.3, 0.06, 0.4), Vector3(-3.3, 1.33, 0.5),
					Materials.enamel(Materials.PAPER, 124))
			_practical(set_root, Vector3(-3.0, 2.0, 0.6), Color(0.94, 0.96, 0.82), 1.0, 3.0)
		&"engine_room":
			# A generator on the left, flywheel and all, wired to the machine.
			var generator: Node3D = Node3D.new()
			generator.position = Vector3(-3.5, 0.0, 2.2)
			set_root.add_child(generator)
			Prims.box(generator, Vector3(0.9, 0.7, 0.6), Vector3(0.0, 0.35, 0.0),
					Materials.rusted(125))
			Prims.cylinder(generator, 0.32, 0.08, Vector3(0.5, 0.55, 0.0),
					Vector3(0.0, 0.0, PI * 0.5), Materials.machined(Materials.STEEL, 126), 20)
			Prims.cylinder(generator, 0.06, 0.2, Vector3(0.55, 0.55, 0.0),
					Vector3(0.0, 0.0, PI * 0.5), Materials.brass(127), 10)
			for i: int in 3:
				Prims.cylinder(generator, 0.05, 0.3, Vector3(-0.3 + float(i) * 0.25, 0.85, 0.1),
						Vector3.ZERO, Materials.rusted(128), 10)
			Prims.segment(set_root, Vector3(-3.1, 0.7, 2.2), Vector3(-1.3, 0.75, 0.2), 0.02,
					Materials.rubber(Color(0.09, 0.085, 0.08), 129))
			# Firelight off the generator, low and warm, from under the flywheel.
			_practical(set_root, Vector3(-3.3, 0.9, 2.2), Color(1.0, 0.52, 0.2), 1.5, 3.0)
		&"the_house":
			# A portrait of nobody, on the back wall, under its own red lamp.
			Prims.box(set_root, Vector3(0.6, 0.8, 0.04), Vector3(2.4, 2.0, -3.24),
					Materials.brass(130))
			Prims.box(set_root, Vector3(0.5, 0.7, 0.02), Vector3(2.4, 2.0, -3.21),
					Materials.painted(Color(0.08, 0.07, 0.06), 131))
			Prims.box(set_root, Vector3(0.36, 0.05, 0.08), Vector3(2.4, 2.48, -3.2),
					Materials.machined(Color(0.2, 0.2, 0.19), 132))
			var lamp: OmniLight3D = OmniLight3D.new()
			lamp.light_color = Color(0.9, 0.2, 0.15)
			lamp.light_energy = 0.7
			lamp.omni_range = 1.6
			lamp.shadow_enabled = false
			lamp.position = Vector3(2.4, 2.4, -3.0)
			set_root.add_child(lamp)
		_:
			pass


## A light belonging to one floor's dressing.
##
## Four of the six dressed floors had none: the velvet rope, the deposit
## boxes, the filing cabinet and the generator were all built and then left
## in the dark at the far end of a room lit by one bulb over the machine. A
## set that cannot be seen is not a set, and this is the cheapest way to
## make a floor's arrival read — the dressing brings its own light with it.
func _practical(parent: Node3D, at: Vector3, tint: Color, energy: float,
		reach: float) -> OmniLight3D:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = tint
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 1.4
	lamp.light_volumetric_fog_energy = 0.6
	lamp.shadow_enabled = false
	lamp.position = at
	parent.add_child(lamp)
	return lamp


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.CASH_CHANGED:
			_sync_stacks(int(payload.get("cash", 0)))
		EffectBus.Event.FLOOR_CLEARED:
			_add_floor_marker(int(payload.get("floor", 0)))
		EffectBus.Event.FLOOR_STARTED:
			# Every floor up to this one leaves its dressing in the room: the
			# spec says the room accumulates rather than swaps, and a resumed
			# run arrives with its whole descent already furnished.
			var index: int = int(payload.get("floor", 1))
			for floor_def: FloorDef in ContentDB.shared().floors:
				if floor_def.index <= index:
					_dress_floor(floor_def.environment_id)
		EffectBus.Event.RUN_STARTED:
			clear()
		_:
			pass


## Grows or shrinks the stacks to match banked cash. Growth is animated; a spend
## just removes blocks, because watching your money leave in slow motion is not
## the feeling this game is after.
func _sync_stacks(cash: int) -> void:
	var target: int = clampi(cash / CREDITS_PER_BLOCK, 0, MAX_BLOCKS)
	while _blocks > target:
		_blocks -= 1
		var last: Node = get_child(get_child_count() - 1)
		if last is MeshInstance3D and last.get_meta(&"kind", &"") == &"cash":
			last.queue_free()
		else:
			break
	while _blocks < target:
		_spawn_block(_blocks)
		_blocks += 1


func _spawn_block(index: int) -> void:
	var block: MeshInstance3D = MeshInstance3D.new()
	block.mesh = _cash_mesh
	block.material_override = _cash_material
	block.set_meta(&"kind", &"cash")
	# Stacks of eight, then start a new column beside the machine.
	var column: int = index / 8
	var height: int = index % 8
	var target: Vector3 = stack_origin + Vector3(
		float(column) * stack_spacing, BLOCK_SIZE.y * (float(height) + 0.5), 0.0)
	add_child(block)
	block.position = target + Vector3(0.0, 1.2, 0.0)
	block.rotation.y = randf_range(-0.08, 0.08)
	var tween: Tween = create_tween()
	tween.tween_property(block, "position", target, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Mounts a plaque on the back wall for a floor that has been cleared.
##
## These used to be orange sticks on the floor beside the machine, which read as
## debris rather than as a record. A row of engraved plates going up the wall is
## the same information as a trophy shelf: how far this run got, readable from
## across the room, and it survives everything else the room accumulates.
func _add_floor_marker(floor_index: int) -> void:
	var plaque: Node3D = Node3D.new()
	plaque.name = "Plaque%d" % floor_index
	plaque.set_meta(&"kind", &"marker")
	add_child(plaque)
	plaque.position = Vector3(
			PLAQUE_ORIGIN.x + PLAQUE_SPACING * float(floor_index - 1),
			PLAQUE_ORIGIN.y, PLAQUE_ORIGIN.z)

	Prims.box(plaque, Vector3(0.3, 0.22, 0.03), Vector3.ZERO,
			Materials.painted(Color(0.098, 0.09, 0.082), 33))
	Prims.box(plaque, Vector3(0.25, 0.17, 0.02), Vector3(0.0, 0.0, 0.02),
			_marker_material)
	for sx: float in [-1.0, 1.0]:
		Prims.sphere(plaque, 0.012, Vector3(sx * 0.12, 0.083, 0.022),
				Materials.machined(Materials.STEEL, 79))

	var number: Label3D = Label3D.new()
	number.name = "Number"
	number.text = str(floor_index)
	number.font_size = 96
	number.pixel_size = 0.0014
	number.modulate = Color(0.086, 0.075, 0.055)
	number.outline_size = 0
	number.shaded = false
	number.position = Vector3(0.0, 0.0, 0.032)
	plaque.add_child(number)
	# Arrives struck, then settles, so clearing a floor is seen being recorded.
	plaque.scale = Vector3.ONE * 1.6
	var tween: Tween = create_tween()
	tween.tween_property(plaque, "scale", Vector3.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
