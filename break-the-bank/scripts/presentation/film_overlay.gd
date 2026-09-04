## The grade over the world, and the render's degradation with the surety.
##
## The frame the premise chose: the game is played from inside a simulation,
## the player's life is the surety on the account, and the simulation is
## what the stake is burning. A framing device that only appears in an
## opening cinematic is dead weight; this one has a job every spin. The
## shader tears, fringes and stutters by [code]strain[/code], and the room
## hands the surety in here as it settles it onto the machine's own column,
## so the two can never disagree.
class_name FilmOverlay
extends CanvasLayer

## How long the strain takes to move: slow, so a bad spin is felt as the
## picture worsening rather than switching.
const EASE: float = 0.8

var _material: ShaderMaterial
var _strain: float = 0.0


func _ready() -> void:
	var rect: ColorRect = get_node_or_null(^"Rect") as ColorRect
	if rect != null:
		_material = rect.material as ShaderMaterial


## Sets how far the render has degraded, in 0..1.
func set_strain(value: float) -> void:
	var target: float = clampf(value, 0.0, 1.0)
	if _material == null:
		_strain = target
		return
	var tween: Tween = create_tween()
	tween.tween_method(func(level: float) -> void:
		_strain = level
		_material.set_shader_parameter(&"strain", level), _strain, target, EASE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func strain() -> float:
	return _strain
