## Draws the reel symbols, rather than spelling them.
##
## The reels used to show the [member SymbolDef.glyph] token as text: "BB",
## "LE", "CH". Those exist because an id like [code]double_bar[/code] is metres
## wide at a readable size on a 0.3m drum — but a two-letter abbreviation means
## nothing to someone looking at a slot machine, and the reels are the one thing
## a player looks at on every single spin.
##
## So each symbol is drawn instead. Shapes are composed from signed distance
## functions and sampled once per pixel, which gives clean edges for a fraction
## of the cost of supersampling a boolean test — the whole set is nine 96px
## sprites and is built once, lazily, on a symbol's first landing.
##
## A symbol with no drawing here is not an error: [SlotView3D] falls back to the
## glyph text, so new content lands legibly without needing art first.
class_name SymbolArt
extends RefCounted

const SIZE: int = 96
## Ink for the outline. Every symbol is drawn on a cream reel strip, so the
## outline is what stops a mid-tone fill from dissolving into it.
const INK: Color = Color(0.09, 0.075, 0.063)
## Outline half-width, in normalised units where the sprite spans -1..1.
const STROKE: float = 0.085
## How far past the shapes the sprite is sampled, leaving room for the outline.
const MARGIN: float = 1.16

static var _cache: Dictionary = {}


## The sprite for [param symbol_id], or null if this symbol has no drawing.
## [param tint] is the symbol's own colour, used for the fill.
static func texture_for(symbol_id: StringName, tint: Color) -> ImageTexture:
	var key: String = "%s:%s" % [symbol_id, tint.to_html(false)]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	if not _has_drawing(symbol_id):
		return null
	# Printed ink, not a light source. A symbol at full saturation clips to white
	# under the machine's own lamp; pulling it down is what lets it behave like
	# something printed on the reel strip.
	var ink: Color = tint.darkened(0.22)
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# One pixel, in the -1..1 space the shapes are described in. Edges are faded
	# across exactly this much, which is what antialiases them.
	var pixel: float = 2.0 * MARGIN / float(SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			# Sampled slightly outside the shapes' own -1..1 range, which insets
			# them in the sprite. Without the margin a shape that reaches the
			# edge has its outline clipped off, and the symbol loses the dark
			# edge that separates it from the cream reel strip.
			var p: Vector2 = Vector2(
					((float(x) + 0.5) / float(SIZE) * 2.0 - 1.0) * MARGIN,
					((float(y) + 0.5) / float(SIZE) * 2.0 - 1.0) * MARGIN)
			var d: float = _distance(symbol_id, p)
			# Two coverages from one distance: the fill, and the fill dilated by
			# the stroke width. The difference between them is the outline.
			var fill: float = _coverage(d, pixel)
			var outer: float = _coverage(d - STROKE, pixel)
			if outer <= 0.0:
				continue
			var colour: Color = ink.lerp(INK, 1.0 - fill)
			if fill > 0.0:
				colour = _emboss(symbol_id, p, d, colour)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, outer))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Lights the fill from the upper left, so a symbol reads as struck enamel
## rather than as a flat sticker.
##
## The trick is that a signed distance field already knows which way its own
## edge faces: sampling it a little up-and-left and differencing gives the slope
## of the shape's boundary, which is exactly the shading term a bevel needs — no
## normals, no second pass.
static func _emboss(symbol_id: StringName, p: Vector2, d: float,
		colour: Color) -> Color:
	const REACH: float = 0.055
	# Up and to the left, and y runs downward in image space, so both components
	# are negative. Sampling the other way lights the bottom-right rim instead,
	# which reads as a symbol lit from below.
	var slope: float = _distance(symbol_id, p - Vector2(REACH, REACH)) - d
	# Fades out toward the middle of a shape, so only the rim is bevelled. The
	# band has to be wide enough to see: at a quarter of this the bevel sat
	# entirely underneath the outline and did nothing at all.
	var rim: float = clampf(1.0 + d / 0.62, 0.0, 1.0)
	var lift: float = clampf(slope / REACH, -1.0, 1.0) * rim
	if lift > 0.0:
		return colour.lerp(Color(1.0, 0.98, 0.94), lift * 0.62)
	return colour.lerp(INK, -lift * 0.5)


## A soft radial falloff, white, for tinting into a backlight behind a symbol.
## One texture serves every symbol: the colour comes from the material.
static func halo() -> ImageTexture:
	if _cache.has("halo"):
		return _cache["halo"] as ImageTexture
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var p: Vector2 = Vector2(
					(float(x) + 0.5) / float(SIZE) * 2.0 - 1.0,
					(float(y) + 0.5) / float(SIZE) * 2.0 - 1.0)
			# Squared falloff, then squared again: a linear ramp reads as a disc
			# with a hard edge, and what this wants is a glow with no edge at all.
			var falloff: float = clampf(1.0 - p.length(), 0.0, 1.0)
			var alpha: float = falloff * falloff * falloff
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache["halo"] = texture
	return texture


static func _has_drawing(symbol_id: StringName) -> bool:
	return symbol_id in [&"seven", &"cherry", &"bar", &"double_bar", &"bell",
			&"lemon", &"diamond", &"wild", &"skull"]


## Signed distance to the symbol: negative inside, positive outside.
static func _distance(symbol_id: StringName, p: Vector2) -> float:
	match symbol_id:
		&"seven":
			return _seven(p)
		&"cherry":
			return _cherry(p)
		&"bar":
			return _bars(p, 1)
		&"double_bar":
			return _bars(p, 2)
		&"bell":
			return _bell(p)
		&"lemon":
			return _lemon(p)
		&"diamond":
			return _diamond(p)
		&"wild":
			return _star(p)
		&"skull":
			return _skull(p)
		_:
			return 1.0


# --- the symbols -----------------------------------------------------------

## A seven: a top bar and a stroke leaning down-left off its right end.
##
## The lean has to be real. An almost-vertical stroke plus a crossbar reads as a
## capital F, which is what the first attempt drew.
static func _seven(p: Vector2) -> float:
	var top: float = _box(p - Vector2(0.0, -0.66), Vector2(0.54, 0.16), 0.04)
	# The stroke runs from under the bar's right end down to the left. Negating
	# the angle is deliberate: _rotate turns the sampling point, so the shape
	# ends up rotated the other way.
	var stroke: float = _box(_rotate(p - Vector2(0.1, 0.14), -0.34),
			Vector2(0.155, 0.7), 0.04)
	return min(top, stroke)


## Two fruit on stems, with a leaf.
static func _cherry(p: Vector2) -> float:
	var left: float = _circle(p - Vector2(-0.38, 0.42), 0.34)
	var right: float = _circle(p - Vector2(0.36, 0.5), 0.28)
	# Stems: thin boxes leaning in toward a joint above the fruit.
	var stem_left: float = _box(_rotate(p - Vector2(-0.24, -0.12), -0.42),
			Vector2(0.055, 0.42), 0.05)
	var stem_right: float = _box(_rotate(p - Vector2(0.2, -0.06), 0.34),
			Vector2(0.05, 0.4), 0.05)
	var leaf: float = _circle((p - Vector2(0.26, -0.62)) * Vector2(1.0, 2.6), 0.3)
	return min(min(min(left, right), min(stem_left, stem_right)), leaf)


## One or two horizontal bands, the way a bar symbol has always been drawn.
static func _bars(p: Vector2, count: int) -> float:
	if count <= 1:
		return _box(p, Vector2(0.72, 0.24), 0.07)
	var upper: float = _box(p - Vector2(0.0, -0.32), Vector2(0.72, 0.22), 0.07)
	var lower: float = _box(p - Vector2(0.0, 0.34), Vector2(0.72, 0.22), 0.07)
	return min(upper, lower)


## A bell: domed body flaring to a foot, with a clapper below.
static func _bell(p: Vector2) -> float:
	var dome: float = _circle(p - Vector2(0.0, -0.14), 0.46)
	# The flare, as a box widening downward — approximated by shearing x with y.
	var flare: Vector2 = Vector2(p.x / (1.0 + maxf(p.y + 0.1, 0.0) * 0.85), p.y)
	var body: float = _box(flare - Vector2(0.0, 0.06), Vector2(0.42, 0.42), 0.06)
	var foot: float = _box(p - Vector2(0.0, 0.5), Vector2(0.78, 0.11), 0.05)
	var clapper: float = _circle(p - Vector2(0.0, 0.72), 0.14)
	var crown: float = _circle(p - Vector2(0.0, -0.66), 0.11)
	return min(min(min(dome, body), min(foot, clapper)), crown)


## A tilted ellipse with a nub at each end.
##
## Scaling the sample point compresses the shape on that axis, so multiplying y
## by 1.5 gives a body two-thirds as tall as it is wide. The nubs are small
## rhombi placed on the ellipse's own axis, which is what makes it a lemon
## rather than a circle.
static func _lemon(p: Vector2) -> float:
	var q: Vector2 = _rotate(p, 0.36)
	var body: float = _circle(q * Vector2(1.0, 1.55), 0.66)
	var tip_a: float = _rhombus(q - Vector2(0.7, 0.0), Vector2(0.24, 0.13))
	var tip_b: float = _rhombus(q + Vector2(0.7, 0.0), Vector2(0.24, 0.13))
	return min(body, min(tip_a, tip_b))


## A rhombus with a facet notched out of the top, so it reads as cut stone.
static func _diamond(p: Vector2) -> float:
	var stone: float = _rhombus(p, Vector2(0.62, 0.86))
	var facet: float = _box(p - Vector2(0.0, -0.42), Vector2(0.26, 0.035), 0.02)
	# Subtract the facet from the stone: max(a, -b).
	return maxf(stone, -facet)


## A five-pointed star: five tapered spokes around a small hub.
##
## The taper must narrow *outward*. Dividing x by a factor that grows toward the
## tip widens it instead, and five spokes that do not come to a point merge with
## the hub into an asterisk — which is what the first attempt drew.
static func _star(p: Vector2) -> float:
	var d: float = _circle(p, 0.22)
	for i: int in 5:
		var angle: float = TAU * float(i) / 5.0
		# Each spoke spans y from -1 (the tip) to 0 (the hub) after this shift.
		var spoke: Vector2 = _rotate(p, angle) - Vector2(0.0, -0.5)
		# Dividing x by a factor below 1 makes the inside test stricter, so the
		# spoke is narrow where that factor is small — at the tip.
		var taper: float = maxf(1.0 + spoke.y * 0.95, 0.12)
		d = min(d, _box(Vector2(spoke.x / taper, spoke.y), Vector2(0.3, 0.5), 0.02))
	return d


## Cranium, jaw, two sockets and a nose.
static func _skull(p: Vector2) -> float:
	var cranium: float = _circle((p - Vector2(0.0, -0.18)) * Vector2(1.0, 1.12), 0.62)
	var jaw: float = _box(p - Vector2(0.0, 0.5), Vector2(0.34, 0.26), 0.12)
	var head: float = min(cranium, jaw)
	var eye_left: float = _circle((p - Vector2(-0.24, -0.16)) * Vector2(1.0, 1.25), 0.2)
	var eye_right: float = _circle((p - Vector2(0.24, -0.16)) * Vector2(1.0, 1.25), 0.2)
	var nose: float = _rhombus(p - Vector2(0.0, 0.16), Vector2(0.09, 0.14))
	var teeth: float = _box(p - Vector2(0.0, 0.5), Vector2(0.4, 0.03), 0.01)
	# Sockets and teeth are cut out of the head.
	return maxf(maxf(head, -min(eye_left, eye_right)), -min(nose, teeth))


# --- distance primitives ---------------------------------------------------

## How much of a pixel the shape covers, from its signed distance.
static func _coverage(d: float, pixel: float) -> float:
	return clampf(0.5 - d / pixel, 0.0, 1.0)


static func _circle(p: Vector2, radius: float) -> float:
	return p.length() - radius


## Rounded box. [param half] is the half-extent before the corner radius.
static func _box(p: Vector2, half: Vector2, radius: float) -> float:
	var q: Vector2 = p.abs() - (half - Vector2(radius, radius))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() \
			+ minf(maxf(q.x, q.y), 0.0) - radius


static func _rhombus(p: Vector2, half: Vector2) -> float:
	var q: Vector2 = p.abs()
	# Distance to the line x/half.x + y/half.y = 1, normalised by its gradient.
	var gradient: float = Vector2(1.0 / half.x, 1.0 / half.y).length()
	return (q.x / half.x + q.y / half.y - 1.0) / gradient


static func _rotate(p: Vector2, angle: float) -> Vector2:
	var c: float = cos(angle)
	var s: float = sin(angle)
	return Vector2(p.x * c - p.y * s, p.x * s + p.y * c)
