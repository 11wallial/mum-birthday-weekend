extends GdUnitTestSuite

## The House's memos as shipped: one for every floor, none too long for the
## monitor, none that can never be printed.

const LINE_MAX: int = 24

var _book: MemoBook


func before() -> void:
	_book = MemoBook.new()
	_book.load_all()


func test_the_house_has_something_to_say_on_every_floor() -> void:
	var content: ContentDB = ContentDB.shared()
	var engine: SimEngine = SimEngine.new(content, EffectBus.new())
	engine.clear_policies()
	var state: RunState = engine.start_run(1)
	for floor_def: FloorDef in content.floors:
		state.floor_index = floor_def.index
		assert_str(_book.memo_for(state)).override_failure_message(
				"the House has nothing to say on floor %d" % floor_def.index).is_not_empty()


func test_every_memo_fits_the_monitor() -> void:
	assert_int(_book.memos.size()).is_greater_equal(15)
	for memo: MemoDef in _book.memos:
		var lines: PackedStringArray = memo.text.split("\n", false)
		assert_int(lines.size()).override_failure_message(
				"%s runs to %d lines" % [memo.id, lines.size()]).is_less_equal(2)
		for line: String in lines:
			assert_int(line.length()).override_failure_message(
					"%s: '%s' is too wide for the screen" % [memo.id, line]).is_less_equal(LINE_MAX)
