## Reports the state of the audio library against the manifest.
##
## Two questions, both of which have bitten shipped games:
##   1. Which cues are still placeholders? (sourcing progress)
##   2. Does every sourced file have a licence entry? (whether you may ship it)
##
##   godot --headless --path . --script res://tools/audio/audit.gd
##   godot --headless --path . --script res://tools/audio/audit.gd -- --strict
##
## --strict exits non-zero on an unlicensed asset, which is what CI runs. A
## missing credit is a release blocker, not a warning: an asset nobody can trace
## is an asset nobody can clear.
extends SceneTree

const CUE_DIR: String = "res://resources/audio/cues"
const CREDITS: String = "res://assets/audio/CREDITS.md"


func _initialize() -> void:
	var strict: bool = OS.get_cmdline_user_args().has("--strict")
	var defs: Array[SoundDef] = _load_defs()
	if defs.is_empty():
		push_error("audit: no cues found in %s" % CUE_DIR)
		quit(1)
		return
	var credited: Dictionary = _credited_files()

	var sourced: Array[SoundDef] = []
	var placeholder: Array[SoundDef] = []
	var unlicensed: Array[SoundDef] = []
	for def: SoundDef in defs:
		if def.is_sourced():
			sourced.append(def)
			if not credited.has(def.file_name):
				unlicensed.append(def)
		else:
			placeholder.append(def)

	print("── Audio manifest ──────────────────────────")
	print("cues          %d" % defs.size())
	print("sourced       %d (%.0f%%)" % [sourced.size(),
			100.0 * float(sourced.size()) / float(defs.size())])
	print("placeholder   %d" % placeholder.size())
	_print_by_category(defs)

	if not placeholder.is_empty():
		print("\nstill synthesised:")
		for def: SoundDef in placeholder:
			print("  %-26s %-28s %d-%d ms" % [
				def.id, def.file_name, def.duration_ms.x, def.duration_ms.y])
	if not unlicensed.is_empty():
		print("\nSOURCED BUT NOT CREDITED — cannot ship:")
		for def: SoundDef in unlicensed:
			print("  %-26s %s" % [def.id, def.file_name])
		print("Add each to %s with source, author and licence." % CREDITS)
	quit(1 if strict and not unlicensed.is_empty() else 0)


func _print_by_category(defs: Array[SoundDef]) -> void:
	var totals: Dictionary = {}
	for def: SoundDef in defs:
		var key: String = String(SoundDef.Category.keys()[def.category])
		var row: Dictionary = totals.get(key, {"total": 0, "sourced": 0})
		row["total"] = int(row["total"]) + 1
		if def.is_sourced():
			row["sourced"] = int(row["sourced"]) + 1
		totals[key] = row
	var keys: Array = totals.keys()
	keys.sort()
	for key: String in keys:
		var row: Dictionary = totals[key]
		print("  %-12s %d/%d sourced" % [key, int(row["sourced"]), int(row["total"])])


## Filenames named anywhere in CREDITS.md. Deliberately a substring match: the
## file is prose for humans first and a database second.
func _credited_files() -> Dictionary:
	var found: Dictionary = {}
	if not FileAccess.file_exists(CREDITS):
		return found
	var text: String = FileAccess.get_file_as_string(CREDITS)
	for def: SoundDef in _load_defs():
		if text.contains(def.file_name):
			found[def.file_name] = true
	return found


func _load_defs() -> Array[SoundDef]:
	var out: Array[SoundDef] = []
	var dir: DirAccess = DirAccess.open(CUE_DIR)
	if dir == null:
		return out
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var def: SoundDef = load("%s/%s" % [CUE_DIR, clean]) as SoundDef
		if def != null:
			out.append(def)
	return out
