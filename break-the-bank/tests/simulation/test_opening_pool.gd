extends GdUnitTestSuite

## The game a new profile actually starts with.
##
## Every unlock takes something out of the opening pool, and nothing has ever
## checked what is left. It matters more than it looks: gating the twelve
## specialists cost the opening nothing (16.1% won over 4,000 runs, against
## 15.6% for the whole content set), and gating four more — the Hot Hand, the
## Whale Ticket, the Mirror Shard and the Dead Man's Grip, the most-taken
## artifacts in the game — took it to 4.2%. The pool has a floor, and this is
## where it is written down.
##
## Measure with: run_lab.gd --fresh, which is what the balance gate now runs
## alongside the whole-content batch.

## The share of the artifacts a new profile must still be able to draw. Below
## this the opening is a different game from the one the lab measures.
const POOL_FLOOR: float = 0.6

var _content: ContentDB
var _catalogue: MetaCatalogue
var _fresh: RunOptions


func before() -> void:
	_content = ContentDB.shared()
	_catalogue = MetaCatalogue.new()
	_catalogue.load_all()
	_fresh = _catalogue.options_for(PlayerProfile.new(), _content)


func test_every_unlock_points_at_something_that_exists() -> void:
	# A typo in target_id gates nothing at all, silently, and the only symptom
	# is a line in the unlock panel that never opens anything.
	for unlock: UnlockDef in _catalogue.unlocks:
		var found: bool = false
		match unlock.kind:
			UnlockDef.Kind.ARTIFACT:
				for artifact: ArtifactDef in _content.artifacts:
					found = found or artifact.id == unlock.target_id
			UnlockDef.Kind.CHIT:
				for chit: ChitDef in _content.chits:
					found = found or chit.id == unlock.target_id
			UnlockDef.Kind.STARTER:
				found = _catalogue.machine_by_id(unlock.target_id) != null
			UnlockDef.Kind.DIFFICULTY:
				found = _catalogue.difficulty_by_id(unlock.target_id) != null
			UnlockDef.Kind.CHALLENGE:
				found = _catalogue.challenge_by_id(unlock.target_id) != null
		assert_bool(found).override_failure_message(
				"%s gates %s, which is not in the content" % [
					unlock.id, unlock.target_id]).is_true()


func test_the_opening_pool_holds_most_of_the_collection() -> void:
	var share: float = float(_fresh.allowed_artifacts.size()) / float(_content.artifacts.size())
	assert_float(share).override_failure_message(
			"a new profile can draw %d of %d artifacts; the opening needs %d%%" % [
				_fresh.allowed_artifacts.size(), _content.artifacts.size(),
				int(POOL_FLOOR * 100.0)]).is_greater_equal(POOL_FLOOR)


func test_nothing_gated_is_dealt_to_a_new_profile() -> void:
	for unlock: UnlockDef in _catalogue.unlocks:
		if unlock.kind == UnlockDef.Kind.ARTIFACT:
			assert_array(_fresh.allowed_artifacts).override_failure_message(
					"%s is gated behind %s and dealt anyway" % [
						unlock.target_id, unlock.id]).not_contains([unlock.target_id])
		elif unlock.kind == UnlockDef.Kind.CHIT:
			assert_array(_fresh.allowed_chits).override_failure_message(
					"%s is gated behind %s and dealt anyway" % [
						unlock.target_id, unlock.id]).not_contains([unlock.target_id])


func test_a_new_profile_starts_on_the_first_rung_with_the_standard_machine() -> void:
	assert_str(String(_fresh.difficulty_id)).is_equal("standard")
	assert_array(_catalogue.available_starters(PlayerProfile.new())).is_equal([&"standard"])
	assert_array(_catalogue.available_challenges(PlayerProfile.new())).is_empty()


func test_the_opening_still_has_paper_in_it() -> void:
	# Two chits are ungated. A gate on either would leave the draft empty on
	# floor one, which is not a difficulty change, it is a missing system.
	assert_int(_fresh.allowed_chits.size()).is_greater_equal(2)
