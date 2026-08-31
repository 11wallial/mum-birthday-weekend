## The room fills up as the run goes on.
##
## Spec calls for the starting room to accumulate over a run rather than swap
## between floors, so everything here is additive: cash stacks grow, and each
## cleared floor leaves a marker behind.
class_name RoomDressing
extends Node3D

## Credits represented by one stack block.
const CREDITS_PER_BLOCK: int = 25
const MAX_BLOCKS: int = 60
const BLOCK_SIZE: Vector3 = Vector3(0.16, 0.035, 0.24)

## On the floor to the right of the plinth, clear of the machine's own spool.
@export var stack_origin: Vector3 = Vector3(1.95, 0.0, 1.45)
@export var stack_spacing: float = 0.24

var _blocks: int = 0
var _bus: EffectBus
var _cash_mesh: BoxMesh
var _cash_material: StandardMaterial3D
var _marker_material: StandardMaterial3D


func _ready() -> void:
	_cash_mesh = BoxMesh.new()
	_cash_mesh.size = BLOCK_SIZE
	# Banded paper rather than flat green: the stacks sit on the same floor as
	# the machine, so they have to take the same grade to look like they belong.
	_cash_material = Materials.enamel(Color(0.451, 0.475, 0.353), 73)
	_marker_material = Materials.glowing(Materials.SIGN, 1.2)


func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)
	clear()


## Removes every accumulated prop. Called when a new run starts.
func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	_blocks = 0


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.CASH_CHANGED:
			_sync_stacks(int(payload.get("cash", 0)))
		EffectBus.Event.FLOOR_CLEARED:
			_add_floor_marker(int(payload.get("floor", 0)))
		EffectBus.Event.RUN_STARTED:
			clear()
		_:
			pass


## Grows or shrinks the stacks to match banked cash. Growth is animated; a spend
## just removes blocks, because watching your money leave in slow motion is not
## the feeling this game is after.
func _sync_stacks(cash: int) -> void:
	var target: int = clampi(cash / CREDITS_PER_BLOCK, 0, MAX_BLOCKS)
	while _blocks > target:
		_blocks -= 1
		var last: Node = get_child(get_child_count() - 1)
		if last is MeshInstance3D and last.get_meta(&"kind", &"") == &"cash":
			last.queue_free()
		else:
			break
	while _blocks < target:
		_spawn_block(_blocks)
		_blocks += 1


func _spawn_block(index: int) -> void:
	var block: MeshInstance3D = MeshInstance3D.new()
	block.mesh = _cash_mesh
	block.material_override = _cash_material
	block.set_meta(&"kind", &"cash")
	# Stacks of eight, then start a new column beside the machine.
	var column: int = index / 8
	var height: int = index % 8
	var target: Vector3 = stack_origin + Vector3(
		float(column) * stack_spacing, BLOCK_SIZE.y * (float(height) + 0.5), 0.0)
	add_child(block)
	block.position = target + Vector3(0.0, 1.2, 0.0)
	block.rotation.y = randf_range(-0.08, 0.08)
	var tween: Tween = create_tween()
	tween.tween_property(block, "position", target, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _add_floor_marker(floor_index: int) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.07, 0.5, 0.07)
	marker.mesh = mesh
	marker.material_override = _marker_material
	marker.set_meta(&"kind", &"marker")
	add_child(marker)
	marker.position = Vector3(-1.75 - 0.17 * float(floor_index - 1), 0.25, 1.3)
