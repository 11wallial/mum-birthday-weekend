extends GdUnitTestSuite

## Meta-progression reaches the simulation only through RunOptions, so this is
## where "unlocks changed the run" has to be provable.


func _engine(options: RunOptions) -> Array:
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var engine: SimEngine = SimEngine.new(TestFixtures.content_with_shop(), bus)
	return [engine, options]


func test_the_default_options_restrict_nothing() -> void:
	var options: RunOptions = RunOptions.new()
	var artifact: ArtifactDef = TestFixtures.artifact(&"anything", ArtifactDef.Effect.FLAT_BONUS, 1.0)
	assert_bool(options.allows(artifact)).is_true()


func test_a_locked_artifact_never_reaches_the_shop() -> void:
	var options: RunOptions = RunOptions.new()
	options.allowed_artifacts = [&"cheap_charm"]
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var engine: SimEngine = SimEngine.new(TestFixtures.content_with_shop(), bus)
	var state: RunState = engine.simulate_run(7, options)
	assert_bool(state.owns(&"dear_engine")).is_false()


func test_starter_bonuses_apply_before_the_first_spin() -> void:
	var options: RunOptions = RunOptions.new()
	options.bonus_cash = 25
	options.bonus_debt = 60
	var state: RunState = SimEngine.new(TestFixtures.content(), EffectBus.new()).start_run(1, options)
	assert_int(state.economy.cash).is_equal(TestFixtures.config().starting_cash + 25)
	assert_int(state.economy.debt).is_equal(60)


func test_debt_can_be_reduced_but_never_below_zero() -> void:
	var options: RunOptions = RunOptions.new()
	options.bonus_debt = -9999
	var state: RunState = SimEngine.new(TestFixtures.content(), EffectBus.new()).start_run(1, options)
	assert_int(state.economy.debt).is_equal(0)


func test_bonus_spins_are_granted_every_floor() -> void:
	var options: RunOptions = RunOptions.new()
	options.bonus_spins = 3
	var state: RunState = SimEngine.new(TestFixtures.content(), EffectBus.new()).start_run(1, options)
	assert_int(state.spins_remaining).is_equal(TestFixtures.floor_def(1, 5, 4).spins + 3)


func test_difficulty_scales_every_ante() -> void:
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	var options: RunOptions = RunOptions.new()
	options.ante_scale = 2.0
	SimEngine.new(TestFixtures.content(), bus).start_run(1, options)
	var started: Array[Dictionary] = bus.events_of(EffectBus.Event.FLOOR_STARTED)
	assert_int(started.size()).is_greater(0)
	# Fixture floor 1 asks for 5; at double difficulty it asks for 10.
	assert_int(int(started[0]["ante"])).is_equal(10)


func test_the_ruleset_key_distinguishes_what_is_comparable() -> void:
	var standard: RunOptions = RunOptions.new()
	var harder: RunOptions = RunOptions.new()
	harder.ante_scale = 1.6
	harder.difficulty_id = &"house_rules"
	assert_str(standard.ruleset_key()).is_not_equal(harder.ruleset_key())
	assert_str(standard.ruleset_key()).is_equal(RunOptions.new().ruleset_key())


func test_options_survive_duplication() -> void:
	var options: RunOptions = RunOptions.new()
	options.allowed_artifacts = [&"a", &"b"]
	options.ante_scale = 1.25
	var copy: RunOptions = options.duplicate_options()
	copy.allowed_artifacts.append(&"c")
	assert_int(options.allowed_artifacts.size()).is_equal(2)
	assert_float(copy.ante_scale).is_equal_approx(1.25, 0.001)
