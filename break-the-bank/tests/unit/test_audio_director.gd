extends GdUnitTestSuite

## Behaviour that has to hold whether or not any asset has been sourced yet.

var _director: AudioDirector


func before_test() -> void:
	_director = auto_free(AudioDirector.new()) as AudioDirector
	add_child(_director)


func test_the_manifest_loads() -> void:
	assert_int(_director.cue_ids().size()).is_greater_equal(40)
	assert_object(_director.definition(&"ui_click")).is_not_null()


func test_an_unknown_cue_is_ignored_rather_than_fatal() -> void:
	assert_object(_director.play(&"no_such_cue")).is_null()
	_director.play_at(&"no_such_cue")
	_director.start_loop(&"no_such_cue")
	assert_bool(_director.is_looping(&"no_such_cue")).is_false()


func test_playing_a_cue_with_no_sourced_file_still_makes_sound() -> void:
	# The whole point of the placeholder path: a full manifest and an empty
	# asset folder still produces a playing voice. It is the safety net for a
	# file that goes missing, so it has to keep working after the manifest is
	# complete — which is now, and is what broke the old version of this test.
	# It hunted the content set for an unsourced one-shot and there are none
	# left, so it failed with its own message about having nothing to prove.
	# The subject is made here instead of found, which tests the fallback
	# directly and cannot be undone by sourcing anything.
	var placeholder: StringName = &""
	for id: Variant in _director.cue_ids():
		var candidate: SoundDef = _director.definition(StringName(id))
		if candidate != null and not candidate.loops:
			placeholder = StringName(id)
			break
	assert_str(String(placeholder)).override_failure_message(
			"the content set has no one-shot cues at all").is_not_empty()
	var subject: SoundDef = _director.definition(placeholder)
	var real: String = subject.file_name
	# Pointed at a file that is not there, exactly as a missing asset would be.
	subject.file_name = "mechanical/no_such_file_on_disk.wav"
	assert_bool(subject.is_sourced()).override_failure_message(
			"the test's own stand-in resolved to a real file").is_false()
	var player: AudioStreamPlayer = _director.play(placeholder)
	subject.file_name = real
	assert_object(player).is_not_null()
	assert_object(player.stream).is_not_null()
	assert_bool(player.playing).is_true()


func test_a_sourced_cue_plays_the_file_rather_than_the_placeholder() -> void:
	var def: SoundDef = _director.definition(&"ui_click")
	assert_bool(def.is_sourced()).override_failure_message(
			"ui_click lost its sourced asset").is_true()
	var player: AudioStreamPlayer = _director.play(&"ui_click")
	assert_object(player).is_not_null()
	assert_object(player.stream).is_same(load(def.absolute_path()))


func test_pitch_and_volume_land_inside_the_declared_ranges() -> void:
	var def: SoundDef = _director.definition(&"ui_chip_place")
	for i: int in 25:
		var player: AudioStreamPlayer = _director.play(&"ui_chip_place")
		if player == null:
			continue
		assert_float(player.pitch_scale).is_between(def.pitch_jitter.x, def.pitch_jitter.y)
		assert_float(player.volume_db).is_between(
				def.base_volume_db + def.volume_jitter_db.x,
				def.base_volume_db + def.volume_jitter_db.y)
		player.stop()


func test_variation_actually_varies() -> void:
	# A jitter range that always returns the same number is repetition fatigue
	# with extra steps.
	var pitches: Dictionary = {}
	for i: int in 30:
		var player: AudioStreamPlayer = _director.play(&"ui_chip_place")
		if player != null:
			pitches[snappedf(player.pitch_scale, 0.001)] = true
			player.stop()
	assert_int(pitches.size()).is_greater(5)


func test_a_cue_cannot_exceed_its_own_voice_cap() -> void:
	# The cap is on simultaneous voices, not on nodes: stealing frees a voice
	# and the next trigger is free to reuse that same player.
	for cue: StringName in [&"ui_purchase_denied", &"ui_chip_place"]:
		var def: SoundDef = _director.definition(cue)
		for i: int in def.max_voices + 4:
			_director.play(cue)
		assert_int(_sounding_count(cue)).override_failure_message(
				"%s exceeded its cap of %d voices" % [cue, def.max_voices]
				).is_less_equal(def.max_voices)


## Players currently sounding [param cue], identified by its cached stream.
func _sounding_count(cue: StringName) -> int:
	var stream: AudioStream = _director.play(cue).stream
	var count: int = 0
	for child: Node in _director.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing and player.stream == stream:
			count += 1
	return count


func test_the_flat_pool_is_bounded() -> void:
	# Spamming must never grow the node count without limit.
	for i: int in 200:
		_director.play(&"ui_seed_type")
	var players: int = 0
	for child: Node in _director.get_children():
		if child is AudioStreamPlayer:
			players += 1
	assert_int(players).is_less_equal(AudioDirector.FLAT_VOICES + AudioDirector.POSITIONAL_VOICES)


func test_loops_start_once_and_stop_cleanly() -> void:
	_director.start_loop(&"amb_room_hum_loop")
	assert_bool(_director.is_looping(&"amb_room_hum_loop")).is_true()
	_director.start_loop(&"amb_room_hum_loop")
	_director.stop_loop(&"amb_room_hum_loop")
	assert_bool(_director.is_looping(&"amb_room_hum_loop")).is_false()


func test_a_loud_cue_ducks_the_music_bus_and_lets_it_back_up() -> void:
	var bus: int = AudioServer.get_bus_index("Music")
	assert_int(bus).is_greater_equal(0)
	var base: float = AudioServer.get_bus_volume_db(bus)
	_director.duck_music(8.0)
	await await_millis(120)
	assert_float(AudioServer.get_bus_volume_db(bus)).is_less(base)
	await await_millis(700)
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(base, 0.5)
