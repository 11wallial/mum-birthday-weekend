extends GdUnitTestSuite

## The manifest is a contract with whoever sources the assets, so it is worth
## holding to a shape: consistent naming, routable buses, sane ranges.

const CUE_DIR: String = "res://resources/audio/cues"
## Buses declared in default_bus_layout.tres.
const BUSES: Array = ["Master", "Music", "SFX", "UI", "Ambience"]

var _defs: Array[SoundDef] = []


func before() -> void:
	var dir: DirAccess = DirAccess.open(CUE_DIR)
	assert_object(dir).is_not_null()
	for file_name: String in dir.get_files():
		if file_name.ends_with(".tres"):
			_defs.append(load("%s/%s" % [CUE_DIR, file_name]) as SoundDef)


func test_the_manifest_is_populated() -> void:
	assert_int(_defs.size()).is_greater_equal(40)


func test_every_cue_has_a_unique_id_matching_its_filename() -> void:
	var seen: Dictionary = {}
	for def: SoundDef in _defs:
		assert_str(String(def.id)).is_not_empty()
		assert_bool(seen.has(def.id)).override_failure_message(
				"duplicate cue id %s" % def.id).is_false()
		seen[def.id] = true
		# Keeps the drop-in workflow honest: the file a sourced asset lands at
		# is derivable from the cue id alone.
		assert_str(def.file_name).ends_with("%s.wav" % def.id)


func test_every_cue_routes_to_a_bus_that_exists() -> void:
	for def: SoundDef in _defs:
		assert_bool(BUSES.has(String(def.bus))).override_failure_message(
				"%s routes to unknown bus %s" % [def.id, def.bus]).is_true()
		assert_int(AudioServer.get_bus_index(String(def.bus))).is_greater_equal(0)


func test_durations_are_ordered_and_plausible() -> void:
	for def: SoundDef in _defs:
		assert_int(def.duration_ms.x).is_greater(0)
		assert_int(def.duration_ms.y).is_greater_equal(def.duration_ms.x)
		# A one-shot longer than five seconds is a music cue in disguise.
		if not def.loops:
			assert_int(def.duration_ms.y).is_less_equal(5000)


func test_randomisation_ranges_are_ordered_and_sane() -> void:
	for def: SoundDef in _defs:
		assert_float(def.pitch_jitter.x).is_less_equal(def.pitch_jitter.y)
		assert_float(def.pitch_jitter.x).is_greater(0.5)
		assert_float(def.pitch_jitter.y).is_less(2.0)
		assert_float(def.volume_jitter_db.x).is_less_equal(def.volume_jitter_db.y)
		# Louder-than-authored jitter would defeat the mix.
		assert_float(def.volume_jitter_db.y).is_less_equal(3.0)


func test_loops_and_ambience_are_declared_consistently() -> void:
	for def: SoundDef in _defs:
		if def.category == SoundDef.Category.AMBIENCE and def.file_name.contains("_loop"):
			assert_bool(def.loops).override_failure_message(
					"%s is named a loop but is not marked looping" % def.id).is_true()
		if def.loops:
			# A loop holding several voices is a mistake that only shows up as
			# a slowly building drone.
			assert_int(def.max_voices).is_equal(1)


func test_the_four_artifact_tiers_all_have_a_cue() -> void:
	var ids: Array[String] = []
	for def: SoundDef in _defs:
		ids.append(String(def.id))
	for tier: int in range(1, 5):
		assert_array(ids).contains(["artifact_t%d_trigger" % tier])


func test_every_artifact_maps_to_a_tier_in_range() -> void:
	for artifact: ArtifactDef in ContentDB.shared().artifacts:
		assert_int(artifact.tier()).is_between(1, 4)
