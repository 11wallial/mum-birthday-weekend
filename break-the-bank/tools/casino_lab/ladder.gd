## Runs a batch on every rung of the ladder, or every challenge, and prints
## the curve: what each rule change does to the win rate.
##
##   godot --headless --path . --script res://tools/casino_lab/ladder.gd -- \
##       --runs=1000 --seed=1 [--challenges]
##
## The ladder is only a ladder if each rung is harder than the one below it,
## and a challenge is only a challenge if it moves the number; this is how
## either claim is checked before a rung or a rule is shipped.
extends SceneTree

const DEFAULT_RUNS: int = 1000


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var runs: int = int(args.get("runs", DEFAULT_RUNS))
	var base_seed: int = int(args.get("seed", 1))
	var catalogue: MetaCatalogue = MetaCatalogue.new()
	catalogue.load_all()
	print("%-4s %-18s %-9s %-8s %-9s %s" % [
		"tier", "rung", "win rate", "floors", "p50", "deaths by floor"])
	if args.has("challenges"):
		for challenge: ChallengeDef in catalogue.challenges:
			_row("—", challenge.display_name,
					CasinoLab.run_batch(runs, base_seed, catalogue.options_for_challenge(challenge.id)))
	else:
		for rung: DifficultyDef in catalogue.difficulties:
			_row(str(rung.tier), rung.display_name,
					CasinoLab.run_batch(runs, base_seed, catalogue.options_for_difficulty(rung.id)))
	quit(0)


func _row(tier: String, name: String, report: Dictionary) -> void:
	var floors: Dictionary = report["floors_cleared"]
	var earnings: Dictionary = report["earnings"]
	print("%-4s %-18s %-9.1f %-8.2f %-9d %s" % [
		tier, name, float(report["win_rate"]) * 100.0, float(floors["mean"]),
		int(earnings["p50"]), JSON.stringify(report["deaths_by_floor"])])


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
