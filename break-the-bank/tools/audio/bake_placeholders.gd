## Renders every placeholder to a WAV so they can be listened to outside the game.
##
## The game does not need these — the director synthesises placeholders in
## memory. This exists so whoever is sourcing assets can hear the intended
## length and register of a cue before going looking for it.
##
##   godot --headless --path . --script res://tools/audio/bake_placeholders.gd -- \
##       --out=res://placeholder_preview
extends SceneTree


func _initialize() -> void:
	var out_dir: String = "res://placeholder_preview"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var dir: DirAccess = DirAccess.open("res://resources/audio/cues")
	if dir == null:
		push_error("bake: no manifest")
		quit(1)
		return
	var names: PackedStringArray = dir.get_files()
	names.sort()
	var written: int = 0
	for file_name: String in names:
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var def: SoundDef = load("res://resources/audio/cues/%s" % clean) as SoundDef
		if def == null:
			continue
		var stream: AudioStreamWAV = ProceduralCues.make_wav(def)
		var path: String = "%s/%s.wav" % [out_dir, def.id]
		if stream.save_to_wav(path) == OK:
			written += 1
		else:
			push_warning("bake: could not write %s" % path)
	print("baked %d placeholders to %s" % [written, out_dir])
	quit(0)
