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

## One [Node3D] per reel, each holding a [Label3D] named "Symbol" and a
## [MeshInstance3D] named "Face".
@export var reel_roots: Array[NodePath] = []
@export var module_anchor_path: NodePath = ^"ModuleAnchor"
@export var payout_particles_path: NodePath = ^"PayoutParticles"
@export var machine_light_path: NodePath = ^"MachineLight"

var _reels: Array[Node3D] = []
var _module_anchor: Node3D
var _particles: CPUParticles3D
var _light: OmniLight3D
var _audio: AudioDirector
var _bus: EffectBus
var _pending: Array[Dictionary] = []
## True from the first frame of a spin until the last reel has settled. The room
## refuses to advance the run while this holds, so the simulation can never get
## more than one spin ahead of what the player is looking at.
var _busy: bool = false


func _ready() -> void:
	for path: NodePath in reel_roots:
		var reel: Node3D = get_node_or_null(path) as Node3D
		if reel != null:
			_reels.append(reel)
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
			_attach_module(StringName(payload.get("artifact", &"")))
		_:
			pass


## True while reels are still turning. The run must not advance until this
## clears, or the readout describes a spin the reels have not shown yet.
func is_busy() -> bool:
	return _busy


## Spins every reel, then stops them left to right.
func _play_spin(payout: int, multiplier: float) -> void:
	_busy = true
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
		var label: Label3D = _reels[index].get_node_or_null("Symbol") as Label3D
		if label != null:
			label.text = String(_pending[index].get("glyph", "?"))
			var tint: Color = _pending[index].get("color", Color.WHITE)
			label.modulate = tint
	# Land on a whole turn so the drum never settles crooked after many spins.
	_reels[index].rotation.x = fmod(_reels[index].rotation.x, TAU)
	if _audio != null:
		_audio.play("reel_stop", randf_range(0.94, 1.06))


func _finish_spin(payout: int, multiplier: float) -> void:
	_busy = false
	_celebrate(payout, multiplier)


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
