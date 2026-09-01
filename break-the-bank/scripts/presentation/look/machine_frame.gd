## Builds the physical slot machine out of primitives, in code.
##
## The machine used to be three boxes. It is now an industrial press: a riveted
## chassis bolted to a concrete plinth, a brass gearbox feeding it through rubber
## hoses, a monitor on a swing arm, a lever, and a receipt spool paying out onto
## the floor. All of it is generated here rather than authored in a scene file,
## because the character comes from density — a few hundred rivets, bolts and
## edge trims that no one would hand-place in a [code].tscn[/code].
##
## Nothing here knows the rules. [SlotView3D] calls [method build] and gets back
## the handful of nodes it drives; everything else is set dressing that exists
## only to be looked at.
class_name MachineFrame
extends RefCounted

## Half-extents of the main chassis. The machine reads as a horizontal press
## rather than an upright cabinet, which is the single biggest thing separating
## a slot machine you feed from a fruit machine you stand at.
const CHASSIS: Vector3 = Vector3(0.95, 0.48, 0.42)
## Centre height of the chassis: the plinth's top plus half the chassis.
const CHASSIS_Y: float = 0.9
const PLINTH_TOP: float = 0.42
const REEL_RADIUS: float = 0.2
const REEL_SPACING: float = 0.37
## Distance from the machine's centre plane to the front face of a reel drum.
const REEL_Z: float = 0.3

var _root: Node3D


## Constructs the machine under [param root] and returns the nodes the view
## drives, keyed [code]reels[/code], [code]lever[/code], [code]screen[/code],
## [code]odds[/code] and [code]spool[/code].
func build(root: Node3D) -> Dictionary:
	_root = root
	_plinth()
	_chassis()
	var reels: Array[Node3D] = _reel_bank()
	_bezel()
	var gearbox: Node3D = _gearbox()
	_hoses()
	var screen: MeshInstance3D = _monitor()
	var readout: Label3D = screen.get_node(^"Readout") as Label3D
	var odds: Label3D = _odds_display()
	var lever: Node3D = _lever()
	var spool: Node3D = _spool()
	_rivets()
	return {
		"reels": reels,
		"gearbox": gearbox,
		"screen": screen,
		"readout": readout,
		"odds": odds,
		"lever": lever,
		"spool": spool,
	}


# --- major assemblies -------------------------------------------------------

## The concrete block the machine is bolted to. It grounds the composition:
## without it the chassis floats and the whole thing reads as a prop.
func _plinth() -> void:
	var plinth: Node3D = _group(&"Plinth")
	_box(plinth, Vector3(2.3, PLINTH_TOP, 1.15),
			Vector3(0.0, PLINTH_TOP * 0.5, 0.0), Materials.concrete())
	# A chamfered cap, slightly proud, so the top edge catches the key light.
	_box(plinth, Vector3(2.42, 0.07, 1.27),
			Vector3(0.0, PLINTH_TOP + 0.02, 0.0), Materials.concrete(84))
	# Rusted steel straps clamping the chassis down at each corner.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(plinth, Vector3(0.16, 0.24, 0.16),
					Vector3(sx * 0.86, PLINTH_TOP + 0.1, sz * 0.44),
					Materials.rusted())


## The painted steel body, framed in angle iron. The frame is what makes it look
## fabricated rather than moulded.
func _chassis() -> void:
	var chassis: Node3D = _group(&"Chassis")
	_box(chassis, CHASSIS * 2.0, Vector3(0.0, CHASSIS_Y, 0.0),
			Materials.painted(Materials.PAINT, 11))
	# Angle iron down all four vertical corners, and along the top edges.
	var post: Vector3 = Vector3(0.1, CHASSIS.y * 2.06, 0.1)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(chassis, post,
					Vector3(sx * CHASSIS.x, CHASSIS_Y, sz * CHASSIS.z),
					Materials.machined(Materials.STEEL, 54))
	for sz: float in [-1.0, 1.0]:
		_box(chassis, Vector3(CHASSIS.x * 2.06, 0.1, 0.1),
				Vector3(0.0, CHASSIS_Y + CHASSIS.y, sz * CHASSIS.z),
				Materials.machined(Materials.STEEL, 55))
	# A recessed housing behind the reels, so the drums sit in shadow rather than
	# on a flat panel. This is most of what sells the depth of the front face.
	_box(chassis, Vector3(1.28, 0.62, 0.3),
			Vector3(0.0, CHASSIS_Y + 0.04, CHASSIS.z - 0.28),
			Materials.cavity())
	# Ventilation louvres on the lower front, an inspection hatch on the left.
	for i: int in 5:
		_box(chassis, Vector3(0.72, 0.022, 0.03),
				Vector3(0.0, CHASSIS_Y - 0.3 + float(i) * 0.045, CHASSIS.z + 0.005),
				Materials.machined(Color(0.18, 0.17, 0.16), 56))
	_box(chassis, Vector3(0.3, 0.34, 0.02),
			Vector3(-0.58, CHASSIS_Y - 0.16, CHASSIS.z + 0.012),
			Materials.machined(Materials.STEEL, 57))


## Three drums on a shared axle, in the node shape [SlotView3D] expects: each
## reel is a [Node3D] carrying a "Face" mesh and a "Symbol" label.
func _reel_bank() -> Array[Node3D]:
	var bank: Node3D = _group(&"Reels")
	bank.position = Vector3(0.0, CHASSIS_Y + 0.05, REEL_Z)
	var drum: CylinderMesh = CylinderMesh.new()
	drum.top_radius = REEL_RADIUS
	drum.bottom_radius = REEL_RADIUS
	drum.height = 0.3
	drum.radial_segments = 32
	var reels: Array[Node3D] = []
	for i: int in 3:
		var reel: Node3D = Node3D.new()
		reel.name = "Reel%d" % i
		reel.position = Vector3((float(i) - 1.0) * REEL_SPACING, 0.0, 0.0)
		bank.add_child(reel)

		var face: MeshInstance3D = MeshInstance3D.new()
		face.name = "Face"
		face.mesh = drum
		# The drum's own axis is Y; rotating it onto X makes it roll toward the
		# player when the reel node turns about X, which is how the view spins it.
		face.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)
		face.material_override = Materials.enamel(Materials.ENAMEL, 67 + i)
		reel.add_child(face)

		# The backlight behind a symbol. A quad rather than a Sprite3D because
		# it has to blend additively, and setting a material_override on a
		# Sprite3D throws away the sprite's own texture handling.
		var glow: MeshInstance3D = MeshInstance3D.new()
		glow.name = "Glow"
		var halo_quad: QuadMesh = QuadMesh.new()
		halo_quad.size = Vector2(0.66, 0.66)
		glow.mesh = halo_quad
		var halo: StandardMaterial3D = StandardMaterial3D.new()
		halo.albedo_texture = SymbolArt.halo()
		halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		halo.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Never write depth: the glow sits between the drum and the symbol, and
		# an additive quad that writes depth punches a hole in whatever follows.
		halo.no_depth_test = false
		halo.disable_receive_shadows = true
		glow.material_override = halo
		glow.visible = false
		glow.position = Vector3(0.0, 0.0, REEL_RADIUS + 0.003)
		reel.add_child(glow)

		# Two ways to show a symbol, and only ever one of them visible: a drawn
		# sprite where SymbolArt has art, and the glyph token as text where it
		# does not. New content therefore lands legible without needing art
		# first, which is the whole reason the text path survives.
		var art: Sprite3D = Sprite3D.new()
		art.name = "Art"
		art.pixel_size = 0.0028
		art.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		art.shaded = false
		# Discard rather than blend: the sprite sits a few millimetres off a
		# curved drum, and alpha blending there sorts against the drum badly.
		art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.visible = false
		art.position = Vector3(0.0, 0.0, REEL_RADIUS + 0.005)
		reel.add_child(art)

		var symbol: Label3D = Label3D.new()
		symbol.name = "Symbol"
		symbol.text = "?"
		symbol.font_size = 96
		symbol.pixel_size = 0.0022
		symbol.outline_size = 14
		symbol.outline_modulate = Color(0.1, 0.08, 0.07, 1.0)
		symbol.modulate = Color(0.16, 0.14, 0.12)
		# Just clear of the drum surface, so it reads as printed on the strip.
		symbol.position = Vector3(0.0, 0.0, REEL_RADIUS + 0.004)
		reel.add_child(symbol)
		reels.append(reel)
	return reels


## The chrome window the drums are read through, plus the payline across it.
func _bezel() -> void:
	var bezel: Node3D = _group(&"Bezel")
	var y: float = CHASSIS_Y + 0.05
	var z: float = CHASSIS.z + 0.02
	var steel: StandardMaterial3D = Materials.chrome()
	_box(bezel, Vector3(1.34, 0.07, 0.09), Vector3(0.0, y + 0.29, z), steel)
	_box(bezel, Vector3(1.34, 0.07, 0.09), Vector3(0.0, y - 0.29, z), steel)
	for sx: float in [-1.0, 1.0]:
		_box(bezel, Vector3(0.07, 0.65, 0.09), Vector3(sx * 0.635, y, z), steel)
	# Divider bars between the three windows.
	for sx: float in [-1.0, 1.0]:
		_box(bezel, Vector3(0.035, 0.58, 0.07),
				Vector3(sx * REEL_SPACING * 0.5, y, z), steel)
	# The payline: the one thing on the machine that must be found instantly.
	_box(bezel, Vector3(1.24, 0.012, 0.012), Vector3(0.0, y, z + 0.04),
			Materials.glowing(Materials.JACKPOT, 1.6))


## The brass mechanism on the left flank — a combination dial on a gear housing.
## It is the machine's one warm, ornate element, and it is deliberately the
## thing the eye lands on after the reels.
func _gearbox() -> Node3D:
	var gearbox: Node3D = _group(&"Gearbox")
	gearbox.position = Vector3(-1.16, CHASSIS_Y - 0.04, 0.34)
	gearbox.rotation = Vector3(0.0, 0.42, 0.0)
	var brass: StandardMaterial3D = Materials.brass()
	# The housing barrel, lying along Z so its face points at the player.
	_cylinder(gearbox, 0.3, 0.46, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), brass)
	# Cooling fins stepping down the barrel.
	for i: int in 4:
		_cylinder(gearbox, 0.34 - float(i) * 0.018, 0.035,
				Vector3(0.0, 0.0, -0.1 - float(i) * 0.07),
				Vector3(PI * 0.5, 0.0, 0.0), brass)
	# The dial itself: a knurled ring, a face, and an index mark.
	_cylinder(gearbox, 0.27, 0.07, Vector3(0.0, 0.0, 0.26),
			Vector3(PI * 0.5, 0.0, 0.0), Materials.machined(Color(0.5, 0.49, 0.47), 59))
	var dial: Node3D = Node3D.new()
	dial.name = "Dial"
	gearbox.add_child(dial)
	_cylinder(dial, 0.21, 0.045, Vector3(0.0, 0.0, 0.31),
			Vector3(PI * 0.5, 0.0, 0.0), Materials.enamel(Color(0.15, 0.14, 0.13), 68))
	for i: int in 12:
		var angle: float = TAU * float(i) / 12.0
		_box(dial, Vector3(0.012, 0.012, 0.05),
				Vector3(cos(angle) * 0.16, sin(angle) * 0.16, 0.325), brass)
	# A mounting collar tying the gearbox back into the chassis.
	_box(gearbox, Vector3(0.34, 0.34, 0.12), Vector3(0.0, 0.0, -0.34),
			Materials.rusted(24))
	return gearbox


## Rubber hoses running from the gearbox into the chassis flank. Curves are
## approximated by short segments — cheap, and at this scale indistinguishable.
func _hoses() -> void:
	var hoses: Node3D = _group(&"Hoses")
	var rubber: StandardMaterial3D = Materials.rubber()
	var runs: Array[Vector2] = [Vector2(0.2, 0.16), Vector2(0.0, 0.3), Vector2(-0.22, 0.1)]
	for run: Vector2 in runs:
		var from: Vector3 = Vector3(-1.16, CHASSIS_Y + run.x, 0.12)
		var to: Vector3 = Vector3(-CHASSIS.x + 0.04, CHASSIS_Y + run.x * 0.4, run.y)
		var segments: int = 6
		for i: int in segments:
			var t0: float = float(i) / float(segments)
			var t1: float = float(i + 1) / float(segments)
			# A control point pushed forward turns the straight run into a sag.
			var bend: Vector3 = (from + to) * 0.5 + Vector3(0.0, -0.12, 0.26)
			var a: Vector3 = _quadratic(from, bend, to, t0)
			var b: Vector3 = _quadratic(from, bend, to, t1)
			_segment(hoses, a, b, 0.032, rubber)
		# A crimped collar where the hose enters the gearbox.
		_cylinder(hoses, 0.045, 0.06, from, Vector3(0.0, 0.0, PI * 0.5),
				Materials.brass(38))


## The monitor on its swing arm. The screen is a separate mesh so the readout
## can be drawn onto it, and it is emissive so it survives the room going dark.
func _monitor() -> MeshInstance3D:
	var monitor: Node3D = _group(&"Monitor")
	monitor.position = Vector3(-0.86, CHASSIS_Y + 0.95, 0.1)
	monitor.rotation = Vector3(0.0, 0.34, 0.0)
	# The arm: a post off the chassis shoulder and an elbow up to the housing.
	_segment(_root, Vector3(-0.72, CHASSIS_Y + 0.4, 0.1),
			Vector3(-0.86, CHASSIS_Y + 0.8, 0.1), 0.055,
			Materials.machined(Color(0.42, 0.41, 0.4), 60))
	# A bolted foot where the arm meets the chassis shoulder.
	_box(_root, Vector3(0.22, 0.08, 0.22), Vector3(-0.72, CHASSIS_Y + 0.44, 0.1),
			Materials.rusted(31))
	_cylinder(monitor, 0.07, 0.12, Vector3(0.0, -0.3, 0.0), Vector3.ZERO,
			Materials.machined(Materials.STEEL, 61))
	# Housing: a deep-backed CRT shell, not a flat panel.
	_box(monitor, Vector3(0.66, 0.54, 0.14), Vector3(0.0, 0.0, 0.16),
			Materials.painted(Materials.PAINT_LIGHT, 15))
	_box(monitor, Vector3(0.5, 0.42, 0.28), Vector3(0.0, 0.0, -0.02),
			Materials.painted(Materials.PAINT, 16))
	var screen: MeshInstance3D = _box(monitor, Vector3(0.56, 0.44, 0.02),
			Vector3(0.0, 0.0, 0.235),
			Materials.phosphor_glass())
	screen.name = "Screen"
	# The readout the room writes onto. Unshaded phosphor green, so it stays
	# readable with every light in the room switched off.
	var readout: Label3D = Label3D.new()
	readout.name = "Readout"
	readout.text = "DEBT\n0"
	readout.font_size = 56
	readout.pixel_size = 0.0016
	readout.modulate = Materials.PHOSPHOR * 1.6
	readout.outline_size = 0
	readout.shaded = false
	readout.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	readout.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	readout.position = Vector3(-0.25, 0.18, 0.02)
	readout.width = 320.0
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(readout)
	return screen


## The odds readout above the chassis: cream digits on a dark strip, in the
## place a nixie tube bank would sit.
func _odds_display() -> Label3D:
	var housing: Node3D = _group(&"Odds")
	housing.position = Vector3(0.16, CHASSIS_Y + 0.72, 0.18)
	_box(housing, Vector3(0.86, 0.26, 0.16), Vector3.ZERO,
			Materials.painted(Materials.PAINT, 17))
	_box(housing, Vector3(0.78, 0.19, 0.02), Vector3(0.0, 0.0, 0.085),
			Materials.readout_face())
	# The mounting stalk down to the chassis top.
	_segment(housing, Vector3(0.0, -0.13, 0.0), Vector3(0.0, -0.34, -0.1), 0.03,
			Materials.machined(Materials.STEEL, 62))
	var label: Label3D = Label3D.new()
	label.name = "Value"
	label.text = "0x"
	label.font_size = 120
	label.pixel_size = 0.0013
	label.modulate = Color(0.95, 0.9, 0.78)
	label.outline_size = 0
	label.position = Vector3(0.0, 0.0, 0.1)
	# The readout has to stay legible when the room light is off it.
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = false
	housing.add_child(label)
	return label


## The arm on the right flank. Returned so the view can throw it on a spin.
func _lever() -> Node3D:
	var mount: Node3D = _group(&"Lever")
	mount.position = Vector3(CHASSIS.x + 0.12, CHASSIS_Y + 0.1, 0.05)
	# The pivot housing stays put; only the arm below it swings.
	_box(mount, Vector3(0.26, 0.3, 0.3), Vector3(0.0, -0.06, 0.0),
			Materials.machined(Materials.STEEL, 63))
	_cylinder(mount, 0.09, 0.34, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5),
			Materials.brass(39))
	var arm: Node3D = Node3D.new()
	arm.name = "Arm"
	mount.add_child(arm)
	# Resting back and up, the way a lever waits to be pulled toward you.
	arm.rotation = Vector3(-0.5, 0.0, 0.0)
	_segment(arm, Vector3(0.16, 0.0, 0.0), Vector3(0.16, 0.62, 0.0), 0.028,
			Materials.machined(Color(0.52, 0.51, 0.5), 64))
	_cylinder(arm, 0.06, 0.09, Vector3(0.16, 0.66, 0.0), Vector3.ZERO,
			Materials.timber())
	return arm


## The receipt spool, and the paper it has already paid out. The tape running
## off the plinth onto the floor is the machine's history made physical.
func _spool() -> Node3D:
	var spool: Node3D = _group(&"Spool")
	spool.position = Vector3(1.32, PLINTH_TOP + 0.3, 0.36)
	var paper: StandardMaterial3D = Materials.enamel(Materials.PAPER, 69)
	_cylinder(spool, 0.17, 0.22, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), paper)
	_cylinder(spool, 0.05, 0.26, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5),
			Materials.machined(Materials.STEEL, 65))
	# The tape: a run of thin panels stepping down and away, each turned a little
	# so the strip creases rather than falling as a plank.
	# The tape hanging off the spool. Panels overlap along the run rather than
	# butting: a gap between two thin plates shows their unlit edges, and a row
	# of those reads as piano keys instead of paper.
	var run: Array[Vector3] = [
		Vector3(1.3, PLINTH_TOP + 0.14, 0.5),
		Vector3(1.31, PLINTH_TOP + 0.11, 0.62),
		Vector3(1.33, PLINTH_TOP - 0.1, 0.68),
	]
	for i: int in run.size() - 1:
		var from: Vector3 = run[i]
		var to: Vector3 = run[i + 1]
		var delta: Vector3 = to - from
		var panel: MeshInstance3D = _box(_root,
				Vector3(0.19, 0.004, delta.length() * 1.35),
				(from + to) * 0.5, paper)
		panel.rotation = Vector3(-atan2(delta.y, delta.z), 0.0, sin(float(i) * 1.7) * 0.06)
	return spool


## Rivets and bolt heads along every seam, drawn as one [MultiMesh] so the whole
## population costs a single draw call on a phone.
func _rivets() -> void:
	var positions: Array[Vector3] = []
	# Along the top and bottom edges of the front face.
	for i: int in 8:
		var x: float = lerpf(-CHASSIS.x + 0.1, CHASSIS.x - 0.1, float(i) / 7.0)
		positions.append(Vector3(x, CHASSIS_Y + CHASSIS.y - 0.06, CHASSIS.z + 0.015))
		positions.append(Vector3(x, CHASSIS_Y - CHASSIS.y + 0.06, CHASSIS.z + 0.015))
	# Down the corner posts, both flanks.
	for i: int in 4:
		var y: float = lerpf(CHASSIS_Y - CHASSIS.y + 0.1, CHASSIS_Y + CHASSIS.y - 0.1,
				float(i) / 3.0)
		for sx: float in [-1.0, 1.0]:
			positions.append(Vector3(sx * (CHASSIS.x + 0.015), y, CHASSIS.z - 0.03))
			positions.append(Vector3(sx * (CHASSIS.x + 0.015), y, -CHASSIS.z + 0.03))
	# Four at the bezel's corners, where a window frame is actually bolted on.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			positions.append(Vector3(sx * 0.6, CHASSIS_Y + 0.05 + sy * 0.29,
					CHASSIS.z + 0.07))

	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.031
	head.height = 0.042
	head.radial_segments = 10
	head.rings = 5
	head.material = Materials.machined(Color(0.353, 0.337, 0.318), 66)

	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = head
	multi.instance_count = positions.size()
	for i: int in positions.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "Rivets"
	instance.multimesh = multi
	_root.add_child(instance)


# --- primitives -------------------------------------------------------------

func _group(node_name: StringName) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = node_name
	_root.add_child(group)
	return group


func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
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
	mesh.rings = 0
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = at
	instance.rotation = euler
	return instance


## A cylinder spanning two points — the workhorse for pipes, hoses and struts,
## since placing those by centre-and-euler by hand is where mistakes live.
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
	mesh.rings = 0
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = (from + to) * 0.5
	# A cylinder points along +Y; aim that at the segment, picking a reference
	# axis that is never parallel to it so the basis stays well-conditioned.
	var up: Vector3 = delta / length
	var reference: Vector3 = (Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.99
			else Vector3.UP)
	var right: Vector3 = reference.cross(up).normalized()
	instance.transform.basis = Basis(right, up, right.cross(up).normalized())
	return instance


func _quadratic(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)
