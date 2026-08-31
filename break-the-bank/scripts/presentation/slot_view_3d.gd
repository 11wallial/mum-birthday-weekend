## The 3D face of one slot machine.
##
## Strictly a listener: it reads [EffectBus] events and [RunState], and never
## calls back into the simulation. Deleting this node leaves a fully playable
## headless game, which is what keeps the balance lab honest.
class_name SlotView3D
extends Node3D

const SPIN_DURATION: float = 0.55
const REEL_STAGGER: float = 0.12

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
var _bus: EffectBus
var _pending: Array[Dictionary] = []


func _ready() -> void:
	for path: NodePath in reel_roots:
		var reel: Node3D = get_node_or_null(path) as Node3D
		if reel != null:
			_reels.append(reel)
	_module_anchor = get_node_or_null(module_anchor_path) as Node3D
	_particles = get_node_or_null(payout_particles_path) as CPUParticles3D
	_light = get_node_or_null(machine_light_path) as OmniLight3D


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
			_spin_reels()
		EffectBus.Event.SYMBOL_LANDED:
			_pending.append(payload)
		EffectBus.Event.PAYOUT_CALCULATED:
			_land_reels()
			_celebrate(int(payload.get("payout", 0)), float(payload.get("multiplier", 1.0)))
		EffectBus.Event.ARTIFACT_ACQUIRED:
			_attach_module(StringName(payload.get("artifact", &"")))
		_:
			pass


func _spin_reels() -> void:
	for i: int in _reels.size():
		var tween: Tween = create_tween()
		tween.tween_property(_reels[i], "rotation:x", _reels[i].rotation.x + TAU * 3.0,
				SPIN_DURATION + REEL_STAGGER * float(i)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _land_reels() -> void:
	for i: int in mini(_reels.size(), _pending.size()):
		var label: Label3D = _reels[i].get_node_or_null("Symbol") as Label3D
		if label != null:
			label.text = String(_pending[i].get("symbol", &""))
		var tween: Tween = create_tween()
		tween.tween_property(_reels[i], "rotation:x", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
