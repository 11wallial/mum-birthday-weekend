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
			return [["BAR", -0.4], ["BAR", 0.0], ["BAR", 0.4]]
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
	# The reach is a fixed width, not a fraction of the shape: at 0.62 a wide
	# disc like the orange was still bevelling at its centre and came out
	# airbrushed, while a thin slab like the bar bevelled edge-to-edge and
	# came out hard — one set, two render styles, from this constant alone.
	var rim: float = clampf(1.0 + d / 0.3, 0.0, 1.0)
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
			# A thick slab seven with a pale inner keyline: the strongest genre
			# signal in the set, so it is drawn heaviest. The lean has to be real
			# — an almost-vertical stroke plus a crossbar reads as a capital F.
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.66), [0.62, 0.22, 0.04])
			_add(ops, OP_BOX, PAINT_INK, -0.34, _rotate(Vector2(0.1, 0.16), -0.34),
					[0.21, 0.74, 0.04])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.72), [0.5, 0.05, 0.02])
			_add(ops, OP_BOX, PAINT_INK2, -0.34, _rotate(Vector2(0.04, 0.16), -0.34),
					[0.06, 0.6, 0.02])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(-0.54, -0.54), [0.09, 0.28, 0.03])
		&"cherry":
			# Two fruit of different sizes on thick stems, the near one lower and
			# larger, with a shadow where it crosses its neighbour so the pair
			# sits in depth instead of lying flat, and a leaf clear of both.
			_add(ops, OP_BOX, PAINT_BLACK, -0.42,
					_rotate(Vector2(-0.24, -0.16), -0.42), [0.07, 0.46, 0.04])
			_add(ops, OP_BOX, PAINT_BLACK, 0.34,
					_rotate(Vector2(0.2, -0.1), 0.34), [0.07, 0.44, 0.04])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.3, 0.46), [0.34])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.4, 0.5), [0.29])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(-0.36, 0.42), [0.38])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.5, _rotate(Vector2(0.3, -0.66), 0.5),
					[0.3], Vector2(1.0, 2.4))
		&"lemon":
			# A fat tilted body drawn to a real point at each end. Round nubs
			# left it an egg; the points are what separate it from the orange.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.36, Vector2.ZERO, [0.68],
					Vector2(1.0, 1.4))
			_add(ops, OP_RHOMBUS, PAINT_INK, 0.36, Vector2(0.78, 0.0), [0.26, 0.17])
			_add(ops, OP_RHOMBUS, PAINT_INK, 0.36, Vector2(-0.78, 0.0), [0.26, 0.17])
			_add(ops, OP_CIRCLE, PAINT_INK2, -0.9, _rotate(Vector2(0.5, -0.7), -0.9),
					[0.2], Vector2(1.0, 2.2))
		&"orange":
			# A whole fruit with a dimple bitten out of the crown, a stem in it,
			# and a leaf. The dimple is what stops this and the plum being the
			# same circle: one is dented at the top, the other is drawn out.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, 0.1), [0.76])
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(0.0, -0.78), [0.22])
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.0, -0.7), [0.07, 0.16, 0.03])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.55, _rotate(Vector2(0.36, -0.72), 0.55),
					[0.27], Vector2(1.0, 2.3))
		&"watermelon":
			# A slice: a green rind, the flesh on it, and three teardrop seeds.
			# Round seeds read as dirt; a pip has a point on it.
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, -0.12), [0.94])
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.12), [0.72])
			_add(ops, OP_RHOMBUS, PAINT_BLACK, 0.3, _rotate(Vector2(-0.32, 0.26), 0.3),
					[0.08, 0.15])
			_add(ops, OP_RHOMBUS, PAINT_BLACK, 0.0, Vector2(0.02, 0.44), [0.08, 0.15])
			_add(ops, OP_RHOMBUS, PAINT_BLACK, -0.3, _rotate(Vector2(0.34, 0.24), -0.3),
					[0.08, 0.15])
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
			# Three slabs stepping wider toward the foot, with a gap between them
			# you can still see at 32px. Two same-width bars made this and the
			# single BAR one shape at reel speed; the gaps are what make it
			# countable in the blur, so they are cut wide on purpose.
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.5), [0.5, 0.15, 0.04])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.5), [0.38, 0.05, 0.02])
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.0), [0.68, 0.15, 0.04])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.0), [0.56, 0.05, 0.02])
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.5), [0.86, 0.15, 0.04])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.5), [0.74, 0.05, 0.02])
		&"bell":
			# Domed body flaring to a broad foot, a clapper under it, and the two
			# diagonal shine stripes without which a dome is just a dome — they
			# are the thing that says slot bell rather than hat.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.14), [0.46])
			_add(ops, OP_SHEAR_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.06),
					[0.42, 0.42, 0.06], Vector2.ONE, 0.85, 0.16)
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.5), [0.88, 0.13, 0.05])
			_add(ops, OP_BOX, PAINT_INK2, -0.5, _rotate(Vector2(-0.2, 0.06), -0.5),
					[0.055, 0.3, 0.02])
			_add(ops, OP_BOX, PAINT_INK2, -0.5, _rotate(Vector2(0.0, 0.1), -0.5),
					[0.035, 0.24, 0.02])
			_add(ops, OP_CIRCLE, PAINT_BLACK, 0.0, Vector2(0.0, 0.74), [0.15])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, -0.64), [0.13])
		&"diamond":
			# A cut stone: the girdle, a pale table across the crown, two facet
			# planes meeting under it and one hard spark. A flat kite reads as a
			# playing-card pip; the facets are what make it a gem.
			_add(ops, OP_RHOMBUS, PAINT_INK, 0.0, Vector2.ZERO, [0.64, 0.88])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.36), [0.42, 0.06, 0.02])
			_add(ops, OP_RHOMBUS, PAINT_INK2, 0.0, Vector2(-0.2, 0.12), [0.16, 0.34])
			_add(ops, OP_RHOMBUS, PAINT_INK2, 0.0, Vector2(0.22, 0.16), [0.12, 0.28])
			_add(ops, OP_BOX, PAINT_CARVE, 0.0, Vector2(0.0, -0.62), [0.22, 0.03, 0.01])
		&"horseshoe":
			# An open ring in iron, heels down and capped, nail holes in black.
			# The arms are thick: tapered thin they broke up at reel speed.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.06), [0.84])
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(-0.62, 0.58), [0.22, 0.16, 0.03])
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.62, 0.58), [0.22, 0.16, 0.03])
			for hole: Vector2 in [Vector2(-0.64, -0.16), Vector2(-0.38, -0.6),
					Vector2(0.38, -0.6), Vector2(0.64, -0.16)]:
				_add(ops, OP_CIRCLE, PAINT_BLACK, 0.0, hole, [0.085])
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(0.0, -0.06), [0.44])
			_add(ops, OP_BOX, PAINT_CARVE, 0.0, Vector2(0.0, 0.82), [0.4, 0.44, 0.0])
		&"bank":
			# Steps, three columns, an entablature and a pediment. Five columns
			# at 32px closed into one grey block — three with real air between
			# them is the same building and survives the drum.
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.5), [0.9, 0.09, 0.03])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.34), [0.78, 0.07, 0.02])
			for column: float in [-0.42, 0.0, 0.42]:
				_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(column, -0.06),
						[0.13, 0.34, 0.03])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.46), [0.84, 0.08, 0.02])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, -0.37), [0.8, 0.04, 0.01])
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.72),
					[0.92, 0.2, 0.02], Vector2.ONE, 4.0, 0.06)
		&"wild":
			# Five spokes tapering to real points around a small hub. A fat hub
			# and blunt tips read as a starfish; the star has to have corners.
			for i: int in 5:
				_add(ops, OP_TAPER_BOX, PAINT_INK, TAU * float(i) / 5.0,
						Vector2(0.0, -0.52), [0.34, 0.52, 0.01], Vector2.ONE,
						1.35, 0.08)
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2.ZERO, [0.15])
		&"skull":
			# A wide cranium, a heavy jaw, and sockets painted black rather
			# than cut to paper — this is the bust symbol and it should be
			# the loudest thing on the drum, not the quietest. Black sockets
			# cost the outline its holes, so the teeth are cut up out of the
			# jaw's bottom edge instead: the silhouette gets its bite back
			# there, where a carve does not fight the black.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, -0.2), [0.72],
					Vector2(1.0, 1.04))
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.52), [0.46, 0.3, 0.1])
			_add(ops, OP_CIRCLE, PAINT_BLACK, 0.0, Vector2(-0.3, -0.2), [0.25],
					Vector2(1.0, 1.15))
			_add(ops, OP_CIRCLE, PAINT_BLACK, 0.0, Vector2(0.3, -0.2), [0.25],
					Vector2(1.0, 1.15))
			_add(ops, OP_RHOMBUS, PAINT_BLACK, 0.0, Vector2(0.0, 0.16), [0.1, 0.15])
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.0, 0.36), [0.46, 0.03, 0.0])
			for gap: float in [-0.3, -0.1, 0.1, 0.3]:
				_add(ops, OP_BOX, PAINT_CARVE, 0.0, Vector2(gap, 0.88), [0.045, 0.2, 0.0])
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(-0.58, 0.36), [0.26])
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(0.58, 0.36), [0.26])
		&"coin":
			# A copper token tipped toward the reader so its edge shows. Face on
			# it was a plain disc — the orange, the plum and the clover's outline
			# all over again at 32px. The edge is the whole point: it is the only
			# thing that says struck metal rather than fruit.
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.42), [0.7, 0.16, 0.1])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, 0.0), [0.82], Vector2(1.0, 1.85))
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, 0.0), [0.66], Vector2(1.0, 1.85))
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.03, 0.0), [0.06, 0.17, 0.01])
			_add(ops, OP_BOX, PAINT_BLACK, -0.6, _rotate(Vector2(-0.07, -0.09), -0.6), [0.09, 0.035, 0.01])
		&"clover":
			# Four lobes, each bitten deep at its outer corner. Shallow notches
			# read as a shrub at 32px — the bite has to take a real chunk or the
			# luck signal is gone and this is broccoli.
			for lobe: Vector2 in [Vector2(-0.34, -0.3), Vector2(0.34, -0.3),
					Vector2(-0.34, 0.26), Vector2(0.34, 0.26)]:
				_add(ops, OP_CIRCLE, PAINT_INK, 0.0, lobe, [0.4])
			for notch: Vector2 in [Vector2(-0.72, -0.66), Vector2(0.72, -0.66),
					Vector2(-0.72, 0.62), Vector2(0.72, 0.62)]:
				_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, notch, [0.3])
			_add(ops, OP_BOX, PAINT_BLACK, 0.12, _rotate(Vector2(0.06, 0.74), 0.12),
					[0.05, 0.28, 0.02])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, -0.02), [0.12])
		&"dice":
			# Turned off square. Axis-aligned it was a plain rectangle at 32px and
			# sat in the same slot as the bar and the bank's entablature; a tilt
			# is the cheapest thing that makes a cube read as an object.
			_add(ops, OP_BOX, PAINT_INK, 0.28, Vector2.ZERO, [0.6, 0.6, 0.12])
			_add(ops, OP_BOX, PAINT_INK2, 0.28, Vector2.ZERO, [0.5, 0.5, 0.08])
			for pip: Vector2 in [Vector2(-0.29, -0.29), Vector2(0.29, -0.29),
					Vector2.ZERO, Vector2(-0.29, 0.29), Vector2(0.29, 0.29)]:
				_add(ops, OP_CIRCLE, PAINT_BLACK, 0.28, pip, [0.1])
		&"crown":
			# A banded base and three spikes, the centre tallest, each capped
			# with a jewel that sits ON its point. Needle-sharp tapers left the
			# jewels floating above the spikes like antennae.
			_add(ops, OP_BOX, PAINT_INK, 0.0, Vector2(0.0, 0.58), [0.66, 0.22, 0.04])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.0, 0.58), [0.54, 0.07, 0.02])
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(0.0, -0.1),
					[0.3, 0.6, 0.02], Vector2.ONE, 2.2, 0.16)
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(-0.44, 0.12),
					[0.26, 0.42, 0.02], Vector2.ONE, 2.2, 0.16)
			_add(ops, OP_TAPER_BOX, PAINT_INK, 0.0, Vector2(0.44, 0.12),
					[0.26, 0.42, 0.02], Vector2.ONE, 2.2, 0.16)
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.0, -0.66), [0.12])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(-0.44, -0.26), [0.1])
			_add(ops, OP_CIRCLE, PAINT_INK2, 0.0, Vector2(0.44, -0.26), [0.1])
		&"plum":
			# Drawn out tall with a cleft at the crown and a crease down the face:
			# the crease is the thing that names a plum, and the cleft keeps its
			# outline out of the orange's.
			_add(ops, OP_CIRCLE, PAINT_INK, 0.0, Vector2(0.0, 0.1), [0.66],
					Vector2(1.0, 1.24))
			_add(ops, OP_CIRCLE, PAINT_CARVE, 0.0, Vector2(0.0, -0.84), [0.26])
			_add(ops, OP_BOX, PAINT_INK2, 0.0, Vector2(0.02, 0.16), [0.045, 0.5, 0.02])
			_add(ops, OP_BOX, PAINT_BLACK, 0.0, Vector2(0.0, -0.72), [0.06, 0.18, 0.03])
			_add(ops, OP_CIRCLE, PAINT_INK2, -0.5, _rotate(Vector2(-0.34, -0.74), -0.5),
					[0.24], Vector2(1.0, 2.2))
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
