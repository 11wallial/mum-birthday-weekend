extends GdUnitTestSuite

## The shipped ladder and challenges, as data: eight rungs each harder in
## authorship than the last, a chain of unlocks up them, and every challenge
## a real rule.

var _catalogue: MetaCatalogue


func before() -> void:
	_catalogue = MetaCatalogue.new()
	_catalogue.load_all()


func test_the_ladder_has_eight_rungs_in_order() -> void:
	assert_int(_catalogue.difficulties.size()).is_equal(8)
	for i: int in _catalogue.difficulties.size():
		assert_int(_catalogue.difficulties[i].tier).is_equal(i + 1)
	assert_str(String(_catalogue.difficulties[0].id)).is_equal("standard")
	assert_str(String(_catalogue.difficulties[7].id)).is_equal("house_rules")


func test_the_first_rung_changes_nothing() -> void:
	var standard: RunOptions = _catalogue.options_for_difficulty(&"standard")
	var plain: RunOptions = RunOptions.new()
	plain.difficulty_id = &"standard"
	assert_str(standard.ruleset_key()).is_equal(plain.ruleset_key())


func test_every_rung_above_the_first_is_opened_by_a_win_on_the_one_below() -> void:
	for i: int in range(1, _catalogue.difficulties.size()):
		var rung: DifficultyDef = _catalogue.difficulties[i]
		var below: DifficultyDef = _catalogue.difficulties[i - 1]
		var found: bool = false
		for unlock: UnlockDef in _catalogue.unlocks:
			if unlock.kind != UnlockDef.Kind.DIFFICULTY or unlock.target_id != rung.id:
				continue
			found = true
			assert_int(unlock.condition).is_equal(UnlockDef.Condition.WINS_AT)
			assert_str(String(unlock.condition_id)).is_equal(String(below.id))
		assert_bool(found).override_failure_message("no unlock opens %s" % rung.id).is_true()


func test_a_win_on_a_rung_opens_the_next_and_only_the_next() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	assert_array(_catalogue.available_difficulties(profile)).contains_exactly([&"standard"])
	profile.wins_by_difficulty["standard"] = 1
	profile.evaluate(_catalogue.unlocks)
	assert_array(_catalogue.available_difficulties(profile)).contains_exactly([&"standard", &"marked_deck"])
	profile.wins_by_difficulty["marked_deck"] = 1
	profile.evaluate(_catalogue.unlocks)
	assert_int(_catalogue.available_difficulties(profile).size()).is_equal(3)


func test_each_rung_is_at_least_as_hard_in_authorship_as_the_one_below() -> void:
	for i: int in range(1, _catalogue.difficulties.size()):
		var rung: DifficultyDef = _catalogue.difficulties[i]
		var below: DifficultyDef = _catalogue.difficulties[i - 1]
		assert_float(rung.ante_scale).is_greater_equal(below.ante_scale)
		assert_int(rung.spins_delta).is_less_equal(below.spins_delta)
		assert_float(rung.debt_service_scale).is_greater_equal(below.debt_service_scale)
		assert_float(rung.price_scale).is_greater_equal(below.price_scale)
		assert_float(rung.debt_scale).is_greater_equal(below.debt_scale)
		assert_float(rung.heat_carry).is_greater_equal(below.heat_carry)
		assert_float(rung.interest_delta).is_greater_equal(below.interest_delta)
		assert_float(rung.payout_scale).is_less_equal(below.payout_scale)
		assert_bool(rung.no_grace or not below.no_grace).is_true()
		assert_str(rung.ruleset_key_of()).is_not_equal(below.ruleset_key_of())


func test_every_challenge_is_a_rule_of_its_own_and_can_be_opened() -> void:
	assert_int(_catalogue.challenges.size()).is_greater_equal(15)
	var plain: String = RunOptions.new().ruleset_key()
	var keys: Dictionary = {}
	for challenge: ChallengeDef in _catalogue.challenges:
		var options: RunOptions = _catalogue.options_for_challenge(challenge.id)
		assert_str(String(options.challenge_id)).is_equal(String(challenge.id))
		assert_str(options.ruleset_key()).override_failure_message(
				"%s changes nothing" % challenge.id).is_not_equal(plain)
		assert_bool(keys.has(options.ruleset_key())).override_failure_message(
				"%s is the same rule as another challenge" % challenge.id).is_false()
		keys[options.ruleset_key()] = true
		var opened: bool = false
		for unlock: UnlockDef in _catalogue.unlocks:
			if unlock.kind == UnlockDef.Kind.CHALLENGE and unlock.target_id == challenge.id:
				opened = true
		assert_bool(opened).override_failure_message("nothing opens %s" % challenge.id).is_true()
		for system: StringName in challenge.locked_systems:
			assert_bool(Systems.ORDER.has(system)).override_failure_message(
					"%s locks unknown system %s" % [challenge.id, system]).is_true()
		for system: StringName in challenge.early_systems:
			assert_bool(Systems.ORDER.has(system)).override_failure_message(
					"%s hands over unknown system %s" % [challenge.id, system]).is_true()


func test_a_chosen_challenge_sets_the_starter_and_the_audit_aside() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.selected_difficulty = &"house_rules"
	profile.selected_starter = &"flush"
	profile.selected_challenge = &"bare_reels"
	var options: RunOptions = _catalogue.options_for(profile, ContentDB.shared())
	assert_str(String(options.challenge_id)).is_equal("bare_reels")
	assert_str(String(options.difficulty_id)).is_equal("standard")
	assert_float(options.ante_scale).is_equal(1.0)
	assert_array(options.locked_systems).contains([Systems.HOLD])


func test_the_top_rung_carries_every_audit_below_it() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.selected_difficulty = &"house_rules"
	var options: RunOptions = _catalogue.options_for(profile, ContentDB.shared())
	assert_float(options.ante_scale).is_equal(1.2)
	assert_float(options.debt_service_scale).is_equal(1.5)
	assert_float(options.price_scale).is_equal(1.2)
	assert_float(options.debt_scale).is_equal(1.5)
	assert_float(options.interest_delta).is_equal(15.0)
	assert_float(options.payout_scale).is_equal(0.95)
	assert_bool(options.no_grace).is_false()


func test_a_batch_on_the_top_rung_wins_less_often_than_one_on_the_first() -> void:
	# Two hundred runs is coarse, but a ladder whose top is not harder than
	# its bottom is not a ladder, and that shows at any size.
	var bottom: Dictionary = CasinoLab.run_batch(200, 7, _catalogue.options_for_difficulty(&"standard"))
	var top: Dictionary = CasinoLab.run_batch(200, 7, _catalogue.options_for_difficulty(&"house_rules"))
	assert_float(float(top["win_rate"])).is_less(float(bottom["win_rate"]))
