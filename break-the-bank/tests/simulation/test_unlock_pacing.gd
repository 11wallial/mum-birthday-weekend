extends GdUnitTestSuite

## The shape of the arc, frozen.
##
## Unlock thresholds are content, so they drift with every retune, and a
## threshold that drifts down is invisible: everything still unlocks, just
## sooner, until the whole game is open in an evening — which is what the
## career lab found the first time it was pointed at this catalogue. Thirty-five
## of the forty-four were open after five runs, and the next thirty hours
## delivered six.
##
## So the milestones below are what a median career actually holds after 1, 5,
## 10, 20, 40 and 60 runs, measured by tools/casino_lab/career.gd, and the bands
## are the curve the roadmap asks for: a steady arrival across 25–40 hours at
## 25–40 minutes a run. Re-measure with the tool when the economy moves; this
## suite is the guard, not the instrument.

const CAREER: Array = [
	# runs, wins, floor, earned, cleared, spins, vig, rungs won, floor of the band
	{"run": 1, "stats": {"runs_played": 1, "wins": 0, "best_floor": 7,
		"lifetime_earned": 25000, "debt_cleared": 0, "total_spins": 70,
		"vig_paid": 1000}, "band": [1, 5]},
	{"run": 5, "stats": {"runs_played": 5, "wins": 1, "best_floor": 7,
		"lifetime_earned": 150000, "debt_cleared": 260, "total_spins": 330,
		"vig_paid": 5000, "wins_at:standard": 1}, "band": [4, 11]},
	{"run": 10, "stats": {"runs_played": 10, "wins": 1, "best_floor": 7,
		"lifetime_earned": 500000, "debt_cleared": 260, "total_spins": 640,
		"vig_paid": 10500, "wins_at:standard": 1}, "band": [8, 16]},
	{"run": 20, "stats": {"runs_played": 20, "wins": 3, "best_floor": 7,
		"lifetime_earned": 1010000, "debt_cleared": 780, "total_spins": 1220,
		"vig_paid": 20500, "wins_at:standard": 1, "wins_at:marked_deck": 1},
		"band": [16, 26]},
	{"run": 40, "stats": {"runs_played": 40, "wins": 3, "best_floor": 7,
		"lifetime_earned": 1650000, "debt_cleared": 1040, "total_spins": 2210,
		"vig_paid": 40000, "wins_at:standard": 1, "wins_at:marked_deck": 1,
		"wins_at:the_vig_rises": 1}, "band": [28, 38]},
	{"run": 60, "stats": {"runs_played": 60, "wins": 5, "best_floor": 7,
		"lifetime_earned": 1860000, "debt_cleared": 1300, "total_spins": 3120,
		"vig_paid": 60000, "wins_at:standard": 1, "wins_at:marked_deck": 1,
		"wins_at:the_vig_rises": 1, "wins_at:tight_purse": 1}, "band": [36, 43]},
]

var _catalogue: MetaCatalogue


func before() -> void:
	_catalogue = MetaCatalogue.new()
	_catalogue.load_all()


func _met(stats: Dictionary) -> int:
	var count: int = 0
	for unlock: UnlockDef in _catalogue.unlocks:
		if unlock.is_met(stats):
			count += 1
	return count


func test_the_curve_arrives_steadily_across_the_arc() -> void:
	for milestone: Dictionary in CAREER:
		var open: int = _met(milestone["stats"])
		var band: Array = milestone["band"]
		assert_int(open).override_failure_message(
				"after %d runs a median career has %d of %d unlocks open; the arc wants %d–%d" % [
					milestone["run"], open, _catalogue.unlocks.size(), band[0], band[1]]
				).is_between(int(band[0]), int(band[1]))


func test_every_run_of_the_arc_still_has_something_coming() -> void:
	# The failure this catches is a flat stretch: an hour of play that opens
	# nothing. Between one milestone and the next, something must arrive.
	var last: int = 0
	for milestone: Dictionary in CAREER:
		var open: int = _met(milestone["stats"])
		assert_int(open).override_failure_message(
				"nothing new arrives before run %d" % milestone["run"]).is_greater(last)
		last = open


func test_something_is_still_out_there_at_the_end_of_the_arc() -> void:
	var open: int = _met(CAREER[CAREER.size() - 1]["stats"])
	assert_int(_catalogue.unlocks.size() - open).override_failure_message(
			"a 30-hour career opens everything; keep some of it past the arc").is_greater_equal(1)


func test_the_first_run_opens_something() -> void:
	# The other failure: an arc so patient the first run is a dead end.
	assert_int(_met(CAREER[0]["stats"])).is_greater(0)


func test_no_unlock_is_out_of_reach() -> void:
	# Every unlock is met by the end of the arc, or is one of the ladder's
	# rungs — which are earned by winning at the rung below, not by playing on.
	var late: Dictionary = (CAREER[CAREER.size() - 1]["stats"] as Dictionary).duplicate()
	for unlock: UnlockDef in _catalogue.unlocks:
		if unlock.condition == UnlockDef.Condition.WINS_AT:
			continue
		assert_bool(unlock.is_met(late)).override_failure_message(
				"%s (%s) is never earned in a 30-hour career" % [
					unlock.id, unlock.requirement_text()]).is_true()


func test_the_ladder_is_a_ladder() -> void:
	# Each rung is opened by a win on the one below it, and no rung opens itself.
	for unlock: UnlockDef in _catalogue.unlocks:
		if unlock.condition != UnlockDef.Condition.WINS_AT:
			continue
		assert_object(_catalogue.difficulty_by_id(unlock.condition_id)).override_failure_message(
				"%s is opened by winning at %s, which is not a rung" % [
					unlock.id, unlock.condition_id]).is_not_null()
		assert_str(String(unlock.condition_id)).is_not_equal(String(unlock.target_id))
