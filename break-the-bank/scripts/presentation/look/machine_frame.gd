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
const CHASSIS: Vector3 = Vector3(0.98, 0.62, 0.42)
## Centre height of the chassis: the plinth's top plus half the chassis.
const CHASSIS_Y: float = 1.04
const PLINTH_TOP: float = 0.42
## Big enough that three symbols fit around the front of the drum without the
## outer two curving away out of sight, at fourteen cells to the turn.
const REEL_RADIUS: float = 0.44
const REEL_SPACING: float = 0.43
## One printed cell of the reel strip, in radians. The drum divides into
## [code]ReelPrint.CELLS[/code] of them, and the band above and below the
## payline sits exactly one cell either side — the band sprites, the strip
## print and a nudge's quarter-turn all share this one number, which is what
## keeps a dynamic plate registered with the printing behind it.
const BAND_ANGLE: float = TAU / float(ReelPrint.CELLS)
## Width of a drum along its axle.
const DRUM_WIDTH: float = 0.38
## Distance from the machine's centre plane to the front face of a reel drum.
const REEL_Z: float = 0.3
## Modules are authored around a 0.26m bracket; at that size they read as
## trinkets pinned to the frame rather than as hardware fitted to it.
const MOUNT_SCALE: float = 1.25
## Rungs on the gamble ladder, matching the length of the odds table.
const LADDER_RUNGS: int = 4
## Angle a dial's needle rests at when its value is zero, and the sweep it turns
## through at full scale. Anticlockwise, the way a pressure gauge reads.
const GAUGE_SWEEP: float = 2.1
## Brightness of the mark beside a row that pays.
const PAYLINE_ENERGY: float = 2.6
## Keys on the console rail. Six is the most the deck ever offers at once.
const CONSOLE_KEYS: int = 6
## The surety column's glass, in metres.
const SURETY_HEIGHT: float = 0.46

var _root: Node3D
## Places on the machine that can be asked what they are. Handed back in
## build() as "inspect"; [SlotView3D] wires them to the pointer.
var _zones: Array[Area3D] = []
var _nixie_halo_material: StandardMaterial3D = null


## Constructs the machine under [param root] and returns the nodes the view
## drives, keyed [code]reels[/code], [code]lever[/code], [code]screen[/code],
## [code]odds[/code] and [code]spool[/code].
func build(root: Node3D, reel_count: int = 3) -> Dictionary:
	_root = root
	_plinth()
	_chassis()
	var reels: Array[Node3D] = _reel_bank(reel_count)
	_bezel(reel_count)
	_button_row(reel_count)
	var counters: Dictionary = _counter_bank()
	var console: Array[Node3D] = _console()
	var gearbox: Node3D = _gearbox()
	_hoses()
	var screen: MeshInstance3D = _monitor()
	var readout: Label = screen.get_node(^"Terminal/Readout") as Label
	var odds: Node3D = _odds_display()
	var lever: Node3D = _lever()
	var arc: Dictionary = _coil()
	var spool: Node3D = _spool()
	var surety: Dictionary = _surety_column()
	var crown: Array[Node3D] = _crown()
	var ladder: Array[Node3D] = _ladder()
	_rivets()
	_wear()
	var mounts: Array[Node3D] = _mounts()
	return {
		"mounts": mounts,
		"counters": counters,
		"console": console,
		"payline": _root.get_node_or_null(^"Bezel/Payline"),
		"lever_pick": lever.get_node_or_null(^"Pick"),
		"crown": crown,
		"ladder": ladder,
		"gauges": [
			_root.get_node_or_null(^"Crown/Gauge_stake"),
			_root.get_node_or_null(^"Crown/Gauge_count"),
		],
		"reels": reels,
		"gearbox": gearbox,
		"screen": screen,
		"readout": readout,
		"odds": odds,
		"lever": lever,
		"arc": arc,
		"spool": spool,
		"surety": surety,
		"inspect": _zones,
	}


# --- major assemblies -------------------------------------------------------

## The concrete block the machine is bolted to. It grounds the composition:
## without it the chassis floats and the whole thing reads as a prop.
func _plinth() -> void:
	var plinth: Node3D = _group(&"Plinth")
	_box(plinth, Vector3(2.3, PLINTH_TOP, 1.15),
			Vector3(0.0, PLINTH_TOP * 0.5, 0.0),
			Materials.weathered("concrete", Materials.CONCRETE, 0.55, 0.9,
					0.45, 0.3, Materials.concrete()))
	# A chamfered cap, slightly proud, so the top edge catches the key light.
	_box(plinth, Vector3(2.42, 0.07, 1.27),
			Vector3(0.0, PLINTH_TOP + 0.02, 0.0),
			Materials.weathered("concrete", Materials.CONCRETE, 0.6, 0.9,
					0.5, 0.22, Materials.concrete(84)))
	# Hex bolts along the bottom rim, the way a machine this heavy is
	# actually held to a floor: the handover asked for them by name.
	var bolt: StandardMaterial3D = Materials.machined(Color(0.34, 0.33, 0.31), 85)
	for i: int in 7:
		var x: float = lerpf(-1.02, 1.02, float(i) / 6.0)
		for sz: float in [-1.0, 1.0]:
			var head: MeshInstance3D = Prims.cylinder(plinth, 0.032, 0.026,
					Vector3(x, 0.07, sz * 0.6), Vector3(PI * 0.5, 0.0, 0.0), bolt, 6)
			head.rotation.z = 0.4
			Prims.cylinder(plinth, 0.042, 0.012, Vector3(x, 0.07, sz * 0.585),
					Vector3(PI * 0.5, 0.0, 0.0), Materials.rusted(86), 6)
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
	# The body is a loft through PROFILE rather than a box: the base kicks
	# forward, the glass band stands straight, the brow leans back over it,
	# and the whole thing narrows as it rises. A cabinet, not a crate.
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _cabinet_mesh()
	body.material_override = Materials.weathered("painted_metal", Materials.PAINT,
			0.9, 1.0, 0.38, 0.3, Materials.painted(Materials.PAINT, 11))
	chassis.add_child(body)
	var steel_post: StandardMaterial3D = Materials.machined(Materials.STEEL, 54)
	# Angle iron down the four corners, following the taper rather than
	# standing plumb beside it.
	var base_y: float = PROFILE[0][0]
	var top_y: float = PROFILE[PROFILE.size() - 1][0]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var from: Vector3 = Vector3(sx * _half_width(base_y), base_y,
					_face_z(base_y) if sz > 0.0 else _back_z(base_y))
			var to: Vector3 = Vector3(sx * _half_width(top_y), top_y,
					_face_z(top_y) if sz > 0.0 else _back_z(top_y))
			_segment(chassis, from, to, 0.05, steel_post)
	# And along the top edges, at the head's own width.
	for sz: float in [-1.0, 1.0]:
		_box(chassis, Vector3(_half_width(top_y) * 2.06, 0.09, 0.09),
				Vector3(0.0, top_y, (_face_z(top_y) if sz > 0.0 else _back_z(top_y))),
				Materials.machined(Materials.STEEL, 55))
	# The A-frame: cast-iron cheeks on both flanks, slanting back from the
	# base to the crown, and a heavier lintel across the top.
	var iron: StandardMaterial3D = Materials.rusted(58)
	for sx: float in [-1.0, 1.0]:
		var cheek: MeshInstance3D = _box(chassis, Vector3(0.09, CHASSIS.y * 2.3, 0.52),
				Vector3(sx * (CHASSIS.x + 0.05), CHASSIS_Y + 0.02, -0.02), iron)
		cheek.rotation.x = -0.16
		cheek.rotation.z = sx * 0.04
		_box(chassis, Vector3(0.16, 0.06, 0.6),
				Vector3(sx * (CHASSIS.x + 0.05), base_y + 0.03, 0.04), iron)
		for i: int in 3:
			Prims.sphere(chassis, 0.016,
					Vector3(sx * (CHASSIS.x + 0.1), CHASSIS_Y - 0.4 + float(i) * 0.4,
							0.2 - float(i) * 0.07),
					Materials.machined(Materials.STEEL, 59))
	_box(chassis, Vector3(_half_width(top_y) * 2.2, 0.09, 0.5),
			Vector3(0.0, top_y + 0.04, _back_z(top_y) + 0.28), iron)
	_recast(chassis, iron)
	# A recessed housing behind the reels, so the drums sit in shadow rather than
	# on a flat panel. This is most of what sells the depth of the front face.
	# Deep enough to swallow the whole drum: a reel poking through the back of
	# its own housing reads as a bug from any angle but the front.
	_box(chassis, Vector3(1.44, 0.9, 0.62),
			Vector3(0.0, CHASSIS_Y + 0.05, CHASSIS.z - 0.32),
			Materials.cavity())
	# Ventilation louvres on the lower front, an inspection hatch on the left.
	for i: int in 5:
		var louvre_y: float = CHASSIS_Y - 0.3 + float(i) * 0.045
		_box(chassis, Vector3(0.72, 0.022, 0.03),
				Vector3(0.0, louvre_y, _face_z(louvre_y) + 0.005),
				Materials.machined(Color(0.18, 0.17, 0.16), 56))
	_box(chassis, Vector3(0.3, 0.34, 0.02),
			Vector3(-0.58, CHASSIS_Y - 0.16, _face_z(CHASSIS_Y - 0.16) + 0.012),
			Materials.machined(Materials.STEEL, 57))


## A place on the machine the pointer can ask about. Everything a player
## can read off the machine — a counter, a dial, a drum, the column — gets
## one, so "what is this number" is answered by the machine rather than by
## a manual.
func _inspect_zone(parent: Node3D, id: StringName, size: Vector3, at: Vector3) -> Area3D:
	var zone: Area3D = Area3D.new()
	zone.name = "Inspect_%s" % String(id).replace(":", "_")
	zone.position = at
	zone.set_meta(&"inspect", id)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	parent.add_child(zone)
	_zones.append(zone)
	return zone


## The cabinet's profile: height, half width, and how far forward the face
## stands at that height. Four rings, read as a section through the machine
## from the floor up — the base kicks out, the glass band is plumb, the brow
## leans back over it, and the head is narrower than the foot.
##
## Everything bolted to the front asks [method _face_z] where the face is at
## its own height rather than assuming [constant CHASSIS]'s flat one.
const PROFILE: Array = [
	[0.42, 1.03, 0.52],
	[0.90, 1.00, 0.44],
	[1.45, 0.98, 0.42],
	[1.66, 0.88, 0.28],
]


static func _face_z(y: float) -> float:
	return _profile_at(y, 2)


static func _half_width(y: float) -> float:
	return _profile_at(y, 1)


## The back is nearly plumb: it faces a wall nobody sees, and a taper there
## would only cost the cabinet its depth.
static func _back_z(y: float) -> float:
	return -CHASSIS.z + 0.04 * clampf((y - 1.45) / 0.21, 0.0, 1.0)


static func _profile_at(y: float, column: int) -> float:
	var rings: Array = PROFILE
	if y <= float(rings[0][0]):
		return float(rings[0][column])
	for i: int in rings.size() - 1:
		var low: Array = rings[i]
		var high: Array = rings[i + 1]
		if y <= float(high[0]):
			var t: float = (y - float(low[0])) / maxf(float(high[0]) - float(low[0]), 0.001)
			return lerpf(float(low[column]), float(high[column]), t)
	return float(rings[rings.size() - 1][column])


## The body itself: the profile lofted round four corners and capped. Built
## by hand because a box cannot cant and a CSG tree cannot ship.
func _cabinet_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for ring: Array in PROFILE:
		var y: float = float(ring[0])
		var half: float = float(ring[1])
		var front: float = float(ring[2])
		var back: float = _back_z(y)
		rings.append(PackedVector3Array([
			Vector3(-half, y, front), Vector3(half, y, front),
			Vector3(half, y, back), Vector3(-half, y, back),
		]))
	for i: int in rings.size() - 1:
		var low: PackedVector3Array = rings[i]
		var high: PackedVector3Array = rings[i + 1]
		for corner: int in 4:
			var next: int = (corner + 1) % 4
			_quad(surface, low[corner], low[next], high[next], high[corner])
	var bottom: PackedVector3Array = rings[0]
	_quad(surface, bottom[3], bottom[2], bottom[1], bottom[0])
	var top: PackedVector3Array = rings[rings.size() - 1]
	_quad(surface, top[0], top[1], top[2], top[3])
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		# Planar UVs off the point's own X and Y: every material on the body
		# is triplanar, so these are only here to keep the format complete.
		surface.set_uv(Vector2(point.x, point.y))
		surface.add_vertex(point)


## The classic cabinet, recast around the box.
##
## A fruit machine is not a crate: the head narrows into shoulders, the
## glass sits under a brow, the hand rests on a rail, the money lands in a
## tray you can reach, and the whole thing stands on a step. None of that
## can move the box — every counter, key, drum and mount is positioned
## against [constant CHASSIS] — so the recast is cut around it, the way the
## cheeks are. First pass: the shoulders, the rail, the tray and the step.
func _recast(chassis: Node3D, iron: StandardMaterial3D) -> void:
	var steel: StandardMaterial3D = Materials.machined(Color(0.4, 0.39, 0.38), 60)
	var top: float = CHASSIS_Y + CHASSIS.y
	# Shoulders: the top corners cut back at forty-five degrees, so the head
	# tapers into the crown instead of ending in a square edge.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var shoulder: MeshInstance3D = _box(chassis, Vector3(0.3, 0.3, 0.26),
					Vector3(sx * (CHASSIS.x - 0.02), top - 0.02, sz * (CHASSIS.z - 0.1)),
					iron)
			shoulder.rotation.z = sx * PI * 0.25
	# No hand rail and no coin tray across the front: the console's keys
	# live there, and both crossed straight through them.
	# No coin tray: it sat under the console shelf's overhang where nothing
	# could see it, and the bottom of a machine a player reads every spin is
	# the last place to put furniture. The printer is where the House pays.
	# The step: the cabinet stands on the plinth, and the plinth stands on a
	# course of its own. It is what makes the machine read as installed.
	_box(_root, Vector3(2.6, 0.09, 1.36), Vector3(0.0, 0.045, 0.0),
			Materials.weathered("concrete", Materials.CONCRETE, 0.5, 0.9, 0.5, 0.3,
					Materials.concrete(62)))


## Three drums on a shared axle, in the node shape [SlotView3D] expects: each
## reel is a [Node3D] carrying a "Face" mesh and a "Symbol" label.
## Rebuilds just the window — the drums and the chrome around them — at a new
## reel count, leaving everything bolted to the frame where it is.
##
## The machine grows on floor six, and rebuilding the whole thing to widen it
## would throw away every module the run has bought. The window is the only part
## that has to change, so it is the only part that is thrown away.
func rebuild_window(root: Node3D, reel_count: int) -> Array[Node3D]:
	_root = root
	for group_name: StringName in [&"Reels", &"Bezel", &"Buttons"]:
		var old: Node = root.get_node_or_null(NodePath(group_name))
		if old != null:
			# Removed as well as freed: queue_free defers, and the new bank is
			# added in this same frame under the same name.
			root.remove_child(old)
			old.queue_free()
	var reels: Array[Node3D] = _reel_bank(reel_count)
	_bezel(reel_count)
	_button_row(reel_count)
	return reels


## Half the width the drums occupy at [param reel_count], for the chrome and the
## housings that have to reach round them.
static func bank_half_width(reel_count: int) -> float:
	return float(maxi(reel_count, 1) - 1) * REEL_SPACING * 0.5


func _reel_bank(reel_count: int) -> Array[Node3D]:
	var bank: Node3D = _group(&"Reels")
	bank.position = Vector3(0.0, CHASSIS_Y + 0.05, REEL_Z)
	var count: int = maxi(reel_count, 1)
	var centre: float = float(count - 1) * 0.5
	# One tube and one arc, shared by every drum: the tube wears the whole
	# printed strip, the arc is a single cell of the same surface, lifted just
	# clear so a landed plate overprints the cell behind it.
	var drum_mesh: ArrayMesh = _drum_tube(REEL_RADIUS, DRUM_WIDTH, 48)
	var plate_mesh: ArrayMesh = _plate_arc(REEL_RADIUS + 0.004, DRUM_WIDTH)
	var reels: Array[Node3D] = []
	# Every material that shows the strip, drums and plates alike, collected so
	# the bake can dress them all in one pass when it lands a frame from now.
	var strip_materials: Array[StandardMaterial3D] = []
	for i: int in count:
		var reel: Node3D = Node3D.new()
		reel.name = "Reel%d" % i
		reel.position = Vector3((float(i) - centre) * REEL_SPACING, 0.0, 0.0)
		bank.add_child(reel)

		var face: MeshInstance3D = MeshInstance3D.new()
		face.name = "Face"
		face.mesh = drum_mesh
		var face_material: StandardMaterial3D = _strip_material()
		# Each drum starts its strip a few cells round from its neighbour.
		# One texture serves every drum, and this is what stops three of them
		# reading as three copies of the same photograph.
		face_material.uv1_offset.y = fmod(float(i) * 3.0,
				float(ReelPrint.CELLS)) / float(ReelPrint.CELLS)
		face.material_override = face_material
		strip_materials.append(face_material)
		reel.add_child(face)

		# Metal end rims and a hub either side: a drum is a wheel, and a strip
		# of paper with no hardware holding it is a label, not a reel.
		for sx: float in [-1.0, 1.0]:
			Prims.cylinder(reel, REEL_RADIUS + 0.009, 0.016,
					Vector3(sx * (DRUM_WIDTH * 0.5 + 0.008), 0.0, 0.0),
					Vector3(0.0, 0.0, PI * 0.5),
					Materials.machined(Materials.STEEL, 61), 32)
			Prims.cylinder(reel, 0.07, 0.03,
					Vector3(sx * (DRUM_WIDTH * 0.5 + 0.03), 0.0, 0.0),
					Vector3(0.0, 0.0, PI * 0.5),
					Materials.brass(62), 20)

		# Three cells of window per reel: what landed, and what nearly did
		# either side of it. The near miss is the drama, and you cannot have
		# one you were never shown. Each plate is the strip's own printing,
		# addressed one cell at a time by uv offset — the payline at full
		# strength, the band dimmed to context.
		for slot: int in 3:
			var offset: float = float(slot - 1) * BAND_ANGLE
			var plate: MeshInstance3D = MeshInstance3D.new()
			plate.name = ["Above", "Payline", "Below"][slot]
			plate.mesh = plate_mesh
			var plate_material: StandardMaterial3D = _strip_material()
			plate_material.uv1_scale = Vector3(
					1.0, 1.0 / float(ReelPrint.CELLS), 1.0)
			# Never pure white. A white plate under the window lamp specular
			# went past the bloom threshold and bleached whatever was printed
			# on it — the "glare" that made one panel a floor unreadable.
			plate_material.albedo_color = (Color(0.93, 0.91, 0.87) if slot == 1
					else Color(0.76, 0.74, 0.71))
			plate.material_override = plate_material
			strip_materials.append(plate_material)
			plate.rotation.x = offset
			plate.visible = false
			reel.add_child(plate)

		# Two ways to show a symbol, and only ever one of them visible: the
		# strip cell where the symbol has printed art, and the glyph token as
		# text where it does not. New content therefore lands legible without
		# needing art first, which is the whole reason the text path survives.
		var symbol: Label3D = Label3D.new()
		symbol.name = "Symbol"
		Type.face(symbol, &"body")
		symbol.text = "?"
		symbol.font_size = 96
		symbol.pixel_size = 0.0022
		symbol.outline_size = 14
		symbol.outline_modulate = Color(0.1, 0.08, 0.07, 1.0)
		symbol.modulate = Color(0.16, 0.14, 0.12)
		# Hidden until something lands on it. A drum nothing has been drawn for
		# is blank, not a question mark — which is what a machine that has just
		# grown two new reels shows until the next spin fills them.
		symbol.visible = false
		# Just clear of the plates, so the fallback is never inside the print.
		symbol.position = Vector3(0.0, 0.0, REEL_RADIUS + 0.009)
		reel.add_child(symbol)
		_inspect_zone(reel, StringName("reel:%d" % i),
				Vector3(DRUM_WIDTH, 0.2, 0.08),
				Vector3(0.0, 0.0, REEL_RADIUS + 0.02))
		_reel_lamps(reel)
		reels.append(reel)
	# The axle the drums turn on, visible in the gaps between them.
	Prims.cylinder(bank, 0.045,
			float(count - 1) * REEL_SPACING + DRUM_WIDTH + 0.2,
			Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5),
			Materials.machined(Materials.STEEL, 63), 14)
	# The lamp inside the window. The key light hangs above the machine, so the
	# band below the payline curves down into its own shadow — which the old
	# unshaded sprites never showed, and physical plates do. Real machines put
	# a bulb in the window for exactly this reason.
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "WindowLamp"
	lamp.light_color = Materials.LAMP
	# Compatibility clamps highlights where Forward+ rolls them off, so the
	# same lamp that reads warm on desktop burns the strip white on the web
	# build. One number, scaled per renderer, keeps the two in the same key.
	lamp.light_energy = 0.85 \
			if RenderingServer.get_current_rendering_method() != "gl_compatibility" \
			else 0.6
	# Diffuse, almost no specular: the lamp is a foot from the centre plate,
	# and its highlight on coated paper was the glare the print vanished under.
	lamp.light_specular = 0.12
	lamp.omni_range = 1.3
	lamp.omni_attenuation = 1.3
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 0.06, REEL_RADIUS + 0.34)
	bank.add_child(lamp)
	# Dress every drum and plate in the printed strip. The bake takes a frame
	# on its first run, so the drums boot wearing plain paper and are dressed
	# the moment the strip exists; on a window rebuild the cached strip dresses
	# them synchronously.
	ReelPrint.bake(_root, func() -> void:
		var strip: ImageTexture = ReelPrint.strip()
		var relief: ImageTexture = ReelPrint.relief()
		var metal: ImageTexture = ReelPrint.metal()
		for material: StandardMaterial3D in strip_materials:
			material.albedo_texture = strip
			# The print stands proud of the paper and the premium symbols are
			# metal, both lit by the room: the art handover's "paint on metal,
			# not a texture" is these two maps.
			if relief != null:
				material.normal_enabled = true
				material.normal_texture = relief
				material.normal_scale = 1.0
			if metal != null:
				material.metallic = 1.0
				material.metallic_texture = metal
				# 0.32: at 0.5 the upward-tilted top row threw a specular
				# highlight straight back at the window lamp.
				material.metallic_specular = 0.32)
	return reels


## An open cylinder about the X axis wearing the full reel strip: U runs along
## the axle, V runs around the circumference, one strip cell per BAND_ANGLE of
## arc, with cell 0 centred on the payline at rest. Built by hand because a
## [CylinderMesh] cannot put the strip's V around its side, and the whole point
## of the drum is that the print and the geometry agree about where cells are.
##
## V runs 0..1 over the full turn. It used to run over a tenth of it, which
## wrapped six cells of ten around the drum at half again their size — so at
## rest the window showed cells cut through the middle and the top of the
## next symbol peering in over the payline, until the first spin covered the
## drum with plates. That was the "overlapping icons" of the first playtest.
func _drum_tube(radius: float, width: float, segments: int) -> ArrayMesh:
	return _arc_tube(radius, width, -0.5 * BAND_ANGLE, TAU - 0.5 * BAND_ANGLE,
			segments, 1.0 / TAU)


## One cell of the same surface, centred on the front, V spanning 0..1 so a
## material's uv offset can address any cell of the strip.
func _plate_arc(radius: float, width: float) -> ArrayMesh:
	return _arc_tube(radius, width, -0.4975 * BAND_ANGLE, 0.4975 * BAND_ANGLE,
			8, 1.0 / BAND_ANGLE)


## The shared builder. Parameter t runs round the drum — t = 0 is the payline,
## the front of the machine — and V is t scaled by [param v_per_radian], offset
## so the arc's own start sits at V = 0 for a plate and cell 0 centres the
## front for a drum.
func _arc_tube(radius: float, width: float, t0: float, t1: float,
		segments: int, v_per_radian: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: int in segments + 1:
		var t: float = lerpf(t0, t1, float(s) / float(segments))
		var v: float = (t - t0) * v_per_radian
		# A point at parameter t, on a drum that rolls toward the player as its
		# rotation about X grows: below the payline is positive t.
		var y: float = -sin(t) * radius
		var z: float = cos(t) * radius
		surface.set_normal(Vector3(0.0, -sin(t), cos(t)))
		surface.set_uv(Vector2(0.0, v))
		surface.add_vertex(Vector3(-width * 0.5, y, z))
		surface.set_normal(Vector3(0.0, -sin(t), cos(t)))
		surface.set_uv(Vector2(1.0, v))
		surface.add_vertex(Vector3(width * 0.5, y, z))
	for s: int in segments:
		var a: int = s * 2
		surface.add_index(a)
		surface.add_index(a + 1)
		surface.add_index(a + 2)
		surface.add_index(a + 2)
		surface.add_index(a + 1)
		surface.add_index(a + 3)
	return surface.commit()


## The material every strip surface wears: plain paper until the bake lands,
## anisotropic because a drum is all grazing angles, and a touch of gloss so
## the print catches the key light the way coated paper does.
func _strip_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.93, 0.91, 0.87)
	# Matte paper. Coated paper's gloss read as glare from the lamp a foot
	# in front of it, and the print is the one thing here that must be read.
	# The metal comes from the bake's metallic map once it lands; until then
	# the strip is paper through and through.
	material.roughness = 0.72
	material.metallic = 0.0
	material.metallic_specular = 0.25
	material.texture_filter = \
			BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


## One physical button per reel, on a console shelf under the window: the
## fruit-machine row, on the machine rather than on an overlay. The buttons
## render ControlDeck's own per-reel model — SlotView3D relights them on every
## deck refresh and clicks re-enter through the same intent path the deck and
## the number keys use, so the chassis and the overlay can never disagree.
func _button_row(reel_count: int) -> void:
	var row: Node3D = _group(&"Buttons")
	var count: int = maxi(reel_count, 1)
	var centre: float = float(count - 1) * 0.5
	# The shelf, tilted toward the player the way a console apron sits.
	var shelf: Node3D = Node3D.new()
	shelf.position = Vector3(0.0, CHASSIS_Y - 0.5, CHASSIS.z + 0.1)
	shelf.rotation.x = 0.42
	row.add_child(shelf)
	var width: float = float(count - 1) * REEL_SPACING + 0.4
	Prims.box(shelf, Vector3(width, 0.05, 0.24), Vector3.ZERO,
			Materials.weathered("painted_metal", Materials.PAINT, 0.9, 1.0,
					0.3, 0.3, Materials.painted(Materials.PAINT, 35)))
	for sx: float in [-1.0, 1.0]:
		Prims.box(shelf, Vector3(0.05, 0.09, 0.26),
				Vector3(sx * (width * 0.5 - 0.02), -0.04, 0.0),
				Materials.rusted(36))
	for i: int in count:
		var x: float = (float(i) - centre) * REEL_SPACING
		var button: Node3D = Node3D.new()
		button.name = "ReelButton%d" % i
		button.position = Vector3(x, 0.03, -0.02)
		shelf.add_child(button)
		# Bezel ring, then the lamp cap the state lights.
		Prims.cylinder(button, 0.08, 0.028, Vector3.ZERO, Vector3.ZERO,
				Materials.brass(37), 18)
		var cap: MeshInstance3D = Prims.cylinder(button, 0.064, 0.036,
				Vector3(0.0, 0.014, 0.0), Vector3.ZERO,
				_button_lamp_material(), 18)
		cap.name = "Lamp"
		# The caption sits on the apron's front face, upright to the player —
		# printed on the cap it is edge-on to a square camera and unreadable.
		var caption: Label3D = Label3D.new()
		caption.name = "Caption"
		caption.text = ""
		# 44pt with a 4px outline is about 58mm of glyph. At 52 with an 8px
		# outline it came to 81mm on a 58mm placard and the word ran off the
		# card top and bottom onto the painted shelf behind it.
		caption.font_size = 44
		Type.face(caption, &"display")
		caption.pixel_size = 0.0012
		caption.modulate = Color(0.9, 0.86, 0.78)
		caption.outline_size = 4
		caption.outline_modulate = Color(0.05, 0.045, 0.04, 0.9)
		caption.shaded = false
		caption.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		# A placard hung off the apron's lip, backed dark so the word reads
		# whatever the key light is doing to the shelf.
		Prims.box(button, Vector3(0.19, 0.078, 0.012),
				Vector3(0.0, -0.036, 0.142), Materials.cavity())
		# 8mm off the card, not 2: at grazing angles on a shelf tilted 0.42
		# rad the transparent pass was depth-fighting the placard it sits on.
		caption.position = Vector3(0.0, -0.036, 0.156)
		caption.rotation.x = 0.0
		button.add_child(caption)
		# The pick body. SlotView3D wires input_event and reads the action
		# the deck's model last assigned from metadata on the button.
		var pick: Area3D = Area3D.new()
		pick.name = "Pick"
		var shape: CollisionShape3D = CollisionShape3D.new()
		var cylinder: CylinderShape3D = CylinderShape3D.new()
		cylinder.radius = 0.075
		cylinder.height = 0.09
		shape.shape = cylinder
		pick.add_child(shape)
		button.add_child(pick)


## The counters: four banks of Nixie tubes across the chassis face above the
## window — cash, the ante, the spins, the chips — so the run's numbers are
## read off the machine and not off a corner of the screen. The first
## playtest asked for the status bars to leave the overlay and live in the
## world; this is where they live. Returns the digit labels per bank.
func _counter_bank() -> Dictionary:
	var housing: Node3D = _group(&"Counters")
	var y: float = CHASSIS_Y + CHASSIS.y - 0.09
	var z: float = CHASSIS.z + 0.02
	# A brass rail the tubes are socketed into, the width of the chassis.
	_box(housing, Vector3(CHASSIS.x * 1.92, 0.15, 0.05), Vector3(0.0, y, z),
			Materials.painted(Color(0.11, 0.1, 0.09), 43))
	_box(housing, Vector3(CHASSIS.x * 1.92, 0.012, 0.06), Vector3(0.0, y + 0.075, z),
			Materials.brass(44))
	# Five tubes for the money: a run past 99,999 reads in thousands with a
	# K on the last tube, which a Nixie can show and a person can read.
	var banks: Array = [
		["cash", "CASH", 5, -0.66], ["ante", "ANTE", 5, -0.1],
		["spins", "SPINS", 2, 0.33], ["chips", "CHIPS", 3, 0.66],
	]
	var out: Dictionary = {}
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.85, 0.72, 0.55, 0.1)
	glass.roughness = 0.06
	glass.metallic = 0.3
	for bank: Array in banks:
		var count: int = int(bank[2])
		var centre: float = float(bank[3])
		var spacing: float = 0.1
		var digits: Array[Label3D] = []
		for i: int in count:
			var x: float = centre + (float(i) - float(count - 1) * 0.5) * spacing
			var collar: MeshInstance3D = Prims.cylinder(housing, 0.042, 0.02,
					Vector3(x, y - 0.065, z + 0.03), Vector3.ZERO, Materials.brass(45), 12)
			collar.name = "Collar"
			Prims.cylinder(housing, 0.044, 0.125, Vector3(x, y + 0.005, z + 0.03),
					Vector3.ZERO, glass, 12)
			var halo: MeshInstance3D = Prims.quad(housing, Vector2(0.16, 0.16),
					Vector3(x, y + 0.005, z + 0.062), _nixie_halo())
			halo.name = "Halo_%s_%d" % [bank[0], i]
			halo.visible = false
			var digit: Label3D = Label3D.new()
			digit.name = "Digit_%s_%d" % [bank[0], i]
			Type.face(digit, &"mono")
			digit.text = ""
			digit.font_size = 100
			digit.pixel_size = 0.0013
			digit.modulate = Color(1.0, 0.6, 0.18) * 2.6
			digit.outline_size = 0
			digit.shaded = false
			digit.position = Vector3(x, y + 0.005, z + 0.068)
			housing.add_child(digit)
			digits.append(digit)
		# The caption, engraved under the bank.
		var caption: Label3D = Label3D.new()
		caption.text = Copy.of(String(bank[1]))
		Type.face(caption, &"display")
		caption.font_size = 48
		caption.pixel_size = 0.0013
		caption.modulate = Color(0.95, 0.82, 0.52)
		caption.outline_size = 0
		caption.shaded = false
		caption.position = Vector3(centre, y - 0.104, z + 0.034)
		housing.add_child(caption)
		out[String(bank[0])] = digits
		_inspect_zone(housing, StringName("counter:%s" % bank[0]),
				Vector3(float(count) * spacing + 0.06, 0.2, 0.1),
				Vector3(centre, y, z + 0.06))
	# What the bank gives the chassis: a warm wash under the tubes.
	var wash: OmniLight3D = OmniLight3D.new()
	wash.light_color = Color(1.0, 0.5, 0.15)
	wash.light_energy = 0.35
	wash.omni_range = 0.9
	wash.omni_attenuation = 1.6
	wash.shadow_enabled = false
	wash.position = Vector3(0.0, y, z + 0.14)
	housing.add_child(wash)
	return out


## The console: a rail of keys under the reel buttons for everything else the
## machine offers — take it, double, collect, settle, the stake, the vault,
## the works, a word — each a lit key with its caption printed on it. Rendered
## from the deck's own model, like the reel buttons, so the chassis and the
## overlay can never disagree. Returns the keys, in slot order.
func _console() -> Array[Node3D]:
	var rail: Node3D = _group(&"Console")
	var shelf: Node3D = Node3D.new()
	# Low enough to clear the button row's placards above it: the two rows
	# of captions were touching, and a word cut in half is not a control.
	shelf.position = Vector3(0.0, CHASSIS_Y - 0.74, CHASSIS.z + 0.24)
	shelf.rotation.x = 0.52
	rail.add_child(shelf)
	var width: float = 1.94
	Prims.box(shelf, Vector3(width, 0.04, 0.2), Vector3.ZERO,
			Materials.weathered("painted_metal", Materials.PAINT, 0.9, 1.0,
					0.3, 0.3, Materials.painted(Materials.PAINT, 46)))
	for sx: float in [-1.0, 1.0]:
		Prims.box(shelf, Vector3(0.05, 0.08, 0.22),
				Vector3(sx * (width * 0.5 - 0.02), -0.03, 0.0), Materials.rusted(47))
	# A lamp over the rail: the apron and the console sat in the chassis's
	# shadow, and a control that cannot be read is not a control.
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "ConsoleLamp"
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 0.9
	lamp.light_specular = 0.2
	lamp.omni_range = 1.4
	lamp.omni_attenuation = 1.5
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 0.34, 0.24)
	shelf.add_child(lamp)
	var keys: Array[Node3D] = []
	for i: int in CONSOLE_KEYS:
		var x: float = (float(i) - float(CONSOLE_KEYS - 1) * 0.5) * 0.31
		var key: Node3D = Node3D.new()
		key.name = "ActionKey%d" % i
		key.position = Vector3(x, 0.03, 0.0)
		shelf.add_child(key)
		Prims.box(key, Vector3(0.28, 0.02, 0.15), Vector3(0.0, -0.01, 0.0),
				Materials.machined(Color(0.24, 0.23, 0.22), 48))
		var cap: MeshInstance3D = Prims.box(key, Vector3(0.26, 0.026, 0.13),
				Vector3(0.0, 0.012, 0.0), _button_lamp_material())
		cap.name = "Lamp"
		var caption: Label3D = Label3D.new()
		caption.name = "Caption"
		caption.text = ""
		caption.font_size = 46
		Type.face(caption, &"display")
		caption.pixel_size = 0.0012
		caption.modulate = Color(0.12, 0.1, 0.08)
		caption.outline_size = 0
		caption.shaded = false
		caption.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		caption.rotation.x = -PI * 0.5
		caption.position = Vector3(0.0, 0.027, 0.0)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_child(caption)
		var pick: Area3D = Area3D.new()
		pick.name = "Pick"
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.28, 0.08, 0.16)
		shape.shape = box
		pick.add_child(shape)
		key.add_child(pick)
		key.visible = false
		keys.append(key)
	return keys


## A lamp cap starts dark; SlotView3D drives its albedo and emission from the
## deck's model. Unique per button, since every button is its own lamp.
func _button_lamp_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.14, 0.12)
	material.roughness = 0.25
	material.metallic = 0.0
	material.emission_enabled = false
	material.emission = Color(1.0, 0.72, 0.3)
	return material


## The two lamps a fruit machine puts by every drum: HOLD under it, and the
## nudge chevron over it.
##
## On the machine rather than only on the overlay, because these are the two
## moves the player makes without looking away from the reels — and a control
## whose state lives only in a panel at the bottom of the screen is a control
## the player has to keep translating back to the drum it belongs to.
func _reel_lamps(reel: Node3D) -> void:
	# The HoldLamp fixture that used to hang here is gone: the console's
	# physical button under each reel IS the hold lamp now, and the old glass
	# sat exactly on the frontal camera's sight-line to it — three dark discs
	# eclipsing the one control row the machine grew them for.
	var chevron: MeshInstance3D = MeshInstance3D.new()
	chevron.name = "NudgeArrow"
	var head: CylinderMesh = CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.07
	head.height = 0.1
	head.radial_segments = 4
	chevron.mesh = head
	# Point it down at the drum: the nudge brings the band above onto the line,
	# so the arrow says which way the symbol is about to travel.
	chevron.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), PI)
	chevron.position = Vector3(0.0, 0.5, REEL_RADIUS - 0.04)
	chevron.material_override = Materials.lamp_glass(Color(1.0, 0.72, 0.28), 0.0)
	chevron.visible = false
	reel.add_child(chevron)


## The chrome window the drums are read through, plus the payline across it.
func _bezel(reel_count: int = 3) -> void:
	var bezel: Node3D = _group(&"Bezel")
	var y: float = CHASSIS_Y + 0.05
	var z: float = CHASSIS.z + 0.02
	# Brass, not chrome. Chrome is the one finish in the set with no age on
	# it, and it read as a modern appliance bolted to a Victorian press.
	var steel: StandardMaterial3D = Materials.brass(53)
	# The chrome reaches round however many drums there are. A machine that grew
	# a fourth reel behind a three-reel window would read as a bug, and the
	# overhang is the point: the works are meant to look bolted on.
	var half: float = bank_half_width(reel_count) + 0.32
	_box(bezel, Vector3(half * 2.0, 0.08, 0.09), Vector3(0.0, y + 0.37, z), steel)
	_box(bezel, Vector3(half * 2.0, 0.08, 0.09), Vector3(0.0, y - 0.37, z), steel)
	for sx: float in [-1.0, 1.0]:
		_box(bezel, Vector3(0.08, 0.82, 0.09), Vector3(sx * (half - 0.04), y, z), steel)
	_payline_marks(bezel, half, y, z)
	# Anything past the chassis gets its own housing, so an added drum is
	# standing in a box someone welded on rather than hanging in the air.
	if half <= CHASSIS.x + 0.02:
		return
	var housing: Material = Materials.painted(Materials.PAINT, 31)
	for sx: float in [-1.0, 1.0]:
		var width: float = half - CHASSIS.x + 0.06
		_box(bezel, Vector3(width, 0.9, CHASSIS.z * 1.6),
				Vector3(sx * (CHASSIS.x + width * 0.5 - 0.03), y, REEL_Z * 0.5), housing)
	# Divider bars between the three windows.
	for sx: float in [-1.0, 1.0]:
		_box(bezel, Vector3(0.035, 0.72, 0.07),
				Vector3(sx * REEL_SPACING * 0.5, y, z), steel)
	# The payline, across the middle row only. It is the one thing on the machine
	# that must be found instantly, and now that three rows are visible it is
	# also the only thing saying which of them counts. Its own material, so a
	# win can flash it without flashing every red lamp on the machine.
	var payline: MeshInstance3D = _box(bezel, Vector3(1.4, 0.014, 0.014),
			Vector3(0.0, y, z + 0.04),
			Materials.glowing(Materials.JACKPOT, 1.8).duplicate())
	payline.name = "Payline"
	for sx: float in [-1.0, 1.0]:
		# Arrowheads at each end of the payline, pointing in at the row it marks.
		var head: MeshInstance3D = _box(bezel, Vector3(0.05, 0.05, 0.014),
				Vector3(sx * 0.7, y, z + 0.04),
				Materials.glowing(Materials.JACKPOT, 1.8))
		head.rotation.z = PI * 0.25


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
	# The dial is a pressure gauge, and it is plumbed in: this face reads the
	# run's HEAT — the House's temperature — off the same event every panel
	# gets. A dial that means nothing is decoration, and decoration that
	# cannot explain itself gets cut or given a job.
	_cylinder(gearbox, 0.27, 0.07, Vector3(0.0, 0.0, 0.26),
			Vector3(PI * 0.5, 0.0, 0.0), Materials.machined(Color(0.5, 0.49, 0.47), 59))
	var dial: Node3D = Node3D.new()
	dial.name = "Dial"
	gearbox.add_child(dial)
	# Aged ivory face, the one pale disc on the machine's flank.
	_cylinder(dial, 0.21, 0.045, Vector3(0.0, 0.0, 0.31),
			Vector3(PI * 0.5, 0.0, 0.0), Materials.enamel(Color(0.62, 0.585, 0.52), 68))
	for i: int in 12:
		var angle: float = TAU * float(i) / 12.0
		_box(dial, Vector3(0.012, 0.012, 0.05),
				Vector3(cos(angle) * 0.16, sin(angle) * 0.16, 0.325),
				Materials.machined(Color(0.2, 0.19, 0.18), 59))
	# The red zone, where GAUGE_SWEEP's hot end parks the needle. Painted,
	# not lit: drawn in the same glowing red as the needle itself, the four
	# marks merged at a distance into a second pink needle sitting at the
	# far end of the sweep. A zone is printed on the face; a needle glows.
	for i: int in 4:
		var angle: float = -GAUGE_SWEEP + float(i) * 0.11 + PI * 0.5
		var mark: MeshInstance3D = _box(dial, Vector3(0.024, 0.038, 0.046),
				Vector3(cos(angle) * 0.155, sin(angle) * 0.155, 0.327),
				Materials.enamel(Materials.JACKPOT, 60))
		mark.rotation.z = angle - PI * 0.5
	var heat_label: Label3D = Label3D.new()
	heat_label.text = Copy.of("HEAT")
	Type.face(heat_label, &"display")
	# Bebas is narrow: a caption set in it needs more size than the same
	# caption set in the engine's default did.
	heat_label.font_size = 48
	heat_label.pixel_size = 0.0011
	heat_label.modulate = Color(0.2, 0.19, 0.18)
	heat_label.shaded = false
	# Low on the face and behind the needle's plane: at -0.1 the needle swept
	# straight over the word for a third of its travel.
	heat_label.position = Vector3(0.0, -0.185, 0.332)
	dial.add_child(heat_label)
	_inspect_zone(dial, &"heat", Vector3(0.42, 0.42, 0.08), Vector3(0.0, 0.0, 0.33))
	var heat_needle: Node3D = Node3D.new()
	heat_needle.name = "HeatNeedle"
	dial.add_child(heat_needle)
	heat_needle.position = Vector3(0.0, 0.0, 0.34)
	# Wide enough to survive a thumbnail: at 320 pixels the whole dial is
	# forty across, and a needle two pixels wide is not a reading.
	Prims.box(heat_needle, Vector3(0.022, 0.17, 0.006),
			Vector3(0.0, 0.085, 0.0), Materials.glowing(Materials.JACKPOT, 1.2))
	_cylinder(heat_needle, 0.024, 0.02, Vector3.ZERO,
			Vector3(PI * 0.5, 0.0, 0.0), brass)
	heat_needle.rotation.z = GAUGE_SWEEP
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
	monitor.position = Vector3(-0.88, CHASSIS_Y + 1.02, 0.1)
	monitor.rotation = Vector3(0.0, 0.34, 0.0)
	# The arm: a post off the chassis shoulder and an elbow up to the housing.
	_segment(_root, Vector3(-0.74, CHASSIS_Y + 0.56, 0.1),
			Vector3(-0.88, CHASSIS_Y + 0.86, 0.1), 0.055,
			Materials.machined(Color(0.42, 0.41, 0.4), 60))
	# A bolted foot where the arm meets the chassis shoulder.
	_box(_root, Vector3(0.22, 0.08, 0.22), Vector3(-0.74, CHASSIS_Y + 0.6, 0.1),
			Materials.rusted(31))
	_cylinder(monitor, 0.07, 0.12, Vector3(0.0, -0.3, 0.0), Vector3.ZERO,
			Materials.machined(Materials.STEEL, 61))
	# Housing: a deep-backed CRT shell, not a flat panel.
	_box(monitor, Vector3(0.66, 0.54, 0.14), Vector3(0.0, 0.0, 0.16),
			Materials.painted(Materials.PAINT_LIGHT, 15))
	_box(monitor, Vector3(0.5, 0.42, 0.28), Vector3(0.0, 0.0, -0.02),
			Materials.painted(Materials.PAINT, 16))
	# The step between shell and glass, screwed at its corners, with a brass
	# maker's plate under the tube: the difference between a monitor and a
	# picture frame is that a monitor is assembled.
	_box(monitor, Vector3(0.6, 0.48, 0.04), Vector3(0.0, 0.0, 0.205),
			Materials.machined(Color(0.22, 0.21, 0.2), 69))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var screw: MeshInstance3D = _cylinder(monitor, 0.013, 0.02,
					Vector3(sx * 0.28, sy * 0.22, 0.235), Vector3.ZERO,
					Materials.brass(70))
			screw.rotation.x = PI * 0.5
	_box(monitor, Vector3(0.2, 0.045, 0.012), Vector3(0.0, -0.312, 0.24),
			Materials.brass(71))
	Prims.sphere(_root, 0.06, Vector3(-0.88, CHASSIS_Y + 0.86, 0.1),
			Materials.machined(Color(0.42, 0.41, 0.4), 60))
	# Cooling slots across the top of the shell, and two knobs under the glass:
	# an appliance has controls and gets hot, and a box with neither is a prop.
	for i: int in 4:
		_box(monitor, Vector3(0.4, 0.012, 0.05),
				Vector3(0.0, 0.278, 0.14 - float(i) * 0.06),
				Materials.machined(Color(0.16, 0.155, 0.15), 66))
	for i: int in 2:
		var knob: MeshInstance3D = _cylinder(monitor, 0.024, 0.035,
				Vector3(0.16 + float(i) * 0.09, -0.315, 0.22), Vector3.ZERO,
				Materials.brass(67))
		knob.rotation.x = PI * 0.5
	# The cable drops out of the shell and sags into the chassis top, because a
	# monitor that touches nothing is scenery, not equipment.
	var shoulder: Vector3 = Vector3(-1.0, CHASSIS_Y + 0.86, 0.04)
	var sag: Vector3 = Vector3(-1.14, CHASSIS_Y + 0.44, -0.04)
	_segment(_root, shoulder, sag, 0.018, Materials.rubber())
	_segment(_root, sag, Vector3(-0.94, CHASSIS_Y + 0.58, -0.1), 0.018,
			Materials.rubber())
	# The terminal itself: a Label rendered at terminal resolution in its own
	# viewport. The ledger stays plain text the room writes to; everything CRT
	# about the picture — dome, scanlines, roll, flicker — is the shader's job.
	var terminal: SubViewport = SubViewport.new()
	terminal.name = "Terminal"
	terminal.size = Vector2i(320, 240)
	terminal.disable_3d = true
	terminal.transparent_bg = false
	terminal.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.012, 0.03, 0.015)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	terminal.add_child(ground)
	var readout: Label = Label.new()
	readout.name = "Readout"
	readout.text = Copy.of("LEDGER OF ACCOUNT") + "\n--------------------\nDEBT 0"
	# Eight lines fit at this size: the heading, the floor, the principal,
	# two of memo and two of the run's log under a rule.
	readout.add_theme_font_size_override(&"font_size", 18)
	# The ledger is printed by the machine: the tube is set in the mono.
	readout.add_theme_font_override(&"font", Type.mono())
	readout.add_theme_color_override(&"font_color", Color(0.9, 1.0, 0.92))
	# Inset well clear of the edges: the barrel distortion samples past the
	# frame at the edge centres, and text placed there is text cut in half.
	readout.position = Vector2(30, 24)
	readout.size = Vector2(260, 194)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terminal.add_child(readout)
	# The glass: a subdivided quad the shader domes outward, self-lit from the
	# viewport's picture.
	var face: QuadMesh = QuadMesh.new()
	face.size = Vector2(0.56, 0.44)
	face.subdivide_width = 24
	face.subdivide_depth = 18
	var screen: MeshInstance3D = MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = face
	screen.position = Vector3(0.0, 0.0, 0.235)
	var glass: ShaderMaterial = ShaderMaterial.new()
	glass.shader = load("res://assets/shaders/crt.gdshader") as Shader
	glass.set_shader_parameter(&"phosphor", Materials.PHOSPHOR)
	screen.material_override = glass
	monitor.add_child(screen)
	screen.add_child(terminal)
	# The texture is bound only now: a ViewportTexture taken before its
	# viewport is in the tree never resolves, and the screen stays black.
	glass.set_shader_parameter(&"screen_tex", terminal.get_texture())
	# What the tube gives the room: a soft green spill on the frame below it.
	var spill: OmniLight3D = OmniLight3D.new()
	spill.light_color = Materials.PHOSPHOR
	spill.light_energy = 0.5
	spill.omni_range = 0.85
	spill.omni_attenuation = 1.7
	spill.shadow_enabled = false
	spill.position = Vector3(0.0, -0.08, 0.42)
	monitor.add_child(spill)
	return screen


## The odds readout above the chassis: a bank of four Nixie tubes on a riveted
## base — warm digits in glass, which is what this display always wanted to be.
func _odds_display() -> Node3D:
	var housing: Node3D = _group(&"Odds")
	housing.position = Vector3(0.62, CHASSIS_Y + 0.92, 0.2)
	# The base the tubes are socketed into, and its stalk down to the chassis.
	_box(housing, Vector3(0.74, 0.1, 0.2), Vector3(0.0, -0.14, 0.0),
			Materials.rusted(64))
	for sx: float in [-1.0, 1.0]:
		var stud: MeshInstance3D = _cylinder(housing, 0.014, 0.02,
				Vector3(sx * 0.33, -0.14, 0.104), Vector3.ZERO,
				Materials.brass(65))
		stud.rotation.x = PI * 0.5
	_segment(housing, Vector3(0.0, -0.19, 0.0), Vector3(0.0, -0.4, -0.1), 0.03,
			Materials.machined(Materials.STEEL, 62))
	# Engraved under the bank, the way every counter on the machine is. This
	# was the one readout with no plate: four lit digits reading "1x" with
	# nothing on the brass to say what they counted.
	var caption: Label3D = Label3D.new()
	caption.text = Copy.of("ODDS")
	Type.face(caption, &"display")
	caption.font_size = 48
	caption.pixel_size = 0.0013
	caption.modulate = Color(0.95, 0.82, 0.52)
	caption.outline_size = 0
	caption.shaded = false
	caption.position = Vector3(0.0, -0.202, 0.108)
	housing.add_child(caption)
	# A dark backboard, so a dead tube reads as glass with nothing lit in it.
	_box(housing, Vector3(0.68, 0.24, 0.02), Vector3(0.0, 0.02, -0.05),
			Materials.cavity())
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.85, 0.72, 0.55, 0.09)
	glass.roughness = 0.06
	glass.metallic = 0.3
	for i: int in 4:
		var x: float = -0.24 + float(i) * 0.16
		# Collar, envelope, and the digit floating in it. The halo quad is the
		# glow a Nixie has in life — and the whole of it on a renderer with no
		# bloom, which the web build is.
		var collar: MeshInstance3D = _cylinder(housing, 0.052, 0.035,
				Vector3(x, -0.075, 0.0), Vector3.ZERO, Materials.brass(68))
		collar.rotation.z = 0.0
		Prims.cylinder(housing, 0.055, 0.21, Vector3(x, 0.03, 0.0),
				Vector3.ZERO, glass, 14)
		var halo: MeshInstance3D = Prims.quad(housing, Vector2(0.17, 0.17),
				Vector3(x, 0.02, 0.035), _nixie_halo())
		halo.name = "Halo%d" % i
		halo.visible = false
		var digit: Label3D = Label3D.new()
		digit.name = "Digit%d" % i
		Type.face(digit, &"mono")
		digit.text = ""
		digit.font_size = 100
		digit.pixel_size = 0.0013
		digit.modulate = Color(1.0, 0.55, 0.14) * 1.5
		digit.outline_size = 0
		digit.shaded = false
		digit.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		digit.position = Vector3(x, 0.02, 0.045)
		digit.visible = false
		housing.add_child(digit)
	_inspect_zone(housing, &"odds", Vector3(0.74, 0.26, 0.1), Vector3(0.0, 0.02, 0.06))
	# What the bank gives the room: the warm orange wash under a lit Nixie.
	var wash: OmniLight3D = OmniLight3D.new()
	wash.name = "Wash"
	wash.light_color = Color(1.0, 0.5, 0.15)
	wash.light_energy = 0.45
	wash.omni_range = 0.6
	wash.omni_attenuation = 1.6
	wash.shadow_enabled = false
	wash.position = Vector3(0.0, 0.0, 0.12)
	housing.add_child(wash)
	return housing


## The additive orange bloom behind a lit Nixie digit. Shared: one material
## serves every tube.
func _nixie_halo() -> StandardMaterial3D:
	if _nixie_halo_material == null:
		_nixie_halo_material = StandardMaterial3D.new()
		_nixie_halo_material.albedo_texture = SymbolArt.halo()
		_nixie_halo_material.albedo_color = Color(1.0, 0.42, 0.1, 0.75)
		_nixie_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_nixie_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_nixie_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_nixie_halo_material.disable_receive_shadows = true
	return _nixie_halo_material


## The coil that powers the machine, and the cable the charge rides in on.
## This is the volatile half of the north star made visible: throw the lever
## and a blue arc leaves the discharge ball, runs the sagging cable, and lands
## on the drivetrain rail — engine, charge, gears, drums, in that order.
## Returns the arc's material and light for [SlotView3D] to fire.
func _coil() -> Dictionary:
	var top: float = CHASSIS_Y + CHASSIS.y
	var coil: Node3D = _group(&"Coil")
	# Top right, in clear air: a coil hidden behind the monitor is a coil
	# nobody knows the machine has.
	coil.position = Vector3(0.88, top, -0.16)
	# A mast, because everything at chassis-top height is already spoken for:
	# the ball has to discharge in open air above the nixies, where the whole
	# room can see what kind of machine this is.
	Prims.cylinder(coil, 0.11, 0.08, Vector3(0.0, 0.04, 0.0), Vector3.ZERO,
			Materials.rusted(34), 14)
	Prims.cylinder(coil, 0.035, 0.3, Vector3(0.0, 0.22, 0.0), Vector3.ZERO,
			Materials.machined(Materials.STEEL, 76), 10)
	# The winding stack: alternating brass and dark bands, narrowing upward.
	for i: int in 6:
		Prims.cylinder(coil, 0.088 - float(i) * 0.007, 0.055,
				Vector3(0.0, 0.4 + float(i) * 0.055, 0.0), Vector3.ZERO,
				Materials.brass(74) if i % 2 == 0
				else Materials.rubber(Color(0.14, 0.08, 0.06), 75), 14)
	Prims.cylinder(coil, 0.018, 0.09, Vector3(0.0, 0.76, 0.0), Vector3.ZERO,
			Materials.machined(Materials.STEEL, 76), 10)
	Prims.sphere(coil, 0.07, Vector3(0.0, 0.85, 0.0), Materials.chrome())
	# The cable: a rubber run sagging from the ball to a terminal on the
	# drivetrain rail, with the arc ribbon riding just proud of it.
	var path: Array = [
		Vector3(0.88, top + 0.85, -0.16),
		Vector3(0.7, top + 0.5, 0.06),
		Vector3(0.48, top + 0.2, 0.15),
		Vector3(0.28, top + 0.08, 0.17),
	]
	for i: int in path.size() - 1:
		_segment(_root, path[i], path[i + 1], 0.016,
				Materials.rubber(Color(0.1, 0.09, 0.085), 77))
	_box(_root, Vector3(0.07, 0.06, 0.06), Vector3(0.27, top + 0.06, 0.18),
			Materials.brass(78))
	var arc_material: ShaderMaterial = ShaderMaterial.new()
	arc_material.shader = load("res://assets/shaders/arc.gdshader") as Shader
	var lifted: Array = []
	for point: Vector3 in path:
		lifted.append(point + Vector3(0.0, 0.012, 0.0))
	var arc: MeshInstance3D = _ribbon(_root, lifted, 0.05, arc_material, -1.0)
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# What the arc gives the room while it rides.
	var flash: OmniLight3D = OmniLight3D.new()
	flash.name = "ArcLight"
	flash.light_color = Color(0.45, 0.68, 1.0)
	# A resting ember: the corner the coil stands in is outside every other
	# light's throw, and a coil the room cannot see is a coil the machine
	# does not have. The blue kiss also says "charged" between spins.
	flash.light_energy = 0.22
	flash.omni_range = 1.3
	flash.omni_attenuation = 1.5
	flash.shadow_enabled = false
	flash.position = Vector3(0.64, top + 0.4, 0.06)
	_root.add_child(flash)
	return {"material": arc_material, "light": flash}


## The arm on the right flank. Returned so the view can throw it on a spin.
func _lever() -> Node3D:
	var mount: Node3D = _group(&"Lever")
	mount.position = Vector3(CHASSIS.x + 0.12, CHASSIS_Y + 0.1, 0.05)
	# The pivot housing stays put; only the arm below it swings.
	# Sized to be hauled, not clicked: this is the machine's one big verb and
	# the hand it is pulled with should read from across the room.
	_box(mount, Vector3(0.3, 0.34, 0.34), Vector3(0.0, -0.06, 0.0),
			Materials.machined(Materials.STEEL, 63))
	_cylinder(mount, 0.1, 0.38, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5),
			Materials.brass(39))
	var arm: Node3D = Node3D.new()
	arm.name = "Arm"
	mount.add_child(arm)
	# Resting back and up, the way a lever waits to be pulled toward you.
	arm.rotation = Vector3(-0.5, 0.0, 0.0)
	_segment(arm, Vector3(0.17, 0.0, 0.0), Vector3(0.17, 0.8, 0.0), 0.034,
			Materials.machined(Color(0.52, 0.51, 0.5), 64))
	_cylinder(arm, 0.042, 0.03, Vector3(0.17, 0.72, 0.0), Vector3.ZERO,
			Materials.brass(39))
	# The grip: wrapped in tape, band over band, the way a handle that has
	# been hauled for years is kept from splitting.
	_cylinder(arm, 0.075, 0.13, Vector3(0.17, 0.84, 0.0), Vector3.ZERO,
			Materials.timber())
	for band: int in 5:
		_cylinder(arm, 0.079, 0.012, Vector3(0.17, 0.79 + float(band) * 0.024, 0.0),
				Vector3.ZERO, Materials.rubber(Color(0.16, 0.13, 0.1), 81 + band))
	# Where the hand goes, the tape is polished: darker, smoother, catching
	# the light the matte bands do not. Wear concentrates where the machine
	# is touched, and this is the one place it is touched every spin.
	var polish: StandardMaterial3D = Materials.rubber(Color(0.1, 0.085, 0.07), 86)
	polish.roughness = 0.25
	_cylinder(arm, 0.08, 0.05, Vector3(0.17, 0.9, 0.0), Vector3.ZERO, polish)
	# Clickable along the whole arm: the lever is the machine's one big verb,
	# and the first thing a new player reaches for.
	var pick: Area3D = Area3D.new()
	pick.name = "Pick"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.09
	capsule.height = 0.95
	shape.shape = capsule
	shape.position = Vector3(0.17, 0.45, 0.0)
	pick.add_child(shape)
	arm.add_child(pick)
	return arm


## The receipt spool, and the paper it has already paid out. The tape running
## off the plinth onto the floor is the machine's history made physical.
## The surety column: the instrument that carries the player's own stake.
##
## The premise puts the player's life on the account, and a thing stated
## once at the door is forgotten by the second floor. So it is a fixture: a
## glass column on the machine's right flank, plumbed into
## [method RunState.surety], with a red level that rises as the House's hold
## on the player tightens and a lamp at the top for when it is nearly all
## held. It moves on every spin — up on a dead one, down on a paying one —
## which is what makes a loss something that happens to you rather than an
## absence. Returns the fluid and the lamp for [SlotView3D] to drive.
func _surety_column() -> Dictionary:
	var column: Node3D = _group(&"Surety")
	# Outboard of the gamble ladder, not on top of it. At +0.1 the column's
	# backplate and its bracket both intersected the ladder's plate, and the
	# glass ran through two of its rung lamps.
	column.position = Vector3(CHASSIS.x + 0.22, CHASSIS_Y - 0.16, CHASSIS.z + 0.02)
	var brass: StandardMaterial3D = Materials.brass(51)
	# The base and the cap, and a bracket tying the column to the flank.
	_box(column, Vector3(0.16, 0.05, 0.14), Vector3(0.0, 0.0, 0.0),
			Materials.machined(Color(0.4, 0.39, 0.37), 71))
	_cylinder(column, 0.062, 0.035, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, brass)
	_cylinder(column, 0.062, 0.035, Vector3(0.0, SURETY_HEIGHT + 0.06, 0.0),
			Vector3.ZERO, brass)
	_box(column, Vector3(0.1, 0.04, 0.06), Vector3(-0.1, SURETY_HEIGHT * 0.5, -0.06),
			Materials.rusted(72))
	# A pale backplate behind the glass, so the level reads against something
	# on the flank the key light never reaches.
	_box(column, Vector3(0.13, SURETY_HEIGHT + 0.04, 0.02),
			Vector3(0.0, 0.06 + SURETY_HEIGHT * 0.5, -0.05),
			Materials.enamel(Color(0.62, 0.585, 0.52), 74))
	# The glass, and the fluid inside it: a cylinder of unit height, scaled by
	# the level from a pivot at the bottom.
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.85, 0.72, 0.55, 0.12)
	glass.roughness = 0.05
	glass.metallic = 0.3
	Prims.cylinder(column, 0.05, SURETY_HEIGHT, Vector3(0.0, 0.06 + SURETY_HEIGHT * 0.5, 0.0),
			Vector3.ZERO, glass, 16)
	var pivot: Node3D = Node3D.new()
	pivot.name = "Fluid"
	pivot.position = Vector3(0.0, 0.06, 0.0)
	pivot.scale = Vector3(1.0, 0.02, 1.0)
	column.add_child(pivot)
	Prims.cylinder(pivot, 0.04, SURETY_HEIGHT, Vector3(0.0, SURETY_HEIGHT * 0.5, 0.0),
			Vector3.ZERO, Materials.glowing(Color(0.72, 0.1, 0.08), 1.05), 14)
	# Graduations: a scale on the glass, the way a sight glass is marked.
	for i: int in 6:
		_box(column, Vector3(0.03, 0.005, 0.005),
				Vector3(0.062, 0.06 + SURETY_HEIGHT * float(i) / 5.0, 0.02),
				Materials.machined(Color(0.8, 0.72, 0.5), 73))
	# The lamp at the top, lit when the House holds nearly all of it.
	var lamp: MeshInstance3D = Prims.sphere(column, 0.03,
			Vector3(0.0, SURETY_HEIGHT + 0.11, 0.0),
			Materials.glowing(Color(0.75, 0.12, 0.1), 0.0))
	lamp.name = "Lamp"
	lamp.material_override = (lamp.material_override as StandardMaterial3D).duplicate()
	var caption: Label3D = Label3D.new()
	caption.text = Copy.of("SURETY")
	Type.face(caption, &"display")
	caption.font_size = 42
	caption.pixel_size = 0.0012
	caption.modulate = Color(0.95, 0.82, 0.52)
	caption.outline_size = 0
	caption.shaded = false
	caption.position = Vector3(0.0, -0.04, 0.075)
	column.add_child(caption)
	_inspect_zone(column, &"surety", Vector3(0.16, SURETY_HEIGHT + 0.2, 0.16),
			Vector3(0.0, 0.06 + SURETY_HEIGHT * 0.5, 0.0))
	return {"fluid": pivot, "lamp": lamp}


func _spool() -> Node3D:
	# The receipt printer: a compact grey desk unit bolted to the plinth's
	# right shoulder, its tape feeding out of the slot on top, down over the
	# concrete and pooling on the floor. It replaced a paper spool on a pole
	# — the art handover's P2 note — because a spool is a prop and a printer
	# is a machine: the receipt the player reads is what this thing prints.
	var printer: Node3D = _group(&"Printer")
	printer.position = Vector3(1.24, PLINTH_TOP + 0.1, 0.34)
	var grey: StandardMaterial3D = Materials.painted(Color(0.36, 0.36, 0.34), 69)
	var dark: StandardMaterial3D = Materials.machined(Color(0.16, 0.16, 0.15), 65)
	_box(printer, Vector3(0.3, 0.16, 0.34), Vector3.ZERO, grey)
	# The lid, stepped, with the tear bar along its front edge.
	_box(printer, Vector3(0.26, 0.04, 0.24), Vector3(0.0, 0.1, -0.03), grey)
	_box(printer, Vector3(0.24, 0.006, 0.02), Vector3(0.0, 0.124, 0.1), dark)
	_box(printer, Vector3(0.22, 0.02, 0.012), Vector3(0.0, 0.1, 0.1), Materials.cavity())
	# A status lamp, a feed button, a cable out of the back into the flank.
	Prims.sphere(printer, 0.012, Vector3(-0.1, 0.06, 0.175), Materials.glowing(Materials.PHOSPHOR, 0.9))
	_cylinder(printer, 0.018, 0.01, Vector3(0.08, 0.06, 0.175), Vector3(PI * 0.5, 0.0, 0.0), dark)
	_segment(_root, Vector3(1.24, PLINTH_TOP + 0.12, 0.17), Vector3(CHASSIS.x + 0.02, PLINTH_TOP + 0.3, 0.1),
			0.01, Materials.rubber(Color(0.09, 0.085, 0.08), 98))
	# Bolted down: two hex heads through the base flange.
	for sx: float in [-1.0, 1.0]:
		Prims.cylinder(printer, 0.014, 0.012, Vector3(sx * 0.13, -0.075, 0.15),
				Vector3.ZERO, Materials.machined(Materials.STEEL, 66), 6)
	# Printed, not blank: a receipt printer that has printed nothing but
	# paper is scenery, and the print is rows of faded figures at exactly
	# the scale a passing glance expects.
	var printed: StandardMaterial3D = StandardMaterial3D.new()
	printed.albedo_texture = ProcTextures.receipt(70)
	printed.roughness = 0.85
	printed.metallic = 0.0
	printed.cull_mode = BaseMaterial3D.CULL_DISABLED
	# One continuous ribbon: out of the slot, over the lid's edge, down the
	# plinth's face, pooling on the floor.
	_ribbon(_root, [
		Vector3(1.24, PLINTH_TOP + 0.235, 0.44),
		Vector3(1.24, PLINTH_TOP + 0.2, 0.53),
		Vector3(1.25, PLINTH_TOP + 0.02, 0.6),
		Vector3(1.27, 0.2, 0.62),
		Vector3(1.24, 0.014, 0.72),
	], 0.19, printed)
	for loop_config: Array in [[0.1, 0.006, Vector3(1.2, 0.006, 0.8)],
			[0.075, 0.006, Vector3(1.3, 0.014, 0.76)]]:
		_cylinder(_root, float(loop_config[0]), float(loop_config[1]),
				loop_config[2] as Vector3, Vector3.ZERO, printed)
	return printer


## A continuous strip of paper along [param points], width held along Z the
## way a tape whose printer slot runs along Z keeps it. One mesh, because a
## run of separate panels reads as separate sheets — which is exactly the
## complaint that retired the old version.
func _ribbon(parent: Node3D, points: Array, width: float,
		material: Material, v_metres: float = 0.45) -> MeshInstance3D:
	var total: float = 0.0
	for i: int in points.size() - 1:
		total += ((points[i + 1] as Vector3) - (points[i] as Vector3)).length()
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector3 = Vector3(0.0, 0.0, width * 0.5)
	var length: float = 0.0
	for i: int in points.size():
		var here: Vector3 = points[i]
		if i > 0:
			length += (here - (points[i - 1] as Vector3)).length()
		var ahead: Vector3 = points[mini(i + 1, points.size() - 1)]
		var behind: Vector3 = points[maxi(i - 1, 0)]
		var tangent: Vector3 = (ahead - behind).normalized()
		var normal: Vector3 = tangent.cross(Vector3(0.0, 0.0, 1.0)).normalized()
		# V in metres per repeat for print, or normalised 0..1 when asked —
		# the arc shader reads the whole run as one unit.
		var v: float = length / total if v_metres <= 0.0 else length / v_metres
		surface.set_normal(normal)
		surface.set_uv(Vector2(0.0, v))
		surface.add_vertex(here - half)
		surface.set_normal(normal)
		surface.set_uv(Vector2(1.0, v))
		surface.add_vertex(here + half)
	for i: int in points.size() - 1:
		var a: int = i * 2
		surface.add_index(a)
		surface.add_index(a + 1)
		surface.add_index(a + 2)
		surface.add_index(a + 2)
		surface.add_index(a + 1)
		surface.add_index(a + 3)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Wear with a location and a cause: rust weeping down from fasteners, and
## stains pooled where things stand. Uniform noise gets you variation; it does
## not get you the record of something having happened at a particular bolt,
## which is what separates a worn machine from a dirty screenshot.
func _wear() -> void:
	var wear_root: Node3D = _group(&"Wear")
	var front: float = CHASSIS.z + 0.004
	var rivet_y: float = CHASSIS_Y + CHASSIS.y - 0.06
	# Under a deterministic handful of the top-edge rivets. Every rivet weeping
	# reads as a pattern; a machine rusts where its luck ran out.
	for i: Array in [[0, 0.34], [2, 0.22], [5, 0.4], [7, 0.27]]:
		var x: float = lerpf(-CHASSIS.x + 0.1, CHASSIS.x - 0.1, float(i[0]) / 7.0)
		_wear_card(wear_root, Vector2(0.09, float(i[1])),
				Vector3(x, rivet_y - 0.05 - float(i[1]) * 0.5, front),
				ProcTextures.weep(71 + int(i[0])))
	# Under the bezel's lower corner bolts, where the window frame drains.
	for sx: float in [-1.0, 1.0]:
		_wear_card(wear_root, Vector2(0.11, 0.3),
				Vector3(sx * 0.6, CHASSIS_Y - 0.24 - 0.15, front + 0.06),
				ProcTextures.weep(79, Color(0.3, 0.18, 0.1)))
	# Off the inspection hatch's lower edge.
	_wear_card(wear_root, Vector2(0.1, 0.24),
			Vector3(-0.5, CHASSIS_Y - 0.33 - 0.12, front + 0.012),
			ProcTextures.weep(81))
	# The straps bleed onto the plinth's concrete — iron staining stone is the
	# oldest wear there is, and it is what bolts the two materials together.
	for sx: float in [-1.0, 1.0]:
		_wear_card(wear_root, Vector2(0.16, 0.3),
				Vector3(sx * 0.86, PLINTH_TOP - 0.13, 0.579),
				ProcTextures.weep(83, Color(0.32, 0.17, 0.09)))
	# Pooled stains on the plinth cap: oil under the machine's working flank,
	# damp under the spool where the paper lands.
	var oil: MeshInstance3D = Prims.quad(wear_root, Vector2(0.72, 0.5),
			Vector3(0.35, PLINTH_TOP + 0.058, 0.42),
			_wear_material(ProcTextures.stain(85)))
	oil.rotation.x = -PI * 0.5
	var damp: MeshInstance3D = Prims.quad(wear_root, Vector2(0.42, 0.42),
			Vector3(1.28, PLINTH_TOP + 0.058, 0.42),
			_wear_material(ProcTextures.stain(86, Color(0.08, 0.06, 0.05))))
	damp.rotation.x = -PI * 0.5
	_decals(wear_root, front)
	_concentrated_wear(wear_root)


## Wear where the machine is worked, not everywhere: grease at the joints
## the gearbox drives, tarnish under the crown's rail brackets, and dust on
## the horizontals nobody wipes. The handover's note that rust tiled alike
## across every surface reads as wallpaper; this is the other half of the
## answer to it.
func _concentrated_wear(parent: Node3D) -> void:
	# Grease, weeping from the gearbox's collar down the flank.
	var grease: MeshInstance3D = Prims.quad(parent, Vector2(0.18, 0.3),
			Vector3(-CHASSIS.x - 0.002, CHASSIS_Y - 0.12, 0.3),
			_wear_material(ProcTextures.stain(108, Color(0.06, 0.05, 0.04))))
	grease.rotation.y = -PI * 0.5
	# Tarnish under each crown bracket, where the pipe sweats.
	var top: float = CHASSIS_Y + CHASSIS.y
	for i: int in 5:
		var x: float = lerpf(-CHASSIS.x + 0.2, CHASSIS.x - 0.2, float(i) / 4.0)
		_wear_card(parent, Vector2(0.1, 0.12), Vector3(x, top - 0.07, CHASSIS.z + 0.004),
				ProcTextures.weep(109 + i, Color(0.2, 0.16, 0.1)))
	# Dust on the chassis top and the plinth's cap, out of the lamp's reach.
	var dust: MeshInstance3D = Prims.quad(parent, Vector2(1.6, 0.6),
			Vector3(-0.1, top + 0.052, -0.05),
			_wear_material(ProcTextures.stain(115, Color(0.62, 0.58, 0.5))))
	dust.rotation.x = -PI * 0.5
	var sill: MeshInstance3D = Prims.quad(parent, Vector2(0.9, 0.36),
			Vector3(-0.7, PLINTH_TOP + 0.057, 0.4),
			_wear_material(ProcTextures.stain(116, Color(0.5, 0.47, 0.42))))
	sill.rotation.x = -PI * 0.5


## Decals: the art handover's last note on materials. Detail density high
## around the face and near zero elsewhere — a serial plate, an inspection
## sticker the House has voided, a scorch where the coil has arced onto the
## paint, and a hand-lettered card on the plinth. Each is a thing someone
## put there, which is what tells wear from wallpaper.
func _decals(parent: Node3D, front: float) -> void:
	# The serial plate, riveted low on the front: the machine has a number
	# the way the player has an account.
	var plate: Node3D = Node3D.new()
	plate.name = "SerialPlate"
	plate.position = Vector3(0.58, CHASSIS_Y - 0.42, front + 0.006)
	parent.add_child(plate)
	Prims.box(plate, Vector3(0.2, 0.06, 0.006), Vector3.ZERO, Materials.brass(102))
	for sx: float in [-1.0, 1.0]:
		Prims.cylinder(plate, 0.005, 0.004, Vector3(sx * 0.085, 0.0, 0.004),
				Vector3(PI * 0.5, 0.0, 0.0), Materials.machined(Materials.STEEL, 103), 8)
	var serial: Label3D = Label3D.new()
	serial.text = Copy.of("No. 0447 · THE HOUSE")
	Type.face(serial, &"mono")
	serial.font_size = 26
	serial.pixel_size = 0.0009
	serial.modulate = Color(0.16, 0.13, 0.09)
	serial.shaded = false
	serial.position = Vector3(0.0, 0.0, 0.005)
	plate.add_child(serial)
	# The inspection sticker, peeling, with the House's red across it.
	var sticker: Node3D = Node3D.new()
	sticker.name = "Sticker"
	sticker.position = Vector3(-0.62, CHASSIS_Y + 0.02, front + 0.004)
	sticker.rotation.z = 0.12
	parent.add_child(sticker)
	Prims.quad(sticker, Vector2(0.13, 0.09), Vector3.ZERO,
			Materials.enamel(Color(0.78, 0.74, 0.62), 104))
	var inspected: Label3D = Label3D.new()
	inspected.text = Copy.of("INSPECTED") + "\n— · —"
	Type.face(inspected, &"display")
	inspected.font_size = 18
	inspected.pixel_size = 0.0009
	inspected.modulate = Color(0.2, 0.18, 0.14)
	inspected.shaded = false
	inspected.position = Vector3(0.0, 0.008, 0.002)
	sticker.add_child(inspected)
	var voided: Label3D = Label3D.new()
	voided.text = Copy.of("VOID")
	Type.face(voided, &"display")
	voided.font_size = 34
	voided.pixel_size = 0.0009
	voided.modulate = Color(0.6, 0.14, 0.1, 0.85)
	voided.shaded = false
	voided.position = Vector3(0.0, -0.01, 0.003)
	voided.rotation.z = -0.35
	sticker.add_child(voided)
	# The scorch: where the coil's arc has been landing on the paint.
	_wear_card(parent, Vector2(0.26, 0.2),
			Vector3(-0.78, CHASSIS_Y + 0.42, front + 0.02),
			ProcTextures.stain(105, Color(0.05, 0.04, 0.035)))
	# The hand-lettered card, taped to the plinth's face.
	var card: Node3D = Node3D.new()
	card.name = "Card"
	card.position = Vector3(-0.72, PLINTH_TOP - 0.16, 0.58)
	card.rotation.z = -0.06
	parent.add_child(card)
	Prims.quad(card, Vector2(0.24, 0.13), Vector3.ZERO,
			Materials.enamel(Materials.PAPER, 106))
	Prims.box(card, Vector3(0.05, 0.02, 0.002), Vector3(-0.08, 0.06, 0.002),
			Materials.enamel(Color(0.72, 0.68, 0.55), 107))
	Prims.box(card, Vector3(0.05, 0.02, 0.002), Vector3(0.09, -0.06, 0.002),
			Materials.enamel(Color(0.72, 0.68, 0.55), 107))
	var lettered: Label3D = Label3D.new()
	lettered.text = "\n".join([Copy.of("NO CREDIT."), Copy.of("NO EXCEPTIONS."), Copy.of("— MGMT")])
	Type.face(lettered, &"display")
	lettered.font_size = 20
	lettered.pixel_size = 0.0011
	lettered.modulate = Color(0.14, 0.12, 0.1)
	lettered.shaded = false
	lettered.position = Vector3(0.0, 0.0, 0.003)
	card.add_child(lettered)


func _wear_card(parent: Node3D, size: Vector2, at: Vector3,
		texture: ImageTexture) -> void:
	var card: MeshInstance3D = Prims.quad(parent, size, at,
			_wear_material(texture))
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Lit like the surface it sits on — a weep in shadow stays in shadow — but
## never casting one of its own, and never fighting the panel for depth.
func _wear_material(texture: ImageTexture) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.92
	material.metallic = 0.0
	material.disable_receive_shadows = false
	return material


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


## The works, along the top of the chassis: gearing, pipework and cable.
##
## The machine reads as a box with a window in it until you can see what is
## driving it. This is the row of exposed mechanism the reference puts above the
## reels — a train of gears of different sizes, a pressure line running the width
## with a valve wheel on it, gauges, and cable draped between the two.
##
## It sits at the back of the crown, forward of z 0 being left clear for bought
## hardware. Returns the turning parts so a spin drives them along with the
## machine's own drums.
func _crown() -> Array[Node3D]:
	var crown: Node3D = _group(&"Crown")
	var top: float = CHASSIS_Y + CHASSIS.y
	var brass: StandardMaterial3D = Materials.brass(45)
	var steel: StandardMaterial3D = Materials.machined(Color(0.42, 0.41, 0.40), 80)
	var pipe: StandardMaterial3D = Materials.rusted(32)
	var drives: Array[Node3D] = []

	# A gear train, sizes descending left to right so it reads as a reduction
	# rather than as a row of identical wheels.
	var sizes: Array[float] = [0.23, 0.16, 0.2, 0.135]
	var xs: Array[float] = [-0.72, -0.36, -0.02, 0.26]
	for i: int in sizes.size():
		var gear: Node3D = Node3D.new()
		gear.name = "Drive%d" % i
		crown.add_child(gear)
		gear.position = Vector3(xs[i], top + sizes[i] * 0.58, 0.2)
		var radius: float = sizes[i]
		Prims.cylinder(gear, radius * 0.82, 0.05, Vector3.ZERO,
				Vector3(PI * 0.5, 0.0, 0.0), brass, 20)
		Prims.ring(gear, int(8.0 + radius * 40.0), radius,
				Vector3(radius * 0.24, radius * 0.3, 0.05), 0.0, brass)
		# A hub and a spindle, so the gear is mounted rather than floating.
		Prims.cylinder(gear, radius * 0.24, 0.09, Vector3.ZERO,
				Vector3(PI * 0.5, 0.0, 0.0), steel, 12)
		# And a bracket landing the spindle on the rail below: a train whose
		# wheels touch nothing is jewellery, not a drive.
		_box(crown, Vector3(0.05, sizes[i] * 0.58 + 0.05, 0.045),
				Vector3(xs[i], top + (sizes[i] * 0.58) * 0.5, 0.13), steel)
		drives.append(gear)

	# What the train is FOR, made visible: a rail it is mounted to, a rod
	# rising from the gearbox to drive the big wheel, and the small wheel's
	# spindle dropping through a collar into the chassis — engine to gears to
	# drums, readable at a glance.
	_box(crown, Vector3(1.34, 0.05, 0.05), Vector3(-0.24, top + 0.025, 0.13),
			steel)
	_segment(_root, Vector3(-1.1, CHASSIS_Y + 0.26, 0.32),
			Vector3(xs[0], top + sizes[0] * 0.58, 0.2), 0.034, steel)
	Prims.sphere(_root, 0.055, Vector3(-1.1, CHASSIS_Y + 0.26, 0.32), steel)
	_segment(crown, Vector3(xs[3], top + sizes[3] * 0.58, 0.2),
			Vector3(xs[3], top - 0.14, 0.2), 0.028, steel)
	_box(crown, Vector3(0.11, 0.05, 0.11), Vector3(xs[3], top + 0.01, 0.2),
			Materials.rusted(33))

	# The pressure line: a pipe across the full width with a valve wheel and a
	# pair of gauges hung off it.
	_segment(crown, Vector3(-CHASSIS.x + 0.04, top + 0.34, -0.02),
			Vector3(CHASSIS.x - 0.04, top + 0.34, -0.02), 0.045, pipe)
	for i: int in 5:
		var x: float = lerpf(-CHASSIS.x + 0.2, CHASSIS.x - 0.2, float(i) / 4.0)
		_box(crown, Vector3(0.07, 0.16, 0.13), Vector3(x, top + 0.28, -0.02), steel)
	var valve: Node3D = Node3D.new()
	valve.name = "Drive_valve"
	crown.add_child(valve)
	valve.position = Vector3(0.62, top + 0.34, -0.02)
	Prims.cylinder(valve, 0.11, 0.022, Vector3.ZERO, Vector3.ZERO, brass, 18)
	for i: int in 5:
		var angle: float = TAU * float(i) / 5.0
		var spoke: MeshInstance3D = Prims.box(valve, Vector3(0.022, 0.2, 0.016),
				Vector3.ZERO, brass)
		spoke.rotation.y = angle
	drives.append(valve)

	# Two dials, and both of them mean something. A gauge with a needle parked at
	# a decorative angle is set dressing; these read the wager and the House's
	# attention, so the player can take both off the machine without looking at
	# an overlay at all.
	for i: int in 2:
		var gx: float = -0.9 + float(i) * 0.22
		Prims.cylinder(crown, 0.062, 0.04, Vector3(gx, top + 0.2, 0.22),
				Vector3(PI * 0.5, 0.0, 0.0), brass, 16)
		Prims.cylinder(crown, 0.05, 0.012, Vector3(gx, top + 0.2, 0.245),
				Vector3(PI * 0.5, 0.0, 0.0), Materials.readout_face(), 16)
		var pivot: Node3D = Node3D.new()
		pivot.name = ["Gauge_stake", "Gauge_count"][i]
		crown.add_child(pivot)
		pivot.position = Vector3(gx, top + 0.2, 0.252)
		# The needle is offset from its own pivot so the pivot can be turned
		# straight from a value, rather than every caller doing the arithmetic.
		Prims.box(pivot, Vector3(0.008, 0.045, 0.004),
				Vector3(0.0, 0.022, 0.0), Materials.glowing(Materials.SIGN, 1.2))
		pivot.rotation.z = GAUGE_SWEEP

	# Cable, sagging between the pipe and the back of the chassis. Straight cable
	# reads as conduit; the sag is what makes it look run rather than designed.
	var rubber: StandardMaterial3D = Materials.rubber(Color(0.31, 0.09, 0.07), 99)
	for run: int in 3:
		var from: Vector3 = Vector3(-0.5 + float(run) * 0.42, top + 0.3, -0.05)
		var to: Vector3 = Vector3(-0.34 + float(run) * 0.42, top - 0.04, -CHASSIS.z + 0.05)
		for seg: int in 5:
			var t0: float = float(seg) / 5.0
			var t1: float = float(seg + 1) / 5.0
			var bend: Vector3 = (from + to) * 0.5 + Vector3(0.0, -0.14, -0.05)
			_segment(crown, _quadratic(from, bend, to, t0),
					_quadratic(from, bend, to, t1), 0.019, rubber)
	return drives


## A lit bar either side of every row, so which rows are paying is something the
## player reads off the machine rather than works out.
##
## Three rows stand in the window and only the middle one pays until the works
## are bought. Without a mark, the first thing a new player does is try to work
## out which of three lines the number came from — and the moment a bought row
## starts paying, they have to work it out again.
func _payline_marks(bezel: Node3D, half: float, y: float, z: float) -> void:
	var rows: Node3D = Node3D.new()
	rows.name = "Paylines"
	bezel.add_child(rows)
	for slot: int in 3:
		var row: Node3D = Node3D.new()
		row.name = "Row%d" % slot
		rows.add_child(row)
		# Matched to where the band sits on the drum, so the mark lines up with
		# the symbols it is pointing at.
		var height: float = -sin(float(slot - 1) * BAND_ANGLE) * (REEL_RADIUS + 0.006)
		for sx: float in [-1.0, 1.0]:
			var mark: MeshInstance3D = Prims.box(row, Vector3(0.09, 0.022, 0.02),
					Vector3(sx * (half - 0.09), y + height, z + 0.03),
					Materials.lamp_glass(Color(1.0, 0.72, 0.3),
							PAYLINE_ENERGY if slot == 1 else 0.0))
			mark.rotation.z = sx * 0.0


## The gamble ladder: four lamps up the machine's right flank.
##
## The rungs are the whole drama of the mechanic — a player watching a light
## climb and deciding whether to reach for the next one is doing something a
## number on an overlay cannot make them feel. Dead until the floor that grants
## the ladder, and dark again the moment a rung is lost.
func _ladder() -> Array[Node3D]:
	var ladder: Node3D = _group(&"Ladder")
	var rungs: Array[Node3D] = []
	var backing: Material = Materials.painted(Materials.PAINT, 47)
	_box(ladder, Vector3(0.16, 0.86, 0.06),
			Vector3(CHASSIS.x + 0.05, CHASSIS_Y + 0.12, CHASSIS.z - 0.06), backing)
	for i: int in LADDER_RUNGS:
		var lamp: MeshInstance3D = MeshInstance3D.new()
		lamp.name = "Rung%d" % i
		var glass: CylinderMesh = CylinderMesh.new()
		glass.top_radius = 0.045
		glass.bottom_radius = 0.05
		glass.height = 0.026
		glass.radial_segments = 16
		lamp.mesh = glass
		lamp.transform.basis = Basis(Vector3(1.0, 0.0, 0.0), PI * 0.5)
		lamp.position = Vector3(CHASSIS.x + 0.05,
				CHASSIS_Y - 0.18 + float(i) * 0.2, CHASSIS.z - 0.02)
		# Warmer the higher it goes, so a full ladder reads as heat rather than
		# as four of the same lamp.
		lamp.material_override = Materials.lamp_glass(
				Color(1.0, 0.72 - float(i) * 0.13, 0.3 - float(i) * 0.08), 0.0)
		ladder.add_child(lamp)
		rungs.append(lamp)
	return rungs


## Where bought hardware bolts on, in the order it is used.
##
## Ordered by how visible each spot is rather than by where it is convenient to
## build: the front face fills first, then the crown, then the flanks, then the
## plinth. A player's first purchase should be the one they cannot miss, and by
## the time the awkward corners are in use the machine is already crowded.
##
## Fixed points rather than a row growing along one axis. Modules used to stack
## outward from a single anchor, which made a long run look like a shelf; spread
## around the chassis they read as a machine that has been added to.
func _mounts() -> Array[Node3D]:
	var group: Node3D = _group(&"Mounts")
	# Ordered by what the machine framing actually shows, which is not the same as
	# where there is room. The crown looked like the obvious place until it was
	# rendered: the camera sits slightly above the reels and looks down, so the
	# crown is foreshortened and half of it hides behind the odds housing and the
	# monitor. The front pocket and the plinth face are dead centre of frame, so
	# they fill first and the crown becomes overflow.
	#
	# Every position below is also chosen to miss something already there: the
	# odds housing spans x -0.27..0.59 on the crown, the gearbox takes the left
	# flank forward of z 0.1, and the lever mount takes the right flank at y 1.0.
	var places: Array[Array] = [
		[Vector3(0.805, CHASSIS_Y + 0.1, CHASSIS.z + 0.05), Vector3.ZERO],
		# The plinth-cap pockets moved to the plinth's face when the button
		# console took the apron: a module bolted where the buttons live
		# would eclipse the one control row the player cannot lose.
		[Vector3(-0.68, 0.24, 0.578), Vector3.ZERO],
		[Vector3(0.68, 0.24, 0.578), Vector3.ZERO],
		[Vector3(CHASSIS.x + 0.07, CHASSIS_Y + 0.34, -0.16), Vector3(0.0, PI * 0.5, 0.0)],
		[Vector3(-CHASSIS.x - 0.07, CHASSIS_Y + 0.28, -0.22), Vector3(0.0, -PI * 0.5, 0.0)],
		[Vector3(-1.0, 0.24, 0.578), Vector3.ZERO],
		[Vector3(-0.9, CHASSIS_Y + CHASSIS.y + 0.14, 0.28), Vector3(-0.7, 0.0, 0.0)],
		[Vector3(0.86, CHASSIS_Y + CHASSIS.y + 0.14, 0.28), Vector3(-0.7, 0.0, 0.0)],
		[Vector3(CHASSIS.x + 0.07, CHASSIS_Y - 0.3, -0.16), Vector3(0.0, PI * 0.5, 0.0)],
		[Vector3(-CHASSIS.x - 0.07, CHASSIS_Y - 0.26, -0.22), Vector3(0.0, -PI * 0.5, 0.0)],
		# The far pocket last: the monitor arm and the gearbox both crowd it.
		[Vector3(-0.805, CHASSIS_Y + 0.1, CHASSIS.z + 0.05), Vector3.ZERO],
	]
	var mounts: Array[Node3D] = []
	for i: int in places.size():
		var mount: Node3D = Node3D.new()
		mount.name = "Mount%d" % i
		group.add_child(mount)
		mount.position = places[i][0]
		mount.rotation = places[i][1]
		mount.scale = Vector3.ONE * MOUNT_SCALE
		mounts.append(mount)
	return mounts


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
