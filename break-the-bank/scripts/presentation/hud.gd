## Run readout: cash, debt, floor, ante and the last line played.
##
## Reads the bus and the [RunState] snapshot only. It holds no game state of its
## own, so it can be rebuilt mid-run without losing anything.
class_name RunHUD
extends CanvasLayer

@export var cash_label_path: NodePath = ^"Panel/Rows/Cash"
@export var debt_label_path: NodePath = ^"Panel/Rows/Debt"
@export var floor_label_path: NodePath = ^"Panel/Rows/Floor"
@export var line_label_path: NodePath = ^"Panel/Rows/Line"
@export var log_label_path: NodePath = ^"Panel/Rows/Log"
@export var prompt_label_path: NodePath = ^"Prompt"

const LOG_LINES: int = 6

var _cash: Label
var _debt: Label
var _floor: Label
var _line: Label
var _log: Label
var _prompt: Label
var _lines: PackedStringArray = PackedStringArray()
var _bus: EffectBus


func _ready() -> void:
	_cash = get_node_or_null(cash_label_path) as Label
	_debt = get_node_or_null(debt_label_path) as Label
	_floor = get_node_or_null(floor_label_path) as Label
	_line = get_node_or_null(line_label_path) as Label
	_log = get_node_or_null(log_label_path) as Label
	_prompt = get_node_or_null(prompt_label_path) as Label
	set_prompt("")


func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.RUN_STARTED:
			_set_text(_cash, "CASH  %d" % int(payload.get("cash", 0)))
			_set_text(_debt, "DEBT  %d" % int(payload.get("debt", 0)))
			_lines.clear()
			_push("Seed %d" % int(payload.get("seed", 0)))
		EffectBus.Event.ANTE_SETTLED:
			_set_text(_line, "ANTE %d %s" % [
				int(payload.get("ante", 0)),
				"paid" if bool(payload.get("paid", false)) else "UNPAID"])
		EffectBus.Event.CASH_CHANGED:
			_set_text(_cash, "CASH  %d" % int(payload.get("cash", 0)))
		EffectBus.Event.FLOOR_STARTED:
			_set_text(_floor, "FLOOR %d — %s   ANTE %d   SPINS %d" % [
				int(payload.get("floor", 0)), String(payload.get("name", "")),
				int(payload.get("ante", 0)), int(payload.get("spins", 0)),
			])
			_push("Entered %s" % String(payload.get("name", "")))
		EffectBus.Event.FLOOR_CLEARED:
			_set_text(_debt, "DEBT  %d" % int(payload.get("debt", 0)))
			_push("Floor %d cleared" % int(payload.get("floor", 0)))
		EffectBus.Event.PAYOUT_CALCULATED:
			_set_text(_line, "%s  ×%.2f  →  %d" % [
				String(payload.get("pattern", "")), float(payload.get("multiplier", 1.0)),
				int(payload.get("payout", 0)),
			])
		EffectBus.Event.ARTIFACT_ACQUIRED:
			_push("Acquired %s" % String(payload.get("artifact", "")))
		EffectBus.Event.RUN_ENDED:
			_push("Run ended: %s" % String(payload.get("end_reason", "")))
		_:
			pass


## Centre-screen callout for the moments that need a decision or an epitaph.
## An empty string hides it.
func set_prompt(text: String) -> void:
	if _prompt == null:
		return
	_prompt.text = text
	_prompt.visible = not text.is_empty()


func _push(text: String) -> void:
	_lines.append(text)
	while _lines.size() > LOG_LINES:
		_lines.remove_at(0)
	_set_text(_log, "\n".join(_lines))


func _set_text(label: Label, text: String) -> void:
	if label != null:
		label.text = text
