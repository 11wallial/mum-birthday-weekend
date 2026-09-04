extends GdUnitTestSuite

var _cherry: SymbolDef
var _lemon: SymbolDef
var _seven: SymbolDef
var _wild: SymbolDef
var _skull: SymbolDef


func before_test() -> void:
	_cherry = TestFixtures.symbol(&"cherry", 2, 20, &"fruit")
	_lemon = TestFixtures.symbol(&"lemon", 2, 20, &"fruit")
	_seven = TestFixtures.symbol(&"seven", 10, 5)
	_wild = TestFixtures.symbol(&"wild", 5, 4, &"", true)
	_skull = TestFixtures.symbol(&"skull", 0, 5, &"", false, true)


func test_three_of_a_kind_is_a_jackpot() -> void:
	var line: Array[SymbolDef] = [_seven, _seven, _seven]
	assert_int(Probability.detect_pattern(line)).is_equal(Probability.Pattern.JACKPOT)


func test_same_family_counts_as_a_match() -> void:
	var line: Array[SymbolDef] = [_cherry, _lemon, _seven]
	assert_int(Probability.detect_pattern(line)).is_equal(Probability.Pattern.PAIR)


func test_wild_completes_the_largest_group() -> void:
	var line: Array[SymbolDef] = [_seven, _seven, _wild]
	assert_int(Probability.detect_pattern(line)).is_equal(Probability.Pattern.JACKPOT)


func test_all_wilds_are_a_jackpot() -> void:
	var line: Array[SymbolDef] = [_wild, _wild, _wild]
	assert_int(Probability.detect_pattern(line)).is_equal(Probability.Pattern.JACKPOT)


func test_distinct_symbols_are_a_clean_sweep() -> void:
	var line: Array[SymbolDef] = [_cherry, _seven, TestFixtures.symbol(&"bell", 4, 10)]
	assert_int(Probability.detect_pattern(line)).is_equal(Probability.Pattern.CLEAN_SWEEP)


func test_a_curse_denies_the_clean_sweep() -> void:
	var line: Array[SymbolDef] = [_cherry, _seven, _skull]
	assert_int(Probability.detect_pattern(line)).is_equal(Probability.Pattern.NONE)


func test_weight_shifts_change_the_reel_but_never_go_negative() -> void:
	var symbols: Array[SymbolDef] = [_cherry, _seven]
	var reel: Array[Probability.ReelEntry] = Probability.build_reel(symbols, {&"cherry": -999, &"seven": 5})
	assert_int(reel[0].weight).is_equal(0)
	assert_int(reel[1].weight).is_equal(10)
	assert_float(Probability.symbol_chance(reel, &"seven")).is_equal_approx(1.0, 0.001)


func test_a_zero_weight_reel_draws_nothing() -> void:
	var symbols: Array[SymbolDef] = [TestFixtures.symbol(&"ghost", 1, 0)]
	var reel: Array[Probability.ReelEntry] = Probability.build_reel(symbols)
	assert_object(Probability.draw_symbol(reel, RngStream.new(1, &"t"))).is_null()


func test_symbol_chance_tracks_the_sampled_frequency() -> void:
	var symbols: Array[SymbolDef] = [_cherry, _seven]
	var reel: Array[Probability.ReelEntry] = Probability.build_reel(symbols)
	var rng: RngStream = RngStream.new(7, &"reels")
	var hits: int = 0
	for i: int in 20000:
		if Probability.draw_symbol(reel, rng).id == &"seven":
			hits += 1
	var expected: float = Probability.symbol_chance(reel, &"seven")
	assert_float(float(hits) / 20000.0).is_equal_approx(expected, 0.02)
