## Turns simulation events into sound.
##
## Owns a small pool of players so overlapping cues (three reels stopping in
## quick succession) do not cut each other off. Like every other node in this
## folder it only listens — muting or deleting it changes nothing about the run.
class_name AudioDirector
extends Node

const CUE_DIR: String = "res://assets/audio"
## Payout at or above which the bigger stinger replaces the plain one.
const BIG_PAYOUT: int = 60
const VOICES: int = 6

@export_range(-40.0, 6.0) var volume_db: float = -6.0

var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cues: Dictionary = {}
var _bus: EffectBus


func _ready() -> void:
	for i: int in VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)
	for cue: String in ["reel_stop", "payout", "payout_big", "artifact",
			"floor_cleared", "run_lost", "coin"]:
		var path: String = "%s/%s.wav" % [CUE_DIR, cue]
		if ResourceLoader.exists(path):
			_cues[cue] = load(path) as AudioStream
		else:
			push_warning("AudioDirector: missing cue %s" % path)


func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)


## Plays a cue by name. Silently ignores unknown or missing cues so a stripped
## asset folder degrades to a silent game rather than a broken one.
func play(cue: String, pitch: float = 1.0) -> void:
	if not _cues.has(cue):
		return
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = _cues[cue]
	player.pitch_scale = pitch
	player.play()


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.PAYOUT_CALCULATED:
			var payout: int = int(payload.get("payout", 0))
			if payout <= 0:
				return
			play("payout_big" if payout >= BIG_PAYOUT else "payout")
		EffectBus.Event.ARTIFACT_TRIGGERED:
			play("artifact")
		EffectBus.Event.ARTIFACT_ACQUIRED:
			play("coin", 0.9)
		EffectBus.Event.FLOOR_CLEARED:
			play("floor_cleared")
		EffectBus.Event.RUN_ENDED:
			if String(payload.get("phase", "")) != "WON":
				play("run_lost")
			else:
				play("floor_cleared", 1.15)
		_:
			pass
