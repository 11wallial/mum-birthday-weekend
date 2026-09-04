extends GdUnitTestSuite

## What the House prints, and when. The memo is chosen from where the run
## stands, the most specific one that fits wins, and the choice is part of
## the run: the same seed on the same floor reads the same line.

var _book: MemoBook
var _content: ContentDB


func before_test() -> void:
	_content = TestFixtures.content()
	_content.floors.assign([
		TestFixtures.floor_granting(1, 20, 6, [Systems.HEAT]),
		TestFixtures.floor_def(2, 40, 6),
		TestFixtures.floor_def(3, 60, 6),
	])
	_book = MemoBook.new()
	_book.memos.assign([
		_memo(&"anywhere", "Your account is open."),
		_memo(&"floor_two", "The market is open.", {"floor_min": 2, "floor_max": 2}),
		_memo(&"heavy", "The vig is due first.", {"debt_ratio_min": 1.0}),
		_memo(&"heavy_on_two", "Read the second half.", {"floor_min": 2, "floor_max": 2, "debt_ratio_min": 1.0}),
		_memo(&"cold", "The good symbols are away.", {"heat_min": 2}),
		_memo(&"after_a", "The lights stay on.", {"after_hours": true}),
		_memo(&"after_b", "Your chair is kept.", {"after_hours": true}),
		_memo(&"last", "Clear the rest.", {"last_floor": true}),
	])


func _memo(id: StringName, text: String, rules: Dictionary = {}) -> MemoDef:
	var memo: MemoDef = MemoDef.new()
	memo.id = id
	memo.text = text
	for key: String in rules:
		memo.set(key, rules[key])
	return memo


func _state(run_seed: int = 9) -> RunState:
	var engine: SimEngine = SimEngine.new(_content, EffectBus.new())
	engine.clear_policies()
	return engine.start_run(run_seed)


func test_the_plainest_memo_is_the_fallback() -> void:
	var state: RunState = _state()
	state.economy.debt = 0
	assert_str(String(_book.choose(state).id)).is_equal("anywhere")


func test_the_most_specific_memo_that_fits_wins() -> void:
	var state: RunState = _state()
	state.floor_index = 2
	state.economy.debt = 0
	assert_str(String(_book.choose(state).id)).is_equal("floor_two")
	state.economy.debt = 100
	assert_str(String(_book.choose(state).id)).is_equal("heavy_on_two")


func test_the_debt_is_read_against_the_ante_in_front_of_the_run() -> void:
	var state: RunState = _state()
	state.economy.debt = 19
	assert_str(String(_book.choose(state).id)).is_equal("anywhere")
	state.economy.debt = 20
	assert_str(String(_book.choose(state).id)).is_equal("heavy")


func test_the_count_has_a_memo_of_its_own() -> void:
	var state: RunState = _state()
	state.economy.debt = 0
	state.heat = state.config.heat_cold_at + 1.0
	assert_str(String(_book.choose(state).id)).is_equal("cold")


func test_the_last_floor_is_told_what_is_still_owed() -> void:
	var state: RunState = _state()
	state.floor_index = 3
	state.economy.debt = 0
	assert_str(String(_book.choose(state).id)).is_equal("last")
	# And not once the run has stayed: there is no last floor after hours.
	state.endless = true
	assert_str(String(_book.choose(state).id)).is_not_equal("last")


func test_the_choice_is_part_of_the_run() -> void:
	# Two memos for the same moment tie; the seed and the floor pick one, and
	# pick the same one every time the ledger is redrawn.
	var state: RunState = _state()
	state.endless = true
	state.floor_index = 4
	state.economy.debt = 0
	var first: StringName = _book.choose(state).id
	for i: int in 5:
		assert_str(String(_book.choose(state).id)).is_equal(String(first))


func test_after_hours_has_its_own_voice_and_never_speaks_before() -> void:
	var state: RunState = _state()
	state.economy.debt = 0
	assert_bool(String(_book.choose(state).id).begins_with("after")).is_false()
	state.endless = true
	state.floor_index = 3
	var said: StringName = _book.choose(state).id
	assert_bool(String(said).begins_with("after")).is_true()
	# Two memos for the same moment both get read, across seeds, not within one.
	var seen: Dictionary = {}
	for run_seed: int in 12:
		var other: RunState = _state(run_seed)
		other.endless = true
		other.floor_index = 3
		other.economy.debt = 0
		seen[_book.choose(other).id] = true
	assert_int(seen.size()).is_equal(2)


func test_nothing_fitting_is_an_empty_line() -> void:
	var empty: MemoBook = MemoBook.new()
	assert_str(empty.memo_for(_state())).is_equal("")
	assert_str(empty.memo_for(null)).is_equal("")
