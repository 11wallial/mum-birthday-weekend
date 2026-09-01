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

const GROUND: Color = Color(0.035, 0.031, 0.027, 0.94)
const ROW: Color = Color(0.075, 0.067, 0.055, 0.85)
const ROW_HOVER: Color = Color(0.126, 0.110, 0.086, 0.92)
const EDGE: Color = Color(0.62, 0.451, 0.196, 0.55)
const EDGE_SOFT: Color = Color(0.55, 0.42, 0.21, 0.3)
const INK: Color = Color(0.905, 0.871, 0.804)
const INK_MUTED: Color = Color(0.686, 0.647, 0.573)
const AMBER: Color = Color(1.0, 0.796, 0.478)
const DENIED: Color = Color(0.749, 0.435, 0.376)

static var _cache: Dictionary = {}


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
