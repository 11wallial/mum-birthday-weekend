## The overlay's visual language, in one place.
##
## The panels are the only part of the game that is not a lit object in a room,
## so they have to earn their place: dark ground, one hairline of the same amber
## the machine's brass and the wall sign use, and no colour that is not already
## somewhere in the set. Anything softer reads as a web form dropped over a
## basement.
##
## Styles are built here rather than authored in each [code].tscn[/code] because
## four panels sharing five stylebox variants by hand is four places to forget.
class_name UiSkin
extends RefCounted

# Every colour below is one of the room's own, and says which. The claim in
# the docstring above — "no colour that is not already somewhere in the set" —
# was true of the intent and not of the constants: the overlay carried four
# near-ambers of its own that matched nothing on the machine. GDScript cannot
# call darkened() in a const and ARCHETYPE_COLOR needs these at parse time, so
# the derivation is written out here rather than evaluated, and the test in
# test_palette.gd is what keeps the arithmetic honest.

## Materials.CONCRETE * 0.3 — the floor, under the panel's own shade.
const GROUND: Color = Color(0.035, 0.031, 0.027, 0.94)
## Tuned, not derived: a row has to sit a step off GROUND at 0.85 alpha over
## a moving 3D scene, which no single swatch in the set does.
const ROW: Color = Color(0.075, 0.067, 0.055, 0.85)
const ROW_HOVER: Color = Color(0.126, 0.110, 0.086, 0.92)
## Materials.BRASS, and BRASS * 0.85 — the hairline is the machine's own trim.
const EDGE: Color = Color(0.663, 0.494, 0.208, 0.55)
const EDGE_SOFT: Color = Color(0.564, 0.42, 0.177, 0.3)
## Materials.PAPER, lightened: the overlay's type is paper seen against dark.
const INK: Color = Color(0.905, 0.871, 0.804)
const INK_MUTED: Color = Color(0.686, 0.647, 0.573)
## Materials.LAMP. The overlay's amber is now the bulb's amber, not a fourth
## one of its own — the set had UiSkin.AMBER, LAMP, SCORE and a caption ink
## all within a few points of each other and none of them equal.
const AMBER: Color = Color(1.0, 0.831, 0.616)
## Materials.JACKPOT, drained toward the neutrals: refused, not alarming.
const DENIED: Color = Color(0.749, 0.435, 0.376)

## The forms on the clipboard: paper, and the inks the House types and
## stamps on it. Dark on cream, the reverse of the overlay's panels, because
## a form is a lit object in the room and not a screen.
## Materials.PAPER, lightened by the desk lamp standing over it.
const PAPER_GROUND: Color = Color(0.875, 0.861, 0.828, 1.0)
const PAPER_ROW: Color = Color(0.85, 0.834, 0.794, 1.0)
const PAPER_ROW_HOVER: Color = Color(0.906, 0.896, 0.871, 1.0)
const PAPER_INK: Color = Color(0.12, 0.1, 0.08)
const PAPER_INK_MUTED: Color = Color(0.38, 0.34, 0.29)
## The stamp: the House's red, for prices, titles and anything it insists on.
## Materials.JACKPOT darkened — the same red as the heat dial's zone and a
## voided pattern, dried into ink.
const PAPER_STAMP: Color = Color(0.601, 0.109, 0.092)
const PAPER_DENIED: Color = Color(0.55, 0.5, 0.45)
## What a contract gives, and what it takes — distinct from PAPER_DENIED
## (which already means "you can't afford this row"), so a toll reads as a
## cost rather than as a row the draft is refusing.
## PAPER_GOOD is PHOSPHOR's green held far deeper than a derivation gives:
## printed on cream under a warm key, the CRT's own value goes muddy and
## stops reading as green at all. Tuned against a render, on purpose.
const PAPER_GOOD: Color = Color(0.09, 0.5, 0.16)
## Materials.JACKPOT, barely darkened.
const PAPER_BAD: Color = Color(0.72, 0.13, 0.11)
const PAPER_SHADER: String = "res://assets/shaders/paper.gdshader"

static var _cache: Dictionary = {}


## Turns a panel into a sheet: an empty stylebox with the form's margins, and
## the paper shader drawn behind everything in it.
static func sheet(panel: PanelContainer) -> void:
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override(&"panel", style)
	var old: Node = panel.get_node_or_null(^"Sheet")
	if old != null:
		return
	var paper: ColorRect = ColorRect.new()
	paper.name = "Sheet"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(PAPER_SHADER) as Shader
	material.set_shader_parameter(&"paper", PAPER_GROUND)
	material.set_shader_parameter(&"tear_px", 0.0)
	material.set_shader_parameter(&"perforation_px", 0.0)
	material.set_shader_parameter(&"seed", 11.0)
	paper.material = material
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(paper)
	panel.move_child(paper, 0)
	var size_it: Callable = func() -> void:
		material.set_shader_parameter(&"size_px", panel.size)
	panel.resized.connect(size_it)
	size_it.call()


## One line of a form: a rule under it, the stamp's red down the left when
## it can be taken, grey when it cannot.
static func paper_row(affordable: bool, hovered: bool = false,
		accent: Color = PAPER_STAMP) -> StyleBoxFlat:
	var key: String = "paper_row:%s:%s:%s" % [affordable, hovered, accent.to_html(false)]
	return _flat(key, func() -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PAPER_ROW_HOVER if hovered else PAPER_ROW
		_radius(style, 1)
		_padding(style, 14.0, 11.0)
		style.border_width_left = 4
		style.border_width_bottom = 1
		style.border_color = accent if affordable else PAPER_DENIED
		return style)


## One stamp-ink colour per build, muted to sit on paper rather than shout —
## a real rubber stamp's ink, not a flat UI accent. The draft's left border
## and the build tag both wear it, so a run chasing one build can scan the
## whole draft for its colour without reading a line of it.
const ARCHETYPE_COLOR: Dictionary = {
	&"clamp": Color(0.29, 0.4, 0.56),
	&"clock": Color(0.58, 0.44, 0.14),
	&"exchange": Color(0.16, 0.45, 0.42),
	&"marker": PAPER_STAMP,
	&"orchard": Color(0.36, 0.44, 0.15),
	&"skulls": Color(0.34, 0.21, 0.34),
	&"trail": Color(0.58, 0.3, 0.13),
	&"whale": Color(0.42, 0.19, 0.44),
}


## The stamp colour for a build id, or the ledger's own red for hardware that
## fits any machine — the same colour a row without a build wore before this,
## so nothing goes uncoloured.
static func archetype_color(id: StringName) -> Color:
	return ARCHETYPE_COLOR.get(id, PAPER_STAMP)


## A button on a form: a boxed line, typed.
static func paper_button(state: StringName) -> StyleBoxFlat:
	return _flat("paper_button:%s" % state, func() -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		match state:
			&"hover", &"pressed":
				style.bg_color = PAPER_ROW_HOVER
				_border(style, 2, PAPER_INK)
			&"disabled":
				style.bg_color = PAPER_ROW
				_border(style, 1, PAPER_DENIED)
			_:
				style.bg_color = PAPER_ROW
				_border(style, 1, PAPER_INK_MUTED)
		_radius(style, 1)
		_padding(style, 16.0, 10.0)
		return style)


static func dress_paper_button(target: Button) -> void:
	target.add_theme_stylebox_override(&"normal", paper_button(&"normal"))
	target.add_theme_stylebox_override(&"hover", paper_button(&"hover"))
	target.add_theme_stylebox_override(&"pressed", paper_button(&"pressed"))
	target.add_theme_stylebox_override(&"disabled", paper_button(&"disabled"))
	target.add_theme_stylebox_override(&"focus", paper_button(&"hover"))
	target.add_theme_color_override(&"font_color", PAPER_INK)
	target.add_theme_color_override(&"font_hover_color", PAPER_STAMP)
	target.add_theme_color_override(&"font_pressed_color", PAPER_STAMP)
	target.add_theme_color_override(&"font_disabled_color", PAPER_DENIED)


## The ground a panel sits on: near-black, one hairline edge, generous padding.
static func panel() -> StyleBoxFlat:
	return _flat("panel", func() -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = GROUND
		_border(style, 1, EDGE)
		_radius(style, 3)
		_padding(style, 26.0, 20.0)
		return style)


## One offer in the draft. [param affordable] picks the accent down its left
## edge — the only thing distinguishing a row you can take from one you cannot,
## since both stay listed and both stay readable.
static func row(affordable: bool, hovered: bool = false) -> StyleBoxFlat:
	var key: String = "row:%s:%s" % [affordable, hovered]
	return _flat(key, func() -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = ROW_HOVER if hovered else ROW
		_radius(style, 2)
		_padding(style, 14.0, 11.0)
		# A bar rather than a full border: it reads at a glance down a column of
		# rows, where four separate outlines would just look like a table.
		style.border_width_left = 3
		style.border_color = AMBER if affordable else DENIED
		return style)


## A button that looks like it is stamped out of the same metal as the machine.
static func button(state: StringName) -> StyleBoxFlat:
	return _flat("button:%s" % state, func() -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		match state:
			&"hover":
				style.bg_color = Color(0.145, 0.125, 0.094, 0.95)
				_border(style, 1, AMBER)
			&"pressed":
				style.bg_color = Color(0.196, 0.157, 0.098, 0.98)
				_border(style, 1, AMBER)
			&"disabled":
				style.bg_color = Color(0.055, 0.051, 0.043, 0.8)
				_border(style, 1, EDGE_SOFT)
			_:
				style.bg_color = Color(0.086, 0.078, 0.063, 0.9)
				_border(style, 1, EDGE)
		_radius(style, 2)
		_padding(style, 18.0, 12.0)
		return style)


## Dresses a [Button] in the full set of states at once. Buttons need four
## styleboxes to stop looking like a default control, and forgetting one is how
## a pressed state ends up rendering as the theme's blue.
static func dress_button(target: Button) -> void:
	target.add_theme_stylebox_override(&"normal", button(&"normal"))
	target.add_theme_stylebox_override(&"hover", button(&"hover"))
	target.add_theme_stylebox_override(&"pressed", button(&"pressed"))
	target.add_theme_stylebox_override(&"disabled", button(&"disabled"))
	target.add_theme_stylebox_override(&"focus", button(&"hover"))
	target.add_theme_color_override(&"font_color", INK)
	target.add_theme_color_override(&"font_hover_color", AMBER)
	target.add_theme_color_override(&"font_pressed_color", AMBER)
	target.add_theme_color_override(&"font_disabled_color", INK_MUTED)


static func _flat(key: String, factory: Callable) -> StyleBoxFlat:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key] as StyleBoxFlat


static func _border(style: StyleBoxFlat, width: int, tint: Color) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = tint


static func _radius(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius


static func _padding(style: StyleBoxFlat, horizontal: float, vertical: float) -> void:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
