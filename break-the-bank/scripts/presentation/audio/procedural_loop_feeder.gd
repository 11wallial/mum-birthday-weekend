## Drives one [AudioStreamGenerator] voice for a sustained placeholder.
##
## Only used for looping cues with no sourced file. A generator has to be topped
## up every frame, so this exists as a node; one-shots take the cheaper
## [method ProceduralCues.make_wav] path and need nothing per frame.
class_name ProceduralLoopFeeder
extends AudioStreamPlayer

var _def: SoundDef
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0


## Starts synthesising [param def]. Safe to call again to switch cue.
func begin(def: SoundDef) -> void:
	_def = def
	# A generator can only be driven through stream playback. The web export
	# defaults to sample playback, where this voice would warn and stay silent.
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	stream = ProceduralCues.make_generator(def)
	bus = String(def.bus)
	volume_db = def.base_volume_db
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_phase = 0.0
	set_process(_playback != null)


func end() -> void:
	set_process(false)
	stop()
	_playback = null


func _process(_delta: float) -> void:
	if _playback == null or _def == null:
		return
	_phase = ProceduralCues.fill_generator(_playback, _def, _phase)
