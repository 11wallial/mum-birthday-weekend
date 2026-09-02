## Headless entry point for the balance gate.
##
## Usage:
##   godot --headless --path . --script res://tools/casino_lab/gate.gd -- \
##       --report=res://reports/balance_report.json \
##       [--bands=res://resources/rules/balance_bands.tres] \
##       [--previous=res://reports/last_night.json]
##
## Prints one line per band and exits non-zero when any is broken, which is
## what lets CI and the nightly batch fail on a content merge that has moved
## the game. With --previous it also prints the delta, because the number that
## matters on a nightly is not where the game is but how far it moved.
extends SceneTree

const DEFAULT_REPORT: String = "res://reports/balance_report.json"
const DEFAULT_BANDS: String = "res://resources/rules/balance_bands.tres"


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var report_path: String = String(args.get("report", DEFAULT_REPORT))
	var report: Dictionary = _read_json(report_path)
	if report.is_empty():
		push_error("gate: cannot read a report at %s" % report_path)
		quit(2)
		return
	var bands_path: String = String(args.get("bands", DEFAULT_BANDS))
	var bands: BalanceBands = load(bands_path) as BalanceBands
	if bands == null:
		push_error("gate: %s is not a BalanceBands resource" % bands_path)
		quit(2)
		return
	var floors: int = ContentDB.shared().floors.size()
	var checks: Array[Dictionary] = BalanceGate.check(report, bands, floors)
	print("── Balance gate ────────────────────────────")
	print("report         %s (%d runs, seed %d)" % [
		report_path, int(report.get("runs", 0)), int(report.get("base_seed", 0))])
	for line: String in BalanceGate.describe(checks):
		print(line)
	if args.has("previous"):
		_print_delta(report, _read_json(String(args["previous"])))
	var ok: bool = BalanceGate.passed(checks)
	print("verdict        %s" % ("inside the bands" if ok
			else "%d band(s) broken" % BalanceGate.failures(checks).size()))
	quit(0 if ok else 1)


func _print_delta(now: Dictionary, before: Dictionary) -> void:
	if before.is_empty():
		print("previous       (unreadable, no delta)")
		return
	var earnings_now: Dictionary = now.get("earnings", {})
	var earnings_then: Dictionary = before.get("earnings", {})
	# Shares rather than counts, so two batches of different sizes still compare.
	print("delta          win rate %+.1f pts   p50 earnings %+d   debt losses %+.1f pts" % [
		(float(now.get("win_rate", 0.0)) - float(before.get("win_rate", 0.0))) * 100.0,
		int(earnings_now.get("p50", 0)) - int(earnings_then.get("p50", 0)),
		(_share(now, "debt_unpaid") - _share(before, "debt_unpaid")) * 100.0,
	])


## Share of a report's runs that ended for [param reason].
func _share(report: Dictionary, reason: String) -> float:
	var runs: int = maxi(1, int(report.get("runs", 0)))
	return float(int((report.get("end_reasons", {}) as Dictionary).get(reason, 0))) / float(runs)


func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg: String in argv:
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var split: int = body.find("=")
		if split < 0:
			out[body] = true
		else:
			out[body.substr(0, split)] = body.substr(split + 1)
	return out


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
