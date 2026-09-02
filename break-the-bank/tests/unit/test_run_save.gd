extends GdUnitTestSuite

const TEST_PATH: String = "user://test_run_in_progress.json"

var _content: ContentDB


func before_test() -> void:
	_content = TestFixtures.content_with_shop()


func after_test() -> void:
	RunSave.clear(TEST_PATH)


func _journal() -> RunJournal:
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = 4242
	journal.daily_key = "2026-09-02"
	journal.options.bonus_cash = 25
	journal.options.allowed_artifacts = [&"cheap_charm"]
	journal.record(&"spin")
	journal.record(&"nudge", [2])
	journal.record(&"step")
	return journal


func test_a_saved_run_reads_back_whole() -> void:
	assert_bool(RunSave.write(_journal(), _content, TEST_PATH)).is_true()
	var back: RunJournal = RunSave.read(_content, TEST_PATH)
	assert_object(back).is_not_null()
	assert_int(back.seed_value).is_equal(4242)
	assert_str(back.daily_key).is_equal("2026-09-02")
	assert_int(back.options.bonus_cash).is_equal(25)
	assert_array(back.options.allowed_artifacts).contains([&"cheap_charm"])
	assert_int(back.entries.size()).is_equal(3)
	assert_int(int((back.entries[1] as Array)[1])).is_equal(2)


func test_nothing_saved_is_nothing_to_resume() -> void:
	assert_object(RunSave.read(_content, TEST_PATH)).is_null()


func test_a_corrupt_save_starts_fresh_rather_than_failing() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ not a run")
	file.close()
	assert_object(RunSave.read(_content, TEST_PATH)).is_null()


func test_a_save_from_a_newer_build_is_not_misread() -> void:
	var data: Dictionary = _journal().to_dict()
	data["save_version"] = RunSave.VERSION + 1
	data["content"] = RunSave.fingerprint(_content)
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	assert_object(RunSave.read(_content, TEST_PATH)).is_null()


func test_a_save_played_against_other_content_is_set_aside() -> void:
	# A replayed log against a different ante is a different run. Handing the
	# player that quietly would be worse than starting fresh.
	RunSave.write(_journal(), _content, TEST_PATH)
	var retuned: ContentDB = TestFixtures.content_with_shop()
	retuned.floors[0].ante += 1
	assert_str(RunSave.fingerprint(retuned)).is_not_equal(RunSave.fingerprint(_content))
	assert_object(RunSave.read(retuned, TEST_PATH)).is_null()
	# The same content, loaded again, still resumes.
	assert_object(RunSave.read(TestFixtures.content_with_shop(), TEST_PATH)).is_not_null()


func test_clearing_forgets_the_run() -> void:
	RunSave.write(_journal(), _content, TEST_PATH)
	RunSave.clear(TEST_PATH)
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()
	assert_object(RunSave.read(_content, TEST_PATH)).is_null()
