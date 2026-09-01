## The 3D face of one slot machine.
##
## Strictly a listener: it reads [EffectBus] events and [RunState], and never
## calls back into the simulation. Deleting this node leaves a fully playable
## headless game, which is what keeps the balance lab honest.
class_name SlotView3D
extends Node3D

## The simulation resolves a spin instantly: SPIN_STARTED and PAYOUT_CALCULATED
## arrive in the same frame. The pacing of a spin is therefore entirely the
## view's business, which is why these live here and not in BalanceConfig.
const SPIN_DURATION: float = 0.45
const REEL_STAGGER: float = 0.14
const SETTLE_DURATION: float = 0.2

@export var module_anchor_path: NodePath = ^"ModuleAnchor"
@export var payout_particles_path: NodePath = ^"PayoutParticles"
@export var machine_light_path: NodePath = ^"MachineLight"

var _reels: Array[Node3D] = []
var _module_anchor: Node3D
## Places on the frame where bought hardware bolts on, in fill order.
var _mounts: Array[Node3D] = []
## Every "Drive" node across the fitted modules, turned while the reels spin.
var _drives: Array[Node3D] = []
var _lever: Node3D
var _odds: Label3D
var _readout: Label3D
var _particles: CPUParticles3D
var _light: OmniLight3D
var _audio: AudioDirector
var _bus: EffectBus
var _pending: Array[Dictionary] = []
## How much a symbol has to be worth before it lights up at all, and the value
## at which its backlight is at full strength. Below the floor a symbol is just
## printed on the strip; a machine where everything glows says nothing about
## what landed.
const GLOW_FLOOR: float = 4.0
const GLOW_CEILING: float = 14.0
## Extra backlight per artifact the run has bought, as a fraction. A stacked
## machine is visibly hotter than a fresh one — the glow is the run's progress
## made physical, which is the same job the cash stacks and floor markers do.
const GLOW_PER_UPGRADE: float = 0.16
## Brightness of a top-value symbol on a fresh machine. Above the environment's
## 1.1 bloom threshold, so the best symbols flare rather than just tint.
const GLOW_GAIN: float = 2.3
const GLOW_MAX: float = 3.4

## How a spin's payout is judged, as a share of what one spin has to be worth
## to clear the floor: the ante divided by the spins allowed. Judging against a
## fixed number made a 60-credit win read as huge on floor 7 and as nothing on
## floor 1; judged against par, "good" means the same thing all the way down.
enum Result {
	## Paid less than a quarter of par. The reels ate the spin.
	DEAD,
	## Paid something, but you are still behind where you need to be.
	THIN,
	## Paid its own way and then some.
	GOOD,
	## Three times par or better.
	JACKPOT,
}

const THIN_SHARE: float = 0.25
const GOOD_SHARE: float = 1.0
const JACKPOT_SHARE: float = 3.0

## True from the first frame of a spin until the last reel has settled. The room
## refuses to advance the run while this holds, so the simulation can never get
## more than one spin ahead of what the player is looking at.
var _busy: bool = false

## How the finished spin was judged. The HUD listens so its readout agrees with
## the machine rather than restating the number in its own words.
signal result_judged(result: Result, payout: int)
## Artifacts acquired this run. Drives how hard the reels are backlit.
var _upgrades: int = 0
## What one spin needs to be worth on this floor. Set from FLOOR_STARTED.
var _par: float = 1.0


func _ready() -> void:
	# The machine is generated rather than authored, so it has to exist before
	# anything below can be resolved against it.
	var parts: Dictionary = MachineFrame.new().build(self)
	_reels.assign(parts.get("reels", []))
	_lever = parts.get("lever", null) as Node3D
	_mounts.assign(parts.get("mounts", []))
	_odds = parts.get("odds", null) as Label3D
	_readout = parts.get("readout", null) as Label3D
	_module_anchor = get_node_or_null(module_anchor_path) as Node3D
	_particles = get_node_or_null(payout_particles_path) as CPUParticles3D
	_light = get_node_or_null(machine_light_path) as OmniLight3D


## Optional: lets the reels click as they stop.
func set_audio(audio: AudioDirector) -> void:
	_audio = audio


## Subscribes to a simulation. Call once, after the engine is built.
func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.SPIN_STARTED:
			_pending.clear()
			_busy = true
		EffectBus.Event.SYMBOL_LANDED:
			_pending.append(payload)
		EffectBus.Event.PAYOUT_CALCULATED:
			_play_spin(int(payload.get("payout", 0)), float(payload.get("multiplier", 1.0)))
		EffectBus.Event.FLOOR_STARTED:
			var spins: int = maxi(1, int(payload.get("spins", 1)))
			_par = maxf(1.0, float(payload.get("ante", 0)) / float(spins))
		EffectBus.Event.ARTIFACT_ACQUIRED:
			_upgrades += 1
			_attach_module(StringName(payload.get("artifact", &"")))
		EffectBus.Event.RUN_STARTED:
			_upgrades = 0
			_clear_modules()
		_:
			pass


## True while reels are still turning. The run must not advance until this
## clears, or the readout describes a spin the reels have not shown yet.
func is_busy() -> bool:
	return _busy


## Spins every reel, then stops them left to right.
func _play_spin(payout: int, multiplier: float) -> void:
	_busy = true
	_throw_lever()
	_turn_drives()
	if _audio != null:
		_audio.play_at(&"handle_pull")
		_audio.play_at(&"reel_start")
		_audio.start_loop(&"reel_spin_loop")
	var last: int = _reels.size() - 1
	for i: int in _reels.size():
		var reel: Node3D = _reels[i]
		var spin_time: float = SPIN_DURATION + REEL_STAGGER * float(i)
		var tween: Tween = create_tween()
		tween.tween_property(reel, "rotation:x", reel.rotation.x + TAU * 4.0, spin_time) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_settle_reel.bind(i))
		tween.tween_property(reel, "rotation:x", 0.0, SETTLE_DURATION) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == last:
			tween.tween_callback(_finish_spin.bind(payout, multiplier))


## Reveals the landed symbol as its reel comes to rest.
func _settle_reel(index: int) -> void:
	if index < _pending.size():
		_show_symbol(_reels[index], _pending[index])
	# Land on a whole turn so the drum never settles crooked after many spins.
	_reels[index].rotation.x = fmod(_reels[index].rotation.x, TAU)
	if _audio == null:
		return
	# The last reel gets the heavier stop. Three identical clicks is a machine
	# ticking over; a lighter, lighter, then a solid one is a machine landing.
	var is_last: bool = index >= _reels.size() - 1
	if is_last:
		_audio.stop_loop(&"reel_spin_loop")
		_audio.play_at(&"reel_stop_final")
	else:
		const TICKS: Array = [&"reel_stop_tick_a", &"reel_stop_tick_b", &"reel_stop_tick_c"]
		_audio.play_at(TICKS[index % TICKS.size()])
	if index < _pending.size() \
			and StringName(_pending[index].get("symbol", &"")) == &"skull":
		_audio.play_at(&"curse_land")


## Puts one landed symbol on one reel, preferring drawn art and falling back to
## the glyph token. Exactly one of the two nodes is ever visible.
func _show_symbol(reel: Node3D, landed: Dictionary) -> void:
	var art: Sprite3D = reel.get_node_or_null(^"Art") as Sprite3D
	var label: Label3D = reel.get_node_or_null(^"Symbol") as Label3D
	var tint: Color = landed.get("color", Color.WHITE)
	var texture: ImageTexture = SymbolArt.texture_for(
			StringName(landed.get("symbol", &"")), tint)
	if art != null:
		art.texture = texture
		art.visible = texture != null
	if label != null:
		label.text = String(landed.get("glyph", "?"))
		label.modulate = tint
		label.visible = texture == null
	_set_glow(reel, tint, float(landed.get("value", 0)))


## Lights the strip behind a symbol in proportion to what it is worth, scaled by
## how many upgrades the run is carrying.
func _set_glow(reel: Node3D, tint: Color, value: float) -> void:
	var glow: MeshInstance3D = reel.get_node_or_null(^"Glow") as MeshInstance3D
	if glow == null:
		return
	var material: StandardMaterial3D = glow.material_override as StandardMaterial3D
	if material == null:
		return
	var importance: float = clampf(
			inverse_lerp(GLOW_FLOOR, GLOW_CEILING, value), 0.0, 1.0)
	if importance <= 0.0:
		glow.visible = false
		return
	# Scaled past 1 deliberately: the environment blooms above 1.1, so a top
	# symbol on a stacked machine does not merely tint the strip, it flares.
	var energy: float = minf(
			importance * GLOW_GAIN * (1.0 + float(_upgrades) * GLOW_PER_UPGRADE),
			GLOW_MAX)
	glow.visible = true
	# Additive, so the alpha carries the falloff and the colour carries the
	# strength; pushing the colour past 1 is what makes a jackpot bloom.
	material.albedo_color = Color(tint.r * energy, tint.g * energy, tint.b * energy, 1.0)
	# A short flare as it lands, settling back to its resting brightness.
	glow.scale = Vector3.ONE * 1.35
	var tween: Tween = create_tween()
	tween.tween_property(glow, "scale", Vector3.ONE, 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish_spin(payout: int, multiplier: float) -> void:
	_busy = false
	_set_odds(multiplier)
	_celebrate(payout, multiplier)


## Snaps the arm down and lets it drift back up. The throw is deliberately
## faster than the return: a lever that falls slowly reads as weightless.
func _throw_lever() -> void:
	if _lever == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_lever, "rotation:x", 0.85, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_lever, "rotation:x", -0.5, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Turns every fitted module's moving parts for the length of a spin. A machine
## whose bought hardware sits dead while the reels turn reads as decoration
## bolted to a machine, rather than as part of one.
func _turn_drives() -> void:
	for i: int in _drives.size():
		var drive: Node3D = _drives[i]
		if not is_instance_valid(drive):
			continue
		# Alternating direction, and never quite the same speed: meshing gears
		# turn against each other, and a rack of identical spinners reads as a
		# single texture scrolling.
		var turns: float = TAU * (1.5 + float(i % 3) * 0.4)
		var direction: float = -1.0 if i % 2 == 1 else 1.0
		var tween: Tween = create_tween()
		tween.tween_property(drive, "rotation:z",
				drive.rotation.z + turns * direction, SPIN_DURATION + 0.35) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Writes the spin's multiplier onto the readout above the reels. The value is
## already on the HUD; putting it on the machine is what makes the machine the
## thing being read rather than a backdrop to a text overlay.
func _set_odds(multiplier: float) -> void:
	if _odds == null:
		return
	_odds.text = "%.0fx" % maxf(multiplier, 1.0) if multiplier < 100.0 \
			else "%dx" % int(multiplier)
	var flash: Tween = create_tween()
	flash.tween_property(_odds, "modulate", Color(1.0, 0.95, 0.7), 0.08)
	flash.tween_property(_odds, "modulate", Color(0.72, 0.68, 0.58), 0.45)


## Puts the run's debt on the machine's own monitor, in phosphor green.
func set_readout(debt: int, floor_name: String) -> void:
	if _readout != null:
		_readout.text = "%s\nDEBT %d" % [floor_name.to_upper(), debt]


## How this spin went, relative to what the floor needs per spin.
func _judge(payout: int) -> Result:
	var share: float = float(payout) / _par
	if share >= JACKPOT_SHARE:
		return Result.JACKPOT
	if share >= GOOD_SHARE:
		return Result.GOOD
	if share >= THIN_SHARE:
		return Result.THIN
	return Result.DEAD


## Everything that tells the player how the spin went, keyed to one judgement so
## the coins, the light, the shake and the sound can never disagree.
##
## Coins used to fall on any payout above zero, which is nearly every spin, and
## the flare scaled off the multiplier rather than the result. So a spin that
## lost you the floor looked and sounded like a spin that won it.
func _celebrate(payout: int, multiplier: float) -> void:
	var result: Result = _judge(payout)
	if _particles != null:
		match result:
			Result.JACKPOT:
				_particles.amount = 220
				_particles.restart()
			Result.GOOD:
				_particles.amount = 60
				_particles.restart()
			_:
				# A thin or dead spin throws nothing. Silence and stillness are
				# the feedback: you needed par and you did not get it.
				pass
	if _light != null:
		var flare: float = [0.35, 0.9, 2.6, 6.0][int(result)]
		var tween: Tween = create_tween()
		tween.tween_property(_light, "light_energy", flare, 0.08)
		tween.tween_property(_light, "light_energy", 1.0, 0.55)
	if _audio != null:
		match result:
			Result.JACKPOT:
				_audio.play(&"jackpot_bells")
				_audio.play_at(&"coin_cascade_large")
			Result.GOOD:
				_audio.play(&"payout_chime_big")
				_audio.play_at(&"coin_cascade_small")
			Result.THIN:
				_audio.play(&"payout_chime_small")
				_audio.play_at(&"coin_drop_single")
			_:
				pass
	result_judged.emit(result, payout)


## Fits hardware without buying it. For visual QA only: a real run reaches a
## well-stocked machine rarely and slowly, which is exactly the state that most
## needs looking at.
func debug_fit(artifact_id: StringName) -> void:
	_upgrades += 1
	_attach_module(artifact_id)


## Bolts the artifact's hardware onto the next free place on the frame.
##
## Every artifact gets hardware, built by [ModuleFactory] from its effect and
## its tag. An artifact may still name a [member ArtifactDef.module_scene_path]
## to override that with an authored scene, which is how a one-off centrepiece
## would be done — but nothing has to, and the default is never "nothing", which
## is what left twenty-four of twenty-six purchases invisible.
func _attach_module(artifact_id: StringName) -> void:
	var artifact: ArtifactDef = ContentDB.shared().artifact_by_id(artifact_id)
	if artifact == null:
		return
	var module: Node3D = _module_for(artifact)
	if module == null:
		return
	var mount: Node3D = _next_mount()
	if mount == null:
		# Out of places to put it. The frame is full at a dozen, which is well
		# past what a run buys; dropping the model is better than stacking two
		# in the same hole.
		module.queue_free()
		return
	mount.add_child(module)
	_collect_drives(module)
	# Arrives oversized and settles, so a purchase is seen being fitted rather
	# than simply existing on the next frame.
	module.scale = Vector3.ONE * 1.7
	var tween: Tween = create_tween()
	tween.tween_property(module, "scale", Vector3.ONE, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Strips the frame back to bare metal for a new run.
func _clear_modules() -> void:
	_drives.clear()
	for mount: Node3D in _mounts:
		for child: Node in mount.get_children():
			# Removed as well as freed: queue_free defers, and a new run that
			# starts in the same frame would find every mount still occupied.
			mount.remove_child(child)
			child.queue_free()


func _module_for(artifact: ArtifactDef) -> Node3D:
	if not artifact.module_scene_path.is_empty() \
			and ResourceLoader.exists(artifact.module_scene_path):
		var packed: PackedScene = load(artifact.module_scene_path) as PackedScene
		if packed != null:
			return packed.instantiate() as Node3D
	return ModuleFactory.build(artifact)


func _next_mount() -> Node3D:
	for mount: Node3D in _mounts:
		if mount.get_child_count() == 0:
			return mount
	return null


## Finds the turning parts of a fitted module, by the name its builder gives
## them. A module with no moving parts simply contributes none.
func _collect_drives(module: Node3D) -> void:
	var pending: Array[Node] = [module]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Node3D and String(node.name).begins_with("Drive"):
			_drives.append(node as Node3D)
		pending.append_array(node.get_children())
