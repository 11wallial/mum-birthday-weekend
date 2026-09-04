## Diffs a recorded human run against the automated policy on the same seed.
##
## The seed makes this possible: replaying it reproduces the identical reels, so
## any difference in outcome is attributable to choices rather than luck. That is
## the whole question Milestone 3 asks — where does a person diverge from the
## agent, and does it cost or pay?
##
##   godot --headless --path . --script res://tools/playtest/compare.gd -- \
##       --run=user://playtests/run_123_456.json
##
## With no --run it compares every recording in user://playtests.
extends SceneTree

const DEFAULT_DIR: String = "user://playtests"


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var paths: PackedStringArray = PackedStringArray()
	if args.has("run"):
		paths.append(String(args["run"]))
	else:
		paths = _recordings(String(args.get("dir", DEFAULT_DIR)))
	if paths.is_empty():
		print("no playtest recordings found — play a run first, they are written to %s"
				% DEFAULT_DIR)
		quit(0)
		return
	for path: String in paths:
		_compare(path)
	quit(0)


func _compare(path: String) -> void:
	var record: Dictionary = _read_json(path)
	if record.is_empty():
		push_error("compare: cannot read %s" % path)
		return
	var run_seed: int = int(record.get("seed", 0))
	var human: Dictionary = _summarise_human(record)
	var agent: Dictionary = _replay_agent(run_seed)

	print("── %s ─────────────────────" % path.get_file())
	print("seed %d" % run_seed)
	print("%-14s %-24s %s" % ["", "human", "agent"])
	print("%-14s %-24s %s" % ["outcome", human["reason"], agent["reason"]])
	print("%-14s %-24d %d" % ["floors", int(human["floors"]), int(agent["floors"])])
	print("%-14s %-24d %d" % ["spins", int(human["spins"]), int(agent["spins"])])
	print("%-14s %-24d %d" % ["earned", int(human["earned"]), int(agent["earned"])])
	print("%-14s %-24s %s" % ["bought", ", ".join(human["bought"]) if not (human["bought"] as Array).is_empty() else "-",
			", ".join(agent["bought"]) if not (agent["bought"] as Array).is_empty() else "-"])

	var only_human: Array[String] = _difference(human["bought"], agent["bought"])
	var only_agent: Array[String] = _difference(agent["bought"], human["bought"])
	if not only_human.is_empty():
		print("  human alone : %s" % ", ".join(only_human))
	if not only_agent.is_empty():
		print("  agent alone : %s" % ", ".join(only_agent))
	if not (human["passed"] as Array).is_empty():
		print("  passed on   : %s" % ", ".join(human["passed"]))
	var dwell: int = int(human["slowest_dwell_ms"])
	if dwell > 0:
		print("  longest deliberation %.1fs on %s" % [float(dwell) / 1000.0, human["slowest_on"]])
	print("")


## Pulls the choices out of a recording.
func _summarise_human(record: Dictionary) -> Dictionary:
	var bought: Array[String] = []
	var passed: Array[String] = []
	var spins: int = 0
	var slowest: int = 0
	var slowest_on: String = "-"
	for entry: Variant in record.get("choices", []):
		var choice: Dictionary = entry
		var kind: String = String(choice.get("kind", ""))
		if kind == "spin":
			spins += 1
		elif kind == "buy":
			bought.append(String(choice.get("artifact", "")))
		elif kind == "leave_shop":
			for item: Variant in choice.get("passed", []):
				passed.append(String(item))
		var dwell: int = int(choice.get("dwell_ms", 0))
		if dwell > slowest:
			slowest = dwell
			slowest_on = kind
	var final: Dictionary = record.get("final", {})
	return {
		"reason": String(record.get("reason", "?")),
		"floors": int(final.get("floors_cleared", 0)),
		"spins": spins,
		"earned": int(final.get("lifetime_earned", 0)),
		"bought": bought,
		"passed": passed,
		"slowest_dwell_ms": slowest,
		"slowest_on": slowest_on,
	}


## Replays the same seed with the built-in policy driving the shop.
func _replay_agent(run_seed: int) -> Dictionary:
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var state: RunState = SimEngine.new(ContentDB.shared(), bus).simulate_run(run_seed)
	var bought: Array[String] = []
	for artifact: ArtifactDef in state.owned:
		bought.append(String(artifact.id))
	return {
		"reason": String(state.end_reason),
		"floors": state.floors_cleared,
		"spins": state.spins_taken,
		"earned": state.economy.lifetime_earned,
		"bought": bought,
	}


static func _difference(a: Array, b: Array) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in a:
		if not b.has(item):
			out.append(String(item))
	return out


func _recordings(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".json"):
			out.append("%s/%s" % [dir_path, file_name])
	return out


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


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
