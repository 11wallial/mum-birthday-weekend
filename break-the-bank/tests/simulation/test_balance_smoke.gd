extends GdUnitTestSuite

## Guardrails, not a balance spec. These catch a change that makes the game
## unplayable or unlosable; the exact numbers are the Casino Lab's business.

const RUNS: int = 400

var _report: Dictionary = {}


func before() -> void:
	_report = CasinoLab.run_batch(RUNS, 1)


func test_the_batch_completes_every_run() -> void:
	assert_int(int(_report["runs"])).is_equal(RUNS)
	assert_int(int((_report["earnings"] as Dictionary)["count"])).is_equal(RUNS)


func test_the_game_is_neither_unwinnable_nor_free() -> void:
	var win_rate: float = float(_report["win_rate"])
	assert_float(win_rate).is_greater(0.0)
	assert_float(win_rate).is_less(1.0)


func test_no_run_stalls_forever() -> void:
	var spins: Dictionary = _report["spins_per_run"]
	assert_int(int(spins["max"])).is_less(1000)
	assert_float(float(spins["mean"])).is_greater(1.0)


func test_deaths_are_spread_over_more_than_one_floor() -> void:
	# Every death on floor 1 means the opening ante, not the run, is the game.
	var deaths: Dictionary = _report["deaths_by_floor"]
	assert_int(deaths.size()).is_greater(1)


func test_percentiles_are_ordered() -> void:
	var earnings: Dictionary = _report["earnings"]
	assert_int(int(earnings["p50"])).is_less_equal(int(earnings["p95"]))
	assert_int(int(earnings["p95"])).is_less_equal(int(earnings["p99"]))
	assert_int(int(earnings["p99"])).is_less_equal(int(earnings["max"]))


func test_the_batch_is_reproducible() -> void:
	var again: Dictionary = CasinoLab.run_batch(RUNS, 1)
	assert_float(float(again["win_rate"])).is_equal(float(_report["win_rate"]))
	assert_dict(again["earnings"]).is_equal(_report["earnings"])


func test_debt_is_a_live_mechanic_not_a_footnote() -> void:
	# Milestone 2 asked debt to influence runs rather than sit unused. These are
	# the loosest bounds that still distinguish "does something" from "inert".
	var debt: Dictionary = _report["debt"]
	assert_float(float(debt["default_rate"])).is_greater(0.0)
	assert_float(float((debt["serviced"] as Dictionary)["mean"])).is_greater(1.0)
	var reasons: Dictionary = _report["end_reasons"]
	assert_bool(reasons.has("debt_unpaid")).override_failure_message(
			"no run in the batch lost to the final debt repayment").is_true()


func test_the_late_floors_are_reachable_and_lethal() -> void:
	# The floor 6 cliff this milestone existed to fix: deaths should appear on
	# the late floors without the win rate collapsing to nothing.
	var deaths: Dictionary = _report["deaths_by_floor"]
	assert_bool(deaths.has(6)).override_failure_message(
			"floor 6 killed nobody: the late-game antes are free").is_true()
	assert_float(float(_report["win_rate"])).is_greater(0.05)


func test_anomaly_detection_ignores_thin_samples() -> void:
	var thin: Dictionary = {
		"win_rate": 0.5,
		"artifact_win_rates": {"rare_thing": {"runs": 4, "wins": 4, "win_rate": 1.0}},
		"synergy_win_rates": {},
	}
	assert_array(CasinoLab.find_anomalies(thin)).is_empty()


func test_a_late_artifact_is_judged_against_the_runs_that_reach_it() -> void:
	# Owning an artifact that unlocks late already implies surviving that far —
	# and, because prices track the ante, being rich when you got there. Judged
	# against the whole batch it looks broken; against the cohort that both
	# reached its floor and bought from its tier it is unremarkable, and only
	# the second reading is worth acting on.
	var rates: Dictionary = _report["artifact_win_rates"]
	assert_bool(rates.has("house_contract")).override_failure_message(
			"no run in the batch bought house_contract; the cohort test cannot run").is_true()
	var late: Dictionary = rates["house_contract"]
	assert_float(float(late["baseline"])).is_greater(float(_report["win_rate"]))
	assert_str(String(late["baseline_note"])).is_equal(
			"runs clearing 5+ floors and buying from that tier")


func test_anomaly_detection_flags_a_dominant_artifact() -> void:
	var loud: Dictionary = {
		"win_rate": 0.2,
		"artifact_win_rates": {"broken_thing": {"runs": 500, "wins": 450, "win_rate": 0.9}},
		"synergy_win_rates": {},
	}
	var found: Array[Dictionary] = CasinoLab.find_anomalies(loud)
	assert_int(found.size()).is_equal(1)
	assert_str(String(found[0]["id"])).is_equal("broken_thing")
	assert_str(String(found[0]["verdict"])).is_equal("overpowered")
