extends GdUnitTestSuite

## The collection: what a profile has met, kept across runs and saves, with
## the first sighting said once.


func test_a_sighting_is_first_once_and_kept() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	assert_bool(profile.note_seen("artifacts", &"lucky_charm")).is_true()
	assert_bool(profile.note_seen("artifacts", &"lucky_charm")).is_false()
	assert_bool(profile.has_seen("artifacts", &"lucky_charm")).is_true()
	assert_int(profile.seen_count("artifacts")).is_equal(1)
	assert_int(profile.seen_count("bosses")).is_equal(0)


func test_the_collection_survives_a_save() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.note_seen("bosses", &"the_bouncer")
	profile.note_seen("contracts", &"overtime")
	var back: PlayerProfile = PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_bool(back.has_seen("bosses", &"the_bouncer")).is_true()
	assert_bool(back.has_seen("contracts", &"overtime")).is_true()
	assert_bool(back.has_seen("artifacts", &"anything")).is_false()


func test_a_run_folds_its_sightings_in() -> void:
	var engine: SimEngine = SimEngine.new(TestFixtures.content_with_shop(), EffectBus.new())
	engine.clear_policies()
	var state: RunState = engine.start_run(2)
	state.offers_seen[&"cheap_charm"] = 1
	state.bosses_faced.append(&"somebody")
	state.contracts_signed.append(&"a_clause")
	var profile: PlayerProfile = PlayerProfile.new()
	profile.note_seen_run(state)
	assert_bool(profile.has_seen("artifacts", &"cheap_charm")).is_true()
	assert_bool(profile.has_seen("bosses", &"somebody")).is_true()
	assert_bool(profile.has_seen("contracts", &"a_clause")).is_true()
