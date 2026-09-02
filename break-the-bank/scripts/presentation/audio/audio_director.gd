## Turns simulation events into sound.
##
## Everything it can play is declared in the manifest under resources/audio/cues;
## nothing here hard-codes a filename or a volume. A cue whose file has not been
## sourced yet is synthesised on demand, so the manifest can be complete long
## before the asset library is, and swapping a placeholder for a real recording
## is a file drop with no code change.
##
## Like every other node in this folder it only listens: muting or deleting it
## changes nothing about the run.
class_name AudioDirector
extends Node

const CUE_DIR: String = "res://resources/audio/cues"
## Flat voices for UI and non-positional cues.
const FLAT_VOICES: int = 16
## Positional voices anchored in the room. Deliberately fewer: past a handful,
## simultaneous 3D sources stop being localisable and start being mud.
const POSITIONAL_VOICES: int = 8
## Payout at or above which the big stinger replaces the plain one.
const BIG_PAYOUT: int = 60
## How quickly the music bus drops and recovers around a ducking cue.
const DUCK_ATTACK: float = 0.06
const DUCK_RELEASE: float = 0.45

@export var master_volume_db: float = 0.0
## Node positional cues are parented to — the machine, normally.
@export var positional_anchor_path: NodePath = ^""

var _defs: Dictionary = {}
var _streams: Dictionary = {}
var _flat: Array[AudioStreamPlayer] = []
var _positional: Array[AudioStreamPlayer3D] = []
## Cue id -> array of players currently sounding it, for per-cue voice caps.
var _sounding: Dictionary = {}
## Cue id -> the dedicated player holding a loop.
var _loops: Dictionary = {}
var _feeders: Dictionary = {}
var _bus: EffectBus
var _music_base_db: float = 0.0
var _duck_tween: Tween
var _anchor: Node3D
## The room's own noises, on their own clocks: a drip, a groan, the sign
## popping. Seconds until each next fires.
var _foley: Dictionary = {&"foley_drip": 4.0, &"foley_groan": 20.0, &"sign_pop": 8.0}
## Where in the room each of them comes from, relative to the anchor.
const FOLEY_AT: Dictionary = {
	&"foley_drip": Vector3(-2.0, 0.0, 1.2),
	&"foley_groan": Vector3(-2.6, 1.3, -3.2),
	&"sign_pop": Vector3(3.5, 2.2, -3.2),
}
## How long each waits between firings, as (min, max) seconds.
const FOLEY_EVERY: Dictionary = {
	&"foley_drip": Vector2(5.0, 16.0),
	&"foley_groan": Vector2(28.0, 70.0),
	&"sign_pop": Vector2(9.0, 30.0),
}
var _room_alive: bool = false


func _ready() -> void:
	load_manifest()
	# Every voice plays as a stream rather than a sample. The web export defaults
	# to sample playback, which cannot play an [AudioStreamGenerator] at all —
	# the ambience beds are generated, so on the web they would simply be silent
	# and warn once per voice. Stream playback behaves the same on every target.
	_anchor = get_node_or_null(positional_anchor_path) as Node3D
	for i: int in FLAT_VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		_flat.append(player)
	var parent: Node = _anchor if _anchor != null else self
	for i: int in POSITIONAL_VOICES:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.max_distance = 18.0
		player.unit_size = 4.0
		parent.add_child(player)
		_positional.append(player)
	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		_music_base_db = AudioServer.get_bus_volume_db(music_bus)


## The room's foley fires on its own clocks once a run has started. Random
## from the engine's own generator: this is presentation, and nothing about
## the run depends on when the ceiling drips.
func _process(delta: float) -> void:
	if not _room_alive:
		return
	for cue: StringName in _foley.keys():
		_foley[cue] = float(_foley[cue]) - delta
		if float(_foley[cue]) > 0.0:
			continue
		var every: Vector2 = FOLEY_EVERY.get(cue, Vector2(10.0, 20.0))
		_foley[cue] = randf_range(every.x, every.y)
		play_at(cue, FOLEY_AT.get(cue, Vector3.ZERO))


## Loads every cue in the manifest. Separate from _ready so tests can call it.
func load_manifest() -> void:
	_defs.clear()
	var dir: DirAccess = DirAccess.open(CUE_DIR)
	if dir == null:
		push_warning("AudioDirector: no manifest at %s" % CUE_DIR)
		return
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var def: SoundDef = load("%s/%s" % [CUE_DIR, clean]) as SoundDef
		if def != null:
			_defs[def.id] = def


func definition(cue: StringName) -> SoundDef:
	return _defs.get(cue, null) as SoundDef


func cue_ids() -> Array:
	var ids: Array = _defs.keys()
	ids.sort()
	return ids


func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)


## Plays a cue by id. Unknown ids are ignored rather than raising: audio must
## never be able to take the game down.
## [param pitch_bias] multiplies on top of the cue's own jitter.
func play(cue: StringName, pitch_bias: float = 1.0) -> AudioStreamPlayer:
	var def: SoundDef = definition(cue)
	if def == null or def.loops:
		return null
	var player: AudioStreamPlayer = _claim_flat(def)
	if player == null:
		return null
	player.stream = _stream_for(def)
	player.bus = String(def.bus)
	player.pitch_scale = randf_range(def.pitch_jitter.x, def.pitch_jitter.y) * pitch_bias
	player.volume_db = (def.base_volume_db + master_volume_db
			+ randf_range(def.volume_jitter_db.x, def.volume_jitter_db.y))
	player.play()
	if def.duck_music_db > 0.0:
		duck_music(def.duck_music_db)
	return player


## Plays a cue in the room rather than flat. Falls back to a flat voice when the
## cue is not marked positional or no anchor exists.
func play_at(cue: StringName, offset: Vector3 = Vector3.ZERO) -> void:
	var def: SoundDef = definition(cue)
	if def == null:
		return
	if not def.positional or _positional.is_empty():
		play(cue)
		return
	var player: AudioStreamPlayer3D = _claim_positional(def)
	if player == null:
		return
	player.position = offset
	player.stream = _stream_for(def)
	player.bus = String(def.bus)
	player.pitch_scale = randf_range(def.pitch_jitter.x, def.pitch_jitter.y)
	player.volume_db = (def.base_volume_db + master_volume_db
			+ randf_range(def.volume_jitter_db.x, def.volume_jitter_db.y))
	player.play()
	if def.duck_music_db > 0.0:
		duck_music(def.duck_music_db)


## Starts a looping cue, or does nothing if it is already running.
func start_loop(cue: StringName) -> void:
	var def: SoundDef = definition(cue)
	if def == null or not def.loops or _loops.has(cue) or _feeders.has(cue):
		return
	if def.is_sourced():
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.stream = _stream_for(def)
		player.bus = String(def.bus)
		player.volume_db = def.base_volume_db + master_volume_db
		add_child(player)
		player.play()
		_loops[cue] = player
		return
	# No sourced file: synthesise it live rather than looping a buffer.
	var feeder: ProceduralLoopFeeder = ProceduralLoopFeeder.new()
	add_child(feeder)
	feeder.begin(def)
	_feeders[cue] = feeder


func stop_loop(cue: StringName) -> void:
	if _loops.has(cue):
		var player: AudioStreamPlayer = _loops[cue]
		player.stop()
		player.queue_free()
		_loops.erase(cue)
	if _feeders.has(cue):
		var feeder: ProceduralLoopFeeder = _feeders[cue]
		feeder.end()
		feeder.queue_free()
		_feeders.erase(cue)


func is_looping(cue: StringName) -> bool:
	return _loops.has(cue) or _feeders.has(cue)


## Drops the music bus by [param amount_db] and lets it back up. Called
## automatically for cues that declare a duck; exposed for anything else that
## needs the floor cleared, such as a cutscene.
func duck_music(amount_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Music")
	if bus_index < 0:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_music_db, AudioServer.get_bus_volume_db(bus_index),
			_music_base_db - amount_db, DUCK_ATTACK)
	_duck_tween.tween_method(_set_music_db, _music_base_db - amount_db,
			_music_base_db, DUCK_RELEASE).set_delay(0.08)


func _set_music_db(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Music")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, value)


## The stream for a cue: the sourced file if it exists, otherwise a synthesised
## placeholder. Cached either way, so the check happens once per cue per run.
func _stream_for(def: SoundDef) -> AudioStream:
	if _streams.has(def.id):
		return _streams[def.id]
	var stream: AudioStream = null
	if def.is_sourced():
		stream = load(def.absolute_path()) as AudioStream
	if stream == null:
		stream = ProceduralCues.make_wav(def)
	_streams[def.id] = stream
	return stream


## A free flat voice, stealing the oldest voice of the same cue once the cue is
## at its own cap, and refusing outright when nothing is stealable.
func _claim_flat(def: SoundDef) -> AudioStreamPlayer:
	var mine: Array = _sounding.get(def.id, [])
	mine = mine.filter(func(p: Node) -> bool: return is_instance_valid(p) and (p as AudioStreamPlayer).playing)
	if mine.size() >= def.max_voices:
		var oldest: AudioStreamPlayer = mine[0]
		oldest.stop()
		mine.remove_at(0)
	for player: AudioStreamPlayer in _flat:
		if not player.playing:
			mine.append(player)
			_sounding[def.id] = mine
			return player
	# Pool exhausted: take a voice from a lower-priority cue if one is sounding.
	var victim: AudioStreamPlayer = _lowest_priority_flat(def.priority)
	if victim != null:
		victim.stop()
		mine.append(victim)
		_sounding[def.id] = mine
		return victim
	return null


func _lowest_priority_flat(priority: int) -> AudioStreamPlayer:
	var worst: int = priority
	var victim: AudioStreamPlayer = null
	for cue: StringName in _sounding:
		var def: SoundDef = definition(cue)
		if def == null or def.priority >= worst:
			continue
		for entry: Variant in _sounding[cue]:
			var player: AudioStreamPlayer = entry as AudioStreamPlayer
			if player != null and is_instance_valid(player) and player.playing:
				worst = def.priority
				victim = player
	return victim


func _claim_positional(def: SoundDef) -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in _positional:
		if not player.playing:
			return player
	# 3D voices are few; the newest sound wins rather than being dropped.
	return _positional[0]


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	# A resumed run announces what it owns and where it stands as the events
	# a fresh run would have fired. They are facts, not moments: a dozen
	# purchase chimes at once is not what walking back to the machine sounds
	# like. The room hum still starts, because the room is still there.
	if bool(payload.get("resumed", false)) and kind != EffectBus.Event.RUN_STARTED:
		return
	match kind:
		# SPIN_STARTED, SYMBOL_LANDED and PAYOUT_CALCULATED are deliberately not
		# handled here. The simulation resolves an entire spin inside one frame,
		# so reacting to those events fired the handle pull, all three reel stops
		# and the payout chime simultaneously — at the instant of the tap, before
		# a single reel had turned. Everything about a spin then happened in
		# silence. [SlotView3D] owns the spin's clock and therefore its audio.
		EffectBus.Event.ARTIFACT_TRIGGERED:
			play(_tier_cue(StringName(payload.get("artifact", &""))))
		EffectBus.Event.ARTIFACT_ACQUIRED:
			play_at(&"artifact_acquire")
			play(&"ui_purchase_confirm")
		EffectBus.Event.SHOP_OPENED:
			play(&"ui_panel_open")
		EffectBus.Event.SHOP_REROLLED:
			play(&"ui_chip_stack")
		EffectBus.Event.ARTIFACT_SOLD:
			play(&"ui_chip_place")
		EffectBus.Event.SLATE_SIGNED:
			play(&"contract_signed")
			play(&"debt_sting")
		EffectBus.Event.CHIPS_CHANGED:
			# Scrip arriving lands as chips do; scrip spent is the purchase's
			# own confirmation and needs nothing here.
			if int(payload.get("delta", 0)) > 0 \
					and StringName(payload.get("reason", &"")) != &"symbols":
				play(&"ui_chip_stack")
		EffectBus.Event.FLOOR_SETTLED_EARLY:
			play_at(&"receipt_tear")
		EffectBus.Event.BOSS_ACTED:
			play(&"alarm_pulse")
			play(&"debt_sting")
		EffectBus.Event.CONTRACTS_OFFERED:
			play(&"ui_panel_open")
		EffectBus.Event.CONTRACT_SIGNED:
			play(&"contract_signed")
		EffectBus.Event.SYSTEM_GRANTED:
			play(&"system_granted")
		EffectBus.Event.NUDGES_AWARDED:
			play(&"nudge_offered")
		EffectBus.Event.GAMBLE_OFFERED:
			play(&"gamble_offered")
		EffectBus.Event.GAMBLE_RESOLVED:
			play(&"gamble_won" if bool(payload.get("won", false)) else &"gamble_lost")
		EffectBus.Event.VAULT_CHANGED:
			# The dividend is not a decision, so it does not get the door.
			var moved: int = int(payload.get("delta", 0))
			if moved > 0:
				play_at(&"vault_deposit")
			elif moved < 0:
				play_at(&"vault_break")
		EffectBus.Event.HEAT_CHANGED:
			if not bool(payload.get("changed", false)):
				return
			play(&"heat_measure" if int(payload.get("measure", 0)) > 0
					else &"heat_rising")
		EffectBus.Event.ANTE_SETTLED:
			if bool(payload.get("paid", false)):
				play(&"ante_settled")
				play_at(&"cash_thud")
			else:
				play(&"fail_sting_ante")
				play(&"alarm_pulse")
		EffectBus.Event.FLOOR_CLEARED:
			play(&"floor_clear_fanfare")
			play_at(&"receipt_tear")
			if int(payload.get("serviced", 0)) > 0:
				play(&"debt_vig_deduct")
				play(&"debt_sting")
		EffectBus.Event.RUN_STARTED:
			_room_alive = true
			start_loop(&"amb_room_hum_loop")
			start_loop(&"machine_hum_loop")
			start_loop(&"crt_hum_loop")
			start_loop(&"nixie_hum_loop")
			start_loop(&"sign_buzz_loop")
			start_loop(&"coil_buzz_loop")
			start_loop(&"amb_vault_drone_loop")
			start_loop(&"amb_wind_loop")
		EffectBus.Event.RUN_ENDED:
			var reason: String = String(payload.get("end_reason", ""))
			if String(payload.get("phase", "")) == "WON":
				play(&"run_win_fanfare")
			elif reason == "debt_unpaid":
				play(&"fail_sting_debt")
			else:
				play(&"fail_sting_ante")
		_:
			pass


## Maps an artifact to its impact tier cue. Tier follows how deep the artifact
## unlocks, so a floor 7 payoff never sounds like a floor 1 trinket.
func _tier_cue(artifact_id: StringName) -> StringName:
	var artifact: ArtifactDef = ContentDB.shared().artifact_by_id(artifact_id)
	var tier: int = artifact.tier() if artifact != null else 1
	return StringName("artifact_t%d_trigger" % tier)
