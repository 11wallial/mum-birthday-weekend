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
## outer two curving away out of sight.
const REEL_RADIUS: float = 0.38
const REEL_SPACING: float = 0.43
## How far round the drum the symbols above and below the payline sit, in
## radians. At this radius that puts them roughly 0.22m either side of centre.
const BAND_ANGLE: float = 0.62
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

var _root: Node3D


## Constructs the machine under [param root] and returns the nodes the view
## drives, keyed [code]reels[/code], [code]lever[/code], [code]screen[/code],
## [code]odds[/code] and [code]spool[/code].
func build(root: Node3D, reel_count: int = 3) -> Dictionary:
	_root = root
	_plinth()
	_chassis()
	var reels: Array[Node3D] = _reel_bank(reel_count)
	_bezel(reel_count)
	var gearbox: Node3D = _gearbox()
	_hoses()
	var screen: MeshInstance3D = _monitor()
	var readout: Label3D = screen.get_node(^"Readout") as Label3D
	var odds: Label3D = _odds_display()
	var lever: Node3D = _lever()
	var spool: Node3D = _spool()
	var crown: Array[Node3D] = _crown()
	var ladder: Array[Node3D] = _ladder()
	_rivets()
	var mounts: Array[Node3D] = _mounts()
	return {
		"mounts": mounts,
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
		"spool": spool,
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
			Materials.weathered("painted_metal", Materials.PAINT, 0.9, 1.0,
					0.38, 0.3, Materials.painted(Materials.PAINT, 11)))
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
	_box(chassis, Vector3(1.44, 0.84, 0.34),
			Vector3(0.0, CHASSIS_Y + 0.05, CHASSIS.z - 0.3),
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
## Rebuilds just the window — the drums and the chrome around them — at a new
## reel count, leaving everything bolted to the frame where it is.
##
## The machine grows on floor six, and rebuilding the whole thing to widen it
## would throw away every module the run has bought. The window is the only part
## that has to change, so it is the only part that is thrown away.
func rebuild_window(root: Node3D, reel_count: int) -> Array[Node3D]:
	_root = root
	for group_name: StringName in [&"Reels", &"Bezel"]:
		var old: Node = root.get_node_or_null(NodePath(group_name))
		if old != null:
			# Removed as well as freed: queue_free defers, and the new bank is
			# added in this same frame under the same name.
			root.remove_child(old)
			old.queue_free()
	var reels: Array[Node3D] = _reel_bank(reel_count)
	_bezel(reel_count)
	return reels


## Half the width the drums occupy at [param reel_count], for the chrome and the
## housings that have to reach round them.
static func bank_half_width(reel_count: int) -> float:
	return float(maxi(reel_count, 1) - 1) * REEL_SPACING * 0.5


func _reel_bank(reel_count: int) -> Array[Node3D]:
	var bank: Node3D = _group(&"Reels")
	bank.position = Vector3(0.0, CHASSIS_Y + 0.05, REEL_Z)
	var drum: CylinderMesh = CylinderMesh.new()
	drum.top_radius = REEL_RADIUS
	drum.bottom_radius = REEL_RADIUS
	drum.height = 0.38
	drum.radial_segments = 40
	var reels: Array[Node3D] = []
	var centre: float = float(maxi(reel_count, 1) - 1) * 0.5
	for i: int in maxi(reel_count, 1):
		var reel: Node3D = Node3D.new()
		reel.name = "Reel%d" % i
		reel.position = Vector3((float(i) - centre) * REEL_SPACING, 0.0, 0.0)
		bank.add_child(reel)

		var face: MeshInstance3D = MeshInstance3D.new()
		face.name = "Face"
		face.mesh = drum
		# The drum's own axis is Y; rotating it onto X makes it roll toward the
		# player when the reel node turns about X, which is how the view spins it.
		face.transform.basis = Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)
		face.material_override = Materials.enamel(Materials.ENAMEL, 67 + i)
		reel.add_child(face)

		# Three symbols per reel, printed round the drum: what landed, and what
		# nearly did either side of it. A window showing one symbol per reel
		# throws away most of what a slot machine is for — the near miss is the
		# drama, and you cannot have one you were never shown.
		#
		# The band symbols ride the drum's surface at BAND_ANGLE, turned to face
		# out, so they are genuinely printed on it rather than floating flat.
		for slot: int in 3:
			var offset: float = float(slot - 1) * BAND_ANGLE
			var printed: Sprite3D = Sprite3D.new()
			printed.name = ["Above", "Payline", "Below"][slot]
			printed.pixel_size = 0.0021
			printed.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			printed.shaded = false
			printed.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			printed.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			printed.visible = false
			# The band is dimmer than the payline: it is context, not the result.
			printed.modulate = (Color(1, 1, 1, 1) if slot == 1
					else Color(0.62, 0.6, 0.58))
			printed.position = Vector3(0.0,
					sin(-offset) * (REEL_RADIUS + 0.006),
					cos(offset) * (REEL_RADIUS + 0.006))
			printed.rotation.x = offset
			reel.add_child(printed)

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
		_reel_lamps(reel)
		reels.append(reel)
	return reels


## The two lamps a fruit machine puts by every drum: HOLD under it, and the
## nudge chevron over it.
##
## On the machine rather than only on the overlay, because these are the two
## moves the player makes without looking away from the reels — and a control
## whose state lives only in a panel at the bottom of the screen is a control
## the player has to keep translating back to the drum it belongs to.
func _reel_lamps(reel: Node3D) -> void:
	var lamp: MeshInstance3D = MeshInstance3D.new()
	lamp.name = "HoldLamp"
	var glass: CylinderMesh = CylinderMesh.new()
	glass.top_radius = 0.05
	glass.bottom_radius = 0.055
	glass.height = 0.03
	glass.radial_segments = 18
	lamp.mesh = glass
	lamp.transform.basis = Basis(Vector3(1.0, 0.0, 0.0), PI * 0.5)
	lamp.position = Vector3(0.0, -0.47, REEL_RADIUS - 0.02)
	lamp.material_override = Materials.lamp_glass(Color(0.55, 0.36, 0.12), 0.0)
	reel.add_child(lamp)

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
	var steel: StandardMaterial3D = Materials.chrome()
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
	# also the only thing saying which of them counts.
	_box(bezel, Vector3(1.4, 0.014, 0.014), Vector3(0.0, y, z + 0.04),
			Materials.glowing(Materials.JACKPOT, 1.8))
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
	housing.position = Vector3(0.62, CHASSIS_Y + 0.92, 0.2)
	_box(housing, Vector3(0.7, 0.24, 0.16), Vector3.ZERO,
			Materials.painted(Materials.PAINT, 17))
	_box(housing, Vector3(0.62, 0.17, 0.02), Vector3(0.0, 0.0, 0.085),
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
		drives.append(gear)

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
		[Vector3(-0.68, PLINTH_TOP + 0.11, 0.52), Vector3(-1.0, 0.0, 0.0)],
		[Vector3(0.68, PLINTH_TOP + 0.11, 0.52), Vector3(-1.0, 0.0, 0.0)],
		[Vector3(CHASSIS.x + 0.07, CHASSIS_Y + 0.34, -0.16), Vector3(0.0, PI * 0.5, 0.0)],
		[Vector3(-CHASSIS.x - 0.07, CHASSIS_Y + 0.28, -0.22), Vector3(0.0, -PI * 0.5, 0.0)],
		[Vector3(0.0, PLINTH_TOP + 0.11, 0.52), Vector3(-1.0, 0.0, 0.0)],
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
