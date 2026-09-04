## The shipped staff: nobody in the basement, at least two people for every
## floor after it, every rule sane against the floor it is sent to, and the
## lab able to say what each of them costs.
extends GdUnitTestSuite

var _content: ContentDB


func before_test() -> void:
	_content = ContentDB.shared()


func test_the_basement_has_nobody_and_every_floor_after_has_a_choice() -> void:
	assert_int(_content.bosses_for(1).size()).is_equal(0)
	for floor_def: FloorDef in _content.floors:
		if floor_def.index == 1:
			continue
		assert_int(_content.bosses_for(floor_def.index).size()).override_failure_message(
				"floor %d has fewer than two people to send" % floor_def.index).is_greater_equal(2)


func test_every_boss_is_named_told_and_sane() -> void:
	var seen: Dictionary = {}
	for boss: BossDef in _content.bosses:
		assert_bool(seen.has(boss.id)).override_failure_message("%s twice" % boss.id).is_false()
		seen[boss.id] = true
		assert_str(boss.display_name).is_not_empty()
		assert_str(boss.intro).is_not_empty()
		assert_str(boss.tell).override_failure_message("%s has no tell" % boss.id).is_not_empty()
		var floor_def: FloorDef = _content.floor_at(boss.floor)
		assert_object(floor_def).override_failure_message(
				"%s is sent to floor %d, which does not exist" % [boss.id, boss.floor]).is_not_null()
		match boss.rule:
			BossDef.Rule.SYMBOL_BANNED, BossDef.Rule.SYMBOL_HEAVY:
				assert_object(_content.symbol_by_id(boss.symbol)).override_failure_message(
						"%s names a symbol that does not exist" % boss.id).is_not_null()
			BossDef.Rule.PATTERN_TAXED:
				assert_float(boss.magnitude).is_between(0.1, 0.9)
			BossDef.Rule.SHORT_FLOOR:
				assert_int(int(boss.magnitude)).is_between(1, floor_def.spins - 4)
			BossDef.Rule.HOLDS_COST_MORE:
				assert_float(boss.magnitude).is_greater(1.0)
			BossDef.Rule.ANTE_CREEPS, BossDef.Rule.SKIMMED:
				assert_float(boss.magnitude).is_greater(0.0)
			_:
				pass


func test_the_lab_can_say_what_each_of_them_costs() -> void:
	var report: Dictionary = CasinoLab.run_batch(300, 5)
	var rates: Dictionary = report["boss_rates"]
	for boss: BossDef in _content.bosses:
		assert_bool(rates.has(String(boss.id))).override_failure_message(
				"%s was never sent in 300 runs" % boss.id).is_true()
		var row: Dictionary = rates[String(boss.id)]
		assert_int(int(row["killed"])).is_less_equal(int(row["faced"]))
