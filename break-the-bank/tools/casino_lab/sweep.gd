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
##        debt, service, debt_growth, synergy_bonus.
extends SceneTree

const DEFAULT_RUNS: int = 3000


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var knob: String = String(args.get("knob", "ante"))
	var runs: int = int(args.get("runs", DEFAULT_RUNS))
	var base_seed: int = int(args.get("seed", 1))
	var floor_index: int = int(args.get("floor", 6))
	var values: PackedFloat32Array = _floats(String(args.get("values", "")))
	if values.is_empty():
		push_error("sweep: --values is required, e.g. --values=3000,3600,4200")
		quit(1)
		return

	var content: ContentDB = ContentDB.shared()
	var target: FloorDef = content.floor_at(floor_index)
	print("sweep %s (floor %d) over %d values, %d runs each" % [
		knob, floor_index, values.size(), runs])
	print("%-12s %-9s %-9s %-8s %s" % ["value", "win rate", "floors", "p50", "deaths by floor"])

	for value: float in values:
		_apply(knob, content, target, value)
		var report: Dictionary = CasinoLab.run_batch(runs, base_seed)
		var floors: Dictionary = report["floors_cleared"]
		var earnings: Dictionary = report["earnings"]
		print("%-12s %-9.1f %-9.2f %-8d %s" % [
			_format_value(value), float(report["win_rate"]) * 100.0,
			float(floors["mean"]), int(earnings["p50"]),
			JSON.stringify(report["deaths_by_floor"])])
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
