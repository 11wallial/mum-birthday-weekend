## Scene root: owns one simulation and lets the player drive it.
##
## The room is a thin shell. It builds a [SimEngine], hands the bus to the
## viewers, and translates input into [method SimEngine.step] calls — every rule
## it appears to enforce actually lives in the simulation.
class_name CasinoRoom
extends Node3D

## Seed for the run. Zero picks a fresh random seed; any other value replays
## exactly, which is how a reported run gets reproduced from a bug report.
@export var run_seed: int = 0
@export var slot_view_path: NodePath = ^"SlotMachine3D"
@export var camera_path: NodePath = ^"CameraRig"
@export var hud_path: NodePath = ^"HUD"

var engine: SimEngine
var state: RunState

var _slot_view: SlotView3D
var _camera: CameraController
var _hud: Node


func _ready() -> void:
	_slot_view = get_node_or_null(slot_view_path) as SlotView3D
	_camera = get_node_or_null(camera_path) as CameraController
	_hud = get_node_or_null(hud_path)
	new_run(run_seed)


## Starts a run. Pass 0 for a random seed.
func new_run(chosen_seed: int) -> void:
	var actual_seed: int = chosen_seed if chosen_seed != 0 else randi()
	engine = SimEngine.new()
	var bus: EffectBus = engine.get_bus()
	bus.event_emitted.connect(_on_event)
	if _slot_view != null:
		_slot_view.bind(bus)
	if _hud != null and _hud.has_method("bind"):
		_hud.call("bind", bus)
	state = engine.start_run(actual_seed)
	print("Break the Bank — run seed %d" % actual_seed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		_advance()
	elif event.is_action_pressed(&"ui_focus_next") and _camera != null:
		_camera.toggle_view()
	elif event.is_action_pressed(&"ui_cancel"):
		new_run(0)


func _advance() -> void:
	if state == null or state.is_over():
		return
	engine.step(state)
	if _camera != null:
		_camera.set_view(CameraController.View.ROOM if state.phase == RunState.Phase.SHOPPING
				else CameraController.View.MACHINE)


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	if kind == EffectBus.Event.PAYOUT_CALCULATED and _camera != null:
		# Shake scales with how far above a routine spin this payout landed.
		_camera.shake(clampf(float(payload.get("payout", 0)) / 60.0, 0.0, 1.0))
	elif kind == EffectBus.Event.RUN_ENDED:
		print("Run ended: %s" % JSON.stringify(payload))
