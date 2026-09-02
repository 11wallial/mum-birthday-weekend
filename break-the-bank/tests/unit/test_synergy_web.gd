## The effects that read the run and the board rather than the line: tallies
## that grow only when a spin settles, triggers on triggers, partners, tags,
## the stake, the holds, the nudges, the streak, the clock, and the boiler
## that lights. Fixture content throughout; nothing here moves with balance.
extends GdUnitTestSuite

var _state: RunState
var _cherry: SymbolDef
var _seven: SymbolDef
var _skull: SymbolDef
## cherry + cherry + seven: a PAIR worth 14, multiplier 1.5 on the fixture config.
var _pair: Array[SymbolDef] = []


func before_test() -> void:
	_state = TestFixtures.run_state()
	_cherry = _state.content.symbol_by_id(&"cherry")
	_seven = _state.content.symbol_by_id(&"seven")
	_skull = _state.content.symbol_by_id(&"skull")
	_pair.assign([_cherry, _cherry, _seven])


func _evaluate(line: Array[SymbolDef]) -> ArtifactEngine.SpinContext:
	return ArtifactEngine.evaluate_spin(_state, line, Probability.detect_pattern(line), false)


func _mult(line: Array[SymbolDef]) -> float:
	return _evaluate(line).multiplier


## Puts [param line] on the board with [param payout] and settles it the way
## the engine does, returning whatever lit.
func _settle(line: Array[SymbolDef], payout: int) -> Array[ArtifactDef]:
	_state.board.resize(line.size())
	for i: int in line.size():
		_state.board.line[i] = line[i]
	_state.board.payout = payout
	return ArtifactEngine.record_spin(_state, _state.board)


func _own(id: StringName, effect: ArtifactDef.Effect, magnitude: float,
		cap: float = 0.0) -> ArtifactDef:
	var artifact: ArtifactDef = TestFixtures.artifact(id, effect, magnitude)
	artifact.cap = cap
	_state.acquire(artifact)
	return artifact


func test_a_ledger_grows_only_when_a_spin_settles() -> void:
	var ledger: ArtifactDef = TestFixtures.artifact(&"ledger", ArtifactDef.Effect.MULT_PER_SEEN, 0.5)
	ledger.symbol_filter = &"cherry"
	_state.acquire(ledger)
	# Looking at a line is not landing it: a preview must leave the tally alone.
	ArtifactEngine.score_line(_state, _pair)
	assert_float(_state.tally(&"ledger")).is_equal(0.0)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)
	_settle(_pair, 10)
	assert_float(_state.tally(&"ledger")).is_equal_approx(2.0, 0.001)
	assert_float(_mult(_pair)).is_equal_approx(2.5, 0.001)


func test_a_ledger_is_capped_and_goes_with_its_keeper() -> void:
	var ledger: ArtifactDef = TestFixtures.artifact(&"ledger", ArtifactDef.Effect.MULT_PER_SEEN, 0.5)
	ledger.symbol_filter = &"cherry"
	ledger.cap = 0.7
	_state.acquire(ledger)
	for i: int in 5:
		_settle(_pair, 10)
	assert_float(_mult(_pair)).is_equal_approx(2.2, 0.001)
	# Sold, the tally goes too; bought back, it starts again. Otherwise the
	# market would be a way to keep a ledger without paying for its keeper.
	assert_bool(_state.release(ledger)).is_true()
	assert_float(_state.tally(&"ledger")).is_equal(0.0)
	_state.acquire(ledger)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)


func test_a_family_filter_matches_every_symbol_of_the_family() -> void:
	var press: ArtifactDef = TestFixtures.artifact(&"press", ArtifactDef.Effect.SYMBOL_BONUS, 3.0)
	press.symbol_filter = &"fruit"
	_state.acquire(press)
	# Two cherries are fruit; the seven is not.
	assert_float(_evaluate(_pair).flat_bonus).is_equal_approx(6.0, 0.001)


func test_a_family_weight_shift_moves_every_symbol_of_the_family() -> void:
	var before: float = Probability.symbol_chance(_state.reel(), &"cherry")
	var wall: ArtifactDef = TestFixtures.artifact(&"wall", ArtifactDef.Effect.WEIGHT_SHIFT, 10.0)
	wall.symbol_filter = &"fruit"
	_state.acquire(wall)
	assert_float(Probability.symbol_chance(_state.reel(), &"cherry")).is_greater(before)
	_state.release(wall)
	assert_float(Probability.symbol_chance(_state.reel(), &"cherry")).is_equal_approx(before, 0.0001)


func test_the_exchange_counts_every_other_trigger_and_never_itself() -> void:
	_own(&"exchange", ArtifactDef.Effect.MULT_PER_TRIGGER, 0.5)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)
	_own(&"charm", ArtifactDef.Effect.FLAT_BONUS, 1.0)
	_own(&"gears", ArtifactDef.Effect.MULT_BONUS, 1.0)
	# 1.5, plus the gears, plus two triggers at a half each.
	assert_float(_mult(_pair)).is_equal_approx(3.5, 0.001)
	# A second exchange counts the charm, the gears and the first exchange.
	_own(&"second", ArtifactDef.Effect.MULT_PER_TRIGGER, 0.5)
	assert_float(_mult(_pair)).is_equal_approx(5.0, 0.001)


func test_skulls_scale_the_line_warded_or_not() -> void:
	_own(&"tally", ArtifactDef.Effect.MULT_PER_CURSE, 0.5)
	var line: Array[SymbolDef] = []
	line.assign([_skull, _cherry, _seven])
	var ctx: ArtifactEngine.SpinContext = _evaluate(line)
	assert_int(ctx.base_payout).is_equal(10)
	assert_float(ctx.multiplier).is_equal_approx(1.5, 0.001)
	_own(&"ward", ArtifactDef.Effect.CURSE_WARD, 4.0)
	ctx = _evaluate(line)
	assert_int(ctx.base_payout).is_equal(16)
	assert_float(ctx.multiplier).is_equal_approx(1.5, 0.001)


func test_holds_and_nudges_pay_by_the_count() -> void:
	_own(&"clamp", ArtifactDef.Effect.MULT_PER_HOLD, 0.6)
	_state.board.holds_used = 2
	assert_float(_mult(_pair)).is_equal_approx(2.7, 0.001)
	_state.board.holds_used = 0
	_own(&"adjuster", ArtifactDef.Effect.MULT_PER_NUDGE, 0.5)
	_state.board.nudges_used = 1
	assert_float(_mult(_pair)).is_equal_approx(2.0, 0.001)
	# A preview of the next nudge prices the nudge being considered, or the
	# hint lamp and the automated player undervalue every nudge by one.
	var settled: int = ArtifactEngine.score_line(_state, _pair)
	assert_int(ArtifactEngine.score_line(_state, _pair, true)).is_greater(settled)


func test_the_stake_hardware_pays_above_the_first_level() -> void:
	_own(&"ticket", ArtifactDef.Effect.MULT_PER_STAKE, 0.5)
	_state.stake = 1
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)
	_state.stake = 3
	assert_float(_mult(_pair)).is_equal_approx(2.5, 0.001)


func test_a_streak_grows_on_paying_spins_and_a_dud_resets_it() -> void:
	_own(&"hand", ArtifactDef.Effect.MULT_PER_STREAK, 0.5, 0.7)
	_settle(_pair, 10)
	_settle(_pair, 10)
	assert_int(_state.streak).is_equal(2)
	assert_float(_mult(_pair)).is_equal_approx(2.2, 0.001)
	_settle(_pair, 0)
	assert_int(_state.streak).is_equal(0)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)


func test_tag_scaling_counts_every_device_of_the_kind() -> void:
	var foreman: ArtifactDef = TestFixtures.artifact(&"foreman", ArtifactDef.Effect.MULT_PER_TAG, 0.3)
	foreman.tag_filter = &"mechanical"
	_state.acquire(foreman)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)
	for id: StringName in [&"gear_a", &"gear_b"]:
		var gear: ArtifactDef = TestFixtures.artifact(id, ArtifactDef.Effect.EXTRA_SPINS, 1.0)
		gear.tags.append(&"mechanical")
		_state.acquire(gear)
	assert_float(_mult(_pair)).is_equal_approx(2.1, 0.001)


func test_spins_left_pay_early_and_cap() -> void:
	_own(&"gauge", ArtifactDef.Effect.MULT_PER_SPIN_LEFT, 0.1, 0.5)
	_state.spins_remaining = 10
	assert_float(_mult(_pair)).is_equal_approx(2.0, 0.001)
	_state.spins_remaining = 2
	assert_float(_mult(_pair)).is_equal_approx(1.7, 0.001)


func test_a_partner_pays_nothing_alone() -> void:
	var shark: ArtifactDef = TestFixtures.artifact(&"shark", ArtifactDef.Effect.PARTNER_MULT, 2.0)
	shark.partner = &"mate"
	_state.acquire(shark)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)
	var mate: ArtifactDef = _own(&"mate", ArtifactDef.Effect.EXTRA_SPINS, 1.0)
	assert_float(_mult(_pair)).is_equal_approx(3.5, 0.001)
	_state.release(mate)
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)


func test_a_boiler_lights_after_its_spins_exactly_once() -> void:
	_own(&"boiler", ArtifactDef.Effect.AWAKENED_MULT, 2.0, 3.0)
	assert_array(_settle(_pair, 1)).is_empty()
	assert_array(_settle(_pair, 1)).is_empty()
	assert_float(_mult(_pair)).is_equal_approx(1.5, 0.001)
	assert_int(_settle(_pair, 1).size()).is_equal(1)
	assert_float(_mult(_pair)).is_equal_approx(3.5, 0.001)
	assert_array(_settle(_pair, 1)).is_empty()
	assert_float(ArtifactEngine.awakening(_state, _state.owned[0])).is_equal_approx(1.0, 0.001)


func test_a_retrigger_can_be_confined_to_a_pattern() -> void:
	var drums: ArtifactDef = TestFixtures.artifact(&"drums", ArtifactDef.Effect.RETRIGGER, 1.0)
	drums.pattern_filter = int(Probability.Pattern.JACKPOT)
	_state.acquire(drums)
	assert_float(_evaluate(_pair).retriggers).is_equal(0.0)
	var jackpot: Array[SymbolDef] = []
	jackpot.assign([_cherry, _cherry, _cherry])
	assert_float(_evaluate(jackpot).retriggers).is_equal_approx(1.0, 0.001)


func test_scaling_hardware_writes_itself_onto_the_line_only_when_it_pays() -> void:
	_own(&"ticket", ArtifactDef.Effect.MULT_PER_STAKE, 0.5)
	_state.stake = 1
	assert_array(_evaluate(_pair).triggered).is_empty()
	_state.stake = 2
	assert_array(_evaluate(_pair).triggered).contains([&"ticket"])


func test_the_whale_plays_at_the_stake_the_purse_can_carry() -> void:
	_state.grant_system(Systems.STAKE)
	_state.spins_remaining = 4
	# Floor one's ante is 5: twelve spare credits over four spins a level.
	_state.economy.cash = 17
	assert_int(AutoPlayer.stake(_state)).is_equal(1)
	_own(&"ticket", ArtifactDef.Effect.MULT_PER_STAKE, 0.5)
	assert_int(AutoPlayer.stake(_state)).is_equal(3)
	_state.economy.cash = 6
	assert_int(AutoPlayer.stake(_state)).is_equal(1)


func test_the_wager_above_the_first_level_costs_a_share_of_the_ante() -> void:
	_state.grant_system(Systems.STAKE)
	_state.config.stake_ante_percent = 20.0
	# Floor one's ante is 5: a credit a level, on top of the spin.
	_state.stake = 1
	assert_int(_state.spin_price()).is_equal(1)
	_state.stake = 3
	assert_int(_state.spin_price()).is_equal(5)
	# With nothing earned yet the machine has not shown it pays the premium,
	# so a rich purse alone is no reason to raise.
	_state.stake = 1
	_state.spins_remaining = 4
	_state.economy.cash = 60
	assert_int(AutoPlayer.stake(_state)).is_equal(1)
	# A machine paying twice the premium every spin raises to what it can carry.
	_state.economy.lifetime_earned = 40
	_state.spins_taken = 20
	assert_int(AutoPlayer.stake(_state)).is_greater(1)


func test_the_clamp_makes_cheap_fruit_worth_holding() -> void:
	_state.economy.cash = 50
	var board: SpinBoard = _state.board
	board.resize(3)
	board.line[0] = _cherry
	board.line[1] = _cherry
	board.line[2] = _seven
	board.pattern = Probability.Pattern.PAIR
	# Two cherries are not worth a lock; the lone seven is what gets kept.
	assert_array(Array(AutoPlayer.hold(_state, board))).contains_exactly([2])
	# With hardware paying per reel held, the pair is the point.
	_own(&"clamp", ArtifactDef.Effect.MULT_PER_HOLD, 0.6)
	assert_array(Array(AutoPlayer.hold(_state, board))).contains_exactly([0, 1])


func test_the_buyer_leans_towards_the_build_it_has_started() -> void:
	var mine: ArtifactDef = TestFixtures.artifact(&"mine", ArtifactDef.Effect.FLAT_BONUS, 1.0)
	mine.archetype = &"clamp"
	var other: ArtifactDef = TestFixtures.artifact(&"other", ArtifactDef.Effect.FLAT_BONUS, 1.0)
	var offers: Array[ArtifactDef] = []
	offers.assign([mine, other])
	var prices: Array[int] = [5, 6]
	_state.economy.chips = 100
	# Nothing started: the dearer thing, as always.
	assert_int(AutoPlayer.shop(_state, offers, prices)).is_equal(1)
	var started: ArtifactDef = TestFixtures.artifact(&"started", ArtifactDef.Effect.EXTRA_SPINS, 1.0)
	started.archetype = &"clamp"
	_state.acquire(started)
	assert_str(String(AutoPlayer.chased_archetype(_state))).is_equal("clamp")
	assert_int(AutoPlayer.shop(_state, offers, prices)).is_equal(0)
