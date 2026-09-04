extends GdUnitTestSuite

## The statement of account: the outcome in the House's terms, the moves
## counted from the journal, and findings a player can point at.

var _engine: SimEngine
var _state: RunState


func before_test() -> void:
	var content: ContentDB = TestFixtures.content_with_shop()
	content.floors.assign([
		TestFixtures.floor_def(1, 60, 6),
		TestFixtures.floor_def(2, 120, 6),
	])
	_engine = SimEngine.new(content, EffectBus.new())
	_engine.clear_policies()
	_state = _engine.start_run(4)


func test_moves_are_counted_by_verb() -> void:
	var moves: Dictionary = RunRecap.count_moves([["spin"], ["spin"], ["toggle_hold", 1], ["nudge", 0]])
	assert_int(int(moves["spin"])).is_equal(2)
	assert_int(int(moves["toggle_hold"])).is_equal(1)
	assert_int(int(moves.get("gamble", 0))).is_equal(0)


func test_a_lost_ante_says_what_was_owed_and_held() -> void:
	_state.economy.cash = 7
	_state.spins_remaining = 0
	_engine.step(_state)
	assert_int(_state.phase).is_equal(RunState.Phase.LOST)
	var recap: Dictionary = RunRecap.build(_state, [["spin"]])
	assert_bool(bool(recap["won"])).is_false()
	assert_str(RunRecap.say(recap["outcome"])).contains("You held 7")
	var findings: PackedStringArray = _said(recap["findings"])
	assert_bool(findings.size() > 0).is_true()
	assert_str(findings[0]).contains("Short by")


func test_findings_name_the_notice_and_the_reel_never_held() -> void:
	_state.notices = 1
	_state.noticed_floor = 1
	_state.noticed_payout = 400
	_state.floors_cleared = 1
	_state.grant_system(Systems.HOLD)
	var findings: PackedStringArray = _said(RunRecap.findings(_state, {"spin": 12}))
	var joined: String = "\n".join(findings)
	assert_str(joined).contains("noticed you once")
	assert_str(joined).contains("never held a reel")


func test_findings_are_capped_and_a_held_reel_is_not_a_finding() -> void:
	_state.notices = 2
	_state.floors_cleared = 5
	_state.grant_system(Systems.HOLD)
	_state.grant_system(Systems.STAKE)
	_state.grant_system(Systems.VAULT)
	_state.chips_left_at_drafts = PackedInt32Array([4, 5, 6])
	var findings: PackedStringArray = _said(RunRecap.findings(_state,
			{"toggle_hold": 3, "decline_nudges": 5, "nudge": 0}))
	assert_int(findings.size()).is_less_equal(RunRecap.MAX_FINDINGS)
	assert_str("\n".join(findings)).not_contains("never held a reel")


func test_a_cleared_run_reads_as_a_return_of_the_surety() -> void:
	_state.phase = RunState.Phase.WON
	_state.end_reason = &"cleared_all_floors"
	var recap: Dictionary = RunRecap.build(_state)
	assert_bool(bool(recap["won"])).is_true()
	assert_str(RunRecap.say(recap["outcome"])).contains("surety is returned")


## The findings as English. They are shapes and their numbers now, so a
## translator can move the number; a test still reads the sentence.
func _said(findings: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in findings:
		out.append(RunRecap.say(entry as Dictionary))
	return out
