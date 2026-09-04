## The scoring performance's timetable, held to the handover's brief: the
## tempo runs away and floors, the ladder climbs a semitone and caps, a device
## breaks the rhythm, the total rolls and the pause never disappears.
extends GdUnitTestSuite

const PAR: float = 10.0


func _symbols(count: int, worth: int = 5) -> Array:
	var steps: Array = []
	for i: int in count:
		steps.append({"kind": "symbol", "label": "Cherry", "text": str(worth), "reel": i})
	return steps


func test_tiers_rank_by_share_of_par() -> void:
	assert_int(ScoreDirector.tier_of(0, PAR)).is_equal(ScoreDirector.Tier.DEAD)
	assert_int(ScoreDirector.tier_of(2, PAR)).is_equal(ScoreDirector.Tier.DEAD)
	assert_int(ScoreDirector.tier_of(5, PAR)).is_equal(ScoreDirector.Tier.SCRAPING)
	assert_int(ScoreDirector.tier_of(10, PAR)).is_equal(ScoreDirector.Tier.PAID)
	assert_int(ScoreDirector.tier_of(30, PAR)).is_equal(ScoreDirector.Tier.STRONG)
	assert_int(ScoreDirector.tier_of(100, PAR)).is_equal(ScoreDirector.Tier.HEAVY)
	assert_int(ScoreDirector.tier_of(300, PAR)).is_equal(ScoreDirector.Tier.OVERLOAD)


func test_every_step_is_its_own_beat_and_the_tempo_runs_away() -> void:
	var plan: Dictionary = ScoreDirector.plan(_symbols(12), 60, PAR)
	var beats: Array = plan["beats"]
	assert_int(beats.size()).is_equal(12)
	var gaps: Array[float] = []
	for i: int in range(1, beats.size()):
		gaps.append(float(beats[i]["at"]) - float(beats[i - 1]["at"]))
	assert_float(gaps[0]).is_equal_approx(ScoreDirector.FIRST_GAP, 0.001)
	for i: int in range(1, gaps.size()):
		assert_float(gaps[i]).is_less_equal(gaps[i - 1] + 0.0001)
	assert_float(gaps[gaps.size() - 1]).is_equal_approx(ScoreDirector.GAP_FLOOR, 0.001)


func test_the_ladder_climbs_a_semitone_a_beat_and_caps() -> void:
	var plan: Dictionary = ScoreDirector.plan(_symbols(16), 80, PAR)
	var beats: Array = plan["beats"]
	assert_int(int(beats[0]["pitch"])).is_equal(1)
	assert_int(int(beats[1]["pitch"])).is_equal(2)
	assert_int(int(beats[11]["pitch"])).is_equal(ScoreDirector.LADDER_CAP)
	assert_bool(bool(beats[11]["cap"])).is_false()
	assert_int(int(beats[12]["pitch"])).is_equal(ScoreDirector.LADDER_CAP)
	assert_bool(bool(beats[12]["cap"])).is_true()
	assert_bool(bool(beats[15]["cap"])).is_true()
	assert_float(ScoreDirector.pitch_scale(12)).is_equal_approx(2.0, 0.001)


func test_a_device_breaks_the_rhythm_and_holds_the_ladder() -> void:
	var steps: Array = _symbols(3)
	steps.append({"kind": "pattern", "label": "Three of a kind", "text": "+3.00x"})
	steps.append({"kind": "artifact", "label": "The Ledger", "text": "+0.30x", "id": "ledger"})
	steps.append({"kind": "symbol", "label": "Bell", "text": "4", "reel": 0})
	var plan: Dictionary = ScoreDirector.plan(steps, 60, PAR)
	var beats: Array = plan["beats"]
	var device: Dictionary = beats[4]
	assert_bool(bool(device["break"])).is_true()
	assert_str(String(device["id"])).is_equal("ledger")
	# The gap after a break is longer than the one before it, against the
	# tempo's own decay.
	var before: float = float(beats[4]["at"]) - float(beats[3]["at"])
	var after: float = float(beats[5]["at"]) - float(beats[4]["at"])
	assert_float(after).is_greater(before)
	# The break plays a different instrument and does not climb.
	assert_int(int(beats[4]["pitch"])).is_equal(int(beats[3]["pitch"]))
	assert_int(int(beats[5]["pitch"])).is_equal(int(beats[3]["pitch"]) + 1)


func test_the_running_total_follows_the_arithmetic() -> void:
	var steps: Array = _symbols(3, 5)
	steps.append({"kind": "pattern", "label": "Three of a kind", "text": "+3.00x"})
	steps.append({"kind": "artifact", "label": "Bolt", "text": "+5  +0.50x", "id": "bolt"})
	steps.append({"kind": "house", "label": "The skim", "text": "x0.85"})
	steps.append({"kind": "stake", "label": "The stake", "text": "x2"})
	var plan: Dictionary = ScoreDirector.plan(steps, 100, PAR)
	var beats: Array = plan["beats"]
	assert_int(int(beats[2]["running"])).is_equal(15)
	assert_int(int(beats[3]["running"])).is_equal(60)
	assert_int(int(beats[4]["running"])).is_equal(90)
	assert_int(int(beats[5]["running"])).is_equal(int(round(20.0 * 4.5 * 0.85)))
	assert_int(int(beats[6]["running"])).is_equal(int(round(20.0 * 4.5 * 0.85)) * 2)


func test_the_count_up_scales_with_magnitude_and_is_capped() -> void:
	var small: Dictionary = ScoreDirector.plan(_symbols(3), 12, PAR)
	var large: Dictionary = ScoreDirector.plan(_symbols(3), 12000, PAR)
	var vast: Dictionary = ScoreDirector.plan(_symbols(3), 1200000000, PAR)
	assert_float(float(small["count_seconds"])).is_less(float(large["count_seconds"]))
	assert_float(float(vast["count_seconds"])).is_equal_approx(ScoreDirector.COUNT_MAX, 0.001)


func test_the_pause_shrinks_with_pace_but_never_disappears() -> void:
	var slow: Dictionary = ScoreDirector.plan(_symbols(3), 40, PAR, 1.4)
	var normal: Dictionary = ScoreDirector.plan(_symbols(3), 40, PAR, 1.0)
	var fast: Dictionary = ScoreDirector.plan(_symbols(3), 40, PAR, 0.1)
	assert_float(float(slow["pause"])).is_greater(float(normal["pause"]))
	assert_float(float(fast["pause"])).is_less(float(normal["pause"]))
	assert_float(float(fast["pause"])).is_equal_approx(ScoreDirector.PAUSE_FLOOR, 0.001)
	assert_float(float(fast["total_at"])).is_greater(float(fast["pause_at"]))
	# Speeding up scales the whole sequence rather than cutting beats out.
	assert_int((fast["beats"] as Array).size()).is_equal((normal["beats"] as Array).size())
	assert_float(float(fast["chain_end"])).is_less(float(normal["chain_end"]))


func test_a_dead_spin_has_no_chain_and_no_pause() -> void:
	var plan: Dictionary = ScoreDirector.plan(_symbols(3, 0), 0, PAR)
	assert_int(int(plan["tier"])).is_equal(ScoreDirector.Tier.DEAD)
	assert_int((plan["beats"] as Array).size()).is_equal(0)
	assert_float(float(plan["pause"])).is_equal(0.0)
	assert_float(float(plan["end"])).is_equal(0.0)


func test_a_scraping_spin_is_one_soft_hit() -> void:
	var plan: Dictionary = ScoreDirector.plan(_symbols(3, 1), 4, PAR)
	assert_int(int(plan["tier"])).is_equal(ScoreDirector.Tier.SCRAPING)
	var beats: Array = plan["beats"]
	assert_int(beats.size()).is_equal(1)
	assert_str(String(beats[0]["kind"])).is_equal("soft")
	assert_float(float(plan["pause"])).is_greater(0.0)


func test_the_timetable_is_in_order() -> void:
	var steps: Array = _symbols(5)
	steps.append({"kind": "artifact", "label": "Bolt", "text": "+5", "id": "bolt"})
	var plan: Dictionary = ScoreDirector.plan(steps, 200, PAR)
	assert_float(float(plan["chain_end"])).is_greater(float((plan["beats"] as Array)[5]["at"]))
	assert_float(float(plan["pause_at"])).is_greater_equal(float(plan["chain_end"]))
	assert_float(float(plan["total_at"])).is_greater(float(plan["pause_at"]))
	assert_float(float(plan["end"])).is_equal(float(plan["total_at"]))
