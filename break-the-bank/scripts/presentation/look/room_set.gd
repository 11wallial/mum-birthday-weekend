## Builds the room the machine stands in.
##
## The room's only job is to make the machine readable: a close ceiling and near
## walls to bounce the key light, a practical lamp so the light has a visible
## source, and a floor sign that names where the run has got to. Everything is
## generated for the same reason the machine is — the character is in the pipes,
## stains and conduit, and those are not worth hand-placing.
##
## The set is deliberately small. An open hall reads as empty; a room you could
## touch the walls of reads as a place you have been shut into, which is the one
## the game is about.
class_name RoomSet
extends RefCounted

const WIDTH: float = 4.6
const DEPTH_BACK: float = -3.3
const DEPTH_FRONT: float = 7.4
const CEILING: float = 2.95
## Where the pendant lamp hangs, and what it is aimed at. The key light is built
## into the fixture, so the light throwing the shadows and the lamp you can see
## hanging there are one object and cannot drift apart.
##
## Forward of the machine as well as above it: a lamp directly overhead lights
## the top of the chassis and leaves the face — the part with the reels on it —
## in its own shadow, which is the single thing that kept the machine unreadable.
const LAMP: Vector3 = Vector3(1.16, 2.34, 1.9)
const LAMP_TARGET: Vector3 = Vector3(-0.2, 0.85, 0.2)

var _root: Node3D


## Builds the set under [param root]. Returns the nodes the room drives, keyed
## [code]sign[/code] and [code]bulb[/code].
func build(root: Node3D) -> Dictionary:
	_root = root
	_shell()
	_conduit()
	var sign_label: Label3D = _floor_sign()
	_vault_door()
	var bulb: MeshInstance3D = _pendant()
	_wall_wash()
	_strip_light()
	_dust()
	# The lights come back out because [FloorMood] has to reach them every floor.
	# They are built here so each stays with its fixture; handing back references
	# is how that survives contact with something that needs to change them.
	return {
		"sign": sign_label,
		"sign_spill": _root.get_node_or_null(^"FloorSign/Spill"),
		"bulb": bulb,
		"key": _root.get_node_or_null(^"Key"),
		"cold": _root.get_node_or_null(^"StripLight/Tube"),
		"wash": _root.get_node_or_null(^"WallWash"),
		"ceiling": _root.get_node_or_null(^"CeilingWash"),
	}


## A dim, wide light aimed at the back wall. Everything past the lamp's throw had
## gone to pure black, so the machine stood in a void instead of a room — and a
## void reads as a rendering budget rather than as darkness.
func _wall_wash() -> void:
	var wash: OmniLight3D = OmniLight3D.new()
	wash.name = "WallWash"
	wash.light_color = Color(0.596, 0.51, 0.404)
	wash.light_energy = 2.0
	wash.light_specular = 0.15
	wash.omni_range = 7.5
	wash.omni_attenuation = 1.1
	wash.shadow_enabled = false
	wash.position = Vector3(-0.5, 2.15, DEPTH_BACK + 1.5)
	_root.add_child(wash)

	var ceiling: OmniLight3D = OmniLight3D.new()
	ceiling.name = "CeilingWash"
	ceiling.light_color = Color(0.62, 0.51, 0.376)
	ceiling.light_energy = 2.6
	ceiling.light_specular = 0.1
	ceiling.omni_range = 6.0
	ceiling.omni_attenuation = 1.4
	ceiling.shadow_enabled = false
	ceiling.position = Vector3(0.7, CEILING - 0.55, 1.5)
	_root.add_child(ceiling)


## Aims a node at a point without anyone writing a basis by hand.
func _aim(node: Node3D, from: Vector3, at: Vector3) -> void:
	node.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(at, Vector3.UP)


## Floor, walls and ceiling. The ceiling matters more than it looks: without one
## the key light has nothing to spill onto and the top of frame goes flat black.
func _shell() -> void:
	var shell: Node3D = _group(&"Shell")
	var floor_material: Material = Materials.weathered("concrete",
			Materials.CONCRETE, 0.5, 0.9, 0.5, 0.25, Materials.concrete(85))
	var wall_material: Material = Materials.weathered("plaster",
			Color(0.137, 0.129, 0.118), 0.45, 0.8, 0.25, 0.7,
			Materials.painted(Color(0.137, 0.129, 0.118), 19))
	var depth: float = DEPTH_FRONT - DEPTH_BACK
	var mid_z: float = (DEPTH_FRONT + DEPTH_BACK) * 0.5

	_box(shell, Vector3(WIDTH * 2.0, 0.3, depth), Vector3(0.0, -0.15, mid_z), floor_material)
	_box(shell, Vector3(WIDTH * 2.0, 0.3, depth),
			Vector3(0.0, CEILING + 0.15, mid_z), wall_material)
	_box(shell, Vector3(WIDTH * 2.0, CEILING, 0.3),
			Vector3(0.0, CEILING * 0.5, DEPTH_BACK - 0.15), wall_material)
	for sx: float in [-1.0, 1.0]:
		_box(shell, Vector3(0.3, CEILING, depth),
				Vector3(sx * (WIDTH + 0.15), CEILING * 0.5, mid_z), wall_material)

	# A tiled dado up to waist height, and the rail capping it. Two materials
	# meeting at a line is what gives a flat wall a sense of scale.
	_box(shell, Vector3(WIDTH * 2.0, 1.15, 0.06),
			Vector3(0.0, 0.575, DEPTH_BACK + 0.02),
			Materials.enamel(Color(0.212, 0.208, 0.180), 70))
	_box(shell, Vector3(WIDTH * 2.0, 0.07, 0.11),
			Vector3(0.0, 1.15, DEPTH_BACK + 0.04), Materials.rusted(25))
	# Skirting where wall meets floor, so the join is not a hairline.
	_box(shell, Vector3(WIDTH * 2.0, 0.12, 0.09),
			Vector3(0.0, 0.06, DEPTH_BACK + 0.05), Materials.rusted(26))


## Pipework and conduit across the back wall and the ceiling. This is most of
## what stops the set reading as three grey planes.
func _conduit() -> void:
	var conduit: Node3D = _group(&"Conduit")
	var pipe: StandardMaterial3D = Materials.rusted(27)
	var duct: StandardMaterial3D = Materials.machined(Color(0.322, 0.310, 0.290), 71)
	# Two horizontal runs high on the back wall, with brackets at intervals.
	for run: float in [2.42, 2.66]:
		_segment(conduit, Vector3(-WIDTH, run, DEPTH_BACK + 0.16),
				Vector3(WIDTH, run, DEPTH_BACK + 0.16), 0.055, pipe)
		for i: int in 7:
			var x: float = lerpf(-WIDTH + 0.3, WIDTH - 0.3, float(i) / 6.0)
			_box(conduit, Vector3(0.07, 0.16, 0.16),
					Vector3(x, run, DEPTH_BACK + 0.08), duct)
	# A thinner run dropping down the left corner and turning along the floor.
	_segment(conduit, Vector3(-WIDTH + 0.22, 2.3, DEPTH_BACK + 0.16),
			Vector3(-WIDTH + 0.22, 0.35, DEPTH_BACK + 0.16), 0.04, pipe)
	_segment(conduit, Vector3(-WIDTH + 0.22, 0.28, DEPTH_BACK + 0.16),
			Vector3(-WIDTH + 0.22, 0.28, 1.6), 0.04, pipe)
	# A square duct crossing the ceiling, catching the top of the lamp's throw.
	_box(conduit, Vector3(0.42, 0.3, DEPTH_FRONT - DEPTH_BACK),
			Vector3(-2.1, CEILING - 0.22, (DEPTH_FRONT + DEPTH_BACK) * 0.5), duct)
	# Joists across it. On a phone held upright the ceiling is the top third of
	# the frame, and an unbroken slab there reads as nothing rendered at all.
	for i: int in 9:
		var z: float = lerpf(DEPTH_BACK + 0.6, DEPTH_FRONT - 0.6, float(i) / 8.0)
		_box(conduit, Vector3(WIDTH * 2.0, 0.22, 0.16),
				Vector3(0.0, CEILING - 0.11, z),
				Materials.painted(Color(0.106, 0.098, 0.086), 22))
	# A second pipe run following the joists, off-centre so the ceiling is not
	# symmetrical about the machine.
	_segment(conduit, Vector3(1.1, CEILING - 0.28, DEPTH_BACK + 0.5),
			Vector3(1.1, CEILING - 0.28, DEPTH_FRONT - 1.0), 0.05, pipe)


## The floor name, in orange, on the back wall. Reading where you are off the
## wall rather than off a text overlay is the whole point of the exercise.
func _floor_sign() -> Label3D:
	var housing: Node3D = _group(&"FloorSign")
	housing.position = Vector3(2.15, 1.98, DEPTH_BACK + 0.12)
	_box(housing, Vector3(2.05, 0.4, 0.09), Vector3.ZERO,
			Materials.painted(Color(0.11, 0.10, 0.095), 20))
	_box(housing, Vector3(2.11, 0.06, 0.13), Vector3(0.0, 0.25, 0.0),
			Materials.rusted(28))
	var label: Label3D = Label3D.new()
	label.name = "Text"
	label.text = "FLOOR 1: THE BASEMENT"
	label.font_size = 80
	label.pixel_size = 0.0026
	# Overdriven: past the environment's 1.1 glow threshold, so the letters
	# bloom like lit tubes rather than reading as painted text.
	label.modulate = Materials.SIGN * 2.2
	label.outline_size = 0
	label.shaded = false
	label.position = Vector3(0.0, 0.0, 0.06)
	housing.add_child(label)
	# A cloud of faded copies nudged one tube-width in each direction: the
	# halo a neon tube has in life, and the whole of the halo on the renderer
	# with no bloom, which the web build is. Nudged rather than scaled — a
	# scaled copy of crisp text doubles its ends and reads as a misprint.
	# Children of the text so the floor writer and FloorMood reach them
	# through it.
	for offset: Vector2 in [Vector2(0.014, 0.0), Vector2(-0.014, 0.0),
			Vector2(0.0, 0.014), Vector2(0.0, -0.014)]:
		var shell: Label3D = Label3D.new()
		shell.name = "Glow"
		shell.text = label.text
		shell.font_size = 80
		shell.pixel_size = 0.0026
		shell.modulate = Color(Materials.SIGN.r, Materials.SIGN.g,
				Materials.SIGN.b, 0.13)
		shell.outline_size = 0
		shell.shaded = false
		shell.position = Vector3(offset.x, offset.y, -0.005)
		shell.render_priority = -1
		label.add_child(shell)
	# The sign lights the wall it is mounted on, which is what separates a lit
	# sign from a bright sticker.
	var spill: OmniLight3D = OmniLight3D.new()
	spill.name = "Spill"
	spill.light_color = Materials.SIGN
	spill.light_energy = 0.85
	spill.omni_range = 2.4
	spill.omni_attenuation = 2.2
	spill.shadow_enabled = false
	spill.position = Vector3(0.0, 0.0, 0.45)
	housing.add_child(spill)
	return label


## The door out, on the back wall under the sign. It is never opened; it exists
## so the room has somewhere the next floor could be.
func _vault_door() -> void:
	var door: Node3D = _group(&"VaultDoor")
	door.position = Vector3(2.15, 0.0, DEPTH_BACK + 0.1)
	_box(door, Vector3(1.5, 2.3, 0.12), Vector3(0.0, 1.15, -0.02),
			Materials.machined(Color(0.196, 0.192, 0.184), 72))
	# The frame, proud of the wall, and a heavy handle wheel.
	for sx: float in [-1.0, 1.0]:
		_box(door, Vector3(0.12, 2.44, 0.2), Vector3(sx * 0.75, 1.22, 0.02),
				Materials.rusted(29))
	_box(door, Vector3(1.62, 0.12, 0.2), Vector3(0.0, 2.36, 0.02), Materials.rusted(30))
	_cylinder(door, 0.24, 0.07, Vector3(0.0, 1.15, 0.09), Vector3(PI * 0.5, 0.0, 0.0),
			Materials.brass(40))
	for i: int in 4:
		var angle: float = TAU * float(i) / 4.0 + PI * 0.25
		_box(door, Vector3(0.05, 0.05, 0.05),
				Vector3(sin(angle) * 0.24, 1.15 + cos(angle) * 0.24, 0.11),
				Materials.brass(41))


## The pendant lamp. The key light lives at the bulb, so the shadows in the room
## agree with the fixture the player can see throwing them.
func _pendant() -> MeshInstance3D:
	var pendant: Node3D = _group(&"Pendant")
	pendant.position = LAMP
	_segment(pendant, Vector3(0.0, CEILING - LAMP.y, 0.0), Vector3(0.0, 0.1, 0.0),
			0.012, Materials.rubber(Color(0.09, 0.085, 0.08), 98))
	# A conical shade, dark outside and bright inside where the bulb hits it.
	var shade: CylinderMesh = CylinderMesh.new()
	shade.top_radius = 0.09
	shade.bottom_radius = 0.42
	shade.height = 0.34
	shade.radial_segments = 20
	var outer: MeshInstance3D = MeshInstance3D.new()
	outer.mesh = shade
	outer.material_override = Materials.painted(Color(0.153, 0.145, 0.133), 21)
	pendant.add_child(outer)
	var inner: MeshInstance3D = MeshInstance3D.new()
	inner.mesh = shade
	var lining: StandardMaterial3D = Materials.glowing(Color(0.88, 0.7, 0.44), 2.6)
	lining.cull_mode = BaseMaterial3D.CULL_FRONT
	inner.material_override = lining
	inner.scale = Vector3(0.94, 0.94, 0.94)
	pendant.add_child(inner)
	var bulb: MeshInstance3D = MeshInstance3D.new()
	bulb.name = "Bulb"
	var glass: SphereMesh = SphereMesh.new()
	glass.radius = 0.07
	glass.height = 0.14
	bulb.mesh = glass
	bulb.material_override = Materials.glowing(Materials.LAMP, 9.0)
	bulb.position = Vector3(0.0, -0.06, 0.0)
	pendant.add_child(bulb)

	# The key light, inside the shade and aimed down at the machine. Everything
	# else in the room is under a tenth of this: the set is one bulb, and the
	# reason the machine reads at all is that the bulb is pointed at it.
	var key: SpotLight3D = SpotLight3D.new()
	key.name = "Key"
	key.light_color = Materials.LAMP
	key.light_energy = 8.0
	key.light_indirect_energy = 1.5
	key.light_volumetric_fog_energy = 1.1
	key.light_specular = 1.0
	key.shadow_enabled = true
	key.shadow_bias = 0.025
	key.shadow_normal_bias = 1.4
	key.shadow_blur = 1.5
	key.spot_range = 11.0
	key.spot_attenuation = 1.3
	key.spot_angle = 38.0
	key.spot_angle_attenuation = 1.5
	_root.add_child(key)
	_aim(key, LAMP + Vector3(0.0, -0.08, 0.0), LAMP_TARGET)
	return bulb


## A dead fluorescent tube over the left of the room: cold and weak. It is not
## there to light the machine — the pendant does that — but to keep the floor
## either side of the plinth readable, which is where a run's winnings and its
## floor markers pile up. Without it the pulled-back survey view, whose whole
## job is to show what the run has accumulated, was a lit island in black.
func _strip_light() -> void:
	var strip: Node3D = _group(&"StripLight")
	strip.position = Vector3(-2.25, CEILING - 0.34, 1.5)
	_box(strip, Vector3(0.16, 0.1, 1.5), Vector3.ZERO,
			Materials.machined(Color(0.298, 0.290, 0.278), 74))
	_box(strip, Vector3(0.11, 0.03, 1.36), Vector3(0.0, -0.06, 0.0),
			Materials.glowing(Color(0.667, 0.749, 0.847), 1.8))
	var tube: OmniLight3D = OmniLight3D.new()
	tube.name = "Tube"
	tube.light_color = Color(0.686, 0.769, 0.882)
	tube.light_energy = 2.2
	tube.light_specular = 0.35
	tube.omni_range = 6.5
	tube.omni_attenuation = 1.5
	tube.shadow_enabled = false
	tube.position = Vector3(0.0, -0.2, 0.0)
	strip.add_child(tube)


## Dust hanging in the light. It is the cheapest thing in the scene and does more
## for the sense of a real volume of air than anything else here.
func _dust() -> void:
	var motes: CPUParticles3D = CPUParticles3D.new()
	motes.name = "Dust"
	motes.amount = 46
	motes.lifetime = 18.0
	motes.preprocess = 7.0
	motes.position = Vector3(0.9, 1.7, 1.2)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(2.0, 1.2, 1.4)
	motes.direction = Vector3(0.2, -1.0, 0.0)
	motes.spread = 40.0
	motes.gravity = Vector3(0.02, -0.012, 0.0)
	motes.initial_velocity_min = 0.005
	motes.initial_velocity_max = 0.03
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.016, 0.016)
	motes.mesh = mesh
	var material: StandardMaterial3D = Materials.glowing(Color(1.0, 0.9, 0.72), 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The soft falloff sprite: a hard-edged additive quad reads as a dead
	# pixel, and forty of them read as a dirty sensor.
	material.albedo_texture = SymbolArt.halo()
	material.albedo_color = Color(1.0, 0.9, 0.72, 0.2)
	motes.mesh.material = material
	_root.add_child(motes)


# --- primitives (shared shape with MachineFrame, kept local to stay readable) -

func _group(node_name: StringName) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = node_name
	_root.add_child(group)
	return group


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = at
	return instance


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3,
		euler: Vector3, material: Material) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = at
	instance.rotation = euler
	return instance


func _segment(parent: Node3D, from: Vector3, to: Vector3, radius: float,
		material: Material) -> MeshInstance3D:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.0001:
		return null
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = (from + to) * 0.5
	var up: Vector3 = delta / length
	var reference: Vector3 = (Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.99
			else Vector3.UP)
	var right: Vector3 = reference.cross(up).normalized()
	instance.transform.basis = Basis(right, up, right.cross(up).normalized())
	return instance
