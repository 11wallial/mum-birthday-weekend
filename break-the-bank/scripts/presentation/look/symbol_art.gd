## The reel symbols, as data: each is a short instruction list of distance
## primitives, and the drawing happens in whichever interpreter is asked.
##
## There are two interpreters and neither is the original. [method ops_for]
## feeds the GPU bake in [code]reel_plate.gdshader[/code], which prints the
## whole strip at boot; [method texture_for] rasterises the same instructions on
## the CPU, which is the fallback for a symbol that lands before the bake or in
## a context with no viewport. One instruction list serving both is what stops
## the print on the drum and the sprite behind it drifting apart.
##
## A symbol with no instructions here is not an error: [SlotView3D] falls back
## to the glyph text and [ReelPrint] bakes a plain plate with the glyph printed
## on it, so new content lands legibly without needing art first.
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

# One instruction is twelve floats:
#   [0] primitive  [1] carve flag  [2] rotation  [3] warp amount
#   [4] pos.x  [5] pos.y  [6] scale.x  [7] scale.y
#   [8..10] primitive params  [11] warp base
# The sample point is rotated, translated, warped, then scaled — in that order,
# on both interpreters. reel_plate.gdshader decodes the same layout.
const FLOATS_PER_OP: int = 12
const MAX_OPS: int = 12
const OP_CIRCLE: float = 0.0
const OP_BOX: float = 1.0
const OP_RHOMBUS: float = 2.0
## A box whose x narrows as y descends: the bell's flare.
const OP_SHEAR_BOX: float = 3.0
## A box whose x narrows toward the tip: the star's spokes.
const OP_TAPER_BOX: float = 4.0

static var _cache: Dictionary = {}
static var _ops_cache: Dictionary = {}


## Printing strength for a symbol's tint: ink, not a light source. A symbol at
## full saturation clips to white under the machine's own lamp.
static func plate_ink(tint: Color) -> Color:
	return tint.darkened(0.22)


## The instruction list for [param symbol_id], or an empty array when the
## symbol has no drawing.
static func ops_for(symbol_id: StringName) -> PackedFloat32Array:
	if _ops_cache.has(symbol_id):
		return _ops_cache[symbol_id] as PackedFloat32Array
	var ops: PackedFloat32Array = _build_ops(symbol_id)
	_ops_cache[symbol_id] = ops
	return ops


## The sprite for [param symbol_id], or null if this symbol has no drawing.
## [param tint] is the symbol's own colour, used for the fill.
static func texture_for(symbol_id: StringName, tint: Color) -> ImageTexture:
	var key: String = "%s:%s" % [symbol_id, tint.to_html(false)]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var ops: PackedFloat32Array = ops_for(symbol_id)
	if ops.is_empty():
		return null
	var ink: Color = plate_ink(tint)
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# One pixel, in the -1..1 space the shapes are described in. Edges are faded
	# across exactly this much, which is what antialiases them.
	var pixel: float = 2.0 * MARGIN / float(SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			# Sampled slightly outside the shapes' own -1..1 range, which insets
			# them in the sprite so the outline is never clipped off.
			var p: Vector2 = Vector2(
					((float(x) + 0.5) / float(SIZE) * 2.0 - 1.0) * MARGIN,
					((float(y) + 0.5) / float(SIZE) * 2.0 - 1.0) * MARGIN)
			var d: float = _distance(ops, p)
			# Two coverages from one distance: the fill, and the fill dilated by
			# the stroke width. The difference between them is the outline.
			var fill: float = _coverage(d, pixel)
			var outer: float = _coverage(d - STROKE, pixel)
			if outer <= 0.0:
				continue
			var colour: Color = ink.lerp(INK, 1.0 - fill)
			if fill > 0.0:
				colour = _emboss(ops, p, d, colour)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, outer))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Lights the fill from the upper left, so a symbol reads as struck enamel
## rather than as a flat sticker. A signed distance field already knows which
## way its own edge faces: sampling it a little up-and-left and differencing
## gives the slope of the boundary, which is exactly the shading a bevel needs.
static func _emboss(ops: PackedFloat32Array, p: Vector2, d: float,
		colour: Color) -> Color:
	const REACH: float = 0.055
	var slope: float = _distance(ops, p - Vector2(REACH, REACH)) - d
	# Fades out toward the middle of a shape, so only the rim is bevelled.
	var rim: float = clampf(1.0 + d / 0.62, 0.0, 1.0)
	var lift: float = clampf(slope / REACH, -1.0, 1.0) * rim
	if lift > 0.0:
		return colour.lerp(Color(1.0, 0.98, 0.94), lift * 0.62)
	return colour.lerp(INK, -lift * 0.5)


## A soft radial falloff, white, for tinting into a backlight behind a symbol.
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
			# with a hard edge, and this wants a glow with no edge at all.
			var falloff: float = clampf(1.0 - p.length(), 0.0, 1.0)
			var alpha: float = falloff * falloff * falloff
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache["halo"] = texture
	return texture


# --- the interpreter -------------------------------------------------------

## Signed distance to the symbol: negative inside, positive outside. Additive
## instructions fold with min; carving ones cut the result afterwards. Both
## interpreters use this two-accumulator fold, and every shape's carves follow
## its adds, so the fold order never changes a result.
static func _distance(ops: PackedFloat32Array, p: Vector2) -> float:
	var added: float = 1.0e6
	var carved: float = -1.0e6
	var count: int = ops.size() / FLOATS_PER_OP
	for i: int in count:
		var base: int = i * FLOATS_PER_OP
		var kind: float = ops[base]
		var q: Vector2 = _rotate(p, ops[base + 2]) \
				- Vector2(ops[base + 4], ops[base + 5])
		if kind == OP_SHEAR_BOX:
			q.x /= 1.0 + maxf(q.y + ops[base + 11], 0.0) * ops[base + 3]
		elif kind == OP_TAPER_BOX:
			q.x /= maxf(1.0 + q.y * ops[base + 3], ops[base + 11])
		q *= Vector2(ops[base + 6], ops[base + 7])
		var d: float
		if kind == OP_CIRCLE:
			d = _circle(q, ops[base + 8])
		elif kind == OP_RHOMBUS:
			d = _rhombus(q, Vector2(ops[base + 8], ops[base + 9]))
		else:
			d = _box(q, Vector2(ops[base + 8], ops[base + 9]), ops[base + 10])
		if ops[base + 1] > 0.5:
			carved = maxf(carved, -d)
		else:
			added = minf(added, d)
	return maxf(added, carved)


# --- the symbols -----------------------------------------------------------

static func _build_ops(symbol_id: StringName) -> PackedFloat32Array:
	var ops: PackedFloat32Array = PackedFloat32Array()
	match symbol_id:
		&"seven":
			# A top bar and a stroke leaning down-left off its right end. The
			# lean has to be real: an almost-vertical stroke plus a crossbar
			# reads as a capital F.
			_add(ops, OP_BOX, false, 0.0, Vector2(0.0, -0.66),
					[0.54, 0.16, 0.04])
			_add(ops, OP_BOX, false, -0.34, _rotate(Vector2(0.1, 0.14), -0.34),
					[0.155, 0.7, 0.04])
		&"cherry":
			# Two fruit on stems, with a leaf.
			_add(ops, OP_CIRCLE, false, 0.0, Vector2(-0.38, 0.42), [0.34])
			_add(ops, OP_CIRCLE, false, 0.0, Vector2(0.36, 0.5), [0.28])
			_add(ops, OP_BOX, false, -0.42,
					_rotate(Vector2(-0.24, -0.12), -0.42), [0.055, 0.42, 0.05])
			_add(ops, OP_BOX, false, 0.34,
					_rotate(Vector2(0.2, -0.06), 0.34), [0.05, 0.4, 0.05])
			_add(ops, OP_CIRCLE, false, 0.0, Vector2(0.26, -0.62), [0.3],
					Vector2(1.0, 2.6))
		&"bar":
			_add(ops, OP_BOX, false, 0.0, Vector2.ZERO, [0.72, 0.24, 0.07])
		&"double_bar":
			_add(ops, OP_BOX, false, 0.0, Vector2(0.0, -0.32),
					[0.72, 0.22, 0.07])
			_add(ops, OP_BOX, false, 0.0, Vector2(0.0, 0.34),
					[0.72, 0.22, 0.07])
		&"bell":
			# Domed body flaring to a foot, with a clapper below. The flare is
			# the shear warp; its base is the original 0.1 plus this op's 0.06
			# translation, because the warp now runs after the translate.
			_add(ops, OP_CIRCLE, false, 0.0, Vector2(0.0, -0.14), [0.46])
			_add(ops, OP_SHEAR_BOX, false, 0.0, Vector2(0.0, 0.06),
					[0.42, 0.42, 0.06], Vector2.ONE, 0.85, 0.16)
			_add(ops, OP_BOX, false, 0.0, Vector2(0.0, 0.5), [0.78, 0.11, 0.05])
			_add(ops, OP_CIRCLE, false, 0.0, Vector2(0.0, 0.72), [0.14])
			_add(ops, OP_CIRCLE, false, 0.0, Vector2(0.0, -0.66), [0.11])
		&"lemon":
			# A tilted ellipse with a nub at each end. The nubs sit on the
			# ellipse's own axis, which is what makes it a lemon, not a circle.
			_add(ops, OP_CIRCLE, false, 0.36, Vector2.ZERO, [0.66],
					Vector2(1.0, 1.55))
			_add(ops, OP_RHOMBUS, false, 0.36, Vector2(0.7, 0.0), [0.24, 0.13])
			_add(ops, OP_RHOMBUS, false, 0.36, Vector2(-0.7, 0.0), [0.24, 0.13])
		&"diamond":
			# A rhombus with a facet notched out of the top: cut stone.
			_add(ops, OP_RHOMBUS, false, 0.0, Vector2.ZERO, [0.62, 0.86])
			_add(ops, OP_BOX, true, 0.0, Vector2(0.0, -0.42),
					[0.26, 0.035, 0.02])
		&"wild":
			# Five tapered spokes around a small hub. The taper must narrow
			# outward, or five blunt spokes merge with the hub into an asterisk.
			_add(ops, OP_CIRCLE, false, 0.0, Vector2.ZERO, [0.22])
			for i: int in 5:
				_add(ops, OP_TAPER_BOX, false, TAU * float(i) / 5.0,
						Vector2(0.0, -0.5), [0.3, 0.5, 0.02], Vector2.ONE,
						0.95, 0.12)
		&"skull":
			# Cranium, jaw, then sockets, nose and teeth carved out.
			_add(ops, OP_CIRCLE, false, 0.0, Vector2(0.0, -0.18), [0.62],
					Vector2(1.0, 1.12))
			_add(ops, OP_BOX, false, 0.0, Vector2(0.0, 0.5), [0.34, 0.26, 0.12])
			_add(ops, OP_CIRCLE, true, 0.0, Vector2(-0.24, -0.16), [0.2],
					Vector2(1.0, 1.25))
			_add(ops, OP_CIRCLE, true, 0.0, Vector2(0.24, -0.16), [0.2],
					Vector2(1.0, 1.25))
			_add(ops, OP_RHOMBUS, true, 0.0, Vector2(0.0, 0.16), [0.09, 0.14])
			_add(ops, OP_BOX, true, 0.0, Vector2(0.0, 0.5), [0.4, 0.03, 0.01])
		_:
			pass
	return ops


static func _add(ops: PackedFloat32Array, kind: float, carve: bool, rot: float,
		pos: Vector2, params: Array, scale: Vector2 = Vector2.ONE,
		warp_amount: float = 0.0, warp_base: float = 0.0) -> void:
	ops.append(kind)
	ops.append(1.0 if carve else 0.0)
	ops.append(rot)
	ops.append(warp_amount)
	ops.append(pos.x)
	ops.append(pos.y)
	ops.append(scale.x)
	ops.append(scale.y)
	for i: int in 3:
		ops.append(float(params[i]) if i < params.size() else 0.0)
	ops.append(warp_base)


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
