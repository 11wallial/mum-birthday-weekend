## Builds the hardware an artifact bolts onto the machine.
##
## Form follows the effect; finish follows the tag. A [enum ArtifactDef.Effect]
## chooses the shape — gearing multiplies, a meter accrues interest, an
## escapement buys time, a shredder cancels debt — and the artifact's first tag
## chooses what it is made of, so a run's purchases read as a growing machine
## with a visible mechanism rather than as a shelf of trinkets.
##
## Generated rather than authored, for the reason [MachineFrame] is: twenty-six
## artifacts is twenty-six scenes to hand-build and then keep in step with the
## balance sheet. This way a new artifact gets hardware that explains it the
## moment its [code].tres[/code] lands, without anyone opening the editor.
##
## Everything here is presentation. Nothing reads or writes [RunState].
class_name ModuleFactory
extends RefCounted

## The turn that puts a cylinder's flat face toward the player.
##
## [CylinderMesh] points along Y, while [method Prims.ring] lays teeth in the XY
## plane and [SlotView3D] spins drives about Z. A wheel built without this shows
## its edge with a ring of teeth floating in front of it — which is what three
## of the mechanisms here did until the module sheet was rendered.
const FACING: Vector3 = Vector3(PI * 0.5, 0.0, 0.0)


## How the module is finished: a body, a trim, and the colour it glows.
class Finish extends RefCounted:
	var body: StandardMaterial3D
	var trim: StandardMaterial3D
	var glow: Color

	func _init(body_material: StandardMaterial3D, trim_material: StandardMaterial3D,
			glow_colour: Color) -> void:
		body = body_material
		trim = trim_material
		glow = glow_colour


## Builds [param artifact]'s hardware. Any node named "Drive" in the result is
## turned by [SlotView3D] while the reels are spinning.
static func build(artifact: ArtifactDef) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Module_%s" % artifact.id
	var finish: Finish = _finish_for(artifact)
	_bracket(root, finish)
	match artifact.effect:
		ArtifactDef.Effect.FLAT_BONUS: _hopper(root, finish)
		ArtifactDef.Effect.MULT_BONUS: _gears(root, finish)
		ArtifactDef.Effect.SYMBOL_BONUS: _stamped_plate(root, finish, artifact.symbol_filter)
		ArtifactDef.Effect.PATTERN_MULT: _comparator(root, finish)
		ArtifactDef.Effect.INTEREST: _meter(root, finish)
		ArtifactDef.Effect.EXTRA_SPINS: _escapement(root, finish)
		ArtifactDef.Effect.WEIGHT_SHIFT: _coil(root, finish)
		ArtifactDef.Effect.ANTE_DISCOUNT: _contract(root, finish)
		ArtifactDef.Effect.RETRIGGER: _twin_drums(root, finish)
		ArtifactDef.Effect.CURSE_WARD: _bell_jar(root, finish)
		ArtifactDef.Effect.MULT_PER_FLOOR: _flywheel(root, finish)
		ArtifactDef.Effect.MULT_PER_ARTIFACT: _manifold(root, finish)
		ArtifactDef.Effect.DEBT_PAYDOWN: _shredder(root, finish)
		ArtifactDef.Effect.DEBT_LEVERAGE: _scale(root, finish)
		ArtifactDef.Effect.SPIN_REFUND: _freewheel(root, finish)
		# The synergy web's effects, each with its own hardware: the promise
		# that a build is visible on the machine, kept for all of them.
		ArtifactDef.Effect.MULT_PER_SEEN: _tally(root, finish)
		ArtifactDef.Effect.AWAKENED_MULT: _lamp(root, finish)
		ArtifactDef.Effect.MULT_PER_TRIGGER: _relays(root, finish)
		ArtifactDef.Effect.MULT_PER_TAG: _rack(root, finish)
		ArtifactDef.Effect.MULT_PER_CURSE: _urn(root, finish)
		ArtifactDef.Effect.MULT_PER_HOLD: _clamp(root, finish)
		ArtifactDef.Effect.MULT_PER_NUDGE: _pawl(root, finish)
		ArtifactDef.Effect.MULT_PER_SPIN_LEFT: _hourglass(root, finish)
		ArtifactDef.Effect.MULT_PER_STAKE: _chip_stack(root, finish)
		ArtifactDef.Effect.MULT_PER_STREAK: _lamp_chain(root, finish)
		ArtifactDef.Effect.PARTNER_MULT: _linked_rings(root, finish)
		_: _gears(root, finish)
	return root


## Materials by faction. The tag is the artifact's character — where it came
## from and who it belongs to — so it picks the metal, not the shape.
static func _finish_for(artifact: ArtifactDef) -> Finish:
	if artifact.has_tag(&"chaos"):
		# Salvage, running hot: dark steel and a violet discharge.
		return Finish.new(Materials.painted(Color(0.239, 0.212, 0.267), 31),
				Materials.machined(Color(0.514, 0.490, 0.573), 75), Color(0.62, 0.35, 1.0))
	if artifact.has_tag(&"greed"):
		# Gilt over the same castings as everything else, which is the point.
		return Finish.new(Materials.brass(42), Materials.machined(Color(0.541, 0.451, 0.239), 76),
				Color(1.0, 0.79, 0.31))
	if artifact.has_tag(&"bank"):
		# Institutional: painted steel, a brass dial, a green banker's lamp.
		return Finish.new(Materials.painted(Color(0.216, 0.278, 0.251), 32),
				Materials.brass(43), Color(0.36, 0.95, 0.62))
	if artifact.has_tag(&"contract"):
		# Paper and wax, on a steel spike.
		return Finish.new(Materials.enamel(Color(0.678, 0.655, 0.596), 71),
				Materials.machined(Color(0.561, 0.549, 0.537), 77), Color(0.85, 0.22, 0.18))
	if artifact.has_tag(&"luck"):
		# Bone and cord, tied on rather than bolted. Nothing here was machined.
		return Finish.new(Materials.enamel(Color(0.616, 0.588, 0.494), 72),
				Materials.timber(102), Color(0.98, 0.84, 0.45))
	return Finish.new(Materials.brass(44), Materials.machined(Materials.STEEL, 78),
			Color(1.0, 0.72, 0.36))


## The plate and bolts every module shares. Common hardware is what makes a
## dozen different mechanisms look like they came off the same machine.
static func _bracket(root: Node3D, finish: Finish) -> void:
	Prims.box(root, Vector3(0.26, 0.26, 0.03), Vector3(0.0, 0.0, -0.09), finish.trim)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			Prims.sphere(root, 0.014, Vector3(sx * 0.1, sy * 0.1, -0.075), finish.trim)


# --- one form per effect ----------------------------------------------------

## FLAT_BONUS: a hopper that drops the same few credits every spin.
static func _hopper(root: Node3D, finish: Finish) -> void:
	Prims.cone(root, 0.115, 0.038, 0.15, Vector3(0.0, 0.035, 0.03),
			Vector3.ZERO, finish.body)
	Prims.box(root, Vector3(0.14, 0.05, 0.1), Vector3(0.0, -0.11, 0.02), finish.trim)
	# One coin caught in the throat, so it reads as paying rather than storing.
	Prims.cylinder(root, 0.028, 0.008, Vector3(0.0, -0.09, 0.06),
			Vector3(PI * 0.5, 0.0, 0.0), Materials.glowing(finish.glow, 1.4), 10)


## MULT_BONUS: two meshing gears. Multiplication, made of teeth.
static func _gears(root: Node3D, finish: Finish) -> void:
	var drive: Node3D = Prims.group(root, &"Drive")
	Prims.cylinder(drive, 0.085, 0.03, Vector3(-0.035, 0.02, 0.05),
			FACING, finish.body, 20)
	Prims.ring(drive, 12, 0.095, Vector3(0.024, 0.03, 0.03), 0.05, finish.body)
	var small: Node3D = Prims.group(root, &"Drive2")
	small.position = Vector3(0.095, -0.075, 0.05)
	Prims.cylinder(small, 0.05, 0.028, Vector3.ZERO, FACING, finish.trim, 16)
	Prims.ring(small, 8, 0.058, Vector3(0.022, 0.026, 0.028), 0.0, finish.trim)


## SYMBOL_BONUS: the symbol itself, stamped on a plate and lit.
##
## This is the one module that says exactly which symbol its artifact pays for,
## and it does it with the same drawing that appears on the reel and in the
## draft — so the player is never asked to match a name to a picture.
static func _stamped_plate(root: Node3D, finish: Finish, symbol_id: StringName) -> void:
	Prims.box(root, Vector3(0.2, 0.2, 0.035), Vector3(0.0, 0.0, 0.0), finish.body)
	Prims.box(root, Vector3(0.23, 0.23, 0.02), Vector3(0.0, 0.0, -0.012), finish.trim)
	var symbol: SymbolDef = ContentDB.shared().symbol_by_id(symbol_id)
	var art: ImageTexture = (null if symbol == null
			else SymbolArt.texture_for(symbol.id, symbol.color))
	if art == null:
		# Applies to every symbol, or to one with no drawing: a blank die face.
		Prims.ring(root, 5, 0.05, Vector3(0.02, 0.02, 0.02), 0.022, finish.trim)
		return
	var face: StandardMaterial3D = StandardMaterial3D.new()
	face.albedo_texture = art
	face.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face.alpha_scissor_threshold = 0.4
	Prims.quad(root, Vector2(0.165, 0.165), Vector3(0.0, 0.0, 0.019), face)


## PATTERN_MULT: a comparator. Three pins, and it pays when they line up.
static func _comparator(root: Node3D, finish: Finish) -> void:
	Prims.box(root, Vector3(0.22, 0.13, 0.04), Vector3(0.0, 0.0, 0.0), finish.body)
	for i: int in 3:
		var x: float = (float(i) - 1.0) * 0.062
		# The outer two sit high and the middle one low: a comparison caught
		# mid-throw reads as a mechanism, three in a row reads as decoration.
		var y: float = 0.028 if i != 1 else -0.024
		Prims.cylinder(root, 0.014, 0.075, Vector3(x, y, 0.035),
				Vector3(PI * 0.5, 0.0, 0.0), finish.trim, 10)
		Prims.sphere(root, 0.021, Vector3(x, y, 0.072), Materials.glowing(finish.glow, 1.1))


## INTEREST: a meter. A dial, a needle, and glass over it.
static func _meter(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.105, 0.05, Vector3(0.0, 0.0, 0.01),
			Vector3(PI * 0.5, 0.0, 0.0), finish.body, 20)
	Prims.cylinder(root, 0.088, 0.012, Vector3(0.0, 0.0, 0.04),
			Vector3(PI * 0.5, 0.0, 0.0), Materials.readout_face(), 20)
	# Graduations round the top half only, the way a pressure gauge is marked.
	for i: int in 7:
		var angle: float = PI * (0.15 + 0.7 * float(i) / 6.0)
		Prims.box(root, Vector3(0.008, 0.018, 0.006),
				Vector3(cos(angle) * 0.068, sin(angle) * 0.068, 0.047), finish.trim)
	var needle: Node3D = Prims.group(root, &"Drive")
	needle.position = Vector3(0.0, 0.0, 0.05)
	needle.rotation.z = 2.1
	Prims.box(needle, Vector3(0.012, 0.075, 0.005), Vector3(0.0, 0.032, 0.0),
			Materials.glowing(finish.glow, 1.3))
	Prims.sphere(root, 0.014, Vector3(0.0, 0.0, 0.052), finish.trim)


## EXTRA_SPINS: an escapement — the part of a clock that hands out time.
static func _escapement(root: Node3D, finish: Finish) -> void:
	var drive: Node3D = Prims.group(root, &"Drive")
	drive.position = Vector3(-0.02, 0.015, 0.045)
	Prims.cylinder(drive, 0.072, 0.02, Vector3.ZERO, FACING, finish.body, 18)
	Prims.ring(drive, 14, 0.082, Vector3(0.016, 0.026, 0.02), 0.0, finish.body)
	# The pallet: the anchor that lets the wheel past one tooth at a time.
	var pallet: MeshInstance3D = Prims.box(root, Vector3(0.13, 0.022, 0.018),
			Vector3(0.02, 0.09, 0.055), finish.trim)
	pallet.rotation.z = -0.3
	Prims.segment(root, Vector3(0.02, 0.09, 0.055), Vector3(0.06, -0.09, 0.055),
			0.008, finish.trim)
	Prims.sphere(root, 0.026, Vector3(0.06, -0.1, 0.055), finish.trim)


## WEIGHT_SHIFT: a coil. It pulls one symbol toward the payline more often.
static func _coil(root: Node3D, finish: Finish) -> void:
	# A U of core iron with the windings stacked up one leg.
	Prims.box(root, Vector3(0.036, 0.15, 0.05), Vector3(-0.07, 0.0, 0.03), finish.trim)
	Prims.box(root, Vector3(0.036, 0.15, 0.05), Vector3(0.07, 0.0, 0.03), finish.trim)
	Prims.box(root, Vector3(0.176, 0.036, 0.05), Vector3(0.0, -0.075, 0.03), finish.trim)
	for i: int in 7:
		Prims.cylinder(root, 0.042, 0.017,
				Vector3(-0.07, -0.05 + float(i) * 0.019, 0.03),
				Vector3.ZERO, finish.body, 12)
	# The field arcing across the gap.
	Prims.sphere(root, 0.022, Vector3(0.0, 0.072, 0.03),
			Materials.glowing(finish.glow, 2.0))


## ANTE_DISCOUNT: a signed contract, spiked. The house's own paperwork, used
## against it.
static func _contract(root: Node3D, finish: Finish) -> void:
	Prims.box(root, Vector3(0.19, 0.23, 0.012), Vector3(0.0, 0.0, 0.02), finish.body)
	var second: MeshInstance3D = Prims.box(root, Vector3(0.19, 0.23, 0.01),
			Vector3(0.012, -0.014, 0.008), finish.body)
	second.rotation.z = 0.08
	# Ruled lines, and a wax seal over the signature.
	for i: int in 5:
		Prims.box(root, Vector3(0.13, 0.006, 0.002),
				Vector3(-0.01, 0.075 - float(i) * 0.028, 0.027), finish.trim)
	Prims.cylinder(root, 0.032, 0.012, Vector3(0.042, -0.072, 0.03),
			Vector3(PI * 0.5, 0.0, 0.0), Materials.glowing(finish.glow, 0.7), 14)
	Prims.segment(root, Vector3(-0.06, 0.14, 0.02), Vector3(-0.06, -0.02, 0.02),
			0.007, finish.trim)


## RETRIGGER: a second set of drums, scoring the same line again.
static func _twin_drums(root: Node3D, finish: Finish) -> void:
	var drive: Node3D = Prims.group(root, &"Drive")
	drive.position = Vector3(0.0, 0.0, 0.05)
	for sx: float in [-0.058, 0.058]:
		Prims.cylinder(drive, 0.062, 0.05, Vector3(sx, 0.0, 0.0),
				FACING, finish.body, 18)
		Prims.cylinder(drive, 0.03, 0.062, Vector3(sx, 0.0, 0.0),
				FACING, finish.trim, 12)
	Prims.cylinder(root, 0.012, 0.26, Vector3(0.0, 0.0, 0.05),
			Vector3(0.0, 0.0, PI * 0.5), finish.trim, 10)


## CURSE_WARD: something unpleasant, kept under glass and paid for.
static func _bell_jar(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.1, 0.022, Vector3(0.0, -0.08, 0.03),
			Vector3.ZERO, finish.trim, 18)
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.72, 0.78, 0.8, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.4
	glass.roughness = 0.1
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	Prims.cone(root, 0.055, 0.092, 0.16, Vector3(0.0, 0.0, 0.03),
			Vector3.ZERO, glass)
	Prims.sphere(root, 0.03, Vector3(0.0, 0.09, 0.03), glass)
	# The warded thing, glowing inside it.
	Prims.sphere(root, 0.036, Vector3(0.0, -0.04, 0.03),
			Materials.glowing(finish.glow, 1.8))


## MULT_PER_FLOOR: a flywheel. It keeps whatever the run has already built.
static func _flywheel(root: Node3D, finish: Finish) -> void:
	var drive: Node3D = Prims.group(root, &"Drive")
	drive.position = Vector3(0.0, 0.0, 0.055)
	Prims.cylinder(drive, 0.115, 0.026, Vector3.ZERO, FACING, finish.body, 24)
	Prims.cylinder(drive, 0.095, 0.04, Vector3(0.0, 0.0, -0.012),
			FACING, finish.trim, 24)
	for i: int in 5:
		var angle: float = TAU * float(i) / 5.0
		var spoke: MeshInstance3D = Prims.box(drive, Vector3(0.026, 0.18, 0.018),
				Vector3.ZERO, finish.trim)
		spoke.rotation.z = angle
	Prims.cylinder(drive, 0.03, 0.06, Vector3.ZERO, FACING, finish.body, 14)


## MULT_PER_ARTIFACT: a manifold. Every other module feeds this one.
static func _manifold(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.036, 0.24, Vector3(0.0, 0.0, 0.04),
			Vector3(0.0, 0.0, PI * 0.5), finish.body, 16)
	for i: int in 4:
		var x: float = -0.09 + float(i) * 0.06
		Prims.segment(root, Vector3(x, 0.0, 0.04), Vector3(x, 0.085, 0.055),
				0.014, finish.trim)
		Prims.cylinder(root, 0.021, 0.014, Vector3(x, 0.092, 0.056),
				Vector3(0.0, 0.0, PI * 0.5), Materials.glowing(finish.glow, 0.9), 10)
	Prims.cylinder(root, 0.044, 0.02, Vector3(-0.12, 0.0, 0.04),
			Vector3(0.0, 0.0, PI * 0.5), finish.trim, 16)


## DEBT_LEVERAGE: a balance, tipped. What is owed on one pan, what it is worth
## on the other, and the beam leaning toward the debt.
static func _scale(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.022, 0.16, Vector3(0.0, -0.04, 0.04),
			Vector3.ZERO, finish.trim, 12)
	var beam: Node3D = Prims.group(root, &"Beam")
	beam.position = Vector3(0.0, 0.045, 0.04)
	# Tipped rather than level: a balance at rest says nothing, and the point of
	# the artifact is that it is out of balance in your favour.
	beam.rotation.z = -0.26
	Prims.box(beam, Vector3(0.24, 0.016, 0.016), Vector3.ZERO, finish.body)
	for sx: float in [-1.0, 1.0]:
		Prims.segment(beam, Vector3(sx * 0.11, 0.0, 0.0),
				Vector3(sx * 0.11, -0.05, 0.0), 0.004, finish.trim)
		Prims.cylinder(beam, 0.042, 0.008, Vector3(sx * 0.11, -0.055, 0.0),
				FACING, finish.body, 14)
	# Chits stacked on the low pan: the debt, and what it is buying.
	for i: int in 3:
		Prims.cylinder(beam, 0.026, 0.007,
				Vector3(-0.11, -0.062 - float(i) * 0.009, 0.0), FACING,
				Materials.glowing(finish.glow, 0.8), 10)
	Prims.sphere(root, 0.02, Vector3(0.0, 0.045, 0.04), finish.trim)


## SPIN_REFUND: a freewheel with a tooth missing off the ratchet, so the counter
## does not always advance.
static func _freewheel(root: Node3D, finish: Finish) -> void:
	var drive: Node3D = Prims.group(root, &"Drive")
	drive.position = Vector3(-0.01, 0.0, 0.05)
	Prims.cylinder(drive, 0.078, 0.024, Vector3.ZERO, FACING, finish.body, 20)
	# One tooth short of a full ring. The gap is the mechanism, so it is built
	# rather than implied.
	for i: int in 11:
		var angle: float = TAU * float(i) / 12.0
		var tooth: MeshInstance3D = Prims.box(drive, Vector3(0.02, 0.028, 0.026),
				Vector3(cos(angle) * 0.088, sin(angle) * 0.088, 0.0), finish.body)
		tooth.rotation.z = angle
	var pawl: MeshInstance3D = Prims.box(root, Vector3(0.11, 0.018, 0.018),
			Vector3(0.085, 0.085, 0.058), finish.trim)
	pawl.rotation.z = -0.7
	Prims.segment(root, Vector3(0.13, 0.115, 0.058), Vector3(0.115, -0.06, 0.058),
			0.007, finish.trim)
	Prims.sphere(root, 0.018, Vector3(0.115, -0.07, 0.058),
			Materials.glowing(finish.glow, 1.0))


## DEBT_PAYDOWN: a shredder, with the paper still coming out of it.
static func _shredder(root: Node3D, finish: Finish) -> void:
	Prims.box(root, Vector3(0.23, 0.1, 0.09), Vector3(0.0, 0.03, 0.045), finish.body)
	Prims.box(root, Vector3(0.19, 0.014, 0.05), Vector3(0.0, 0.085, 0.045),
			Materials.readout_face())
	var paper: StandardMaterial3D = Materials.enamel(Materials.PAPER, 73)
	for i: int in 5:
		var x: float = -0.072 + float(i) * 0.036
		var length: float = 0.09 + sin(float(i) * 2.1) * 0.035
		var strip: MeshInstance3D = Prims.box(root, Vector3(0.022, length, 0.004),
				Vector3(x, -0.03 - length * 0.5, 0.045), paper)
		strip.rotation.z = sin(float(i) * 1.7) * 0.16
	Prims.box(root, Vector3(0.23, 0.016, 0.1), Vector3(0.0, -0.025, 0.045), finish.trim)


# --- the synergy web's own forms --------------------------------------------

## MULT_PER_SEEN: a tally — a counter drum with a pawl, turned by what lands.
static func _tally(root: Node3D, finish: Finish) -> void:
	var drum: Node3D = Prims.group(root, &"Drive")
	drum.position = Vector3(0.0, 0.01, 0.04)
	Prims.cylinder(drum, 0.075, 0.06, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), finish.body, 24)
	for i: int in 10:
		var angle: float = TAU * float(i) / 10.0
		Prims.box(drum, Vector3(0.05, 0.006, 0.014),
				Vector3(0.0, cos(angle) * 0.076, sin(angle) * 0.076), finish.trim)
	Prims.box(root, Vector3(0.02, 0.09, 0.012), Vector3(0.0, 0.1, 0.03), finish.trim)
	Prims.sphere(root, 0.014, Vector3(0.0, 0.056, 0.03), Materials.glowing(finish.glow, 1.3))


## AWAKENED_MULT: a caged lamp, lit once its hardware has woken.
static func _lamp(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.05, 0.03, Vector3(0.0, -0.08, 0.03), Vector3.ZERO, finish.trim, 14)
	Prims.sphere(root, 0.055, Vector3(0.0, 0.0, 0.03), Materials.glowing(finish.glow, 1.5))
	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0
		Prims.box(root, Vector3(0.006, 0.16, 0.006),
				Vector3(cos(angle) * 0.065, 0.0, 0.03 + sin(angle) * 0.065), finish.trim)
	Prims.cylinder(root, 0.03, 0.02, Vector3(0.0, 0.085, 0.03), Vector3.ZERO, finish.trim, 12)


## MULT_PER_TRIGGER: a bank of relays, contacts lit as they close.
static func _relays(root: Node3D, finish: Finish) -> void:
	for i: int in 3:
		var x: float = -0.075 + float(i) * 0.075
		Prims.box(root, Vector3(0.06, 0.13, 0.07), Vector3(x, 0.0, 0.0), finish.body)
		Prims.box(root, Vector3(0.04, 0.02, 0.02), Vector3(x, 0.05, 0.045), finish.trim)
		Prims.sphere(root, 0.011, Vector3(x, -0.04, 0.045),
				Materials.glowing(finish.glow, 0.7 + 0.4 * float(i)))
	Prims.box(root, Vector3(0.24, 0.012, 0.03), Vector3(0.0, -0.085, 0.02), finish.trim)


## MULT_PER_TAG: a rack of badges, one for every kind the run has bought.
static func _rack(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.008, 0.24, Vector3(0.0, 0.06, 0.03), Vector3(0.0, 0.0, PI * 0.5), finish.trim, 8)
	for i: int in 4:
		var x: float = -0.09 + float(i) * 0.06
		Prims.box(root, Vector3(0.006, 0.05, 0.006), Vector3(x, 0.03, 0.03), finish.trim)
		Prims.cylinder(root, 0.022, 0.008, Vector3(x, -0.01, 0.03), FACING,
				Materials.glowing(finish.glow, 0.9) if i % 2 == 0 else finish.body, 12)


## MULT_PER_CURSE: an urn for the skulls, sealed and faintly lit from within.
static func _urn(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.07, 0.14, Vector3(0.0, -0.01, 0.03), Vector3.ZERO,
			Materials.painted(Color(0.09, 0.08, 0.075), 141), 16)
	Prims.cylinder(root, 0.078, 0.02, Vector3(0.0, 0.07, 0.03), Vector3.ZERO, finish.trim, 16)
	Prims.cylinder(root, 0.03, 0.025, Vector3(0.0, 0.09, 0.03), Vector3.ZERO, finish.trim, 10)
	Prims.box(root, Vector3(0.05, 0.03, 0.006), Vector3(0.0, -0.01, 0.102),
			Materials.glowing(Color(0.75, 0.12, 0.1), 0.8))


## MULT_PER_HOLD: a clamp — two jaws on a screw, the lock made of iron.
static func _clamp(root: Node3D, finish: Finish) -> void:
	Prims.box(root, Vector3(0.04, 0.16, 0.06), Vector3(-0.07, 0.0, 0.03), finish.body)
	Prims.box(root, Vector3(0.04, 0.16, 0.06), Vector3(0.07, 0.0, 0.03), finish.body)
	var screw: Node3D = Prims.group(root, &"Drive")
	screw.position = Vector3(0.0, 0.05, 0.03)
	Prims.cylinder(screw, 0.012, 0.2, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), finish.trim, 8)
	Prims.ring(screw, 6, 0.03, Vector3(0.02, 0.012, 0.012), 0.0, finish.trim)
	Prims.box(root, Vector3(0.09, 0.03, 0.03), Vector3(0.0, -0.03, 0.03),
			Materials.glowing(finish.glow, 1.0))


## MULT_PER_NUDGE: a pawl on a ratchet wheel — one tooth at a time.
static func _pawl(root: Node3D, finish: Finish) -> void:
	var wheel: Node3D = Prims.group(root, &"Drive")
	wheel.position = Vector3(-0.03, -0.02, 0.04)
	Prims.cylinder(wheel, 0.07, 0.025, Vector3.ZERO, FACING, finish.body, 16)
	Prims.ring(wheel, 10, 0.08, Vector3(0.02, 0.024, 0.024), 0.0, finish.trim)
	var arm: Node3D = Prims.group(root, &"Arm")
	arm.position = Vector3(0.06, 0.07, 0.04)
	arm.rotation.z = -0.5
	Prims.box(arm, Vector3(0.016, 0.12, 0.016), Vector3(0.0, -0.05, 0.0), finish.trim)
	Prims.sphere(root, 0.012, Vector3(0.06, 0.07, 0.04), Materials.glowing(finish.glow, 1.2))


## MULT_PER_SPIN_LEFT: an hourglass — the spins you have not spent, running.
static func _hourglass(root: Node3D, finish: Finish) -> void:
	Prims.cone(root, 0.06, 0.006, 0.07, Vector3(0.0, 0.045, 0.03), Vector3.ZERO,
			Materials.lamp_glass(finish.glow, 0.6))
	Prims.cone(root, 0.006, 0.06, 0.07, Vector3(0.0, -0.045, 0.03), Vector3.ZERO,
			Materials.lamp_glass(finish.glow, 0.6))
	for sy: float in [-1.0, 1.0]:
		Prims.cylinder(root, 0.07, 0.014, Vector3(0.0, sy * 0.088, 0.03), Vector3.ZERO, finish.trim, 14)
	for i: int in 3:
		var angle: float = TAU * float(i) / 3.0
		Prims.box(root, Vector3(0.008, 0.18, 0.008),
				Vector3(cos(angle) * 0.062, 0.0, 0.03 + sin(angle) * 0.062), finish.trim)


## MULT_PER_STAKE: a stack of the House's chips, the wager made visible.
static func _chip_stack(root: Node3D, finish: Finish) -> void:
	for i: int in 6:
		Prims.cylinder(root, 0.055, 0.012, Vector3(0.0, -0.06 + float(i) * 0.016, 0.03),
				Vector3.ZERO, finish.body if i % 2 == 0 else finish.trim, 16)
	Prims.cylinder(root, 0.03, 0.006, Vector3(0.0, 0.04, 0.03), Vector3.ZERO,
			Materials.glowing(finish.glow, 1.1), 12)
	Prims.box(root, Vector3(0.16, 0.012, 0.16), Vector3(0.0, -0.075, 0.03), finish.trim)


## MULT_PER_STREAK: a chain of lamps, each brighter than the last.
static func _lamp_chain(root: Node3D, finish: Finish) -> void:
	Prims.cylinder(root, 0.008, 0.22, Vector3(0.0, 0.0, 0.03), Vector3(0.0, 0.0, PI * 0.5), finish.trim, 8)
	for i: int in 4:
		var x: float = -0.08 + float(i) * 0.053
		Prims.cylinder(root, 0.014, 0.02, Vector3(x, -0.02, 0.03), Vector3.ZERO, finish.trim, 10)
		Prims.sphere(root, 0.018, Vector3(x, -0.045, 0.03),
				Materials.glowing(finish.glow, 0.5 + 0.35 * float(i)))


## PARTNER_MULT: two rings, linked — the pair that pays together.
static func _linked_rings(root: Node3D, finish: Finish) -> void:
	var left: Node3D = Prims.group(root, &"Drive")
	left.position = Vector3(-0.035, 0.0, 0.03)
	Prims.ring(left, 14, 0.06, Vector3(0.018, 0.02, 0.02), 0.0, finish.body)
	var right: Node3D = Prims.group(root, &"Drive2")
	right.position = Vector3(0.035, 0.0, 0.05)
	right.rotation.y = 0.6
	Prims.ring(right, 14, 0.06, Vector3(0.018, 0.02, 0.02), 0.0, finish.trim)
	Prims.sphere(root, 0.014, Vector3(0.0, 0.0, 0.04), Materials.glowing(finish.glow, 1.2))
