## Moves the camera between the two ways the game is read.
##
## Close in, the machine is a physical object you operate. Pulled back, the run
## is an ecosystem you manage. Both views are just anchors — no gameplay state
## lives here.
class_name CameraController
extends Node3D

enum View {
	## At the machine: reels fill the frame.
	MACHINE,
	## Pulled back: the whole room and everything the run has accumulated.
	ROOM,
}

const TRANSITION_TIME: float = 0.7

@export var camera_path: NodePath = ^"Camera3D"
@export var machine_anchor_path: NodePath = ^"../MachineAnchor"
@export var room_anchor_path: NodePath = ^"../RoomAnchor"
## Peak positional offset of a payout shake, in metres.
@export var shake_strength: float = 0.06

var current_view: View = View.MACHINE

var _camera: Camera3D
var _anchors: Dictionary = {}
var _shake: float = 0.0
var _rest: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_anchors[View.MACHINE] = get_node_or_null(machine_anchor_path) as Node3D
	_anchors[View.ROOM] = get_node_or_null(room_anchor_path) as Node3D
	set_view(current_view, true)


func _process(delta: float) -> void:
	if _camera == null or _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - delta * 3.0)
	var offset: Vector3 = Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake_strength * _shake
	_camera.global_transform = _rest.translated_local(offset)


func set_view(view: View, immediate: bool = false) -> void:
	current_view = view
	var anchor: Node3D = _anchors.get(view, null) as Node3D
	if _camera == null or anchor == null:
		return
	_rest = anchor.global_transform
	if immediate:
		_camera.global_transform = _rest
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "global_transform", _rest, TRANSITION_TIME)


func toggle_view() -> void:
	set_view(View.ROOM if current_view == View.MACHINE else View.MACHINE)


## Kicks the camera. [param intensity] is normalised 0..1 by the caller.
func shake(intensity: float) -> void:
	if _camera != null:
		_rest = _camera.global_transform if _shake <= 0.0 else _rest
	_shake = maxf(_shake, clampf(intensity, 0.0, 1.0))
