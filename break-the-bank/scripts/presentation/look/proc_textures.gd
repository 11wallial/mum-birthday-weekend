## Procedural texture synthesis for the machine and the room.
##
## The build promise is that nothing is fetched at launch, so there is no
## texture library to ship and no artist in the loop. Every map here is sampled
## out of [FastNoiseLite] into an [Image] at startup instead — the same bargain
## the audio system already makes, and for the same reason.
##
## Sampling is synchronous rather than using [NoiseTexture2D], which generates on
## a worker thread: a 256px map costs a few milliseconds once, and in exchange a
## material is never handed a blank texture on the first frame it is drawn.
class_name ProcTextures
extends RefCounted

## Big enough to hold grain at arm's length on a phone, small enough that the
## whole set costs well under a megabyte of VRAM.
const SIZE: int = 256

static var _cache: Dictionary = {}


## A blotchy greyscale map for multiplying into albedo: mostly light, with dark
## patches where dirt collects. [param contrast] above 1 deepens the patches.
static func grime(seed_value: int, frequency: float = 0.02,
		contrast: float = 1.0, floor_value: float = 0.35) -> ImageTexture:
	var key: String = "grime:%d:%f:%f:%f" % [seed_value, frequency, contrast, floor_value]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var noise: FastNoiseLite = _noise(seed_value, frequency, FastNoiseLite.TYPE_SIMPLEX)
	noise.fractal_octaves = 4
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in SIZE:
		for x: int in SIZE:
			# Noise is -1..1; fold to 0..1, then bias so clean beats dirty.
			var n: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var v: float = lerpf(floor_value, 1.0, pow(n, contrast))
			image.set_pixel(x, y, Color(v, v, v))
	var texture: ImageTexture = _finish(image)
	_cache[key] = texture
	return texture


## A roughness map: metal that has been handled is polished in patches and dull
## everywhere else, and a single value for the whole surface is what makes an
## untextured mesh read as plastic.
static func roughness(seed_value: int, low: float, high: float,
		frequency: float = 0.035) -> ImageTexture:
	var key: String = "rough:%d:%f:%f:%f" % [seed_value, low, high, frequency]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var noise: FastNoiseLite = _noise(seed_value, frequency, FastNoiseLite.TYPE_SIMPLEX)
	noise.fractal_octaves = 3
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in SIZE:
		for x: int in SIZE:
			var n: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var v: float = lerpf(low, high, n)
			image.set_pixel(x, y, Color(v, v, v))
	var texture: ImageTexture = _finish(image)
	_cache[key] = texture
	return texture


## A tangent-space normal map derived from the height of a noise field, so a
## flat box picks up cast-metal pitting and rolled-steel tooth.
static func bumps(seed_value: int, strength: float = 1.0,
		frequency: float = 0.06) -> ImageTexture:
	var key: String = "bump:%d:%f:%f" % [seed_value, strength, frequency]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var noise: FastNoiseLite = _noise(seed_value, frequency, FastNoiseLite.TYPE_SIMPLEX)
	noise.fractal_octaves = 3
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in SIZE:
		for x: int in SIZE:
			# Central differences on the height field. Wrapping the lookups keeps
			# the map tileable, which matters because these are used triplanar.
			var left: float = noise.get_noise_2d(float((x - 1 + SIZE) % SIZE), float(y))
			var right: float = noise.get_noise_2d(float((x + 1) % SIZE), float(y))
			var up: float = noise.get_noise_2d(float(x), float((y - 1 + SIZE) % SIZE))
			var down: float = noise.get_noise_2d(float(x), float((y + 1) % SIZE))
			var normal: Vector3 = Vector3(
					(left - right) * strength, (up - down) * strength, 1.0).normalized()
			image.set_pixel(x, y, Color(
					normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	var texture: ImageTexture = _finish(image)
	_cache[key] = texture
	return texture


## Vertical streaking, for rust weeping down a painted panel and water stains on
## concrete. Stretching the noise along Y is what separates a stain from a blob.
static func streaks(seed_value: int, floor_value: float = 0.45) -> ImageTexture:
	var key: String = "streak:%d:%f" % [seed_value, floor_value]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var noise: FastNoiseLite = _noise(seed_value, 0.05, FastNoiseLite.TYPE_SIMPLEX)
	noise.fractal_octaves = 4
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in SIZE:
		for x: int in SIZE:
			# Eight times the detail across than down: the streak is the anisotropy.
			var n: float = noise.get_noise_2d(float(x), float(y) * 0.125) * 0.5 + 0.5
			var v: float = lerpf(floor_value, 1.0, smoothstep(0.35, 0.85, n))
			image.set_pixel(x, y, Color(v, v, v))
	var texture: ImageTexture = _finish(image)
	_cache[key] = texture
	return texture


## Horizontal phosphor lines for the monitor. A CRT that is a flat lit rectangle
## reads as painted card; the line structure is what makes it a screen.
static func scanlines(line_height: int = 3) -> ImageTexture:
	var key: String = "scan:%d" % line_height
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in SIZE:
		# Every third row dark, with the rows either side of it half-lit, so the
		# gap has a soft edge rather than aliasing into moire at a distance.
		var phase: int = y % line_height
		var v: float = 0.62 if phase == 0 else (0.86 if phase == 1 else 1.0)
		for x: int in SIZE:
			image.set_pixel(x, y, Color(v, v, v))
	var texture: ImageTexture = _finish(image)
	_cache[key] = texture
	return texture


## Turns a sampled [Image] into a texture the renderer can minify safely.
##
## [method ImageTexture.create_from_image] does not build a mip chain, and
## without one every one of these maps aliases the moment it is drawn smaller
## than its own texels — which for a 256px map on a bezel a few centimetres wide
## is always. That aliasing is what made worn steel read as salt and pepper and
## painted panels read as leopard print, and no amount of retuning the noise
## fixed it, because the noise was never the problem.
static func _finish(image: Image) -> ImageTexture:
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _noise(seed_value: int, frequency: float, type: int) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.noise_type = type
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	return noise
