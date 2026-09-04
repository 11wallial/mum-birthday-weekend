## The material palette the machine and the room are built from.
##
## Every material is a named surface with a story — painted steel that has been
## chipped, brass that has been handled, concrete that has been stood on — rather
## than a colour with a metallic slider. They are built once and shared, so a
## thousand rivets cost one material.
##
## The palette is deliberately narrow and desaturated: worn olive, oxide, brass
## and cream, with saturation spent only on the four things that must be read at
## a glance — the phosphor readout, the sign, the payline and the jackpot seven.
class_name Materials
extends RefCounted

# The set's neutrals. Nothing here is a pure grey; each carries a little of the
# warm cast the key light throws, so an unlit face still belongs to the room.
const PAINT: Color = Color(0.153, 0.161, 0.129)
const PAINT_LIGHT: Color = Color(0.216, 0.224, 0.184)
const OXIDE: Color = Color(0.353, 0.180, 0.094)
const STEEL: Color = Color(0.404, 0.400, 0.392)
const BRASS: Color = Color(0.663, 0.494, 0.208)
const ENAMEL: Color = Color(0.596, 0.573, 0.522)
const CONCRETE: Color = Color(0.118, 0.114, 0.106)
const RUBBER: Color = Color(0.267, 0.078, 0.063)
const TIMBER: Color = Color(0.286, 0.212, 0.145)
const PAPER: Color = Color(0.792, 0.769, 0.714)

# The four saturated accents, and the only saturated colours in the set.
const PHOSPHOR: Color = Color(0.353, 1.0, 0.427)
const SIGN: Color = Color(1.0, 0.376, 0.078)
const JACKPOT: Color = Color(0.847, 0.153, 0.129)
const LAMP: Color = Color(1.0, 0.831, 0.616)
## The cold side of the set: the ambient, the fog, and the bounce off the left
## wall. Shadows lean cool against the warm key, and this is that blue — the
## fifth colour of the spine, and the only one the palette never wrote down.
const SHADOW: Color = Color(0.125, 0.145, 0.196)
## The accent, and the one rule about it: SCORE is reserved for scoring and
## state feedback — a plate lit because it paid, the payline bar on a win, a
## tube flaring as the total lands, the receipt's total. Nothing decorative
## may use it, so the player learns that this colour flashing means the
## machine paid. The swatches are in docs/PALETTE.md.
const SCORE: Color = Color(1.0, 0.71, 0.22)

## Scanned surfaces, by folder under [code]assets/textures/[/code]. Each supplies
## an albedo, an OpenGL-convention normal, and an ARM map packing ambient
## occlusion, roughness and metallic into one image's three channels.
##
## These replaced the noise that used to stand in for them. Sampled noise gets
## you variation; it does not get you the specific way paint chips at an edge or
## rust creeps along a weld, because those are not random — they are the record
## of something having happened to the surface. That is what a scan carries and
## what no amount of retuning a frequency will produce.
##
## The palette above still leads. Every scan is partly desaturated on the way in
## and every material tints it, so five unrelated photographs read as one set.
const SCANS: String = "res://assets/textures/%s/%s.jpg"

const WEATHERED_SHADER: String = "res://assets/shaders/weathered.gdshader"

static var _cache: Dictionary = {}
static var _scan_cache: Dictionary = {}
static var _weathered_shader: Shader = null


## Loads one map of one scanned set, or null when it is missing.
##
## Missing is not fatal on purpose: the procedural fallbacks below still work, so
## a checkout without the texture pack renders a plainer machine rather than a
## broken one.
static func scan(set_name: String, map_name: String) -> Texture2D:
	var key: String = "%s/%s" % [set_name, map_name]
	if _scan_cache.has(key):
		return _scan_cache[key] as Texture2D
	var path: String = SCANS % [set_name, map_name]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	else:
		push_warning("Materials: no scan at %s; falling back to noise" % path)
	_scan_cache[key] = texture
	return texture


## A scanned surface that weathers according to which way it faces: dust settling
## on what points up, grime running down what points out.
##
## Used for the large surfaces — chassis, plinth, floor, walls — where a face's
## orientation varies and the effect has something to work with. Small parts stay
## on [StandardMaterial3D]: a bolt head is one facing, so per-face weathering
## costs a shader and buys nothing.
##
## Falls back to [param fallback] when the scan or the shader is missing, so the
## machine still builds without the texture pack.
static func weathered(set_name: String, tint: Color, tiles_per_metre: float,
		normal_depth: float, dust: float, grime: float,
		fallback: StandardMaterial3D) -> Material:
	var key: String = "weathered:%s:%s:%f:%f:%f" % [
		set_name, tint.to_html(false), tiles_per_metre, dust, grime]
	if _cache.has(key):
		return _cache[key] as Material
	var albedo: Texture2D = scan(set_name, "albedo")
	if albedo == null or not ResourceLoader.exists(WEATHERED_SHADER):
		return fallback
	if _weathered_shader == null:
		_weathered_shader = load(WEATHERED_SHADER) as Shader
	if _weathered_shader == null:
		return fallback
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _weathered_shader
	material.set_shader_parameter(&"albedo_map", albedo)
	material.set_shader_parameter(&"normal_map", scan(set_name, "normal"))
	material.set_shader_parameter(&"arm_map", scan(set_name, "arm"))
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"tiles_per_metre", tiles_per_metre)
	material.set_shader_parameter(&"normal_depth", normal_depth)
	material.set_shader_parameter(&"dust_amount", dust)
	material.set_shader_parameter(&"grime_amount", grime)
	material.set_shader_parameter(&"dust_colour", Color(0.325, 0.310, 0.271))
	_cache[key] = material
	return material


## Dresses [param material] in a scanned set: albedo, normal, and the ARM map
## wired to the three channels it packs.
##
## Returns false when the set is missing, so a caller can fall back.
static func _dress(material: StandardMaterial3D, set_name: String,
		normal_depth: float, tiles_per_metre: float, phase: int = 0) -> bool:
	var albedo: Texture2D = scan(set_name, "albedo")
	if albedo == null:
		return false
	material.albedo_texture = albedo
	var normal: Texture2D = scan(set_name, "normal")
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = normal_depth
	var arm: Texture2D = scan(set_name, "arm")
	if arm != null:
		# One image, three channels: AO in red, roughness in green, metallic in
		# blue. Godot reads a channel per map, so the packing costs a third of
		# the bytes three greyscale images would.
		material.ao_enabled = true
		material.ao_texture = arm
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.ao_light_affect = 0.35
		material.roughness_texture = arm
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.metallic_texture = arm
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	_triplanar(material, tiles_per_metre)
	# Every part built from one scan otherwise shares a tiling phase, so the
	# same scratch lands in the same place on the rail, the bezel and the
	# crown gears and the eye reads the repeat as pattern. The seed each
	# caller already passes for the procedural fallback offsets it instead.
	if phase != 0:
		var drift: float = float(phase % 97) / 97.0
		var lift: float = float((phase * 31) % 89) / 89.0
		material.uv1_offset = Vector3(drift, lift, 0.0)
	return true


## Chipped industrial paint over steel: the machine's chassis and the room.
static func painted(tint: Color = PAINT, seed_value: int = 11) -> StandardMaterial3D:
	return _build("paint:%s:%d" % [tint.to_html(false), seed_value], func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = tint
		if _dress(material, "painted_metal", 1.0, 0.9):
			material.metallic_texture = null
			material.metallic = 0.18
			material.metallic_specular = 0.42
			return material
		material.albedo_texture = ProcTextures.grime(seed_value, 0.012, 1.05, 0.82)
		material.roughness_texture = ProcTextures.roughness(seed_value + 1, 0.72, 0.84, 0.012)
		material.normal_enabled = true
		material.normal_texture = ProcTextures.bumps(seed_value + 2, 0.8, 0.02)
		material.normal_scale = 0.1
		material.metallic = 0.25
		material.metallic_specular = 0.4
		_triplanar(material, 3.6)
		return material)


## Bare metal that has rusted where it was left wet. Used for the frame ends,
## the plinth straps and anything that reads as structural.
static func rusted(seed_value: int = 23) -> StandardMaterial3D:
	return _build("rust:%d" % seed_value, func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = OXIDE
		if _dress(material, "rusted_metal", 1.3, 1.1):
			# Rust is oxide, not metal, whatever the plate underneath it is.
			material.metallic_texture = null
			material.metallic = 0.08
			return material
		material.albedo_texture = ProcTextures.streaks(seed_value, 0.58)
		material.roughness_texture = ProcTextures.roughness(seed_value + 1, 0.76, 0.96)
		material.normal_enabled = true
		material.normal_texture = ProcTextures.bumps(seed_value + 2, 1.4, 0.09)
		material.normal_scale = 0.3
		material.metallic = 0.15
		_triplanar(material, 2.4)
		return material)


## Handled brass: bright where a hand has polished it, dark in the recesses.
static func brass(seed_value: int = 37) -> StandardMaterial3D:
	return _build("brass:%d" % seed_value, func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = BRASS
		# 2.8 tiles/m, not 7.5. At 7.5 the scan repeated every 13cm, and the
		# counter rail is 1.88m of it — fourteen visible repeats reading as
		# a printed pattern rather than as metal.
		if _dress(material, "plate_metal", 0.42, 2.8, seed_value):
			# Brass is a full metal whatever the scan's own metallic channel
			# says: the plate it was scanned from is steel, and only the wear
			# pattern is being borrowed.
			material.metallic_texture = null
			material.metallic = 1.0
			return material
		material.albedo_texture = ProcTextures.grime(seed_value, 0.024, 1.2, 0.62)
		material.roughness_texture = ProcTextures.roughness(seed_value + 1, 0.2, 0.56, 0.022)
		material.normal_enabled = true
		material.normal_texture = ProcTextures.bumps(seed_value + 2, 0.5, 0.12)
		material.normal_scale = 0.12
		material.metallic = 1.0
		_triplanar(material, 2.6)
		return material)


## Machined steel: bezels, hinges, the lever shaft. Cleaner than the chassis
## because these are the parts that get touched.
static func machined(tint: Color = STEEL, seed_value: int = 53) -> StandardMaterial3D:
	return _build("steel:%s:%d" % [tint.to_html(false), seed_value], func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = tint
		if _dress(material, "plate_metal", 0.5, 3.2, seed_value):
			material.metallic_texture = null
			material.metallic = 1.0
			return material
		material.albedo_texture = ProcTextures.grime(seed_value, 0.022, 1.0, 0.82)
		material.roughness_texture = ProcTextures.roughness(seed_value + 1, 0.26, 0.46, 0.02)
		material.metallic = 1.0
		_triplanar(material, 3.2)
		return material)


## Baked enamel, as on a reel strip or a dial face: smooth, near-dielectric, and
## only lightly soiled, so printed symbols stay legible against it.
static func enamel(tint: Color = ENAMEL, seed_value: int = 67) -> StandardMaterial3D:
	return _build("enamel:%s:%d" % [tint.to_html(false), seed_value], func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = tint
		material.albedo_texture = ProcTextures.grime(seed_value, 0.05, 1.0, 0.82)
		material.roughness = 0.38
		material.metallic = 0.0
		_triplanar(material, 1.4)
		return material)


## Poured concrete: the plinth and the floor. Coarse, matte, water-stained.
static func concrete(seed_value: int = 83) -> StandardMaterial3D:
	return _build("concrete:%d" % seed_value, func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = CONCRETE
		if _dress(material, "concrete", 0.9, 0.55):
			material.metallic_texture = null
			material.metallic = 0.0
			return material
		material.albedo_texture = ProcTextures.grime(seed_value, 0.02, 1.2, 0.7)
		material.roughness_texture = ProcTextures.roughness(seed_value + 1, 0.86, 0.98)
		material.normal_enabled = true
		material.normal_texture = ProcTextures.bumps(seed_value + 2, 1.1, 0.14)
		material.normal_scale = 0.22
		material.metallic = 0.0
		_triplanar(material, 2.6)
		return material)


## Perished rubber hose. Matte and slightly dusty, never shiny.
static func rubber(tint: Color = RUBBER, seed_value: int = 97) -> StandardMaterial3D:
	return _build("rubber:%s:%d" % [tint.to_html(false), seed_value], func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = tint
		material.albedo_texture = ProcTextures.grime(seed_value, 0.11, 1.3, 0.6)
		material.roughness = 0.85
		material.metallic = 0.0
		_triplanar(material, 1.6)
		return material)


## Oiled hardwood, for the lever grip and anything that predates the machine.
static func timber(seed_value: int = 101) -> StandardMaterial3D:
	return _build("timber:%d" % seed_value, func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = TIMBER
		material.albedo_texture = ProcTextures.streaks(seed_value, 0.62)
		material.roughness = 0.6
		material.metallic = 0.0
		_triplanar(material, 1.2)
		return material)


## An emissive surface that also survives being unlit — a sign, a phosphor
## screen, a payline. [param energy] is in the same units as a light's.
static func glowing(tint: Color, energy: float = 2.0) -> StandardMaterial3D:
	return _build("glow:%s:%f" % [tint.to_html(false), energy], func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = tint
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = energy
		material.roughness = 0.5
		return material)


## Applies world-space triplanar mapping. Every mesh in the set is an untextured
## primitive with no meaningful UVs, so projecting from world space is the only
## way the maps land at a consistent physical scale — and it means a 0.2m bolt
## and a 14m floor show grain of the same size.
static func phosphor_glass() -> StandardMaterial3D:
	return _build("phosphor", func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.008, 0.016, 0.011)
		material.emission_enabled = true
		material.emission = Color(0.031, 0.098, 0.051)
		material.emission_energy_multiplier = 0.28
		material.emission_texture = ProcTextures.scanlines()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.roughness = 0.18
		material.metallic = 0.0
		return material)


## A pressed-glass lamp cover, lit or dead.
##
## Used for the hold lamps and the nudge chevrons: a control whose state lives
## only in a panel at the bottom of the screen is one the player has to keep
## translating back to the drum it belongs to, so the machine carries it too.
## Deliberately not cached — every lamp needs its own emission to switch.
static func lamp_glass(tint: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.35, 1.0)
	material.roughness = 0.32
	material.metallic = 0.0
	material.emission_enabled = energy > 0.0
	material.emission = tint
	material.emission_energy_multiplier = energy
	return material


## An unlit dark face for a readout to sit on — the odds strip, a dial window.
## Polished chrome, for the one part of the machine that is kept clean: the
## window frame the reels are read through. Every other metal here carries a
## roughness map, and on a full metal that breaks the highlight into a cast,
## hammered surface — right for the chassis, wrong for a bezel someone wipes.
static func chrome() -> StandardMaterial3D:
	return _build("chrome", func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.616, 0.608, 0.596)
		material.albedo_texture = ProcTextures.grime(91, 0.02, 1.0, 0.9)
		material.metallic = 1.0
		material.roughness = 0.24
		_triplanar(material, 2.0)
		return material)


## A plain, matte, near-black interior — the inside of the reel housing. Wear
## maps belong on surfaces the world has touched; the inside of a sealed box is
## not one of them, and putting grain there just adds noise where the eye is
## trying to read three symbols.
static func cavity() -> StandardMaterial3D:
	return _build("cavity", func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.055, 0.051, 0.043)
		material.roughness = 0.92
		material.metallic = 0.0
		return material)


static func readout_face() -> StandardMaterial3D:
	return _build("readout_face", func() -> StandardMaterial3D:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.027, 0.024, 0.02)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return material)


static func _triplanar(material: StandardMaterial3D, scale: float) -> void:
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(scale, scale, scale)
	# Anisotropic, not merely mipmapped. Almost every surface here is seen at a
	# grazing angle — the chassis top, the bezel's frame, the floor running away
	# from camera — and that is exactly the case a plain mip chain blurs along
	# one axis and shimmers along the other.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


static func _build(key: String, factory: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key] as StandardMaterial3D
