extends GdUnitTestSuite

## The gate decides whether a batch still describes the game we shipped. These
## hand it synthetic reports, so every verdict is pinned without running one.

const RUNS: int = 1000

var _bands: BalanceBands


func before_test() -> void:
	_bands = BalanceBands.new()


## A batch shaped like the one on the shipping commit: deaths climbing floor by
## floor, and a fifth of runs lost to the debt after the last floor.
func _healthy() -> Dictionary:
	return {
		"runs": RUNS,
		"win_rate": 0.196,
		"deaths_by_floor": {1: 8, 2: 19, 3: 44, 4: 67, 5: 98, 6: 124, 7: 214, 8: 230},
		"end_reasons": {"ante_unpaid": 574, "cleared_all_floors": 196, "debt_unpaid": 230},
		"debt": {"default_rate": 0.005},
		"spins_per_run": {"max": 170},
		"anomalies": [],
	}


func _failed_ids(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for verdict: Dictionary in BalanceGate.failures(BalanceGate.check(report, _bands, 7)):
		out.append(String(verdict["id"]))
	return out


func test_the_shipping_shape_passes_every_band() -> void:
	var checks: Array[Dictionary] = BalanceGate.check(_healthy(), _bands, 7)
	assert_bool(BalanceGate.passed(checks)).override_failure_message(
			"\n".join(BalanceGate.describe(checks))).is_true()
	assert_int(checks.size()).is_equal(10)


func test_a_win_rate_outside_the_band_fails_on_the_right_side() -> void:
	var easy: Dictionary = _healthy()
	easy["win_rate"] = 0.5
	assert_array(_failed_ids(easy)).contains_exactly(["win_rate_max"])
	var brutal: Dictionary = _healthy()
	brutal["win_rate"] = 0.02
	assert_array(_failed_ids(brutal)).contains_exactly(["win_rate_min"])


func test_an_opening_ante_that_ends_runs_is_a_wall() -> void:
	var report: Dictionary = _healthy()
	report["deaths_by_floor"] = {1: 600, 2: 100, 3: 100, 4: 50, 5: 50, 6: 50, 7: 50, 8: 30}
	assert_array(_failed_ids(report)).contains(["floor_one_deaths", "single_floor_share"])


func test_a_death_past_the_last_floor_is_a_debt_problem_not_a_wall() -> void:
	# Most of a batch losing to the debt after the House is the debt band's
	# business. There is no floor eight to be a wall.
	var report: Dictionary = _healthy()
	report["deaths_by_floor"] = {1: 5, 2: 10, 3: 20, 4: 30, 5: 40, 6: 50, 7: 60, 8: 450}
	report["end_reasons"] = {"ante_unpaid": 215, "cleared_all_floors": 335, "debt_unpaid": 450}
	var failed: Array[String] = _failed_ids(report)
	assert_bool(failed.has("single_floor_share")).is_false()
	assert_array(failed).contains(["debt_loss_max"])


func test_a_bump_in_the_middle_of_the_climb_is_a_spike() -> void:
	# The shape the floor 5 spike had, scaled: a floor that kills more than the
	# whole rest of the run after it, while holding well under half of all
	# floor deaths — which is why the share band alone never saw it.
	var report: Dictionary = _healthy()
	report["deaths_by_floor"] = {1: 10, 2: 20, 3: 40, 4: 300, 5: 60, 6: 80, 7: 120, 8: 170}
	var failed: Array[Dictionary] = BalanceGate.failures(BalanceGate.check(report, _bands, 7))
	assert_int(failed.size()).is_equal(1)
	assert_str(String(failed[0]["id"])).is_equal("mid_run_spike")
	assert_str(String(failed[0]["note"])).contains("floor 4")


func test_the_last_floor_may_be_the_biggest_killer() -> void:
	# Everyone who reaches the House faces the hardest ante, so the last floor
	# holding two fifths of the floor deaths is the design, not a wall.
	var report: Dictionary = _healthy()
	report["deaths_by_floor"] = {1: 10, 2: 20, 3: 40, 4: 60, 5: 90, 6: 120, 7: 260, 8: 200}
	assert_bool(BalanceGate.passed(BalanceGate.check(report, _bands, 7))).is_true()


func test_a_debt_nobody_loses_to_is_not_a_threat() -> void:
	var report: Dictionary = _healthy()
	report["end_reasons"] = {"ante_unpaid": 804, "cleared_all_floors": 196}
	assert_array(_failed_ids(report)).contains_exactly(["debt_loss_min"])


func test_a_run_that_never_ends_fails_the_gate() -> void:
	var report: Dictionary = _healthy()
	report["spins_per_run"] = {"max": 100000}
	assert_array(_failed_ids(report)).contains_exactly(["spins_per_run_max"])


func test_an_anomaly_the_lab_flagged_fails_the_gate_by_name() -> void:
	var report: Dictionary = _healthy()
	report["anomalies"] = [{"id": "broken_thing", "verdict": "overpowered"}]
	var failed: Array[Dictionary] = BalanceGate.failures(BalanceGate.check(report, _bands, 7))
	assert_int(failed.size()).is_equal(1)
	assert_str(String(failed[0]["note"])).contains("broken_thing")


func test_a_report_read_back_from_json_is_judged_the_same() -> void:
	# JSON turns the floor keys into strings and the counts into floats. The
	# nightly reads its report off disk, so the verdicts must not change.
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(_healthy()))
	assert_bool(BalanceGate.passed(BalanceGate.check(round_tripped, _bands, 7))).is_true()
	var walled: Dictionary = _healthy()
	walled["deaths_by_floor"] = {1: 400, 2: 100, 3: 100, 4: 50, 5: 50, 6: 50, 7: 50, 8: 30}
	var walled_json: Dictionary = JSON.parse_string(JSON.stringify(walled))
	assert_array(_failed_ids(walled_json)).contains(["floor_one_deaths"])


func test_the_shipped_bands_load_and_are_ordered() -> void:
	var shipped: BalanceBands = load("res://resources/rules/balance_bands.tres") as BalanceBands
	assert_object(shipped).is_not_null()
	assert_float(shipped.win_rate_min).is_less(shipped.win_rate_max)
	assert_float(shipped.debt_loss_min).is_less(shipped.debt_loss_max)


func test_every_verdict_names_what_it_judged() -> void:
	var lines: PackedStringArray = BalanceGate.describe(BalanceGate.check(_healthy(), _bands, 7))
	assert_int(lines.size()).is_equal(10)
	for line: String in lines:
		assert_str(line).starts_with("PASS")
		assert_str(line).contains("within")
