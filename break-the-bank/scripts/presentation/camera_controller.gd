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

## Aspect at which the framing was authored: the 1152x648 design viewport. A
## screen wider than this keeps its vertical field; anything narrower — every
## phone held upright — switches to a fixed horizontal field so the machine
## still fits across the frame instead of running off both edges.
const DESIGN_ASPECT: float = 16.0 / 9.0

@export var camera_path: NodePath = ^"Camera3D"

## Each view is a position and a point to look at, rather than an authored
## transform. Writing a [Transform3D] by hand means writing a basis by hand, and
## a basis written by hand is a basis silently mis-signed — that mistake has
## already aimed this camera at the ceiling once. A look-at target cannot be
## wrong in that way, and it is also the thing a person actually wants to adjust.
@export var machine_eye: Vector3 = Vector3(0.78, 1.66, 4.05)
@export var machine_target: Vector3 = Vector3(-0.1, 1.3, 0.05)
@export var machine_fov: float = 55.0
@export var room_eye: Vector3 = Vector3(2.15, 2.2, 5.4)
@export var room_target: Vector3 = Vector3(-0.25, 1.05, 0.15)
@export var room_fov: float = 62.0
## How far the camera rises and how much further up it looks on a tall screen.
## With a fixed horizontal field, every pixel of extra height is extra vertical
## field, and on a phone held upright all of it lands on empty ceiling and blown
## floor. Tilting up spends it on the lamp and the sign instead.
@export var portrait_eye_rise: float = 0.16
@export var portrait_target_rise: float = 0.34
## How far the field narrows on a tall screen, in degrees.
##
## With a fixed horizontal field, the vertical field is the horizontal one times
## the aspect — so a 9:16 phone sees nearly twice the height a 16:9 screen does,
## and all of it is ceiling and floor. Narrowing the field pulls that back and
## fills the frame with the machine, at the cost of cropping the plinth's ends.
## That crop is the right trade: the reference framing is a crop too.
@export var portrait_fov_narrowing: float = 23.0
## How far the camera backs off on a tall screen, to buy some of that crop back.
@export var portrait_dolly_out: float = 0.4
## Peak positional offset of a payout shake, in metres.
@export var shake_strength: float = 0.06

var current_view: View = View.MACHINE

var _camera: Camera3D
var _shake: float = 0.0
var _rest: Transform3D = Transform3D.IDENTITY
## Drift is what stops a static shot reading as a screenshot: the camera never
## quite settles, so the room feels observed rather than diagrammed.
var _drift: float = 0.0
## 0 on a 16:9 screen or wider, 1 on a tall phone, and interpolated between.
var _portrait: float = 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)
	set_view(current_view, true)


## Chooses which axis the field of view is measured on, from the window's shape.
## A rotated phone and a resized desktop window both land here.
func _fit_to_screen() -> void:
	if _camera == null:
		return
	var size: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	if size.y <= 0.0:
		return
	var aspect: float = size.x / size.y
	_camera.keep_aspect = (Camera3D.KEEP_HEIGHT if aspect >= DESIGN_ASPECT
			else Camera3D.KEEP_WIDTH)
	# 9:16 is the tall end of the scale — a phone held upright. Anything taller
	# than that is treated the same rather than tilting further.
	_portrait = clampf(inverse_lerp(DESIGN_ASPECT, 9.0 / 16.0, aspect), 0.0, 1.0)
	if is_inside_tree():
		set_view(current_view, true)


func _process(delta: float) -> void:
	if _camera == null:
		return
	_drift += delta
	var offset: Vector3 = Vector3(
			sin(_drift * 0.31) * 0.012,
			sin(_drift * 0.23 + 1.7) * 0.009,
			sin(_drift * 0.17 + 0.4) * 0.008)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		offset += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) \
				* shake_strength * _shake
	_camera.global_transform = _rest.translated_local(offset)


func set_view(view: View, immediate: bool = false) -> void:
	current_view = view
	if _camera == null:
		return
	var eye: Vector3 = machine_eye if view == View.MACHINE else room_eye
	var target: Vector3 = machine_target if view == View.MACHINE else room_target
	var fov: float = machine_fov if view == View.MACHINE else room_fov
	eye += Vector3.UP * portrait_eye_rise * _portrait
	target += Vector3.UP * portrait_target_rise * _portrait
	eye += (eye - target).normalized() * portrait_dolly_out * _portrait
	fov -= portrait_fov_narrowing * _portrait
	_rest = Transform3D(Basis.IDENTITY, eye).looking_at(target, Vector3.UP)
	if immediate:
		_camera.global_transform = _rest
		_camera.fov = fov
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "global_transform", _rest, TRANSITION_TIME)
	tween.tween_property(_camera, "fov", fov, TRANSITION_TIME)


func toggle_view() -> void:
	set_view(View.ROOM if current_view == View.MACHINE else View.MACHINE)


## Kicks the camera. [param intensity] is normalised 0..1 by the caller.
func shake(intensity: float) -> void:
	_shake = maxf(_shake, clampf(intensity, 0.0, 1.0))
