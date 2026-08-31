## Synthesises a placeholder for any cue with no sourced file behind it.
##
## The manifest is deliberately allowed to run ahead of the asset library: a cue
## that exists in the manifest but not on disk still plays, at roughly the right
## length and register, so the game is never silent while sourcing is in
## progress and a missing file is audible as "obviously temporary" rather than
## as nothing at all.
##
## Two paths, because they answer different problems:
##   - [method make_wav] renders a finite buffer once. One-shots use this: it
##     costs nothing per frame and can be cached like any other stream.
##   - [method make_generator] hands back an [AudioStreamGenerator] fed live by
##     [ProceduralLoopFeeder]. Sustained beds use this — a drone that has to run
##     for minutes should not be a minutes-long buffer in memory.
class_name ProceduralCues
extends RefCounted

const RATE: int = 22050
## Longest placeholder rendered as a buffer. Loops are rendered as one seamless
## second and looped rather than rendered at full length.
const MAX_ONESHOT_SECONDS: float = 3.0
const LOOP_SECONDS: float = 1.0


## Renders [param def] to a finite stream. Loops come back seamless.
static func make_wav(def: SoundDef) -> AudioStreamWAV:
	var seconds: float = LOOP_SECONDS if def.loops else clampf(
			def.nominal_seconds(), 0.02, MAX_ONESHOT_SECONDS)
	var frames: int = maxi(int(RATE * seconds), 8)
	var hz: float = def.fallback_hz
	if def.loops:
		# Snap to a whole number of cycles per loop so the seam is silent.
		hz = maxf(1.0, round(hz * seconds) / seconds)

	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Seeded from the cue id: a placeholder sounds the same on every launch.
	rng.seed = RngStream.derive_seed(0, def.id)
	var noise_state: float = 0.0
	for i: int in frames:
		var t: float = float(i) / float(RATE)
		var progress: float = float(i) / float(frames)
		var value: float = 0.0
		match def.fallback:
			SoundDef.Fallback.CLICK:
				# One-pole lowpass over white noise: a body, not a hiss.
				noise_state += 0.45 * (rng.randf_range(-1.0, 1.0) - noise_state)
				value = noise_state * exp(-progress * 14.0)
				value += 0.35 * sin(TAU * hz * t) * exp(-progress * 22.0)
			SoundDef.Fallback.TONE:
				value = _partials(hz, t, progress, 3.5)
			SoundDef.Fallback.RISE:
				value = _partials(hz * (1.0 + 0.5 * progress), t, progress, 2.5)
			SoundDef.Fallback.FALL:
				value = _partials(hz * (1.0 - 0.35 * progress), t, progress, 2.5)
			SoundDef.Fallback.DRONE:
				value = 0.7 * sin(TAU * hz * t) + 0.2 * sin(TAU * hz * 2.0 * t)
				# Slow beat so a bed does not read as a test tone.
				value *= 0.9 + 0.1 * sin(TAU * 0.5 * t)
			SoundDef.Fallback.SIREN:
				var sweep: float = hz * (1.0 + 0.35 * sin(TAU * 0.7 * t))
				value = sin(TAU * sweep * t) * (0.7 + 0.3 * sin(TAU * 1.4 * t))
		if not def.loops:
			value *= _edge_fade(progress)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0 * 0.7))

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if def.loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream


## A generator sized for [param def], to be driven by [ProceduralLoopFeeder].
static func make_generator(def: SoundDef) -> AudioStreamGenerator:
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = float(RATE)
	# Roughly 100 ms of headroom: long enough to survive a frame spike, short
	# enough that a parameter change is audible promptly.
	generator.buffer_length = 0.1
	return generator


## Fills whatever space [param playback] has free, continuing from [param phase].
## Returns the phase to pass in next time.
static func fill_generator(playback: AudioStreamGeneratorPlayback, def: SoundDef,
		phase: float) -> float:
	var hz: float = def.fallback_hz
	var frames: int = playback.get_frames_available()
	for i: int in frames:
		var value: float = 0.0
		match def.fallback:
			SoundDef.Fallback.SIREN:
				value = sin(TAU * phase) * (0.7 + 0.3 * sin(TAU * phase * 0.02))
			_:
				value = 0.7 * sin(TAU * phase) + 0.2 * sin(TAU * phase * 2.0)
		playback.push_frame(Vector2(value, value) * 0.5)
		phase = fmod(phase + hz / float(RATE), 1.0)
	return phase


## Decaying harmonic stack. [param decay] is in units of the cue's own length,
## so a long cue and a short one both end at silence.
static func _partials(hz: float, t: float, progress: float, decay: float) -> float:
	var envelope: float = exp(-progress * decay)
	return envelope * (
			sin(TAU * hz * t)
			+ 0.35 * sin(TAU * hz * 2.0 * t)
			+ 0.12 * sin(TAU * hz * 3.0 * t)) * 0.6


## 2 ms in, 15% out. Without the leading fade a placeholder starts on a click.
static func _edge_fade(progress: float) -> float:
	const ATTACK: float = 0.02
	const RELEASE: float = 0.15
	if progress < ATTACK:
		return progress / ATTACK
	if progress > 1.0 - RELEASE:
		return (1.0 - progress) / RELEASE
	return 1.0
