## On-screen controls for the actions a touch device cannot otherwise reach.
##
## Tapping the world already advances the run — Godot emulates a left click from
## a touch, and [code]bb_advance[/code] is bound to that — so the bar carries
## only the keys with no pointer equivalent: the camera toggle, a new run, and
## the setup panel. It emits intent and never touches the simulation.
##
## The bar hides itself on a device without a touchscreen, so a desktop build
## keeps a clean screen while a phone build needs no separate scene.
class_name TouchBar
extends CanvasLayer

signal camera_requested()
signal new_run_requested()
signal setup_requested()

## Forces the bar on for a screenshot or a desktop check of the touch layout.
@export var force_visible: bool = false

## Big enough to hit with a thumb on a phone: Material's 48dp floor, rounded up
## because these sit near the screen edge where accuracy is worst.
const BUTTON_SIZE: Vector2 = Vector2(112, 56)

var _row: HBoxContainer


## True when the running device takes touch input. Static so panels that must
## reword a hint can ask without holding a reference to the bar.
static func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available()


## Picks the wording that matches the device. Prompts name the key that does the
## thing, and on a phone there is no key — so the choice is made once, here,
## rather than each caller testing for a touchscreen itself.
static func hint(desktop: String, touch: String) -> String:
	return touch if is_touch_device() else desktop


func _ready() -> void:
	_row = get_node_or_null(^"Row") as HBoxContainer
	_wire(^"Row/Camera", camera_requested)
	_wire(^"Row/Setup", setup_requested)
	_wire(^"Row/NewRun", new_run_requested)
	for button: Button in _buttons():
		button.custom_minimum_size = BUTTON_SIZE
		# The bar sits over the room; a focus ring left on a button after a tap
		# would then eat the next keyboard advance on a hybrid device.
		button.focus_mode = Control.FOCUS_NONE
	visible = force_visible or is_touch_device()


func _wire(path: NodePath, out: Signal) -> void:
	var button: Button = get_node_or_null(path) as Button
	if button != null:
		button.pressed.connect(func() -> void: out.emit())


func _buttons() -> Array[Button]:
	var found: Array[Button] = []
	if _row == null:
		return found
	for child: Node in _row.get_children():
		var button: Button = child as Button
		if button != null:
			found.append(button)
	return found
