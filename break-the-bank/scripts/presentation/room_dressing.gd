## The room fills up as the run goes on.
##
## Spec calls for the starting room to accumulate over a run rather than swap
## between floors, so everything here is additive: cash stacks grow, and each
## cleared floor leaves a marker behind.
class_name RoomDressing
extends Node3D

## Where the first plaque hangs and how far apart the row is spaced. On the back
## wall above the dado rail, well clear of the floor sign and the door.
const PLAQUE_ORIGIN: Vector3 = Vector3(-2.55, 1.72, -3.24)
const PLAQUE_SPACING: float = 0.42

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


## Mounts a plaque on the back wall for a floor that has been cleared.
##
## These used to be orange sticks on the floor beside the machine, which read as
## debris rather than as a record. A row of engraved plates going up the wall is
## the same information as a trophy shelf: how far this run got, readable from
## across the room, and it survives everything else the room accumulates.
func _add_floor_marker(floor_index: int) -> void:
	var plaque: Node3D = Node3D.new()
	plaque.name = "Plaque%d" % floor_index
	plaque.set_meta(&"kind", &"marker")
	add_child(plaque)
	plaque.position = Vector3(
			PLAQUE_ORIGIN.x + PLAQUE_SPACING * float(floor_index - 1),
			PLAQUE_ORIGIN.y, PLAQUE_ORIGIN.z)

	Prims.box(plaque, Vector3(0.3, 0.22, 0.03), Vector3.ZERO,
			Materials.painted(Color(0.098, 0.09, 0.082), 33))
	Prims.box(plaque, Vector3(0.25, 0.17, 0.02), Vector3(0.0, 0.0, 0.02),
			_marker_material)
	for sx: float in [-1.0, 1.0]:
		Prims.sphere(plaque, 0.012, Vector3(sx * 0.12, 0.083, 0.022),
				Materials.machined(Materials.STEEL, 79))

	var number: Label3D = Label3D.new()
	number.name = "Number"
	number.text = str(floor_index)
	number.font_size = 96
	number.pixel_size = 0.0014
	number.modulate = Color(0.086, 0.075, 0.055)
	number.outline_size = 0
	number.shaded = false
	number.position = Vector3(0.0, 0.0, 0.032)
	plaque.add_child(number)
	# Arrives struck, then settles, so clearing a floor is seen being recorded.
	plaque.scale = Vector3.ONE * 1.6
	var tween: Tween = create_tween()
	tween.tween_property(plaque, "scale", Vector3.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
