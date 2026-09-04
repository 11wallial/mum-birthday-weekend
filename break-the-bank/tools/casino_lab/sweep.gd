## Sweeps one balance knob across values and prints the resulting curve.
##
## The lab answers "what does this build do"; the sweep answers "what should
## this number be". It mutates the loaded content in memory, so nothing is
## written until you decide on a value and edit the .tres yourself.
##
##   godot --headless --path . --script res://tools/casino_lab/sweep.gd -- \
##       --knob=ante --floor=6 --values=3000,3600,4200 --runs=3000
##
## Knobs: ante (needs --floor), spins (needs --floor), payout_scale (--floor),
##        debt, service, debt_growth, synergy_bonus, endless_growth,
##        endless_floors.
## --stay tells every run to take the House's offer, which is how the two
## endless knobs are measured: the curve after the win is what they shape.
extends SceneTree

const DEFAULT_RUNS: int = 3000


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var knob: String = String(args.get("knob", "ante"))
	var runs: int = int(args.get("runs", DEFAULT_RUNS))
	var base_seed: int = int(args.get("seed", 1))
	var floor_index: int = int(args.get("floor", 6))
	var values: PackedFloat32Array = _floats(String(args.get("values", "")))
	# A second knob held at one value under the sweep, as knob:value, for the
	# pairs that only make sense together — the chip supply against the antes.
	var also: String = String(args.get("also", ""))
	if also.contains(":"):
		var held: PackedStringArray = also.split(":")
		_apply(held[0], ContentDB.shared(), ContentDB.shared().floor_at(floor_index),
				held[1].to_float())
		print("holding %s at %s" % [held[0], held[1]])
	if values.is_empty():
		push_error("sweep: --values is required, e.g. --values=3000,3600,4200")
		quit(1)
		return

	var content: ContentDB = ContentDB.shared()
	var target: FloorDef = content.floor_at(floor_index)
	var options: RunOptions = null
	if args.has("stay"):
		options = RunOptions.new()
		options.stay_at_table = true
	print("sweep %s (floor %d) over %d values, %d runs each%s" % [
		knob, floor_index, values.size(), runs, ", staying at the table" if options != null else ""])
	if options != null:
		print("%-12s %-9s %-9s %-9s %-8s %s" % [
			"value", "win rate", "stayed", "after hrs", "dawn", "deaths after hours"])
	else:
		print("%-12s %-9s %-9s %-8s %-9s %-9s %-8s %s" % ["value", "win rate", "floors", "p50",
				"hardware", "took", "settled", "deaths by floor"])

	for value: float in values:
		_apply(knob, content, target, value)
		var report: Dictionary = CasinoLab.run_batch(runs, base_seed, options)
		var floors: Dictionary = report["floors_cleared"]
		var earnings: Dictionary = report["earnings"]
		if options != null:
			var after: Dictionary = report["after_hours"]
			var beyond: Dictionary = after["floors"]
			print("%-12s %-9.1f %-9d %-9.1f %-8d %s" % [
				_format_value(value), float(report["win_rate"]) * 100.0,
				int(after["stayed"]), float(beyond.get("mean", 0.0)), int(after["dawns"]),
				JSON.stringify(after["deaths_by_floor"])])
		else:
			var hardware: Dictionary = report["hardware"]
			var settled: Dictionary = report["settled_early"]
			print("%-12s %-9.1f %-9.2f %-8d %-9.1f %-9s %-8.2f %s" % [
				_format_value(value), float(report["win_rate"]) * 100.0,
				float(floors["mean"]), int(earnings["p50"]), float(hardware["mean"]),
				"%.0f%%" % (float(report["draft_take_rate"]) * 100.0),
				float(settled["mean"]), JSON.stringify(report["deaths_by_floor"])])
	quit(0)


func _apply(knob: String, content: ContentDB, target: FloorDef, value: float) -> void:
	match knob:
		"ante":
			target.ante = int(round(value))
		"spins":
			target.spins = int(round(value))
		"payout_scale":
			target.payout_scale = value
		"debt":
			content.balance.starting_debt = int(round(value))
		"service":
			content.balance.debt_service_percent = value
		"debt_growth":
			# Every floor past the grace period compounds at the same rate.
			for floor_def: FloorDef in content.floors:
				if floor_def.index > content.balance.debt_grace_floors:
					floor_def.debt_interest_percent = value
		"synergy_bonus":
			content.balance.synergy_bonus = value
		"endless_growth":
			content.balance.endless_ante_growth = value
		"endless_floors":
			content.balance.endless_floors_max = int(round(value))
		"chips":
			# Every floor's stipend, scaled: the supply side of the draft.
			for floor_def: FloorDef in content.floors:
				floor_def.chips = maxi(1, int(round(float(floor_def.chips) * value)))
		"chip_prices":
			# Every artifact's price, scaled: the demand side.
			for artifact: ArtifactDef in content.artifacts:
				artifact.cost = maxi(1, int(round(float(artifact.cost) * value)))
		"spin_left_chips":
			content.balance.chips_per_spin_left = int(round(value))
		"late_antes":
			# Every ante from the third floor up, scaled together: the curve a
			# machine that buys a share of the draft has to climb.
			for floor_def: FloorDef in content.floors:
				if floor_def.index >= 3:
					floor_def.ante = maxi(1, int(round(float(floor_def.ante) * value)))
		"settle_reserve":
			# The automated player's threshold for leaving a floor early, as
			# a share of the next ante over what this one costs to leave.
			AutoPlayer.settle_reserve = value
		"chips_and_hold":
			# Both at once: the stipend doubled, and the player never leaving
			# early, to read the reel change on its own.
			for floor_def: FloorDef in content.floors:
				floor_def.chips = maxi(1, int(round(float(floor_def.chips) * 2.0)))
			AutoPlayer.settle_reserve = value
		_:
			push_error("sweep: unknown knob %s" % knob)


func _format_value(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.2f" % value


func _floats(text: String) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for part: String in text.split(",", false):
		var trimmed: String = part.strip_edges()
		if trimmed.is_valid_float():
			out.append(trimmed.to_float())
	return out


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
