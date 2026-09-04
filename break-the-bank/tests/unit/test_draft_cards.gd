extends GdUnitTestSuite

## The draft's offers, now that they are cards on the desk rather than rows
## on the form. Everything here moved out of test_shop_panel when the view
## did, and it is the same set of guarantees: a card per offer, each naming
## its piece and its price, the symbol it singles out badged, and — the one
## that matters most — a card reports intent and never touches the run.
##
## Two of these were still passing after the move, against an empty list.
## A test that asserts something about every row in a container with no rows
## in it passes whatever the code does, which is worse than failing.

const ROOM_CARDS: String = "res://scenes/3d/casino_room.tscn"

var _cards: DraftCards
var _tray: Node3D
var _state: RunState
var _engine: SimEngine


func before_test() -> void:
	var bus: EffectBus = EffectBus.new()
	_engine = SimEngine.new(TestFixtures.content_with_shop(), bus)
	_engine.shop_policy = Callable()
	_state = _engine.start_run(7)
	var guard: int = 0
	while _state.phase != RunState.Phase.SHOPPING and not _state.is_over() and guard < 50:
		_engine.step(_state)
		guard += 1
	# The props the room builds, without the room: three quads with a pick
	# body each is all the view needs to attach to.
	_tray = auto_free(Node3D.new())
	add_child(_tray)
	for i: int in 3:
		var quad: MeshInstance3D = MeshInstance3D.new()
		quad.name = "Card%d" % i
		quad.mesh = QuadMesh.new()
		var pick: Area3D = Area3D.new()
		pick.name = "Pick"
		quad.add_child(pick)
		_tray.add_child(quad)
	_cards = auto_free(DraftCards.new()) as DraftCards
	add_child(_cards)
	_cards.attach(_tray)


func _faces() -> Array[SubViewport]:
	var found: Array[SubViewport] = []
	for child: Node in _cards.get_children():
		var face: SubViewport = child as SubViewport
		if face != null:
			found.append(face)
	return found


## Every piece of text on one card's face, joined.
func _face_text(index: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var pending: Array[Node] = [_faces()[index]]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var label: Label = node as Label
		if label != null:
			parts.append(label.text)
		pending.append_array(node.get_children())
	return " ".join(parts)


func _badges(index: int) -> Array[Node]:
	var found: Array[Node] = []
	var pending: Array[Node] = [_faces()[index]]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is TextureRect and (node as TextureRect).texture != null:
			found.append(node)
		pending.append_array(node.get_children())
	return found


func _shown() -> int:
	var count: int = 0
	for child: Node in _tray.get_children():
		var quad: MeshInstance3D = child as MeshInstance3D
		if quad != null and quad.visible:
			count += 1
	return count


func test_the_desk_is_clear_until_a_draft_is_dealt() -> void:
	assert_int(_shown()).is_equal(0)


func test_dealing_lays_out_one_card_per_offer() -> void:
	_cards.deal(_state)
	assert_int(_shown()).is_equal(_state.shop_offers.size())


func test_each_card_names_its_piece_and_its_price() -> void:
	_cards.deal(_state)
	for i: int in _state.shop_offers.size():
		var shown: String = _face_text(i)
		assert_str(shown).contains(_state.shop_offers[i].display_name)
		assert_str(shown).contains(str(_state.shop_prices[i]))


## Only the offers that single out a symbol carry its icon.
func test_a_card_badges_the_symbol_its_piece_singles_out() -> void:
	_state.shop_offers[0].symbol_filter = &"seven"
	for i: int in range(1, _state.shop_offers.size()):
		_state.shop_offers[i].symbol_filter = &""
	_cards.deal(_state)
	assert_int(_badges(0).size()).is_equal(1)
	for i: int in range(1, _state.shop_offers.size()):
		assert_int(_badges(i).size()).is_equal(0)


## A piece naming a symbol with no drawing must not leave a blank badge
## behind — the icon is dropped and the card reads normally.
func test_a_symbol_with_no_drawing_gets_no_badge() -> void:
	_state.shop_offers[0].symbol_filter = &"not_a_real_symbol"
	_cards.deal(_state)
	assert_int(_badges(0).size()).is_equal(0)
	assert_str(_face_text(0)).contains(_state.shop_offers[0].display_name)


## The guarantee the whole split rests on: a card is a view. Taking one says
## so and changes nothing; only the room may spend.
func test_taking_a_card_reports_intent_without_changing_the_run() -> void:
	_cards.deal(_state)
	var cash: int = _state.economy.cash
	var owned: int = _state.owned.size()
	var reported: Array[int] = []
	_cards.card_pressed.connect(func(index: int) -> void: reported.append(index))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var pick: Area3D = _tray.get_node("Card0/Pick") as Area3D
	pick.input_event.emit(null, click, Vector3.ZERO, Vector3.ZERO, 0)
	assert_array(reported).is_equal([0])
	assert_int(_state.economy.cash).is_equal(cash)
	assert_int(_state.owned.size()).is_equal(owned)


func test_a_bought_piece_leaves_the_desk_when_the_draft_is_dealt_again() -> void:
	_cards.deal(_state)
	var before: int = _shown()
	var index: int = -1
	for i: int in _state.shop_offers.size():
		if _state.can_buy(i):
			index = i
			break
	assert_int(index).is_greater_equal(0)
	_engine.buy_offer(_state, index)
	_cards.deal(_state)
	assert_int(_shown()).is_equal(before - 1)


func test_clearing_takes_every_card_off_the_desk() -> void:
	_cards.deal(_state)
	_cards.clear()
	assert_int(_shown()).is_equal(0)
