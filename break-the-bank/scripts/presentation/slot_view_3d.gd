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

## True from the first frame of a spin until the last reel has settled. The room
## refuses to advance the run while this holds, so the simulation can never get
## more than one spin ahead of what the player is looking at.
var _busy: bool = false
## Artifacts acquired this run. Drives how hard the reels are backlit.
var _upgrades: int = 0


func _ready() -> void:
	# The machine is generated rather than authored, so it has to exist before
	# anything below can be resolved against it.
	var parts: Dictionary = MachineFrame.new().build(self)
	_reels.assign(parts.get("reels", []))
	_lever = parts.get("lever", null) as Node3D
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
		EffectBus.Event.ARTIFACT_ACQUIRED:
			_upgrades += 1
			_attach_module(StringName(payload.get("artifact", &"")))
		EffectBus.Event.RUN_STARTED:
			_upgrades = 0
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
	if _audio != null:
		_audio.play("reel_stop", randf_range(0.94, 1.06))


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


func _celebrate(payout: int, multiplier: float) -> void:
	if _particles != null and payout > 0:
		_particles.amount = clampi(payout * 2, 8, 240)
		_particles.restart()
	if _light != null:
		var tween: Tween = create_tween()
		tween.tween_property(_light, "light_energy", clampf(1.0 + multiplier, 1.0, 8.0), 0.1)
		tween.tween_property(_light, "light_energy", 1.0, 0.5)


## Bolts the artifact's physical module onto the machine frame, if it has one.
func _attach_module(artifact_id: StringName) -> void:
	if _module_anchor == null:
		return
	var artifact: ArtifactDef = ContentDB.shared().artifact_by_id(artifact_id)
	if artifact == null or artifact.module_scene_path.is_empty():
		return
	if not ResourceLoader.exists(artifact.module_scene_path):
		push_warning("SlotView3D: missing module scene %s" % artifact.module_scene_path)
		return
	var packed: PackedScene = load(artifact.module_scene_path) as PackedScene
	if packed == null:
		return
	var module: Node3D = packed.instantiate() as Node3D
	if module == null:
		return
	# Modules stack outward along +X so the frame visibly grows over a run.
	module.position = Vector3(0.28 * float(_module_anchor.get_child_count()), 0.0, 0.0)
	_module_anchor.add_child(module)
