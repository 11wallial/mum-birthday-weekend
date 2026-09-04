extends GdUnitTestSuite

## A shared seed is a shared run, so the code has to survive a round trip
## through a person: typed, mistyped, lower-cased, read aloud.


func test_codes_round_trip() -> void:
	for value: int in [0, 1, 42, 99999, SeedBook.SEED_SPACE - 1]:
		assert_int(SeedBook.from_code(SeedBook.to_code(value))).is_equal(value)


func test_codes_are_case_and_space_insensitive() -> void:
	var code: String = SeedBook.to_code(12345)
	assert_int(SeedBook.from_code("  " + code.to_lower() + " ")).is_equal(12345)


func test_a_bad_code_is_rejected_rather_than_guessed() -> void:
	assert_int(SeedBook.from_code("NOT-A-REAL-SEED-CODE")).is_equal(-1)
	assert_int(SeedBook.from_code("SOLAR-MIRTH")).is_equal(-1)
	assert_int(SeedBook.from_code("")).is_equal(-1)


func test_parse_accepts_codes_numbers_and_phrases() -> void:
	assert_int(SeedBook.parse(SeedBook.to_code(777))).is_equal(777)
	assert_int(SeedBook.parse("1234")).is_equal(1234)
	# A phrase is hashed, and the same phrase always gives the same run.
	var phrase: int = SeedBook.parse("mum's birthday")
	assert_int(phrase).is_greater_equal(0)
	assert_int(SeedBook.parse("Mum's Birthday")).is_equal(phrase)
	assert_int(SeedBook.parse("a different phrase")).is_not_equal(phrase)


func test_empty_input_is_the_only_failure() -> void:
	assert_int(SeedBook.parse("   ")).is_equal(-1)


func test_the_daily_seed_is_stable_per_date_and_differs_between_days() -> void:
	assert_int(SeedBook.daily_seed("2026-08-31")).is_equal(SeedBook.daily_seed("2026-08-31"))
	assert_int(SeedBook.daily_seed("2026-08-31")).is_not_equal(SeedBook.daily_seed("2026-09-01"))


func test_daily_seeds_stay_inside_the_code_space() -> void:
	# Otherwise the day's code would not decode back to the day's run.
	for day: int in range(1, 29):
		var seed_value: int = SeedBook.daily_seed("2026-02-%02d" % day)
		assert_int(seed_value).is_between(0, SeedBook.SEED_SPACE - 1)
		assert_int(SeedBook.from_code(SeedBook.to_code(seed_value))).is_equal(seed_value)
