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


## Carries the noise filter's state back out of the helpers below. GDScript has
## no out-parameters, and threading a filter through a match arm any other way
## costs more clarity than one file-local float does.
static var _last_noise: float = 0.0


## A cylinder venting: noise through a closing filter, falling in pitch, shut off
## by a thud. Three stages, because a single decaying hiss reads as a leak rather
## than as something being pulled.
static func _pneumatic(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	# The filter closes as the stroke completes, so the hiss darkens.
	var cutoff: float = lerpf(0.55, 0.08, progress)
	_last_noise = state + cutoff * (rng.randf_range(-1.0, 1.0) - state)
	# Loud at the break, easing as the pressure equalises.
	var hiss: float = _last_noise * (1.0 - progress) * 0.8
	# The rod itself, falling as it extends.
	var rod: float = 0.3 * sin(TAU * hz * (1.0 - 0.45 * progress) * t) \
			* exp(-progress * 3.0)
	# And the stop it hits at the end of travel.
	var thud: float = 0.0
	if progress > 0.72:
		var hit: float = (progress - 0.72) / 0.28
		thud = 0.55 * sin(TAU * hz * 0.45 * t) * exp(-hit * 9.0)
	return hiss + rod + thud


## Cha-chunk. A bright strike, then a low body a fraction later — the second hit
## is what makes it a lock rather than a click.
static func _clack(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.7 * (rng.randf_range(-1.0, 1.0) - state)
	# The strike: bright, and gone almost immediately.
	var strike: float = _last_noise * exp(-progress * 55.0) * 0.9
	strike += 0.4 * sin(TAU * hz * 2.4 * t) * exp(-progress * 60.0)
	# The body, one beat behind, low and damped.
	var body: float = 0.0
	if progress > 0.18:
		var since: float = (progress - 0.18) / 0.82
		body = 0.75 * sin(TAU * hz * 0.5 * t) * exp(-since * 7.0)
		body += 0.25 * _last_noise * exp(-since * 16.0)
	return strike + body


## A struck bell. The partial ratios are a bell's, not a harmonic series, and the
## higher ones decay first — which is the whole difference between a bell and an
## organ pipe.
static func _bell(hz: float, t: float, progress: float) -> float:
	const RATIOS: Array = [1.0, 2.76, 5.4, 8.93]
	const WEIGHTS: Array = [1.0, 0.6, 0.36, 0.22]
	var value: float = 0.0
	for i: int in RATIOS.size():
		var decay: float = 3.0 + float(i) * 3.4
		value += float(WEIGHTS[i]) * sin(TAU * hz * float(RATIOS[i]) * t) \
				* exp(-progress * decay)
	# A touch of strike noise at the very start, so it is hit rather than faded in.
	value += 0.15 * sin(TAU * hz * 11.0 * t) * exp(-progress * 90.0)
	return value * 0.5


## Machinery turning. The rumble is a stack of detuned partials with hashed
## phases rather than filtered noise, because noise cannot loop without a
## seam and a spin loop lives or dies on its seam. Whole-number tick and
## flutter rates per second keep the loop silent at the join.
static func _ratchet(hz: float, t: float, _progress: float) -> float:
	var rumble: float = 0.0
	for i: int in 10:
		var partial: float = hz * (0.5 + 0.23 * float(i))
		var phase: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		rumble += sin(TAU * (partial * t + phase)) / (1.4 + float(i) * 0.8)
	# Rotational flutter, twelve a second, and the pawl ticking at fourteen.
	rumble *= 0.42 * (0.82 + 0.18 * sin(TAU * 12.0 * t))
	var stroke: float = fposmod(t * 14.0, 1.0)
	var tick: float = 0.3 * sin(TAU * hz * 9.0 * t) * exp(-stroke * 34.0)
	return rumble + tick


## A vent of steam: the valve opens fast, holds, and eases shut, with a low
## sputter underneath as the pressure falls off.
static func _steam(t: float, progress: float, seconds: float, state: float,
		rng: RandomNumberGenerator) -> float:
	# The filter opens wide at the front of the vent and closes with it.
	var body: float = smoothstep(0.0, 0.06, progress) \
			* (1.0 - smoothstep(0.35, 1.0, progress))
	var cutoff: float = lerpf(0.12, 0.75, body)
	_last_noise = state + cutoff * (rng.randf_range(-1.0, 1.0) - state)
	var hiss: float = _last_noise * body * 0.85
	# The sputter: pressure pulses about nine a second, fading with the vent.
	var sputter: float = 0.18 * sin(TAU * 9.0 * t + sin(t * 40.0)) \
			* body * (1.0 - progress)
	return hiss + sputter * (0.5 + seconds * 0.0)


## An electric arc: a gated buzz that keeps breaking contact, with a few hard
## snaps scattered through it. The gate is what reads as electricity — a
## steady buzz is a fridge, not a spark gap.
static func _zap(hz: float, t: float, progress: float,
		rng: RandomNumberGenerator) -> float:
	var buzz: float = signf(sin(TAU * hz * 7.0 * t)) * 0.3 \
			+ sin(TAU * hz * 11.3 * t) * 0.25
	# Contact gate: drops out at random, more often as the charge dies.
	var gate: float = 1.0 if rng.randf() > 0.25 + progress * 0.4 else 0.15
	var snap: float = 0.0
	if rng.randf() < 0.008:
		snap = rng.randf_range(-1.0, 1.0) * 0.9
	var envelope: float = (1.0 - smoothstep(0.6, 1.0, progress)) \
			* smoothstep(0.0, 0.03, progress)
	return (buzz * gate + snap) * envelope


## Coins landing: a scatter of short pings at irregular times. Deterministic from
## the grain index, so the cue is the same every launch without carrying state.
static func _coins(hz: float, t: float, progress: float, seconds: float) -> float:
	const GRAINS: int = 22
	var value: float = 0.0
	for i: int in GRAINS:
		# Uneven spacing: evenly spaced grains read as a machine gun.
		var at: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		# Front-loaded, the way a handful of coins actually lands.
		at = at * at * seconds
		if t < at:
			continue
		var age: float = (t - at) / seconds
		var ping: float = hz * (2.0 + fposmod(sin(float(i) * 78.233) * 3721.7, 1.6))
		value += 0.34 * sin(TAU * ping * (t - at)) * exp(-age * 46.0)
	return value * (1.0 - progress * 0.35)


## A motor: fundamental and a fifth over it, with the whir of the armature
## rising through the cue. Looped, the whir is held at speed.
static func _motor(hz: float, t: float, progress: float, loops: bool) -> float:
	var speed: float = 1.0 if loops else smoothstep(0.0, 0.45, progress)
	var hum: float = 0.5 * sin(TAU * hz * t) + 0.25 * sin(TAU * hz * 1.5 * t)
	var whir: float = 0.22 * sin(TAU * hz * (6.0 + 4.0 * speed) * t) \
			* (0.7 + 0.3 * sin(TAU * 13.0 * t))
	return (hum + whir * speed) * (0.8 + 0.2 * speed)


## Gears meshing: noise chopped at tooth rate over a low buzz that slips.
static func _grind(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.35 * (rng.randf_range(-1.0, 1.0) - state)
	var teeth: float = 0.55 + 0.45 * signf(sin(TAU * 27.0 * t))
	var buzz: float = 0.35 * sin(TAU * hz * t * (1.0 - 0.1 * progress))
	var envelope: float = smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.55, 1.0, progress))
	return (_last_noise * 0.7 * teeth + buzz) * envelope


## A dot-matrix printer: pins striking in bursts, a line every tenth of a
## second, with the paper feed ticking between lines.
static func _printer(hz: float, t: float, _progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.8 * (rng.randf_range(-1.0, 1.0) - state)
	var line_phase: float = fposmod(t * 9.0, 1.0)
	var printing: float = 1.0 if line_phase < 0.62 else 0.0
	var pins: float = _last_noise * printing * (0.5 + 0.5 * signf(sin(TAU * hz * 0.6 * t)))
	var feed: float = 0.0
	if line_phase >= 0.62 and line_phase < 0.7:
		feed = 0.5 * sin(TAU * hz * 0.25 * t) * exp(-(line_phase - 0.62) * 40.0)
	return pins * 0.55 + feed


## Paper torn off the spool: a burst of noise that rises as the tear runs.
static func _tear(_hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	var cutoff: float = lerpf(0.3, 0.95, progress)
	_last_noise = state + cutoff * (rng.randf_range(-1.0, 1.0) - state)
	var fray: float = 0.7 + 0.3 * sin(TAU * (30.0 + 80.0 * progress) * t)
	var envelope: float = smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.7, 1.0, progress))
	return _last_noise * fray * envelope


## Coins on concrete: the scatter of [method _coins] with the floor's dead
## thud under each landing rather than a tray's ring.
static func _clatter(hz: float, t: float, progress: float, seconds: float) -> float:
	var pings: float = _coins(hz * 1.4, t, progress, seconds) * 0.7
	var thud: float = 0.0
	for i: int in 6:
		var at: float = fposmod(sin(float(i) * 7.31) * 977.0, 1.0) * seconds * 0.7
		if t >= at:
			thud += 0.4 * sin(TAU * hz * 0.18 * (t - at)) * exp(-(t - at) * 30.0)
	return pings + thud


## A stack of paper landing: low, filtered, over almost at once.
static func _thud(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.12 * (rng.randf_range(-1.0, 1.0) - state)
	return (_last_noise * 1.4 + 0.5 * sin(TAU * hz * 0.3 * t)) * exp(-progress * 9.0)


## Leather on a grip: a tone with a wobble in it, brief, breathy.
static func _squeak(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.5 * (rng.randf_range(-1.0, 1.0) - state)
	var wobble: float = hz * (1.0 + 0.12 * sin(TAU * 21.0 * t) - 0.2 * progress)
	var envelope: float = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.5, 1.0, progress))
	return (0.6 * sin(TAU * wobble * t) + 0.25 * _last_noise) * envelope


## A live CRT: mains hum with its harmonics, a faint crackle of static, and
## the flyback whine high over it all. Loops.
static func _hum(hz: float, t: float, state: float, rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.9 * (rng.randf_range(-1.0, 1.0) - state)
	var mains: float = 0.5 * sin(TAU * hz * t) + 0.22 * sin(TAU * hz * 2.0 * t) \
			+ 0.12 * sin(TAU * hz * 3.0 * t)
	var whine: float = 0.06 * sin(TAU * 7800.0 * t)
	var crackle: float = _last_noise * 0.02
	return mains + whine + crackle


## A Nixie cathode swapping: a short metallic tink with a glass ring behind.
static func _tink(hz: float, t: float, progress: float) -> float:
	var strike: float = 0.6 * sin(TAU * hz * 4.0 * t) * exp(-progress * 30.0)
	var ring: float = 0.3 * sin(TAU * hz * 6.3 * t) * exp(-progress * 12.0)
	return strike + ring


## A gas-discharge transformer: a buzz with sputter, and the odd pop.
static func _buzz(hz: float, t: float, rng: RandomNumberGenerator) -> float:
	var body: float = 0.4 * signf(sin(TAU * hz * t)) * (0.7 + 0.3 * sin(TAU * 3.0 * t)) \
			+ 0.2 * sin(TAU * hz * 2.0 * t)
	var pop: float = 0.0
	if rng.randf() < 0.0015:
		pop = rng.randf_range(-0.8, 0.8)
	return body * 0.6 + pop


## One drop into a puddle: a blip falling in pitch, then the splash.
static func _drip(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	var blip: float = 0.7 * sin(TAU * hz * (1.6 - 0.9 * progress) * t) * exp(-progress * 18.0)
	var splash: float = 0.0
	if progress > 0.25:
		_last_noise = state + 0.5 * (rng.randf_range(-1.0, 1.0) - state)
		splash = _last_noise * 0.4 * exp(-(progress - 0.25) * 14.0)
	else:
		_last_noise = state
	return blip + splash


## A structure shifting: a low tone bending down with a resonance riding it.
static func _groan(hz: float, t: float, progress: float) -> float:
	var bend: float = hz * (1.0 - 0.3 * progress + 0.05 * sin(TAU * 2.5 * t))
	var body: float = 0.6 * sin(TAU * bend * t) + 0.3 * sin(TAU * bend * 2.01 * t)
	var resonance: float = 0.2 * sin(TAU * bend * 5.0 * t) * (0.5 + 0.5 * sin(TAU * 7.0 * t))
	var envelope: float = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.6, 1.0, progress))
	return (body + resonance) * envelope


## A rising swell: three detuned saws climbing an octave, vibrato on the top.
static func _swell(hz: float, t: float, progress: float) -> float:
	var pitch: float = hz * pow(2.0, progress) * (1.0 + 0.012 * sin(TAU * 6.0 * t))
	var value: float = 0.0
	for detune: float in [0.993, 1.0, 1.007]:
		value += fposmod(pitch * detune * t, 1.0) * 2.0 - 1.0
	var envelope: float = smoothstep(0.0, 0.3, progress) * (1.0 - smoothstep(0.85, 1.0, progress))
	return value * 0.25 * envelope


## A sub drop: a sine falling from the fundamental to well under it.
static func _drop(hz: float, t: float, progress: float) -> float:
	var pitch: float = hz * pow(0.36, progress)
	return 0.9 * sin(TAU * pitch * t) * (1.0 - smoothstep(0.6, 1.0, progress))


## An alarm: a hard, bright tone gated on and off four times a second.
static func _alarm(hz: float, t: float, _progress: float) -> float:
	var gate: float = 1.0 if fposmod(t * 4.0, 1.0) < 0.5 else 0.0
	return gate * (0.5 * signf(sin(TAU * hz * t)) * 0.6 + 0.4 * sin(TAU * hz * 1.5 * t))


## A tactile switch: the click, then the copper zap of a contact closing.
static func _switch(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.8 * (rng.randf_range(-1.0, 1.0) - state)
	var click: float = _last_noise * exp(-progress * 60.0)
	var zap: float = 0.0
	if progress > 0.15:
		zap = 0.35 * signf(sin(TAU * hz * 5.0 * t)) * exp(-(progress - 0.15) * 20.0) \
				* (1.0 if rng.randf() > 0.3 else 0.2)
	return click + zap


## A tannoy keying on: a burst of static, the line's hum, and a voice's
## mumble — pitch and rhythm and no words, which is all a placeholder for a
## voice should ever be.
static func _crackle(hz: float, t: float, progress: float, state: float,
		rng: RandomNumberGenerator) -> float:
	_last_noise = state + 0.9 * (rng.randf_range(-1.0, 1.0) - state)
	var static_burst: float = _last_noise * 0.6 * exp(-progress * 12.0)
	var hum: float = 0.08 * sin(TAU * 100.0 * t)
	var talk: float = 0.0
	if progress > 0.2:
		var syllable: float = 0.5 + 0.5 * sin(TAU * 5.5 * t + sin(t * 17.0))
		var voice: float = hz * (1.0 + 0.15 * sin(TAU * 2.1 * t)) * (1.0 + 0.04 * sin(TAU * 31.0 * t))
		talk = 0.3 * syllable * (sin(TAU * voice * t) + 0.5 * sin(TAU * voice * 2.0 * t)) \
				* (1.0 - smoothstep(0.8, 1.0, progress))
	return static_burst + hum + talk


## Wind through a vent: filtered noise that swells and dies slowly. Loops.
static func _wind(t: float, state: float, rng: RandomNumberGenerator) -> float:
	var breath: float = 0.5 + 0.5 * sin(TAU * 0.5 * t)
	var cutoff: float = lerpf(0.04, 0.16, breath)
	_last_noise = state + cutoff * (rng.randf_range(-1.0, 1.0) - state)
	return _last_noise * (0.5 + 0.5 * breath) * 1.6


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
			SoundDef.Fallback.PNEUMATIC:
				value = _pneumatic(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.CLACK:
				value = _clack(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.BELL:
				value = _bell(hz, t, progress)
			SoundDef.Fallback.COINS:
				value = _coins(hz, t, progress, seconds)
			SoundDef.Fallback.RATCHET:
				value = _ratchet(hz, t, progress)
			SoundDef.Fallback.STEAM:
				value = _steam(t, progress, seconds, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.ZAP:
				value = _zap(hz, t, progress, rng)
			SoundDef.Fallback.MOTOR:
				value = _motor(hz, t, progress, def.loops)
			SoundDef.Fallback.GRIND:
				value = _grind(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.PRINTER:
				value = _printer(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.TEAR:
				value = _tear(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.CLATTER:
				value = _clatter(hz, t, progress, seconds)
			SoundDef.Fallback.THUD:
				value = _thud(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.SQUEAK:
				value = _squeak(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.HUM:
				value = _hum(hz, t, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.TINK:
				value = _tink(hz, t, progress)
			SoundDef.Fallback.BUZZ:
				value = _buzz(hz, t, rng)
			SoundDef.Fallback.DRIP:
				value = _drip(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.GROAN:
				value = _groan(hz, t, progress)
			SoundDef.Fallback.SWELL:
				value = _swell(hz, t, progress)
			SoundDef.Fallback.DROP:
				value = _drop(hz, t, progress)
			SoundDef.Fallback.ALARM:
				value = _alarm(hz, t, progress)
			SoundDef.Fallback.SWITCH:
				value = _switch(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.CRACKLE:
				value = _crackle(hz, t, progress, noise_state, rng)
				noise_state = _last_noise
			SoundDef.Fallback.WIND:
				value = _wind(t, noise_state, rng)
				noise_state = _last_noise
		if not def.loops:
			value *= _edge_fade(progress)
		# Soft-clipped, never clamped: a busy cue that sums past 1.0 should
		# round over like tape, not square off like a broken driver — the hard
		# clamp here was most of what the web build's "crackle" was.
		value = tanh(value * 1.15)
		data.encode_s16(i * 2, int(value * 32767.0 * 0.72))

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
	generator.buffer_length = 0.18
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
			SoundDef.Fallback.HUM:
				value = 0.5 * sin(TAU * phase) + 0.22 * sin(TAU * phase * 2.0) \
						+ 0.1 * sin(TAU * phase * 3.0)
			SoundDef.Fallback.BUZZ:
				value = 0.4 * signf(sin(TAU * phase)) + 0.2 * sin(TAU * phase * 2.0)
			_:
				value = 0.7 * sin(TAU * phase) + 0.2 * sin(TAU * phase * 2.0)
		var shaped: float = tanh(value * 1.1) * 0.42
		playback.push_frame(Vector2(shaped, shaped))
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
