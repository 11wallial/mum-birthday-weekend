## Headless entry point for the balance lab.
##
## Usage:
##   godot --headless --script res://tools/casino_lab/run_lab.gd -- \
##       --runs=10000 --seed=1 --out=user://balance_report.json [--stay]
##
## --stay tells every run to take the House's offer and play on past the last
## floor, which measures the endless curve rather than the game that ends.
## --difficulty=<id> measures one rung of the ladder; --challenge=<id> one
## challenge, each with the whole content set allowed. --no-bosses sends
## nobody to any floor, which is how what the bosses cost is measured.
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
	if args.has("machine"):
		var catalogue: MetaCatalogue = MetaCatalogue.new()
		catalogue.load_all()
		options = catalogue.options_for_machine(StringName(String(args["machine"])))
	if args.has("difficulty") or args.has("challenge"):
		var catalogue: MetaCatalogue = MetaCatalogue.new()
		catalogue.load_all()
		options = (catalogue.options_for_challenge(StringName(String(args["challenge"])))
				if args.has("challenge")
				else catalogue.options_for_difficulty(StringName(String(args["difficulty"]))))
	if args.has("stay"):
		if options == null:
			options = RunOptions.new()
		options.stay_at_table = true
	if args.has("no-bosses"):
		if options == null:
			options = RunOptions.new()
		options.no_bosses = true

	var report: Dictionary = CasinoLab.run_batch(runs, base_seed, options)
	report["anomalies"] = CasinoLab.find_anomalies(report, lift)
	_write(out_path, report)
	_summarise(report, out_path)
	quit(0)


## Floor first, then name, so the table reads top to bottom like the run.
func _boss_order(bosses: Dictionary, key: String) -> String:
	return "%02d:%s" % [int(bosses[key]["floor"]), key]


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
	var chips: Dictionary = report.get("chips", {})
	var hardware: Dictionary = report.get("hardware", {})
	var settled: Dictionary = report.get("settled_early", {})
	var unspent: Dictionary = report.get("chips_unspent_at_draft", {})
	print("unspent at draft  mean %.1f chips  p50 %d  p95 %d   rerolls %.2f a draft" % [
		float(unspent.get("mean", 0.0)), int(unspent.get("p50", 0)), int(unspent.get("p95", 0)),
		float(report.get("rerolls_per_draft", 0.0))])
	var top: Dictionary = report.get("top_build_share", {})
	print("top build      %s in %.0f%% of wins" % [String(top.get("build", "")),
		float(top.get("share", 0.0)) * 100.0])
	var noticed: Dictionary = report.get("notices", {})
	print("noticed        mean %.2f a run  p95 %d" % [float(noticed.get("mean", 0.0)), int(noticed.get("p95", 0))])
	var bought: Dictionary = report.get("chits_bought", {})
	var used: Dictionary = report.get("chits_used", {})
	print("chits          bought %.2f a run  spent %.2f" % [float(bought.get("mean", 0.0)), float(used.get("mean", 0.0))])
	print("chips          mean %.1f  p50 %d  p95 %d   hardware mean %.1f  max %d   took %.0f%% of the draft   settled early mean %.2f floors" % [
		float(chips.get("mean", 0.0)), int(chips.get("p50", 0)), int(chips.get("p95", 0)),
		float(hardware.get("mean", 0.0)), int(hardware.get("max", 0)),
		float(report.get("draft_take_rate", 0.0)) * 100.0,
		float(settled.get("mean", 0.0))])
	var after: Dictionary = report.get("after_hours", {})
	if int(after.get("stayed", 0)) > 0:
		var beyond: Dictionary = after.get("floors", {})
		print("after hours    %d stayed, %d saw dawn, %.1f floors mean (p95 %d), deaths %s" % [
			int(after["stayed"]), int(after["dawns"]), float(beyond.get("mean", 0.0)),
			int(beyond.get("p95", 0)), JSON.stringify(after.get("deaths_by_floor", {}))])
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
	var archetypes: Dictionary = report.get("archetype_win_rates", {})
	if not archetypes.is_empty():
		print("archetypes:")
		for key: String in archetypes:
			var row: Dictionary = archetypes[key]
			print("  %-14s runs %-6d win %.1f%% vs %.1f%% cohort (%+.1f pts)" % [
				key, int(row["runs"]), float(row["win_rate"]) * 100.0,
				float(row["baseline"]) * 100.0,
				(float(row["win_rate"]) - float(row["baseline"])) * 100.0])
	var bosses: Dictionary = report.get("boss_rates", {})
	if not bosses.is_empty():
		print("bosses:")
		var ids: Array = bosses.keys()
		ids.sort_custom(func(a: String, b: String) -> bool:
			return _boss_order(bosses, a) < _boss_order(bosses, b))
		for key: String in ids:
			var row: Dictionary = bosses[key]
			print("  %d  %-16s met %-5d killed %.1f%% of them vs %.1f%% on the floor (%+.1f pts)" % [
				int(row["floor"]), key, int(row["faced"]), float(row["death_rate"]) * 100.0,
				float(row["floor_rate"]) * 100.0, float(row["lift"]) * 100.0])
	var picks: Dictionary = report.get("pick_rates", {})
	var flagged: Array[String] = []
	for key: String in picks:
		var verdict: String = String(picks[key].get("verdict", "fair"))
		if verdict != "fair" and verdict != "unmeasured":
			flagged.append(key)
	if not flagged.is_empty():
		print("picks worth a look:")
		for key: String in flagged:
			var row: Dictionary = picks[key]
			print("  %-18s %-8s taken from %.0f%% of %d drafts, win %.1f%% vs %.1f%% cohort, %+.1f pts against the pack" % [
				key, String(row["verdict"]), float(row["pick_rate"]) * 100.0,
				int(row["offered"]), float(row["win_rate"]) * 100.0,
				float(row["baseline"]) * 100.0, float(row["delta"]) * 100.0])
	print("report → %s" % out_path)
