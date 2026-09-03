extends GdUnitTestSuite

## Every save this game writes, corrupted every way a disk corrupts one,
## and none of it may crash or come back as anything but a fresh start.
##
## The three loaders already claim to fail to fresh. Nothing had ever
## handed them a truncated file, a list where an object belongs, a number
## past the end of the world, or twenty thousand records — and "it never
## happened in a run" is not the same as "it cannot".

const DIR: String = "user://torture"

## What a broken file looks like. Each is something a real disk, a real
## crash or a real editor has produced.
const WRECKAGE: Array = [
	["empty", ""],
	["whitespace", "   "],
	["truncated object", '{"version": 1, "runs_play'],
	["not json", "binary nonsense"],
	["a list, not an object", "[1, 2, 3]"],
	["a number", "42"],
	["a string", '"a profile, honestly"'],
	["null", "null"],
	["nested past reason", '{"a": {"a": {"a": {"a": {"a": {"a": 1}}}}}}'],
	["wrong types throughout", '{"version": "one", "runs_played": [], "wins": {}, "unlocked": 7, "settings": "none", "seen": 3}'],
	["numbers past the end of the world", '{"runs_played": 1e308, "wins": -1e308, "best_floor": 99999999999}'],
	["keys that are not keys", '{"": 1, "a b": 2}'],
]


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(DIR)
	if dir != null:
		for file_name: String in dir.get_files():
			dir.remove(file_name)


func _wreck(wreck_name: String, text: String) -> String:
	var path: String = "%s/%s.json" % [DIR, wreck_name.replace(" ", "_")]
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(text)
	handle.close()
	return path


func test_a_wrecked_profile_comes_back_fresh() -> void:
	for wreck: Array in WRECKAGE:
		var path: String = _wreck("profile_%s" % wreck[0], String(wreck[1]))
		var profile: PlayerProfile = PlayerProfile.load_or_new(path)
		assert_object(profile).override_failure_message(
				"a %s profile came back as nothing" % wreck[0]).is_not_null()
		assert_int(profile.runs_played).override_failure_message(
				"a %s profile came back with runs on it" % wreck[0]).is_greater_equal(0)
		# And it can still be written back out over the wreckage.
		assert_bool(profile.save(path)).is_true()
		assert_object(PlayerProfile.load_or_new(path)).is_not_null()


func test_a_wrecked_leaderboard_comes_back_fresh() -> void:
	for wreck: Array in WRECKAGE:
		var path: String = _wreck("board_%s" % wreck[0], String(wreck[1]))
		var board: Leaderboard = Leaderboard.load_or_new(path)
		assert_object(board).override_failure_message(
				"a %s board came back as nothing" % wreck[0]).is_not_null()
		assert_bool(board.save(path)).is_true()


func test_a_wrecked_run_save_is_refused_rather_than_replayed() -> void:
	var content: ContentDB = ContentDB.shared()
	for wreck: Array in WRECKAGE:
		var path: String = _wreck("run_%s" % wreck[0], String(wreck[1]))
		var journal: RunJournal = RunSave.read(content, path)
		assert_object(journal).override_failure_message(
				"a %s run save was accepted" % wreck[0]).is_null()


func test_a_save_from_a_newer_build_is_refused() -> void:
	var path: String = _wreck("run_future",
			'{"save_version": 99, "content": "whatever", "seed": 1, "entries": []}')
	assert_object(RunSave.read(ContentDB.shared(), path)).is_null()


func test_a_save_against_other_content_is_refused() -> void:
	var path: String = _wreck("run_other",
			'{"save_version": 1, "content": "not-this-content", "seed": 1, "entries": []}')
	assert_object(RunSave.read(ContentDB.shared(), path)).is_null()


func test_a_journal_full_of_nonsense_verbs_replays_to_a_playable_run() -> void:
	# The half-way case that matters most: the file parses, the fingerprint
	# matches, and the entries are rubbish. A run must come back playable.
	var content: ContentDB = ContentDB.shared()
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = 7
	journal.entries = [["spin"], ["nudge", 99], ["fly"], [], ["press", -4],
			["buy_offer", 12345], [42], ["use_chit", 9]]
	var path: String = "%s/run_rubbish.json" % DIR
	assert_bool(RunSave.write(journal, content, path)).is_true()
	var back: RunJournal = RunSave.read(content, path)
	assert_object(back).is_not_null()
	var engine: SimEngine = SimEngine.new(content, EffectBus.new())
	engine.clear_policies()
	var state: RunState = engine.start_run(back.seed_value, back.options)
	var replayed: int = RunJournal.replay(engine, state, back.entries)
	assert_int(replayed).override_failure_message(
			"a journal of nonsense replayed further than the nonsense").is_less_equal(back.entries.size())
	assert_object(state).is_not_null()
	assert_int(state.floor_index).is_greater_equal(1)


func test_a_profile_with_twenty_thousand_records_still_loads() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	for i: int in 20000:
		profile.records["ruleset-%d|%d" % [i % 97, i]] = i
	var path: String = "%s/profile_big.json" % DIR
	assert_bool(profile.save(path)).is_true()
	var back: PlayerProfile = PlayerProfile.load_or_new(path)
	assert_int(back.records.size()).is_equal(20000)
