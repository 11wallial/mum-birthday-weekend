## Judges a lab report against [BalanceBands].
##
## The lab measures; this decides. Kept apart from [CasinoLab] so a report
## written last night can be judged by today's bands, and so a test can hand it
## a synthetic report without running a batch.
class_name BalanceGate
extends RefCounted


## One verdict per band. Every entry carries the number that was judged and the
## bound it was judged against, so a failure reads as "win rate 0.31 above
## 0.28" rather than "check 3 failed".
##
## [param floors] is how many floors the content has: the lab records a death
## past the last floor — the run that cleared the House and lost to the debt —
## under the index one beyond it, and that is a different kind of death from a
## floor's.
static func check(report: Dictionary, bands: BalanceBands, floors: int = 7) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var runs: int = maxi(1, int(report.get("runs", 0)))
	var win_rate: float = float(report.get("win_rate", 0.0))
	out.append(_verdict(&"win_rate_min", win_rate >= bands.win_rate_min,
			win_rate, bands.win_rate_min, "win rate below the band"))
	out.append(_verdict(&"win_rate_max", win_rate <= bands.win_rate_max,
			win_rate, bands.win_rate_max, "win rate above the band"))

	# JSON round-trips the floor keys to strings; a report straight from the
	# lab still has integers. Read both.
	var deaths: Dictionary = report.get("deaths_by_floor", {})
	var by_floor: Dictionary = {}
	for key: Variant in deaths:
		by_floor[int(key)] = int(deaths[key])
	var floor_deaths: int = 0
	var worst_floor: int = 0
	var worst: int = 0
	for floor_index: int in range(1, floors + 1):
		var count: int = int(by_floor.get(floor_index, 0))
		floor_deaths += count
		if count > worst:
			worst = count
			worst_floor = floor_index
	var first: float = float(by_floor.get(1, 0)) / float(runs)
	out.append(_verdict(&"floor_one_deaths", first <= bands.floor_one_deaths_max,
			first, bands.floor_one_deaths_max, "the opening ante is ending too many runs"))
	var share: float = float(worst) / float(maxi(floor_deaths, 1))
	out.append(_verdict(&"single_floor_share", share <= bands.single_floor_share_max,
			share, bands.single_floor_share_max,
			"floor %d is a wall" % worst_floor if worst_floor > 0 else "no floor deaths"))

	var reasons: Dictionary = report.get("end_reasons", {})
	var debt_loss: float = float(int(reasons.get("debt_unpaid", 0))) / float(runs)
	out.append(_verdict(&"debt_loss_min", debt_loss >= bands.debt_loss_min,
			debt_loss, bands.debt_loss_min, "the final debt is not a threat"))
	out.append(_verdict(&"debt_loss_max", debt_loss <= bands.debt_loss_max,
			debt_loss, bands.debt_loss_max, "the final debt is the whole game"))

	var debt: Dictionary = report.get("debt", {})
	var default_rate: float = float(debt.get("default_rate", 0.0))
	out.append(_verdict(&"default_rate", default_rate <= bands.default_rate_max,
			default_rate, bands.default_rate_max, "too many runs miss a vig payment"))

	var spins: Dictionary = report.get("spins_per_run", {})
	var longest: int = int(spins.get("max", 0))
	out.append(_verdict(&"spins_per_run_max", longest <= bands.spins_per_run_max,
			float(longest), float(bands.spins_per_run_max), "a run has stopped ending"))

	var anomalies: Array = report.get("anomalies", [])
	out.append(_verdict(&"anomalies", anomalies.size() <= bands.anomalies_max,
			float(anomalies.size()), float(bands.anomalies_max),
			_anomaly_note(anomalies)))
	return out


## True when every verdict passed.
static func passed(checks: Array[Dictionary]) -> bool:
	for verdict: Dictionary in checks:
		if not bool(verdict["passed"]):
			return false
	return true


## The verdicts that failed, worst-named first as they were checked.
static func failures(checks: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for verdict: Dictionary in checks:
		if not bool(verdict["passed"]):
			out.append(verdict)
	return out


## One line per verdict, for a terminal or a CI log.
static func describe(checks: Array[Dictionary]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for verdict: Dictionary in checks:
		lines.append("%s  %-20s %8.3f  %s %.3f%s" % [
			"PASS" if bool(verdict["passed"]) else "FAIL",
			String(verdict["id"]),
			float(verdict["value"]),
			"within" if bool(verdict["passed"]) else "against",
			float(verdict["bound"]),
			"" if bool(verdict["passed"]) else "   " + String(verdict["note"]),
		])
	return lines


static func _verdict(id: StringName, ok: bool, value: float, bound: float,
		note: String) -> Dictionary:
	return {"id": id, "passed": ok, "value": value, "bound": bound, "note": note}


static func _anomaly_note(anomalies: Array) -> String:
	if anomalies.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in anomalies:
		if entry is Dictionary:
			names.append("%s (%s)" % [String((entry as Dictionary).get("id", "?")),
					String((entry as Dictionary).get("verdict", "?"))])
	return "the lab flagged " + ", ".join(names)
