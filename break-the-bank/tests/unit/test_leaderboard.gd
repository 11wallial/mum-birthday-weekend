extends GdUnitTestSuite

const TEST_PATH: String = "user://test_leaderboard.json"


func after_test() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func _finished_run(run_seed: int, score: int, difficulty: StringName = &"standard") -> RunState:
	var state: RunState = TestFixtures.run_state(run_seed)
	state.options.difficulty_id = difficulty
	state.economy.lifetime_earned = score
	state.floors_cleared = 2
	state.phase = RunState.Phase.LOST
	state.end_reason = &"ante_unpaid"
	return state


func test_submitting_stores_the_seed_and_its_shareable_code() -> void:
	var board: Leaderboard = Leaderboard.new()
	var entry: Dictionary = board.submit(_finished_run(4242, 500))
	assert_int(int(entry["seed"])).is_equal(4242)
	assert_str(String(entry["code"])).is_equal(SeedBook.to_code(4242))
	assert_int(int(entry["score"])).is_equal(500)


func test_the_board_is_ordered_by_score() -> void:
	var board: Leaderboard = Leaderboard.new()
	board.submit(_finished_run(1, 100))
	board.submit(_finished_run(2, 900))
	board.submit(_finished_run(3, 400))
	var rows: Array[Dictionary] = board.top(3)
	assert_int(int(rows[0]["score"])).is_equal(900)
	assert_int(int(rows[2]["score"])).is_equal(100)


func test_rulesets_are_scored_separately() -> void:
	# A run on a harder difficulty is not comparable to a standard one.
	var board: Leaderboard = Leaderboard.new()
	board.submit(_finished_run(1, 100))
	board.submit(_finished_run(2, 5000, &"house_rules"))
	var standard: String = _finished_run(3, 0).options.ruleset_key()
	assert_int(board.top(10, standard).size()).is_equal(1)
	assert_int(board.rank_of(50, standard)).is_equal(2)
	assert_int(board.rank_of(5000, standard)).is_equal(1)


func test_daily_runs_can_be_listed_on_their_own() -> void:
	var board: Leaderboard = Leaderboard.new()
	board.submit(_finished_run(1, 100), "2026-08-31")
	board.submit(_finished_run(2, 200))
	assert_int(board.top(10, "", "2026-08-31").size()).is_equal(1)


func test_saving_and_loading_round_trips() -> void:
	var board: Leaderboard = Leaderboard.new()
	board.submit(_finished_run(9, 777), "2026-08-31")
	assert_bool(board.save(TEST_PATH)).is_true()
	var loaded: Leaderboard = Leaderboard.load_or_new(TEST_PATH)
	assert_int(loaded.entries.size()).is_equal(1)
	assert_int(int(loaded.entries[0]["score"])).is_equal(777)


func test_a_missing_board_loads_empty_rather_than_failing() -> void:
	assert_array(Leaderboard.load_or_new("user://definitely_not_here.json").entries).is_empty()
