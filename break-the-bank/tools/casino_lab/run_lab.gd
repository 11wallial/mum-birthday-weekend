## Headless entry point for the balance lab.
##
## Usage:
##   godot --headless --script res://tools/casino_lab/run_lab.gd -- \
##       --runs=10000 --seed=1 --out=user://balance_report.json [--stay]
##
## --stay tells every run to take the House's offer and play on past the last
## floor, which measures the endless curve rather than the game that ends.
##
## Writes a JSON report and prints a short summary. The agent balance loop reads
## the JSON, edits resources/rules/*.tres, and runs it again.
extends SceneTree

const DEFAULT_RUNS: int = 10000
const DEFAULT_SEED: int = 1


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var runs: int = int(args.get("runs", DEFAULT_RUNS))
	var base_seed: int = int(args.get("seed", DEFAULT_SEED))
	var out_path: String = String(args.get("out", "user://balance_report.json"))
	var lift: float = float(args.get("lift", 0.25))
	var options: RunOptions = null
	if args.has("stay"):
		options = RunOptions.new()
		options.stay_at_table = true

	var report: Dictionary = CasinoLab.run_batch(runs, base_seed, options)
	report["anomalies"] = CasinoLab.find_anomalies(report, lift)
	_write(out_path, report)
	_summarise(report, out_path)
	quit(0)


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


func _write(path: String, report: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("run_lab: cannot write %s (%d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()


func _summarise(report: Dictionary, out_path: String) -> void:
	var earnings: Dictionary = report.get("earnings", {})
	var floors: Dictionary = report.get("floors_cleared", {})
	print("── Casino Lab ──────────────────────────────")
	print("runs           %d (seed %d, %d ms)" % [
		int(report.get("runs", 0)), int(report.get("base_seed", 0)), int(report.get("elapsed_ms", 0))])
	print("win rate       %.1f%%   death rate %.1f%%" % [
		float(report.get("win_rate", 0.0)) * 100.0, float(report.get("death_rate", 0.0)) * 100.0])
	print("earnings       mean %.1f  p50 %d  p95 %d  p99 %d" % [
		float(earnings.get("mean", 0.0)), int(earnings.get("p50", 0)),
		int(earnings.get("p95", 0)), int(earnings.get("p99", 0))])
	print("floors cleared mean %.2f  max %d" % [
		float(floors.get("mean", 0.0)), int(floors.get("max", 0))])
	print("deaths by floor %s" % JSON.stringify(report.get("deaths_by_floor", {})))
	var debt: Dictionary = report.get("debt", {})
	var serviced: Dictionary = debt.get("serviced", {})
	print("debt           vig paid mean %.0f  p95 %d   defaulted %.1f%% of runs   paydown owned %.1f%%" % [
		float(serviced.get("mean", 0.0)), int(serviced.get("p95", 0)),
		float(debt.get("default_rate", 0.0)) * 100.0,
		float(debt.get("paydown_owned_rate", 0.0)) * 100.0])
	var anomalies: Array = report.get("anomalies", [])
	if anomalies.is_empty():
		print("anomalies      none above threshold")
	else:
		print("anomalies:")
		for entry: Variant in anomalies:
			var row: Dictionary = entry
			print("  %-18s %-12s runs %-6d win %.1f%% vs %.1f%% cohort (%+.1f pts)" % [
				String(row["id"]), String(row["verdict"]), int(row["runs"]),
				float(row["win_rate"]) * 100.0, float(row["baseline"]) * 100.0,
				float(row["delta"]) * 100.0])
	print("report → %s" % out_path)
