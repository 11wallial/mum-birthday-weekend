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
## Every symbol is printed in two inks plus the press's own black — the fruit
## and its leaf, the bar and its lettering, the bank and its columns — with a
## heavy keyline, a drop shadow and a gloss, which is the fruit-machine plate
## the first playtest asked for by name. A symbol with no instructions here is
## not an error: [SlotView3D] falls back to the glyph text and [ReelPrint]
## bakes a plain plate with the glyph printed on it, so new content lands
## legibly without needing art first.
class_name SymbolArt
extends RefCounted

const SIZE: int = 96
## Ink for the outline. Every symbol is drawn on a cream reel strip, so the
## outline is what stops a mid-tone fill from dissolving into it.
const INK: Color = Color(0.09, 0.075, 0.063)
## Outline half-width, in normalised units where the sprite spans -1..1.
## Heavy: a fruit-machine plate is a keyline first and a fill second.
const STROKE: float = 0.12
## How far past the shapes the sprite is sampled, leaving room for the outline.
const MARGIN: float = 1.2

# One instruction is twelve floats:
#   [0] primitive  [1] paint  [2] rotation  [3] warp amount
#   [4] pos.x  [5] pos.y  [6] scale.x  [7] scale.y
#   [8..10] primitive params  [11] warp base
# The sample point is rotated, translated, warped, then scaled — in that order,
# on both interpreters. reel_plate.gdshader decodes the same layout.
#
# Paint says what the op does to the print: adds in the symbol's first ink,
# carves a hole, adds in the second ink, or adds in the press's black. Adds
# are painted in order, later on top, so a leaf drawn after the fruit sits on
# it; carves cut everything.
const FLOATS_PER_OP: int = 12
const MAX_OPS: int = 14
const OP_CIRCLE: float = 0.0
const OP_BOX: float = 1.0
const OP_RHOMBUS: float = 2.0
## A box whose x narrows as y descends: the bell's flare.
const OP_SHEAR_BOX: float = 3.0
## A box whose x narrows toward the tip: the star's spokes, the bank's roof.
const OP_TAPER_BOX: float = 4.0
const PAINT_INK: float = 0.0
const PAINT_CARVE: float = 1.0
const PAINT_INK2: float = 2.0
const PAINT_BLACK: float = 3.0

static var _cache: Dictionary = {}
static var _ops_cache: Dictionary = {}


## Printing strength for a symbol's tint: ink, not a light source. A symbol at
## full saturation clips to white under the machine's own lamp.
static func plate_ink(tint: Color) -> Color:
	return tint.darkened(0.12)


## The instruction list for [param symbol_id], or an empty array when the
## symbol has no drawing.
static func ops_for(symbol_id: StringName) -> PackedFloat32Array:
	if _ops_cache.has(symbol_id):
		return _ops_cache[symbol_id] as PackedFloat32Array
	var ops: PackedFloat32Array = _build_ops(symbol_id)
	_ops_cache[symbol_id] = ops
	return ops


## Lettering the press adds over a symbol's drawing, as [text, y] pairs in
## the -1..1 space, for the plates that are words as much as pictures.
static func captions_for(symbol_id: StringName) -> Array:
	match symbol_id:
		&"bar":
			return [["BAR", 0.02]]
		&"double_bar":
			return [["BAR", -0.32], ["BAR", 0.34]]
		&"bank":
			return [["BANK", 0.8]]
		_:
			return []


## The sprite for [param symbol_id], or null if this symbol has no drawing.
## [param tint] is the symbol's own colour and [param tint2] its second ink.
static func texture_for(symbol_id: StringName, tint: Color,
		tint2: Color = Color(0.0, 0.0, 0.0, 0.0)) -> ImageTexture:
	var second: Color = tint2 if tint2.a > 0.0 else tint
	var key: String = "%s:%s:%s" % [symbol_id, tint.to_html(false), second.to_html(false)]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var ops: PackedFloat32Array = ops_for(symbol_id)
	if ops.is_empty():
		return null
	var inks: Array[Color] = [plate_ink(tint), INK, plate_ink(second), INK]
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
			var sample: Vector2 = _sample(ops, p)
			var d: float = sample.x
			# Two coverages from one distance: the fill, and the fill dilated by
			# the stroke width. The difference between them is the outline.
			var fill: float = _coverage(d, pixel)
			var outer: float = _coverage(d - STROKE, pixel)
			if outer <= 0.0:
				continue
			var paint: Color = inks[clampi(int(sample.y), 0, 3)]
			var colour: Color = paint.lerp(INK, 1.0 - fill)
			if fill > 0.0:
				colour = _shade(ops, p, d, colour)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, outer))
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Lights the fill from the upper left, so a symbol reads as struck enamel
## rather than as a flat sticker, and lays a gloss across its shoulder. A
## signed distance field already knows which way its own edge faces: sampling
## it a little up-and-left and differencing gives the slope of the boundary,
## which is exactly the shading a bevel needs.
static func _shade(ops: PackedFloat32Array, p: Vector2, d: float,
		colour: Color) -> Color:
	const REACH: float = 0.055
	var slope: float = _sample(ops, p - Vector2(REACH, REACH)).x - d
	# Fades out toward the middle of a shape, so only the rim is bevelled.
	var rim: float = clampf(1.0 + d / 0.62, 0.0, 1.0)
	var lift: float = clampf(slope / REACH, -1.0, 1.0) * rim
	var lit: Color = colour
	if lift > 0.0:
		lit = colour.lerp(Color(1.0, 0.98, 0.94), lift * 0.55)
	else:
		lit = colour.lerp(INK, -lift * 0.45)
	# The gloss: a soft cap of light high on the left, inside the ink only.
	var gloss: float = gloss_at(p, d)
	return lit.lerp(Color(1.0, 0.99, 0.96), gloss)


## How much shine sits at [param p], for a point [param d] inside a shape.
## Shared with the shader's reading of the same curve.
static func gloss_at(p: Vector2, d: float) -> float:
	var inside: float = clampf(-d / 0.16, 0.0, 1.0)
	var cap: float = 1.0 - smoothstep(0.0, 0.62, (p - Vector2(-0.3, -0.42)).length())
	return cap * inside * 0.42


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

## Signed distance to the symbol, and which ink covers the point: negative
## distance inside, positive outside; the ink is that of the last additive
## op the point is inside, or the nearest one when it is outside all of them.
## Additive instructions fold with min; carving ones cut the result
## afterwards. Both interpreters use this fold, so the fold order never
## changes a result.
static func _sample(ops: PackedFloat32Array, p: Vector2) -> Vector2:
	var added: float = 1.0e6
	var carved: float = -1.0e6
	var paint: float = PAINT_INK
	var nearest: float = 1.0e6
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
		var mode: float = ops[base + 1]
		if mode == PAINT_CARVE:
			carved = maxf(carved, -d)
			continue
		added = minf(added, d)
		# Painter's order: whatever was drawn last over this point owns it.
		if d <= 0.0 or d < nearest:
			if d <= 0.0 or added >= 0.0:
				paint = mode
			nearest = minf(nearest, d)
	return Vector2(maxf(added, carved), paint)


## The signed distance alone, for callers that only want the shape.
static func _distance(ops: PackedFloat32Array, p: Vector2) -> float:
	return _sample(ops, p).x


# --- the symbols -----------------------------------------------------------

static func _build_ops(symbol_id: StringName) -> PackedFloat32Array:
	var ops: PackedFloat32Array = PackedFloat32Array()
	match symbol_id:
		&"seven":
			# A top bar and a stroke leaning down-left off its right end. The
			# lean has to be real: an almost-vertical stroke plus a crossbar
			# reads as a capital F. A gold serif on the bar's left end.
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.66),
					[0.56, 0.17, 0.04])
			_add(ops, OP_BOX, PAINT_INK, -0.34, _rotate(Vector2(0.1, 0.14), -0.34),
					[0.16, 0.7, 0.04])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(-0.5, -0.56),
					[0.08, 0.26, 0.03])
		&"cherry":
			# Two fruit on stems, with a leaf. Stems in the press's black, leaf
			# in the second ink, drawn after the fruit so it sits on them.
			_add(ops, OP_BOX, PAINT_BLACK, -0.42,
					_rotate(Vector2(-0.24, -0.16), -0.42), [0.05, 0.44, 0.04])
			_add(ops, OP_BOX, PAINT_BLACK, 0.34,
					_rotate(Vector2(0.2, -0.1), 0.34), [0.05, 0.42, 0.04])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(-0.38, 0.44), [0.36])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.38, 0.5), [0.3])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.5, _rotate(Vector2(0.3, -0.64), 0.5),
					[0.28], Vector2(1.0, 2.4))
		&"lemon":
			# A fat tilted ellipse with a round nub at each end, and a leaf.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.36, Vector2.ZERO, [0.7],
					Vector2(1.0, 1.35))
			_add(ops, OP_CIRCLE, PAINT_INK, 0.36, Vector2(0.72, 0.0), [0.15])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.36, Vector2(-0.72, 0.0), [0.15])
			_add(ops, OP_CIRCLE, PAINT_INK2, -0.9, _rotate(Vector2(0.5, -0.7), -0.9),
					[0.2], Vector2(1.0, 2.2))
		&"orange":
			# A whole fruit, a stub of stem and one leaf.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, 0.08), [0.74])
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.0, -0.72), [0.06, 0.14, 0.03])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.55, _rotate(Vector2(0.32, -0.74), 0.55),
					[0.26], Vector2(1.0, 2.3))
		&"watermelon":
			# A slice: the rind in the second ink, the flesh on it, three
			# seeds in black, and the straight edge cut across the top.
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, -0.12), [0.92])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.12), [0.64])
			_add(ops, OP_CIRCLE, PAINT_BLACK, 0.3, _rotate(Vector2(-0.3, 0.24), 0.3),
					[0.08], Vector2(1.0, 1.7))
			_add(ops, OP_CIRCLE, PAINT_BLACK, 0.0, Vector2(0.02, 0.4), [0.08],
					Vector2(1.0, 1.7))
			_add(ops, OP_CIRCLE, PAINT_BLACK, -0.3, _rotate(Vector2(0.32, 0.22), -0.3),
					[0.08], Vector2(1.0, 1.7))
			_add(ops, OP_BOX, PAINT_CARVE, 0.0, Vector2(0.0, -0.86), [1.3, 0.74, 0.0])
		&"grapes":
			# A bunch of six, a stem in black, a leaf in the second ink.
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.0, -0.66), [0.05, 0.22, 0.03])
			for berry: Vector2 in [Vector2(-0.42, -0.34), Vector2(0.0, -0.36),
					Vector2(0.42, -0.34), Vector2(-0.22, 0.06), Vector2(0.22, 0.06),
					Vector2(0.0, 0.46)]:
				_add(ops, OP_CIRCLE, PAINT_INK, 0.0, berry, [0.27])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.6, _rotate(Vector2(0.3, -0.76), 0.6),
					[0.22], Vector2(1.0, 2.2))
		&"bar":
			# A gold slab; the lettering is the press's, over it.
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2.ZERO, [0.8, 0.3, 0.08])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2.ZERO, [0.7, 0.2, 0.05])
		&"double_bar":
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.34), [0.8, 0.25, 0.07])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.34), [0.7, 0.16, 0.04])
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.36), [0.8, 0.25, 0.07])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.36), [0.7, 0.16, 0.04])
		&"bell":
			# Domed body flaring to a foot, with a clapper below and a loop
			# above, both in the darker second ink. The flare is the shear
			# warp; its base is the original 0.1 plus this op's 0.06
			# translation, because the warp now runs after the translate.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.14), [0.46])
			_add(ops, OP_SHEAR_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.06),
					[0.42, 0.42, 0.06], Vector2.ONE, 0.85, 0.16)
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.5), [0.78, 0.11, 0.05])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, 0.72), [0.15])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, -0.66), [0.12])
		&"diamond":
			# A cut stone: the rhombus, a pale table across the top, and a
			# facet notched out of the crown.
			_add(ops, OP_RHOMBUS, PAINT_INK, 0.0, Vector2.ZERO, [0.64, 0.88])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.34), [0.4, 0.05, 0.02])
			_add(ops, OP_BOX, PAINT_CARVE, 0.0, Vector2(0.0, -0.6),
					[0.2, 0.03, 0.01])
		&"horseshoe":
			# An open ring, heels down and capped, nail holes in black. The gap
			# is wide and the hole large so the arms read as a U, not a bagel.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.06), [0.82])
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(-0.64, 0.6), [0.18, 0.12, 0.02])
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.64, 0.6), [0.18, 0.12, 0.02])
			for hole: Vector2 in [Vector2(-0.64, -0.2), Vector2(-0.4, -0.6),
					Vector2(0.4, -0.6), Vector2(0.64, -0.2)]:
				_add(ops, OP_CIRCLE, PAINT_BLACK, 0.0, hole, [0.075])
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(0.0, -0.06), [0.5])
			_add(ops, OP_BOX, PAINT_CARVE, 0.0, Vector2(0.0, 0.8), [0.46, 0.46, 0.0])
		&"bank":
			# Steps, four columns, an entablature and a pediment: the building
			# the game is named after, with the word under it. Sat high in the
			# cell so the lettering has the bottom of the plate.
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.5), [0.9, 0.09, 0.03])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.34), [0.78, 0.07, 0.02])
			for column: float in [-0.56, -0.19, 0.19, 0.56]:
				_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(column, -0.06),
						[0.1, 0.34, 0.03])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.46), [0.84, 0.08, 0.02])
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.72),
					[0.92, 0.2, 0.02], Vector2.ONE, 4.0, 0.06)
		&"wild":
			# Five tapered spokes around a small hub. The taper must narrow
			# outward, or five blunt spokes merge with the hub into an asterisk.
			for i: int in 5:
				_add(ops, OP_TAPER_BOX, PAINT_INK, TAU * float(i) / 5.0,
						Vector2(0.0, -0.5), [0.3, 0.5, 0.02], Vector2.ONE,
						0.95, 0.12)
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2.ZERO, [0.24])
		&"skull":
			# Cranium, jaw, then sockets, nose and teeth carved out.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.18), [0.62],
					Vector2(1.0, 1.12))
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.5), [0.34, 0.26, 0.12])
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(-0.24, -0.16), [0.2],
					Vector2(1.0, 1.25))
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(0.24, -0.16), [0.2],
					Vector2(1.0, 1.25))
			_add(ops, OP_RHOMBUS, PAINT_CARVE, 0.0, Vector2(0.0, 0.16), [0.09, 0.14])
			_add(ops, OP_BOX, PAINT_CARVE, 0.0, Vector2(0.0, 0.5), [0.4, 0.03, 0.01])
		&"coin":
			# A token, face on: a bronze rim, a gold face, and a bold struck "1".
			# A disc with an abstract mark read as a washer, and a stack fused
			# into a bun; a denomination is what makes a disc money.
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2.ZERO, [0.84])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2.ZERO, [0.64])
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.04, 0.0), [0.09, 0.36, 0.01])
			_add(ops, OP_BOX, PAINT_BLACK, -0.6, _rotate(Vector2(-0.1, -0.28), -0.6), [0.13, 0.05, 0.01])
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.04, 0.32), [0.2, 0.05, 0.01])
		&"clover":
			# The classic luck symbol: four round lobes and a stem, nothing else.
			for lobe: Vector2 in [Vector2(-0.34, -0.24), Vector2(0.34, -0.24),
					Vector2(-0.34, 0.3), Vector2(0.34, 0.3)]:
				_add(ops, OP_CIRCLE, PAINT_INK, 0.0, lobe, [0.36])
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.0, 0.74), [0.055, 0.24, 0.02])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, 0.02), [0.16])
		&"dice":
			# A single die: a bordered panel and five pips in the classic
			# cross layout — the panel-in-panel is the bar's own technique,
			# the pips are the horseshoe's nail holes at a bigger size.
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2.ZERO, [0.72, 0.72, 0.16])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2.ZERO, [0.58, 0.58, 0.12])
			for pip: Vector2 in [Vector2(-0.32, -0.32), Vector2(0.32, -0.32),
					Vector2.ZERO, Vector2(-0.32, 0.32), Vector2(0.32, 0.32)]:
				_add(ops, OP_CIRCLE, PAINT_BLACK, 0.0, pip, [0.12])
		&"crown":
			# A banded base and three tall spikes — the centre tallest — each
			# tipped with a jewel. The first pass was squat; the spikes now
			# take two thirds of the cell so the points are the shape.
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.58), [0.76, 0.2, 0.04])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.58), [0.62, 0.07, 0.02])
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.08),
					[0.3, 0.6, 0.02], Vector2.ONE, 4.0, 0.06)
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(-0.5, 0.06),
					[0.26, 0.46, 0.02], Vector2.ONE, 4.0, 0.06)
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(0.5, 0.06),
					[0.26, 0.46, 0.02], Vector2.ONE, 4.0, 0.06)
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, -0.68), [0.11])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(-0.5, -0.4), [0.09])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.5, -0.4), [0.09])
		&"gold_bar":
			# An ingot: a trapezoid wider at the foot than the crown, filling the
			# cell, a lighter top face in the second ink, a struck mark. The
			# taper is the crown's warp held shallow so it stays a slab.
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.08),
					[0.62, 0.4, 0.03], Vector2.ONE, 1.0, 0.3)
			_add(ops, OP_TAPER_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.22),
					[0.44, 0.1, 0.02], Vector2.ONE, 1.0, 0.3)
			_add(ops, OP_RHOMBUS, PAINT_BLACK, 0.0, Vector2(0.0, 0.16), [0.15, 0.12])
		&"plum":
			# A single deep fruit, bold and round, a thick stem and a leaf.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, 0.06), [0.68],
					Vector2(1.0, 1.14))
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.0, -0.56), [0.06, 0.18, 0.03])
			_add(ops, OP_CIRCLE, PAINT_INK2, -0.5, _rotate(Vector2(-0.32, -0.72), -0.5),
					[0.26], Vector2(1.0, 2.2))
		_:
			pass
	return ops


static func _add(ops: PackedFloat32Array, kind: float, paint: float, rot: float,
		pos: Vector2, params: Array, scale: Vector2 = Vector2.ONE,
		warp_amount: float = 0.0, warp_base: float = 0.0) -> void:
	ops.append(kind)
	ops.append(paint)
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
