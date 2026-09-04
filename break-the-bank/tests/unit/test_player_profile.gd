extends GdUnitTestSuite

const TEST_PATH: String = "user://test_profile.json"

var _catalogue: Array[UnlockDef] = []


func before_test() -> void:
	_catalogue = [
		_unlock(&"u_floor3", UnlockDef.Kind.ARTIFACT, &"vault_key", UnlockDef.Condition.BEST_FLOOR, 3),
		_unlock(&"u_win", UnlockDef.Kind.DIFFICULTY, &"marked_deck", UnlockDef.Condition.WINS, 1),
	]


func after_test() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func _unlock(id: StringName, kind: UnlockDef.Kind, target: StringName,
		condition: UnlockDef.Condition, threshold: int) -> UnlockDef:
	var unlock: UnlockDef = UnlockDef.new()
	unlock.id = id
	unlock.display_name = String(id)
	unlock.kind = kind
	unlock.target_id = target
	unlock.condition = condition
	unlock.threshold = threshold
	return unlock


func test_a_fresh_profile_starts_empty() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	assert_int(profile.runs_played).is_equal(0)
	assert_array(profile.unlocked).is_empty()


func test_saving_and_loading_round_trips() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.runs_played = 7
	profile.wins = 2
	profile.best_floor = 5
	profile.lifetime_earned = 9000
	profile.selected_difficulty = &"marked_deck"
	profile.unlocked.append(&"u_win")
	assert_bool(profile.save(TEST_PATH)).is_true()

	var loaded: PlayerProfile = PlayerProfile.load_or_new(TEST_PATH)
	assert_int(loaded.runs_played).is_equal(7)
	assert_int(loaded.wins).is_equal(2)
	assert_int(loaded.best_floor).is_equal(5)
	assert_int(loaded.lifetime_earned).is_equal(9000)
	assert_str(String(loaded.selected_difficulty)).is_equal("marked_deck")
	assert_bool(loaded.has_unlock(&"u_win")).is_true()


func test_a_corrupt_save_starts_fresh_rather_than_failing() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert_int(PlayerProfile.load_or_new(TEST_PATH).runs_played).is_equal(0)


func test_a_save_from_a_newer_build_is_not_misread() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": PlayerProfile.VERSION + 1, "runs_played": 99}))
	file.close()
	assert_int(PlayerProfile.load_or_new(TEST_PATH).runs_played).is_equal(0)


func test_unlocks_are_granted_once_when_their_condition_is_met() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	assert_array(profile.evaluate(_catalogue)).is_empty()
	profile.best_floor = 3
	var earned: Array[UnlockDef] = profile.evaluate(_catalogue)
	assert_int(earned.size()).is_equal(1)
	assert_str(String(earned[0].id)).is_equal("u_floor3")
	# Evaluating again must not re-announce it.
	assert_array(profile.evaluate(_catalogue)).is_empty()


func test_recording_a_run_folds_in_its_totals() -> void:
	var state: RunState = TestFixtures.run_state(5)
	state.floors_cleared = 4
	state.economy.lifetime_earned = 1200
	state.phase = RunState.Phase.WON
	var profile: PlayerProfile = PlayerProfile.new()
	var earned: Array[UnlockDef] = profile.record_run(state, _catalogue)
	assert_int(profile.runs_played).is_equal(1)
	assert_int(profile.wins).is_equal(1)
	assert_int(profile.best_floor).is_equal(4)
	assert_int(profile.lifetime_earned).is_equal(1200)
	# Best floor 4 and one win clear both catalogue entries.
	assert_int(earned.size()).is_equal(2)


func test_a_run_folds_into_the_lifetime_ledger_and_the_ladder() -> void:
	var state: RunState = TestFixtures.run_state(5)
	state.spins_taken = 40
	state.best_payout = 900
	state.economy.debt_serviced = 77
	state.owned.append(TestFixtures.artifact(&"lucky_charm", ArtifactDef.Effect.FLAT_BONUS, 1.0))
	state.options.difficulty_id = &"marked_deck"
	state.phase = RunState.Phase.WON
	var profile: PlayerProfile = PlayerProfile.new()
	profile.record_run(state, [])
	assert_int(profile.total_spins).is_equal(40)
	assert_int(profile.biggest_spin).is_equal(900)
	assert_int(profile.vig_paid).is_equal(77)
	assert_str(String(profile.favourite_artifact())).is_equal("lucky_charm")
	assert_int(int(profile.wins_by_difficulty["marked_deck"])).is_equal(1)
	assert_int(int(profile.stats()["wins_at:marked_deck"])).is_equal(1)
	# A challenge win is a win, but not a rung climbed.
	state.options.challenge_id = &"bare_reels"
	profile.record_run(state, [])
	assert_int(profile.wins).is_equal(2)
	assert_int(int(profile.wins_by_difficulty["marked_deck"])).is_equal(1)

	assert_bool(profile.save(TEST_PATH)).is_true()
	var loaded: PlayerProfile = PlayerProfile.load_or_new(TEST_PATH)
	assert_int(loaded.biggest_spin).is_equal(900)
	assert_int(int(loaded.wins_by_difficulty["marked_deck"])).is_equal(1)
	assert_str(String(loaded.favourite_artifact())).is_equal("lucky_charm")


func test_locked_artifacts_are_kept_out_of_the_pool() -> void:
	var artifacts: Array[ArtifactDef] = [
		TestFixtures.artifact(&"vault_key", ArtifactDef.Effect.FLAT_BONUS, 1.0),
		TestFixtures.artifact(&"always_there", ArtifactDef.Effect.FLAT_BONUS, 1.0),
	]
	var profile: PlayerProfile = PlayerProfile.new()
	var allowed: Array[StringName] = profile.unlocked_artifacts(_catalogue, artifacts)
	# Ungated artifacts are always available; the gated one is not, yet.
	assert_array(allowed).contains([&"always_there"])
	assert_bool(allowed.has(&"vault_key")).is_false()

	profile.best_floor = 3
	profile.evaluate(_catalogue)
	assert_array(profile.unlocked_artifacts(_catalogue, artifacts)).contains([&"vault_key"])
