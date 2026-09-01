extends GdUnitTestSuite

## The back office must show both halves of every contract. A panel that led
## with the boon and buried the toll would be the casino's own marketing, and
## the whole point of the floor is that the player reads the terms.

const SCENE: String = "res://scenes/ui/contract_panel.tscn"

var _panel: ContractPanel
var _state: RunState


func before_test() -> void:
	var content: ContentDB = TestFixtures.content()
	content.contracts.assign([_contract(&"a", "Skeleton Crew"), _contract(&"b", "Danger Money")])
	_state = TestFixtures.run_state(4, content)
	_state.contract_offers.assign(content.contracts)
	_panel = auto_free((load(SCENE) as PackedScene).instantiate()) as ContractPanel
	add_child(_panel)


func _contract(id: StringName, display_name: String) -> ContractDef:
	var contract: ContractDef = ContractDef.new()
	contract.id = id
	contract.display_name = display_name
	contract.description = "Terms and conditions apply."
	contract.boon = ContractDef.Clause.SPINS
	contract.boon_magnitude = 4.0
	contract.toll = ContractDef.Clause.PAYOUT_PERCENT
	contract.toll_magnitude = -30.0
	return contract


func _text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var pending: Array[Node] = [_panel.get_node(^"Panel/Rows/Offers")]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var label: Label = node as Label
		if label != null:
			parts.append(label.text)
		pending.append_array(node.get_children())
	return " | ".join(parts)


func test_the_office_starts_shut() -> void:
	assert_bool(_panel.is_open()).is_false()
	assert_bool(_panel.visible).is_false()


func test_every_offer_shows_what_it_gives_and_what_it_takes() -> void:
	_panel.open(_state)
	var shown: String = _text()
	assert_str(shown).contains("Skeleton Crew")
	assert_str(shown).contains("Danger Money")
	assert_str(shown).contains("+4 spins on the floor")
	assert_str(shown).contains("-30% on every payout")


func test_signing_reports_the_row_without_touching_the_run() -> void:
	_panel.open(_state)
	var seen: Array[int] = []
	_panel.sign_requested.connect(func(index: int) -> void: seen.append(index))
	var rows: Array[Node] = _panel.get_node(^"Panel/Rows/Offers").get_children()
	(rows[1] as Button).pressed.emit()
	assert_array(seen).is_equal([1])
	assert_object(_state.contract).is_null()
