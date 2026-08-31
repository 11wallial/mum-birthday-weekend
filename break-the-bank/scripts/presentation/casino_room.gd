## Scene root: owns one simulation and lets a human drive it.
##
## The room is a thin shell. It builds a [SimEngine], hands the bus to the
## viewers, and turns input into simulation calls — every rule it appears to
## enforce actually lives in the simulation. In particular it buys artifacts
## through [method SimEngine.buy_offer], the same call the headless shop policy
## uses, so playing by hand and simulating a batch exercise one code path.
class_name CasinoRoom
extends Node3D

## Seed for the run. Zero picks a fresh random seed; any other value replays
## exactly, which is how a reported run gets reproduced from a bug report.
@export var run_seed: int = 0
@export var slot_view_path: NodePath = ^"SlotMachine3D"
@export var camera_path: NodePath = ^"CameraRig"
@export var hud_path: NodePath = ^"HUD"
@export var audio_path: NodePath = ^"AudioDirector"
@export var dressing_path: NodePath = ^"RoomDressing"
@export var shop_path: NodePath = ^"ShopPanel"
## Records every choice for comparison against agent telemetry.
@export var record_playtest: bool = true

var engine: SimEngine
var state: RunState

var _slot_view: SlotView3D
var _camera: CameraController
var _hud: Node
var _audio: AudioDirector
var _dressing: RoomDressing
var _shop: ShopPanel
var _recorder: PlaytestRecorder
## True once the floor's spins are gone and the ante has not yet been settled.
var _ante_pending: bool = false


func _ready() -> void:
	_slot_view = get_node_or_null(slot_view_path) as SlotView3D
	_camera = get_node_or_null(camera_path) as CameraController
	_hud = get_node_or_null(hud_path)
	_audio = get_node_or_null(audio_path) as AudioDirector
	_dressing = get_node_or_null(dressing_path) as RoomDressing
	_shop = get_node_or_null(shop_path) as ShopPanel
	if _slot_view != null and _audio != null:
		_slot_view.set_audio(_audio)
	if _shop != null:
		_shop.buy_requested.connect(_on_buy_requested)
		_shop.leave_requested.connect(_on_leave_requested)
	new_run(run_seed)


## Starts a run. Pass 0 for a random seed.
func new_run(chosen_seed: int) -> void:
	var actual_seed: int = chosen_seed if chosen_seed != 0 else randi()
	engine = SimEngine.new()
	# A human is the shop policy here, so the automatic one is cleared and the
	# shop stays open until the player leaves it.
	engine.shop_policy = Callable()
	var bus: EffectBus = engine.get_bus()
	bus.event_emitted.connect(_on_event)
	if _slot_view != null:
		_slot_view.bind(bus)
	if _hud != null and _hud.has_method("bind"):
		_hud.call("bind", bus)
	if _audio != null:
		_audio.bind(bus)
	if _dressing != null:
		_dressing.bind(bus)
	if _shop != null:
		_shop.close()
	_ante_pending = false
	if record_playtest:
		_recorder = PlaytestRecorder.new()
		add_child(_recorder)
		_recorder.begin(actual_seed)
	state = engine.start_run(actual_seed)
	print("Break the Bank — run seed %d" % actual_seed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"bb_new_run"):
		_end_recording(&"abandoned")
		new_run(0)
		return
	if event.is_action_pressed(&"bb_camera") and _camera != null:
		_camera.toggle_view()
		return
	# The shop panel consumes its own input while open.
	if _shop != null and _shop.is_open():
		return
	if event.is_action_pressed(&"bb_advance") or event.is_action_pressed(&"bb_confirm"):
		_advance()


## Steps the run from a tool or a test, bypassing input. Visual QA uses this.
func debug_advance() -> void:
	_advance()


## True while the draft is waiting on a choice. For tools and tests.
func debug_shop_open() -> bool:
	return _shop != null and _shop.is_open()


## Leaves the draft without buying. For tools and tests.
func debug_leave_shop() -> void:
	_on_leave_requested()


## Forces a camera framing by [enum CameraController.View] index.
func debug_set_view(view: int) -> void:
	if _camera != null:
		_camera.set_view(view as CameraController.View)


func _advance() -> void:
	if state == null or state.is_over():
		return
	# The guard belongs here rather than only in _unhandled_input: a tool or a
	# test calling debug_advance() must not be able to step past an open draft.
	if _shop != null and _shop.is_open():
		return
	# Never let the run outrun the reels: a second press mid-spin would show a
	# payout for symbols the player has not been shown yet.
	if _slot_view != null and _slot_view.is_busy():
		return
	if _ante_pending:
		# The confirmation beat is presentation-only. The simulation settles the
		# ante on its next step either way; this just makes the player look at
		# the number before it happens.
		_ante_pending = false
		_clear_prompt()
	elif state.phase == RunState.Phase.SPINNING and state.spins_remaining <= 0:
		_prompt_ante()
		return
	if _recorder != null and state.phase == RunState.Phase.SPINNING:
		_recorder.record_spin(state)
	engine.step(state)


func _prompt_ante() -> void:
	_ante_pending = true
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		return
	var ante: int = int(round(float(floor_def.ante)
			* (1.0 - ArtifactEngine.ante_discount_percent(state) / 100.0)))
	var short: int = ante - state.economy.cash
	var verdict: String = "you are %d short" % short if short > 0 else "you can cover it"
	_set_prompt("ANTE DUE  %d     CASH %d     %s\nSPACE to settle" % [
		ante, state.economy.cash, verdict])
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)


func _on_buy_requested(index: int) -> void:
	if state == null or not state.can_buy(index):
		return
	var artifact: ArtifactDef = state.shop_offers[index]
	var price: int = state.shop_prices[index]
	if engine.buy_offer(state, index) and _recorder != null:
		_recorder.record_purchase(state, artifact, price)
	if _shop != null:
		_shop.refresh()


func _on_leave_requested() -> void:
	if state == null or state.phase != RunState.Phase.SHOPPING:
		return
	if _recorder != null:
		_recorder.record_leave_shop(state)
	if _shop != null:
		_shop.close()
	engine.leave_shop(state)


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.PAYOUT_CALCULATED:
			if _camera != null:
				# Shake scales with how far above a routine spin this landed.
				_camera.shake(clampf(float(payload.get("payout", 0)) / 60.0, 0.0, 1.0))
		EffectBus.Event.SHOP_OPENED:
			if _shop != null:
				_shop.open(state)
			if _camera != null:
				_camera.set_view(CameraController.View.ROOM)
		EffectBus.Event.RUN_ENDED:
			_set_prompt("RUN OVER — %s\nF5 for a new run" % String(payload.get("end_reason", "")))
			_end_recording(StringName(payload.get("end_reason", &"")))
		_:
			pass


func _end_recording(reason: StringName) -> void:
	if _recorder == null:
		return
	_recorder.finish(state, reason)
	_recorder.queue_free()
	_recorder = null


func _set_prompt(text: String) -> void:
	if _hud != null and _hud.has_method("set_prompt"):
		_hud.call("set_prompt", text)


func _clear_prompt() -> void:
	_set_prompt("")
