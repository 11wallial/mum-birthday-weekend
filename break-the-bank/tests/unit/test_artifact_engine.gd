extends GdUnitTestSuite

var _state: RunState
var _cherry: SymbolDef
var _seven: SymbolDef
var _skull: SymbolDef
## cherry + cherry + seven: a PAIR worth 14 before modifiers.
var _pair_line: Array[SymbolDef] = []


func before_test() -> void:
	_state = TestFixtures.run_state()
	_cherry = _state.content.symbol_by_id(&"cherry")
	_seven = _state.content.symbol_by_id(&"seven")
	_skull = _state.content.symbol_by_id(&"skull")
	_pair_line.assign([_cherry, _cherry, _seven])


func _score(line: Array[SymbolDef]) -> ArtifactEngine.SpinContext:
	return ArtifactEngine.evaluate_spin(_state, line, Probability.detect_pattern(line))


func test_a_bare_line_pays_symbols_times_the_pattern_multiplier() -> void:
	var ctx: ArtifactEngine.SpinContext = _score(_pair_line)
	assert_int(ctx.base_payout).is_equal(14)
	assert_float(ctx.multiplier).is_equal_approx(1.5, 0.001)
	assert_int(ctx.total()).is_equal(21)


func test_debt_leverage_scales_the_multiplier_with_what_is_owed() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(
			&"marker", ArtifactDef.Effect.DEBT_LEVERAGE, 0.5)
	_state.acquire(artifact)
	# Nothing owed, nothing gained: the effect has to be worth zero at zero debt
	# or it is just a multiplier with extra steps.
	_state.economy.debt = 0
	assert_float(_score(_pair_line).multiplier).is_equal_approx(1.5, 0.001)
	# 400 owed is four hundreds, so four times the magnitude.
	_state.economy.debt = 400
	assert_float(_score(_pair_line).multiplier).is_equal_approx(3.5, 0.001)


func test_debt_leverage_is_capped_so_defaulting_is_never_the_strategy() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(
			&"margin", ArtifactDef.Effect.DEBT_LEVERAGE, 0.5)
	artifact.cap = 2.0
	_state.acquire(artifact)
	_state.economy.debt = 100000
	# Debt compounds without bound; the bonus must not.
	assert_float(_score(_pair_line).multiplier).is_equal_approx(3.5, 0.001)


func test_a_spin_refund_draws_from_the_tempo_stream_not_the_reels() -> void:
	# The named streams exist so a new die roll in one system cannot shift
	# another. A refund artifact must therefore leave the reel stream untouched.
	_state.acquire(TestFixtures.artifact(
			&"loose", ArtifactDef.Effect.SPIN_REFUND, 50.0))
	var reel_draws_before: int = _state.reel_rng.draws
	for i: int in 20:
		ArtifactEngine.refunds_spin(_state)
	assert_int(_state.reel_rng.draws).is_equal(reel_draws_before)
	assert_int(_state.tempo_rng.draws).is_equal(20)


func test_no_refund_artifact_means_no_draw_at_all() -> void:
	# Not merely "returns false": drawing anyway would consume the stream and
	# desync a replay of a run that owns no refund artifact.
	assert_bool(ArtifactEngine.refunds_spin(_state)).is_false()
	assert_int(_state.tempo_rng.draws).is_equal(0)


func test_a_certain_refund_never_consumes_a_spin() -> void:
	_state.acquire(TestFixtures.artifact(
			&"free", ArtifactDef.Effect.SPIN_REFUND, 100.0))
	# Capped at 45%, so "always" is not reachable — but every draw below the cap
	# must refund, and none above it may.
	var refunds: int = 0
	for i: int in 400:
		if ArtifactEngine.refunds_spin(_state):
			refunds += 1
	assert_int(refunds).is_greater(120)
	assert_int(refunds).is_less(280)


func test_a_curse_costs_credits_and_the_pattern_bonus() -> void:
	var line: Array[SymbolDef] = [_cherry, _seven, _skull]
	var ctx: ArtifactEngine.SpinContext = _score(line)
	assert_int(ctx.base_payout).is_equal(10)
	assert_float(ctx.multiplier).is_equal_approx(1.0, 0.001)


func test_flat_bonus_applies_before_the_multiplier() -> void:
	_state.acquire(TestFixtures.artifact(&"charm", ArtifactDef.Effect.FLAT_BONUS, 3.0))
	assert_int(_score(_pair_line).total()).is_equal(25)


func test_mult_bonus_stacks_additively() -> void:
	_state.acquire(TestFixtures.artifact(&"gears_a", ArtifactDef.Effect.MULT_BONUS, 0.5))
	_state.acquire(TestFixtures.artifact(&"gears_b", ArtifactDef.Effect.MULT_BONUS, 1.0))
	var ctx: ArtifactEngine.SpinContext = _score(_pair_line)
	assert_float(ctx.multiplier).is_equal_approx(3.0, 0.001)
	assert_int(ctx.total()).is_equal(42)


func test_symbol_bonus_pays_once_per_matching_symbol() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(&"bomb", ArtifactDef.Effect.SYMBOL_BONUS, 4.0,
			ArtifactDef.Trigger.SYMBOL_LANDED)
	artifact.symbol_filter = &"cherry"
	_state.acquire(artifact)
	assert_int(_score(_pair_line).total()).is_equal(33)


func test_symbol_bonus_stays_silent_when_nothing_matches() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(&"bomb", ArtifactDef.Effect.SYMBOL_BONUS, 4.0,
			ArtifactDef.Trigger.SYMBOL_LANDED)
	artifact.symbol_filter = &"diamond"
	_state.acquire(artifact)
	var ctx: ArtifactEngine.SpinContext = _score(_pair_line)
	assert_array(ctx.triggered).is_empty()
	assert_int(ctx.total()).is_equal(21)


func test_pattern_mult_only_fires_on_its_pattern() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(&"ledger", ArtifactDef.Effect.PATTERN_MULT, 3.0)
	artifact.pattern_filter = Probability.Pattern.JACKPOT
	_state.acquire(artifact)
	assert_int(_score(_pair_line).total()).is_equal(21)
	var jackpot: Array[SymbolDef] = [_seven, _seven, _seven]
	assert_float(_score(jackpot).multiplier).is_equal_approx(8.0, 0.001)


func test_synergy_pays_once_the_tag_threshold_is_met() -> void:
	for i: int in 3:
		var artifact: ArtifactDef = TestFixtures.artifact(
				StringName("gear_%d" % i), ArtifactDef.Effect.FLAT_BONUS, 0.0)
		artifact.tags.assign([&"mechanical"])
		_state.acquire(artifact)
	assert_array(_state.active_synergies()).contains([&"mechanical"])
	assert_float(_score(_pair_line).multiplier).is_equal_approx(2.0, 0.001)


func test_extra_spins_accumulate() -> void:
	_state.acquire(TestFixtures.artifact(&"clock_a", ArtifactDef.Effect.EXTRA_SPINS, 2.0))
	_state.acquire(TestFixtures.artifact(&"clock_b", ArtifactDef.Effect.EXTRA_SPINS, 1.0))
	assert_int(ArtifactEngine.spin_bonus(_state)).is_equal(3)


func test_ante_discount_is_capped_below_a_free_ride() -> void:
	for i: int in 6:
		_state.acquire(TestFixtures.artifact(
				StringName("contract_%d" % i), ArtifactDef.Effect.ANTE_DISCOUNT, 20.0))
	assert_float(ArtifactEngine.ante_discount_percent(_state)).is_equal_approx(90.0, 0.001)


func test_weight_shift_artifacts_rebuild_the_reel_on_acquisition() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(&"coil", ArtifactDef.Effect.WEIGHT_SHIFT, 15.0,
			ArtifactDef.Trigger.SPIN_STARTED)
	artifact.symbol_filter = &"seven"
	var before: float = Probability.symbol_chance(_state.reel(), &"seven")
	_state.acquire(artifact)
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_greater(before)


func test_retrigger_scores_the_line_again() -> void:
	_state.acquire(TestFixtures.artifact(&"drums", ArtifactDef.Effect.RETRIGGER, 1.0))
	# The pair pays 21 once, so scoring it twice pays 42.
	assert_int(_score(_pair_line).total()).is_equal(42)


func test_a_ward_turns_curses_into_payers_and_restores_the_pattern() -> void:
	var line: Array[SymbolDef] = [_cherry, _cherry, _skull]
	# Unwarded: the skull costs 2 and kills the pair bonus.
	var bare: ArtifactEngine.SpinContext = _score(line)
	assert_int(bare.base_payout).is_equal(2)
	assert_float(bare.multiplier).is_equal_approx(1.0, 0.001)

	_state.acquire(TestFixtures.artifact(&"ward", ArtifactDef.Effect.CURSE_WARD, 6.0))
	var warded: ArtifactEngine.SpinContext = _score(line)
	assert_int(warded.base_payout).is_equal(10)
	assert_float(warded.multiplier).is_equal_approx(1.5, 0.001)


func test_mult_per_floor_scales_with_progress() -> void:
	_state.acquire(TestFixtures.artifact(&"flywheel", ArtifactDef.Effect.MULT_PER_FLOOR, 0.5))
	assert_float(_score(_pair_line).multiplier).is_equal_approx(1.5, 0.001)
	_state.floors_cleared = 4
	assert_float(_score(_pair_line).multiplier).is_equal_approx(3.5, 0.001)


func test_mult_per_artifact_scales_with_the_build() -> void:
	_state.acquire(TestFixtures.artifact(&"coupling", ArtifactDef.Effect.MULT_PER_ARTIFACT, 0.25))
	# One artifact owned: +0.25 on top of the pair's 1.5.
	assert_float(_score(_pair_line).multiplier).is_equal_approx(1.75, 0.001)
	_state.acquire(TestFixtures.artifact(&"filler", ArtifactDef.Effect.FLAT_BONUS, 0.0))
	assert_float(_score(_pair_line).multiplier).is_equal_approx(2.0, 0.001)


func test_debt_paydown_wipes_a_share_of_the_principal() -> void:
	_state.economy.debt = 400
	_state.acquire(TestFixtures.artifact(&"clause", ArtifactDef.Effect.DEBT_PAYDOWN, 25.0,
			ArtifactDef.Trigger.FLOOR_CLEARED))
	assert_int(ArtifactEngine.apply_debt_paydown(_state)).is_equal(100)
	assert_int(_state.economy.debt).is_equal(300)


func test_interest_artifacts_pay_from_banked_cash() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(&"key", ArtifactDef.Effect.INTEREST, 10.0,
			ArtifactDef.Trigger.FLOOR_CLEARED)
	artifact.cap = 15.0
	_state.acquire(artifact)
	_state.economy.credit(190, &"payout")
	assert_int(ArtifactEngine.apply_floor_interest(_state)).is_equal(15)
