extends GdUnitTestSuite

## The reel as it ships today: one symbol heavy, one light, by the seed.
## A seed's reel is its own, two seeds differ, and the skull is never one.

var _engine: SimEngine


func before_test() -> void:
	_engine = SimEngine.new(TestFixtures.content(), EffectBus.new())
	_engine.clear_policies()


func test_a_seed_ships_the_same_reel_every_time() -> void:
	var first: RunState = _engine.start_run(21)
	var again: RunState = _engine.start_run(21)
	assert_bool(first.ship_lean.is_empty()).is_false()
	assert_str(String(first.ship_lean["heavy"])).is_equal(String(again.ship_lean["heavy"]))
	assert_str(String(first.ship_lean["light"])).is_equal(String(again.ship_lean["light"]))
	assert_str(String(first.ship_lean["heavy"])).is_not_equal(String(first.ship_lean["light"]))


func test_seeds_ship_different_reels() -> void:
	var seen: Dictionary = {}
	for seed: int in 12:
		var state: RunState = _engine.start_run(100 + seed)
		seen["%s>%s" % [state.ship_lean["heavy"], state.ship_lean["light"]]] = true
	assert_int(seen.size()).is_greater(1)


func test_the_lean_is_on_the_reel_and_never_the_skull() -> void:
	var content: ContentDB = TestFixtures.content()
	for seed: int in 20:
		var state: RunState = _engine.start_run(seed)
		var heavy: SymbolDef = content.symbol_by_id(state.ship_lean["heavy"])
		var light: SymbolDef = content.symbol_by_id(state.ship_lean["light"])
		assert_bool(heavy.is_curse or light.is_curse).is_false()
		var plain: RunState = RunState.new(seed, content, EffectBus.new())
		assert_float(Probability.symbol_chance(state.reel(), heavy.id)).is_greater(
				Probability.symbol_chance(plain.reel(), heavy.id))
		assert_float(Probability.symbol_chance(state.reel(), light.id)).is_less(
				Probability.symbol_chance(plain.reel(), light.id))


func test_the_lean_does_not_move_the_reels_draws() -> void:
	# The lean is off its own stream: the first line drawn on a seed is the
	# same whether or not the reel was leaned, up to what the lean changed.
	var leaned: RunState = _engine.start_run(5)
	assert_int(leaned.reel_rng.draws).is_equal(0)
	assert_int(leaned.lean_rng.draws).is_equal(2)
