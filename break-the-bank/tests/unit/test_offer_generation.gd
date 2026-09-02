extends GdUnitTestSuite

## The offer generator, held to the balance guide's four requirements: no
## dead offers, a draft the purse can buy from, builds leaned toward at
## arm's length, and never a flood of one build.

var _content: ContentDB
var _engine: SimEngine
var _state: RunState


func _artifact(id: StringName, cost: int, archetype: StringName = &"",
		symbol_filter: StringName = &"") -> ArtifactDef:
	var def: ArtifactDef = TestFixtures.artifact(id, ArtifactDef.Effect.FLAT_BONUS, 1.0)
	def.cost = cost
	def.archetype = archetype
	def.symbol_filter = symbol_filter
	return def


func before_test() -> void:
	_content = TestFixtures.content()
	_content.floors.assign([
		TestFixtures.floor_def(1, 20, 6),
		TestFixtures.floor_def(2, 40, 6),
	])
	for floor_def: FloorDef in _content.floors:
		floor_def.shop_slots = 3
	_content.artifacts.assign([
		_artifact(&"a_one", 2, &"alpha"), _artifact(&"a_two", 2, &"alpha"),
		_artifact(&"a_three", 2, &"alpha"), _artifact(&"a_four", 2, &"alpha"),
		_artifact(&"b_one", 2, &"beta"), _artifact(&"b_two", 2, &"beta"),
		_artifact(&"b_three", 2, &"beta"), _artifact(&"b_four", 2, &"beta"),
		_artifact(&"dear", 9999, &"gamma"),
	])
	_engine = SimEngine.new(_content, EffectBus.new())
	_engine.clear_policies()
	_state = _engine.start_run(11)


func _draft() -> Array[ArtifactDef]:
	return _engine._roll_offers(_state, _state.current_floor())


func test_an_offer_keyed_to_a_symbol_the_reel_cannot_land_is_not_dealt() -> void:
	var symbol: SymbolDef = _content.symbols[0]
	_content.artifacts.append(_artifact(&"keyed", 2, &"", symbol.id))
	_state.add_weight_shift(symbol.id, -1000000)
	for seed: int in 40:
		_state = _engine.start_run(seed)
		_state.add_weight_shift(symbol.id, -1000000)
		for offer: ArtifactDef in _draft():
			assert_str(String(offer.id)).is_not_equal("keyed")


func test_a_family_keyed_offer_is_never_dead() -> void:
	_content.artifacts.assign([_artifact(&"fruity", 2, &"", &"fruit")])
	_state = _engine.start_run(3)
	assert_int(_draft().size()).is_equal(1)


func test_a_draft_the_purse_can_buy_from_is_dealt_when_one_exists() -> void:
	_content.artifacts.assign([
		_artifact(&"dear_a", 9999), _artifact(&"dear_b", 9999), _artifact(&"dear_c", 9999),
		_artifact(&"dear_d", 9999), _artifact(&"cheap", 1),
	])
	for seed: int in 30:
		_state = _engine.start_run(seed)
		_state.economy.chips = 2
		var offers: Array[ArtifactDef] = _draft()
		var affordable: bool = false
		for offer: ArtifactDef in offers:
			if _state.economy.can_afford_chips(_engine.price_for(_state, offer)):
				affordable = true
		assert_bool(affordable).override_failure_message(
				"seed %d dealt a draft nothing could be bought from" % seed).is_true()


func test_a_started_build_is_offered_more_often() -> void:
	var with: int = 0
	var without: int = 0
	for seed: int in 200:
		_state = _engine.start_run(seed)
		for offer: ArtifactDef in _draft():
			if offer.archetype == &"alpha":
				without += 1
		_state = _engine.start_run(seed)
		_state.acquire(_content.artifact_by_id(&"a_one"))
		for offer: ArtifactDef in _draft():
			if offer.archetype == &"alpha":
				with += 1
	assert_int(with).is_greater(without)
	# Arm's length: the lean is a lean, not a funnel.
	assert_float(float(with) / float(maxi(without, 1))).is_less(1.8)


func test_no_more_than_the_cap_of_one_build_in_a_draft() -> void:
	for seed: int in 100:
		_state = _engine.start_run(seed)
		_state.acquire(_content.artifact_by_id(&"a_one"))
		var alphas: int = 0
		for offer: ArtifactDef in _draft():
			if offer.archetype == &"alpha":
				alphas += 1
		assert_int(alphas).is_less_equal(_state.config.offer_build_cap)


func test_a_draft_is_the_seeds_own() -> void:
	_state = _engine.start_run(7)
	var first: Array[ArtifactDef] = _draft()
	_state = _engine.start_run(7)
	var again: Array[ArtifactDef] = _draft()
	assert_int(first.size()).is_equal(again.size())
	for i: int in first.size():
		assert_str(String(first[i].id)).is_equal(String(again[i].id))
