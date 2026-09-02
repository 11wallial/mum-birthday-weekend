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
	## Behind the door: the machine idling under its lamp, framed to the right
	## so the title has the left of the screen.
	DOOR,
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
## The machine view is not authored, it is computed: a box around the whole
## machine — plinth to monitor, gearbox to lever — held square-on and fitted to
## whatever shape the screen is. The old three-quarter framing cropped the
## flanks on a wide window and the crown on a phone, and every fix was a new
## magic eye position; fitting the box is the fix that stays fixed.
## Tightened by the art handover: the machine had a third of the frame, with
## a dead zone on the right and a run of empty floor doing nothing. The box
## now holds the chassis, the crown and the gearbox and lets the spool and the
## lever's tip crop; the reference titles are claustrophobic on purpose.
@export var machine_frame_center: Vector3 = Vector3(0.03, 1.2, 0.15)
@export var machine_frame_extents: Vector2 = Vector2(1.36, 1.16)
## Breathing room between the camera and the frame box, on top of the fitted
## distance — the machine's front hardware protrudes toward the lens.
@export var machine_depth_margin: float = 0.55
## A long lens. A wide field puts the floor in the shot and makes the machine a
## thing on a stage; a narrow one makes it a wall in front of you.
@export var machine_fov: float = 42.0
## Below dead centre, looking slightly up: the machine over the player rather
## than displayed to them.
@export var machine_eye_lift: float = -0.1
@export var room_fov: float = 62.0

## The room is read from a ring of anchored viewpoints, walked with the arrow
## keys: the wide establisher, the left angle onto the door and the sign, the
## right flank over the spool, and the back corner. Anchors rather than a free
## orbit, because each is a place future appliances can be composed for.
## Where the camera stands while the title is up.
const DOOR_VIEW: Dictionary = {
	"eye": Vector3(-1.9, 1.75, 4.3), "target": Vector3(1.05, 1.15, 0.1),
}

const ROOM_VIEWS: Array = [
	{"eye": Vector3(2.15, 2.2, 5.4), "target": Vector3(-0.25, 1.05, 0.15)},
	{"eye": Vector3(-3.4, 2.0, 4.6), "target": Vector3(0.9, 1.1, -0.8)},
	{"eye": Vector3(3.9, 1.8, 2.4), "target": Vector3(-0.8, 1.15, 0.2)},
	{"eye": Vector3(-3.6, 2.1, -1.6), "target": Vector3(0.6, 1.0, 3.2)},
]
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
## Where on the ring of room viewpoints the camera last stood.
var _room_index: int = 0

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
	var eye: Vector3
	var target: Vector3
	var fov: float
	if view == View.MACHINE:
		# Fit the frame box to the screen's shape. The fov's meaning follows
		# keep_aspect — vertical on a wide screen, horizontal on a tall one —
		# so both axes' required distances come from the same half-angle.
		var size: Vector2 = Vector2(get_viewport().get_visible_rect().size)
		var aspect: float = size.x / maxf(size.y, 1.0)
		fov = machine_fov
		var half_tan: float = tan(deg_to_rad(fov * 0.5))
		var tan_v: float = half_tan if aspect >= DESIGN_ASPECT else half_tan / aspect
		var tan_h: float = half_tan * aspect if aspect >= DESIGN_ASPECT else half_tan
		# A tall screen cannot hold the whole flank without drowning the
		# machine in vertical air, so the box tightens to the machine's core
		# as the screen narrows — the monitor and the spool are the crop.
		var extents: Vector2 = machine_frame_extents.lerp(
				Vector2(1.3, 1.3), _portrait)
		var margin: float = lerpf(machine_depth_margin, 0.5, _portrait)
		var distance: float = maxf(extents.y / tan_v,
				extents.x / tan_h) + margin
		target = machine_frame_center
		eye = machine_frame_center \
				+ Vector3(0.0, machine_eye_lift, distance)
	else:
		var anchor: Dictionary = DOOR_VIEW if view == View.DOOR else ROOM_VIEWS[_room_index]
		eye = anchor["eye"]
		target = anchor["target"]
		fov = room_fov if view == View.ROOM else room_fov - 6.0
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


## True while the camera stands anywhere but at the machine.
func is_pulled_back() -> bool:
	return current_view != View.MACHINE


## Steps to the next or previous anchor on the room's ring of viewpoints.
## Only meaningful pulled back; at the machine the arrows belong to the game.
func cycle_room_view(direction: int) -> void:
	if current_view != View.ROOM:
		return
	_room_index = posmod(_room_index + direction, ROOM_VIEWS.size())
	set_view(View.ROOM)


## Kicks the camera. [param intensity] is normalised 0..1 by the caller.
func shake(intensity: float) -> void:
	_shake = maxf(_shake, clampf(intensity, 0.0, 1.0))
