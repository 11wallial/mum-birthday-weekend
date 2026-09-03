## Plays careers, not runs: the arc the unlocks are paced against.
##
##   godot --headless --path . --script res://tools/casino_lab/career.gd -- \
##       --careers=200 --runs=90 --seed=1 [--flat] [--out=user://career.json]
##
## The lab measures one run at a time from a full content set. Nobody plays
## that game. A player plays run after run through the same profile, with the
## pool the last run earned and the rung the last win opened, and the only
## question the unlock curve asks is when each thing arrives in that career —
## which is a number about the player, not about the run.
##
## So: a fresh profile, N runs, every finished run folded in, and the run index
## written down each time an unlock fires. Careers are luck, so it takes many
## and reports the median. --flat keeps the player on the first rung instead of
## climbing the ladder as it opens, which is the other honest player.
##
## A run is 25–40 minutes (docs/PLAYTEST.md), so 60 runs is about the 30-hour
## arc the roadmap wants the unlocks paced across.
extends SceneTree

const DEFAULT_CAREERS: int = 120
const DEFAULT_RUNS: int = 90
## Minutes a run takes, for turning run indices into the hours the arc is
## specified in. The middle of the playtest bar.
const MINUTES_PER_RUN: float = 32.0
## Careers are independent players, so their seeds must not share a stream.
const CAREER_STRIDE: int = 10007


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var careers: int = int(args.get("careers", DEFAULT_CAREERS))
	var runs: int = int(args.get("runs", DEFAULT_RUNS))
	var base_seed: int = int(args.get("seed", 1))
	var climb: bool = not args.has("flat")

	var content: ContentDB = ContentDB.shared()
	var catalogue: MetaCatalogue = MetaCatalogue.new()
	catalogue.load_all()
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var engine: SimEngine = SimEngine.new(content, bus)

	# Per unlock id: the run index it fired on, one entry per career that
	# ever earned it. A career that never earns it contributes nothing, which
	# is why the share of careers is reported next to the median.
	var fired: Dictionary = {}
	# Per career: how many unlocks were open after each run, for the curve.
	var opened_after: Array = []
	# What every paced condition is worth at each run, so a threshold can be
	# chosen for the run it should land on rather than guessed at.
	var stat_track: Dictionary = {}
	var wins_total: int = 0
	var started: int = Time.get_ticks_msec()
	for career: int in careers:
		var profile: PlayerProfile = PlayerProfile.new()
		var opened: PackedInt32Array = PackedInt32Array()
		for run: int in runs:
			var options: RunOptions = catalogue.options_for(profile, content)
			var state: RunState = engine.simulate_run(base_seed + career * CAREER_STRIDE + run, options)
			if state.phase == RunState.Phase.WON:
				wins_total += 1
			for unlock: UnlockDef in profile.record_run(state, catalogue.unlocks):
				var key: String = String(unlock.id)
				# A packed array in a dictionary is a value, not a handle:
				# appending to what get() hands back appends to a copy.
				var when: PackedInt32Array = fired.get(key, PackedInt32Array())
				when.append(run + 1)
				fired[key] = when
			opened.append(profile.unlocked.size())
			var stats: Dictionary = profile.stats()
			for key: Variant in ["runs_played", "wins", "best_floor", "lifetime_earned",
					"debt_cleared", "total_spins", "vig_paid"]:
				var name: String = String(key)
				var track: Array = stat_track.get(name, [])
				if track.size() <= run:
					track.append(PackedInt64Array())
				var at_run: PackedInt64Array = track[run]
				at_run.append(int(stats.get(name, 0)))
				track[run] = at_run
				stat_track[name] = track
			if climb:
				var rungs: Array[StringName] = catalogue.available_difficulties(profile)
				profile.selected_difficulty = rungs[rungs.size() - 1]
		opened_after.append(opened)

	var report: Dictionary = _report(catalogue, fired, opened_after, careers, runs, climb)
	report["stats"] = _stat_curve(stat_track, runs)
	report["win_rate"] = float(wins_total) / float(maxi(1, careers * runs))
	report["seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
	if args.has("out"):
		_write(String(args["out"]), report)
	_print(report, catalogue, careers, runs, climb)
	quit(0)


func _report(catalogue: MetaCatalogue, fired: Dictionary, opened_after: Array,
		careers: int, runs: int, climb: bool) -> Dictionary:
	var rows: Array = []
	for unlock: UnlockDef in catalogue.unlocks:
		var key: String = String(unlock.id)
		var sample: PackedInt32Array = fired.get(key, PackedInt32Array())
		var earned: int = sample.size()
		var sorted: PackedInt32Array = sample.duplicate()
		sorted.sort()
		rows.append({
			"id": key,
			"kind": UnlockDef.Kind.keys()[unlock.kind],
			"requirement": unlock.requirement_text(),
			"share": float(earned) / float(maxi(1, careers)),
			"median": CasinoLab.percentile(sorted, 50.0) if earned > 0 else -1,
			"p90": CasinoLab.percentile(sorted, 90.0) if earned > 0 else -1,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: int = int(a["median"]) if int(a["median"]) > 0 else 1 << 30
		var right: int = int(b["median"]) if int(b["median"]) > 0 else 1 << 30
		return left < right if left != right else String(a["id"]) < String(b["id"]))
	# The curve: how many unlocks a median career has open after each run.
	var curve: PackedInt32Array = PackedInt32Array()
	for run: int in runs:
		var at_run: PackedInt32Array = PackedInt32Array()
		for career: Variant in opened_after:
			at_run.append((career as PackedInt32Array)[run])
		at_run.sort()
		curve.append(CasinoLab.percentile(at_run, 50.0))
	return {
		"careers": careers, "runs": runs, "climb": climb,
		"total": catalogue.unlocks.size(), "unlocks": rows, "curve": curve,
	}


## The median of each stat after each run: the conversion table between "this
## unlock should arrive around run 25" and the threshold that puts it there.
func _stat_curve(stat_track: Dictionary, runs: int) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in stat_track:
		var medians: PackedInt64Array = PackedInt64Array()
		for run: int in runs:
			var at_run: PackedInt64Array = (stat_track[key] as Array)[run]
			var sorted: Array = Array(at_run)
			sorted.sort()
			medians.append(int(sorted[sorted.size() / 2]))
		out[key] = medians
	return out


func _print(report: Dictionary, catalogue: MetaCatalogue, careers: int, runs: int, climb: bool) -> void:
	print("\n%d careers of %d runs, %s. %.1fs, %.1f%% of runs won.\n" % [
		careers, runs, "climbing the ladder" if climb else "on the first rung",
		float(report["seconds"]), float(report["win_rate"]) * 100.0])
	print("%-34s %-10s %-26s %6s %6s %7s" % [
		"unlock", "kind", "requirement", "run", "p90", "careers"])
	for row: Dictionary in report["unlocks"]:
		var median: int = int(row["median"])
		print("%-34s %-10s %-26s %6s %6s %6.0f%%" % [
			row["id"], row["kind"], row["requirement"],
			str(median) if median > 0 else "—",
			str(int(row["p90"])) if median > 0 else "—",
			float(row["share"]) * 100.0])
	var curve: PackedInt32Array = report["curve"]
	print("\nA median career has this many of the %d open:" % catalogue.unlocks.size())
	var line: PackedStringArray = PackedStringArray()
	var step: int = maxi(1, runs / 18)
	for run: int in range(step - 1, runs, step):
		line.append("run %d: %d (%.0fh)" % [
			run + 1, curve[run], float(run + 1) * MINUTES_PER_RUN / 60.0])
	print("  " + "\n  ".join(line))
	var stats: Dictionary = report["stats"]
	print("\nWhat a median career has by then:")
	var keys: Array = ["runs_played", "wins", "best_floor", "lifetime_earned",
			"debt_cleared", "total_spins", "vig_paid"]
	print("  %-6s %s" % ["run", " ".join(keys.map(func(k: String) -> String:
		return "%14s" % k))])
	for run: int in range(step - 1, runs, step):
		var cells: PackedStringArray = PackedStringArray()
		for key: Variant in keys:
			cells.append("%14d" % (stats[key] as PackedInt64Array)[run])
		print("  %-6d %s" % [run + 1, " ".join(cells)])


func _write(path: String, report: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("career: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()


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
