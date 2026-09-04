extends GdUnitTestSuite

## The fallback has to be boring and reliable: right length, no clicks, and the
## same every launch so a placeholder is never mistaken for a bug.


func _def(id: StringName, shape: SoundDef.Fallback, ms: Vector2i, loops: bool = false) -> SoundDef:
	var def: SoundDef = SoundDef.new()
	def.id = id
	def.fallback = shape
	def.duration_ms = ms
	def.loops = loops
	def.fallback_hz = 440.0
	return def


func test_every_shape_renders_audible_audio() -> void:
	for shape: int in SoundDef.Fallback.values():
		var def: SoundDef = _def(&"probe", shape as SoundDef.Fallback, Vector2i(200, 300))
		var stream: AudioStreamWAV = ProceduralCues.make_wav(def)
		assert_object(stream).is_not_null()
		assert_int(stream.data.size()).is_greater(0)
		var peak: int = 0
		for i: int in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(i)))
		assert_int(peak).override_failure_message(
				"shape %d rendered silence" % shape).is_greater(1000)


func test_length_follows_the_declared_duration() -> void:
	var def: SoundDef = _def(&"probe", SoundDef.Fallback.TONE, Vector2i(400, 600))
	var stream: AudioStreamWAV = ProceduralCues.make_wav(def)
	# 500 ms nominal, 16-bit mono at the fallback rate.
	var expected: int = int(ProceduralCues.RATE * 0.5) * 2
	assert_int(stream.data.size()).is_between(expected - 64, expected + 64)


func test_one_shots_start_and_end_at_silence() -> void:
	# A placeholder that clicks reads as a bug in the mix rather than a stand-in.
	var def: SoundDef = _def(&"probe", SoundDef.Fallback.TONE, Vector2i(300, 300))
	var stream: AudioStreamWAV = ProceduralCues.make_wav(def)
	assert_int(absi(stream.data.decode_s16(0))).is_less(600)
	assert_int(absi(stream.data.decode_s16(stream.data.size() - 2))).is_less(600)


func test_loops_are_marked_and_bounded() -> void:
	var def: SoundDef = _def(&"probe", SoundDef.Fallback.DRONE, Vector2i(20000, 40000), true)
	var stream: AudioStreamWAV = ProceduralCues.make_wav(def)
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	# One second rendered and looped, not forty seconds held in memory.
	assert_int(stream.data.size()).is_equal(int(ProceduralCues.RATE * ProceduralCues.LOOP_SECONDS) * 2)


func test_rendering_is_deterministic_per_cue() -> void:
	var def: SoundDef = _def(&"stable", SoundDef.Fallback.CLICK, Vector2i(90, 110))
	assert_array(ProceduralCues.make_wav(def).data).is_equal(ProceduralCues.make_wav(def).data)


## Where the buffer's energy sits, in four equal slices. A crude envelope, but
## enough to tell a shape from a different shape.
func _envelope(def: SoundDef) -> PackedFloat32Array:
	var data: PackedByteArray = ProceduralCues.make_wav(def).data
	var frames: int = data.size() / 2
	var slices: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for i: int in frames:
		slices[mini(3, i * 4 / maxi(frames, 1))] += \
				absf(float(data.decode_s16(i * 2)) / 32768.0)
	var total: float = maxf(0.0001, slices[0] + slices[1] + slices[2] + slices[3])
	for i: int in 4:
		slices[i] /= total
	return slices


func test_a_reel_lock_is_two_hits_not_one() -> void:
	# The cha-chunk. A single decaying transient — which is what every one of
	# these cues used to be — puts nearly all its energy in the first quarter;
	# a lock has a second, lower hit behind the strike.
	var lock: SoundDef = load("res://resources/audio/cues/reel_stop_final.tres")
	var tick: SoundDef = load("res://resources/audio/cues/reel_stop_tick_a.tres")
	var lock_shape: PackedFloat32Array = _envelope(lock)
	var tick_shape: PackedFloat32Array = _envelope(tick)
	assert_float(tick_shape[0]).is_greater(0.85)
	assert_float(lock_shape[1]).is_greater(0.2)


func test_the_handle_does_not_sound_like_a_click() -> void:
	# A pull is a stroke: energy spread across it, ending on a thud. It shared a
	# fallback with the reel ticks and was literally the same sound.
	var handle: SoundDef = load("res://resources/audio/cues/handle_pull.tres")
	var shape: PackedFloat32Array = _envelope(handle)
	assert_float(shape[0]).is_less(0.75)
	assert_float(shape[2]).is_greater(0.06)


func test_different_cues_render_differently() -> void:
	var a: SoundDef = _def(&"cue_a", SoundDef.Fallback.CLICK, Vector2i(90, 110))
	var b: SoundDef = _def(&"cue_b", SoundDef.Fallback.CLICK, Vector2i(90, 110))
	assert_array(ProceduralCues.make_wav(a).data).is_not_equal(ProceduralCues.make_wav(b).data)


func test_a_generator_is_offered_for_sustained_cues() -> void:
	var def: SoundDef = _def(&"bed", SoundDef.Fallback.DRONE, Vector2i(20000, 40000), true)
	var generator: AudioStreamGenerator = ProceduralCues.make_generator(def)
	assert_object(generator).is_not_null()
	assert_float(generator.mix_rate).is_equal_approx(float(ProceduralCues.RATE), 1.0)
	assert_float(generator.buffer_length).is_greater(0.0)
