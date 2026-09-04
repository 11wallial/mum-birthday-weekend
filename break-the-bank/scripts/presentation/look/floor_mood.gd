## What each floor does to the light.
##
## The room does not change between floors — the spec is explicit that it
## accumulates rather than swapping, and a player's winnings, debt and hardware
## all stay where they were put. What changes is the light in it. Seven floors
## of the same basement, lit seven different ways, gives the descent somewhere to
## go without throwing away everything the run has built.
##
## The simulation has emitted [code]environment[/code] on every FLOOR_STARTED
## since it was written; nothing had ever listened.
##
## These are presentation constants, not balance, so they live in code rather
## than in a [code].tres[/code]: no sweep will ever want to tune the colour of
## the vault.
##
## The value structure is the point, on every floor: the key is the only
## bright thing, the cold fill is a stop or two under it, and the ambient is
## just enough to keep the corners from going dead. Raising any of these to
## "see the room" flattens the frame into one orange midtone — that is what
## the art handover found and it is the first thing it asked for.
class_name FloorMood
extends RefCounted

## How long a floor takes to change the light. Slow on purpose — a hard cut
## reads as a scene change, and the point is that it is the same room.
const TRANSITION: float = 2.2

## One floor's lighting, keyed by [member FloorDef.environment_id].
##
## Read as a descent: tungsten and damp at the top, then noise and warmth, then
## money, then cold storage, then paperwork, then heat — and finally a floor with
## no warmth in it at all, lit like a place that is counting rather than playing.
const MOODS: Dictionary = {
	&"basement": {
		"key": Color(1.0, 0.831, 0.616), "key_energy": 9.20,
		"cold": Color(0.42, 0.545, 0.769), "cold_energy": 1.26,
		"ambient": Color(0.125, 0.145, 0.196), "ambient_energy": 0.14,
		"fog": Color(0.129, 0.145, 0.184), "fog_density": 0.01,
		"sign": Color(1.0, 0.376, 0.078),
		# the shell as built: everything else is measured from here
		"tint": Color(1.0, 1.0, 1.0),
	},
	&"casino": {
		# Carpet and noise: everything warmer, hazier, and a red sign over it.
		"key": Color(1.0, 0.784, 0.545), "key_energy": 9.89,
		"cold": Color(0.86, 0.29, 0.31), "cold_energy": 1.56,
		"ambient": Color(0.204, 0.145, 0.161), "ambient_energy": 0.16,
		"fog": Color(0.216, 0.149, 0.161), "fog_density": 0.01,
		"sign": Color(1.0, 0.267, 0.212),
		# nicotine and carpet dye
		"tint": Color(1.06, 0.9, 0.86),
	},
	&"high_roller": {
		# Baize and brass. The green comes off the tables, not the walls.
		"key": Color(1.0, 0.867, 0.667), "key_energy": 10.81,
		"cold": Color(0.267, 0.667, 0.443), "cold_energy": 1.32,
		"ambient": Color(0.11, 0.157, 0.129), "ambient_energy": 0.13,
		"fog": Color(0.125, 0.169, 0.145), "fog_density": 0.01,
		"sign": Color(1.0, 0.796, 0.267),
		# baize throwing green up the walls
		"tint": Color(0.96, 1.02, 0.94),
	},
	&"vault": {
		# Cold storage. Hard, blue-white, and the air completely still.
		"key": Color(0.878, 0.929, 1.0), "key_energy": 8.28,
		"cold": Color(0.361, 0.478, 0.71), "cold_energy": 1.68,
		"ambient": Color(0.106, 0.129, 0.176), "ambient_energy": 0.12,
		"fog": Color(0.11, 0.133, 0.184), "fog_density": 0.00,
		"sign": Color(0.706, 0.847, 1.0),
		# cold concrete, no warmth in it at all
		"tint": Color(0.9, 0.95, 1.04),
	},
	&"back_office": {
		# Fluorescent and flat. The least dramatic floor in the game, on purpose:
		# it is where the paperwork happens, and it should feel like it.
		"key": Color(0.933, 0.973, 0.898), "key_energy": 7.36,
		"cold": Color(0.62, 0.678, 0.573), "cold_energy": 1.92,
		"ambient": Color(0.169, 0.184, 0.153), "ambient_energy": 0.20,
		"fog": Color(0.176, 0.192, 0.161), "fog_density": 0.01,
		"sign": Color(0.851, 0.910, 0.62),
		# strip light and old paper
		"tint": Color(1.0, 1.0, 0.94),
	},
	&"engine_room": {
		# Hot. Every machine on the floor wired to yours, and the air full of it.
		"key": Color(1.0, 0.663, 0.322), "key_energy": 11.27,
		"cold": Color(0.902, 0.353, 0.157), "cold_energy": 1.80,
		"ambient": Color(0.235, 0.137, 0.086), "ambient_energy": 0.18,
		"fog": Color(0.267, 0.157, 0.098), "fog_density": 0.02,
		"sign": Color(1.0, 0.478, 0.129),
		# soot, and the fire under it
		"tint": Color(1.08, 0.94, 0.84),
	},
	&"the_house": {
		# No warmth anywhere. One cold light, deep shadow, and a sign the colour
		# of a screen rather than of a bulb.
		"key": Color(0.816, 0.867, 0.918), "key_energy": 6.44,
		"cold": Color(0.271, 0.318, 0.408), "cold_energy": 0.96,
		"ambient": Color(0.075, 0.086, 0.106), "ambient_energy": 0.09,
		"fog": Color(0.086, 0.098, 0.118), "fog_density": 0.01,
		"sign": Color(0.902, 0.937, 1.0),
		# clean, and colder than any of them
		"tint": Color(0.94, 0.94, 0.98),
	},
}


## Eases the room's light toward [param mood_id]. Unknown ids are ignored rather
## than defaulted, so a floor with a typo in its environment keeps the light it
## has instead of snapping back to the basement mid-run.
static func apply(mood_id: StringName, parts: Dictionary, environment: Environment,
		host: Node) -> void:
	if not MOODS.has(mood_id) or host == null:
		return
	var mood: Dictionary = MOODS[mood_id]
	var tween: Tween = host.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_light(tween, parts.get("key", null) as Light3D,
			mood["key"], float(mood["key_energy"]))
	_light(tween, parts.get("cold", null) as Light3D,
			mood["cold"], float(mood["cold_energy"]))
	# The shell itself takes a cast. Lamp colour alone moves the light in the
	# room and leaves the room the same colour underneath it; a floor that
	# has been lived in differently should be a different colour when the
	# lamp is off it. Held near white on purpose — this is a cast, not a
	# repaint, and the surfaces are scanned concrete and plaster that stop
	# looking like either if they are pushed.
	for key: String in ["ground", "back_wall"]:
		var surface: MeshInstance3D = parts.get(key, null) as MeshInstance3D
		if surface == null:
			continue
		var material: StandardMaterial3D = surface.material_override as StandardMaterial3D
		if material != null:
			tween.tween_property(material, "albedo_color",
					mood.get("tint", Color.WHITE) as Color, TRANSITION)
	var sign_label: Label3D = parts.get("sign", null) as Label3D
	if sign_label != null:
		# Overdriven for bloom; the glow shells keep their own faded alpha.
		tween.tween_property(sign_label, "modulate",
				(mood["sign"] as Color) * 2.2, TRANSITION)
		for child: Node in sign_label.get_children():
			var shell: Label3D = child as Label3D
			if shell != null:
				var tint: Color = mood["sign"] as Color
				tween.tween_property(shell, "modulate",
						Color(tint.r, tint.g, tint.b, shell.modulate.a),
						TRANSITION)
	var spill: Light3D = parts.get("sign_spill", null) as Light3D
	if spill != null:
		tween.tween_property(spill, "light_color", mood["sign"], TRANSITION)

	if environment != null:
		tween.tween_property(environment, "ambient_light_color",
				mood["ambient"], TRANSITION)
		tween.tween_property(environment, "ambient_light_energy",
				float(mood["ambient_energy"]), TRANSITION)
		tween.tween_property(environment, "fog_light_color", mood["fog"], TRANSITION)
		tween.tween_property(environment, "fog_density",
				float(mood["fog_density"]), TRANSITION)


static func _light(tween: Tween, light: Light3D, tint: Color, energy: float) -> void:
	if light == null:
		return
	tween.tween_property(light, "light_color", tint, TRANSITION)
	tween.tween_property(light, "light_energy", energy, TRANSITION)
