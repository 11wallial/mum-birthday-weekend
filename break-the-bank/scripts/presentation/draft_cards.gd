## The draft's hardware, as three cards on the desk.
##
## The review's finding was that the draft screens read as a web form laid
## over a moody 3D room, and that the offers in particular "need card
## identity — icon, rarity colour, art — not a list". Three rows of text in
## a panel is the shape a form takes. A thing for sale on a desk is a
## different shape, and the room already knows how to draw onto paper: the
## clipboard is a quad with a viewport painted into it, and so is a card.
##
## The form does not go away. It keeps the press, the market, the pocket and
## the doorman, because those are paperwork the House wants signed; the
## cards carry the goods. Both are on the same desk under the same lamp.
##
## This is a view and not a controller. It never touches [RunState]: it
## reads the offers to draw them and emits [signal card_pressed], which the
## room turns into the same [method SimEngine.buy_offer] call the panel's
## own rows made and the headless shop policy makes.
class_name DraftCards
extends Node

## A card was taken. Carries the index into the state's offers.
signal card_pressed(index: int)

## The face is drawn at four times the size it is read at, so the type on a
## card twenty centimetres tall survives being a texture on a tilted quad.
const FACE_PX: Vector2i = Vector2i(400, 540)
## How long a card takes to rise under the pointer.
const LIFT_TIME: float = 0.12

var _cards: Node3D
var _faces: Array[SubViewport] = []
var _quads: Array[MeshInstance3D] = []
var _homes: Array[Vector3] = []
var _shown: int = 0


## Binds the card props the room built and gives each one a viewport to draw
## its face into. Called once; the props outlive every draft.
func attach(cards: Node3D) -> void:
	_cards = cards
	if _cards == null:
		return
	_cards.visible = false
	for i: int in 3:
		var quad: MeshInstance3D = _cards.get_node_or_null(NodePath("Card%d" % i)) as MeshInstance3D
		if quad == null:
			continue
		_quads.append(quad)
		_homes.append(quad.position)
		# The view owns its own starting state rather than trusting the props
		# to have been authored hidden. A card visible before a draft is dealt
		# is a card showing the last draft's offer.
		quad.visible = false
		var face: SubViewport = SubViewport.new()
		face.name = "Face%d" % i
		face.disable_3d = true
		face.transparent_bg = false
		face.size = FACE_PX
		# Drawn when it changes rather than every frame: a draft is three
		# still pictures that stand until the player takes one.
		face.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		face.gui_disable_input = true
		add_child(face)
		_faces.append(face)
		var paper: StandardMaterial3D = StandardMaterial3D.new()
		paper.albedo_texture = face.get_texture()
		# The room's own paper, so a card and the form on the clipboard are
		# cut from the same stock.
		paper.albedo_color = Materials.PAPER
		paper.roughness = 0.9
		paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		quad.material_override = paper
		var pick: Area3D = quad.get_node_or_null(^"Pick") as Area3D
		if pick == null:
			continue
		pick.input_event.connect(_on_card_input.bind(i))
		pick.mouse_entered.connect(_on_card_hover.bind(i, true))
		pick.mouse_exited.connect(_on_card_hover.bind(i, false))


## Lays the draft out. Anything past the offers on the table stays face down.
func deal(state: RunState) -> void:
	if _cards == null or state == null:
		return
	_shown = mini(state.shop_offers.size(), _quads.size())
	for i: int in _quads.size():
		var live: bool = i < _shown
		_quads[i].visible = live
		if not live:
			continue
		_draw_face(i, state)
	_cards.visible = true


## Off the desk. The cards are the draft's, not the room's.
func clear() -> void:
	if _cards == null:
		return
	_cards.visible = false
	for quad: MeshInstance3D in _quads:
		quad.visible = false
	_shown = 0


## One card's face: the build's ink across the head, the piece's name, what
## it does, the symbol it does it to, and the price stamped at the foot.
func _draw_face(index: int, state: RunState) -> void:
	var face: SubViewport = _faces[index]
	for child: Node in face.get_children():
		face.remove_child(child)
		child.queue_free()
	var artifact: ArtifactDef = state.shop_offers[index]
	var price: int = state.shop_prices[index]
	var affordable: bool = state.can_buy(index)
	var accent: Color = UiSkin.archetype_color(artifact.archetype)
	var ink: Color = UiSkin.PAPER_INK if affordable else UiSkin.PAPER_DENIED

	var sheet: ColorRect = ColorRect.new()
	sheet.color = UiSkin.PAPER_ROW if affordable else UiSkin.PAPER_ROW.darkened(0.12)
	sheet.size = Vector2(FACE_PX)
	face.add_child(sheet)

	# The build's colour as a band across the head. On a row it was a 4px
	# border; a card can afford to say it properly. Hardware that belongs to
	# no build gets a rule instead of a band: a filled head with nothing
	# printed on it reads as a name that failed rather than as a piece that
	# has none, and a third of the drafts show one.
	var build: ArchetypeDef = ContentDB.shared().archetype_by_id(artifact.archetype)
	var band: ColorRect = ColorRect.new()
	band.color = accent if affordable else UiSkin.PAPER_DENIED
	band.position = Vector2.ZERO
	band.size = Vector2(float(FACE_PX.x), 74.0 if build != null else 8.0)
	sheet.add_child(band)
	if build != null:
		sheet.add_child(_text(Copy.upper(build.display_name), 24.0,
				UiSkin.INK, Rect2(20.0, 20.0, FACE_PX.x - 40.0, 40.0),
				HORIZONTAL_ALIGNMENT_LEFT))

	# The symbol it singles out, big, because a card has room for a picture.
	var badge: TextureRect = _badge(artifact.symbol_filter, affordable)
	if badge != null:
		badge.position = Vector2(float(FACE_PX.x) * 0.5 - 66.0, 96.0)
		badge.size = Vector2(132.0, 132.0)
		sheet.add_child(badge)
	var top: float = 244.0 if badge != null else 116.0

	sheet.add_child(_text(Copy.of(artifact.display_name), 29.0, ink,
			Rect2(20.0, top, FACE_PX.x - 40.0, 92.0), HORIZONTAL_ALIGNMENT_CENTER, true))
	var body: Label = _text(Copy.of(artifact.description), 20.0,
			UiSkin.PAPER_INK_MUTED if affordable else UiSkin.PAPER_DENIED,
			Rect2(24.0, top + 96.0, FACE_PX.x - 48.0, 170.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	sheet.add_child(body)

	# The price, stamped at the foot in the House's red, with the key that
	# takes it — the number keys still work and the card should say so.
	var rule: ColorRect = ColorRect.new()
	rule.color = UiSkin.PAPER_INK_MUTED
	rule.position = Vector2(30.0, float(FACE_PX.y) - 92.0)
	rule.size = Vector2(float(FACE_PX.x) - 60.0, 2.0)
	sheet.add_child(rule)
	sheet.add_child(_text(Copy.filled("%d chips", [price]), 32.0,
			UiSkin.PAPER_STAMP if affordable else UiSkin.PAPER_DENIED,
			Rect2(22.0, float(FACE_PX.y) - 76.0, FACE_PX.x - 44.0, 52.0),
			HORIZONTAL_ALIGNMENT_CENTER))
	sheet.add_child(_text(str(index + 1), 26.0, UiSkin.PAPER_INK_MUTED,
			Rect2(float(FACE_PX.x) - 56.0, 88.0, 36.0, 34.0),
			HORIZONTAL_ALIGNMENT_RIGHT))

func _text(value: String, size: float, tint: Color, box: Rect2,
		align: int, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = tr(value)
	# Wrapping is set before the size, not after. A Label sizes itself to its
	# own minimum, and the minimum of an unwrapped line is that whole line —
	# so a label told to wrap only after it had been measured kept the width
	# it was measured at and ran off the edge of the card.
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = box.position
	label.size = box.size
	# A definite width, or autowrap has nothing to wrap against: a Label in a
	# plain rect takes its own minimum size, and the minimum of an unwrapped
	# line is the whole line. The names ran off the edge of the card for
	# exactly this reason.
	label.custom_minimum_size = Vector2(box.size.x, 0.0)
	label.clip_text = true
	label.horizontal_alignment = align as HorizontalAlignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_override(&"font", Type.mono())
	label.add_theme_font_size_override(&"font_size", int(roundf(size)))
	label.add_theme_color_override(&"font_color", tint)
	return label


func _badge(symbol_id: StringName, affordable: bool) -> TextureRect:
	if symbol_id == &"":
		return null
	var symbol: SymbolDef = ContentDB.shared().symbol_by_id(symbol_id)
	if symbol == null:
		return null
	var art: ImageTexture = SymbolArt.texture_for(symbol.id, symbol.color,
			symbol.second_color())
	if art == null:
		return null
	var badge: TextureRect = TextureRect.new()
	badge.texture = art
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Faded rather than tinted when it cannot be afforded: the symbol has to
	# stay the colour it is on the drum or it stops being a reference to it.
	var wash: Color = Color.WHITE
	wash.a = 1.0 if affordable else 0.45
	badge.modulate = wash
	return badge


## A card answers the pointer before it is read: it rises off the desk.
func _on_card_hover(index: int, over: bool) -> void:
	if index >= _quads.size() or index >= _shown:
		return
	var quad: MeshInstance3D = _quads[index]
	var home: Vector3 = _homes[index]
	var lift: Tween = create_tween()
	lift.tween_property(quad, "position",
			home + Vector3(0.0, 0.0, RoomSet.CARD_LIFT if over else 0.0), LIFT_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_card_input(_camera: Node, event: InputEvent, _at: Vector3,
		_normal: Vector3, _shape: int, index: int) -> void:
	if index >= _shown:
		return
	var taken: bool = false
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		taken = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		taken = (event as InputEventScreenTouch).pressed
	if taken:
		card_pressed.emit(index)
