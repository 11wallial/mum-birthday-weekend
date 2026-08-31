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
@export var setup_path: NodePath = ^"RunSetup"
@export var touch_bar_path: NodePath = ^"TouchBar"
@export var room_set_path: NodePath = ^"RoomSet"
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
var _setup: RunSetupPanel
var _touch: TouchBar
## The wall sign naming the current floor. Diegetic: the player reads where they
## are off the room, not off an overlay.
var _floor_sign: Label3D
var _recorder: PlaytestRecorder
var _profile: PlayerProfile
var _catalogue: MetaCatalogue
var _board: Leaderboard
## Daily-challenge key for the current run, empty for an ordinary run.
var _daily_key: String = ""
## Seed of the run in progress, so the setup panel can offer it back.
var _current_seed: int = 0
## True once the floor's spins are gone and the ante has not yet been settled.
var _ante_pending: bool = false


func _ready() -> void:
	_slot_view = get_node_or_null(slot_view_path) as SlotView3D
	_camera = get_node_or_null(camera_path) as CameraController
	_hud = get_node_or_null(hud_path)
	_audio = get_node_or_null(audio_path) as AudioDirector
	_dressing = get_node_or_null(dressing_path) as RoomDressing
	_shop = get_node_or_null(shop_path) as ShopPanel
	_setup = get_node_or_null(setup_path) as RunSetupPanel
	_touch = get_node_or_null(touch_bar_path) as TouchBar
	var room_root: Node3D = get_node_or_null(room_set_path) as Node3D
	if room_root != null:
		_floor_sign = RoomSet.new().build(room_root).get("sign", null) as Label3D
	_profile = PlayerProfile.load_or_new()
	_catalogue = MetaCatalogue.new()
	_catalogue.load_all()
	# A profile from an older build may already meet newer conditions.
	_profile.evaluate(_catalogue.unlocks)
	_board = Leaderboard.load_or_new()
	if _setup != null:
		_setup.start_requested.connect(_on_start_requested)
	if _slot_view != null and _audio != null:
		_slot_view.set_audio(_audio)
	if _shop != null:
		_shop.buy_requested.connect(_on_buy_requested)
		_shop.leave_requested.connect(_on_leave_requested)
	# The bar reaches the same entry points as the keys it stands in for, so a
	# tap and a keypress cannot drift apart.
	if _touch != null:
		_touch.camera_requested.connect(_on_touch_camera)
		_touch.setup_requested.connect(_on_touch_setup)
		_touch.new_run_requested.connect(_on_touch_new_run)
	new_run(run_seed)


## Starts a run. Pass 0 for a random seed.
func new_run(chosen_seed: int, daily_key: String = "") -> void:
	var actual_seed: int = chosen_seed if chosen_seed != 0 else randi()
	_current_seed = actual_seed
	_daily_key = daily_key
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
	state = engine.start_run(actual_seed, _catalogue.options_for(_profile, ContentDB.shared()))
	print("Break the Bank — seed %d (%s)%s" % [
		actual_seed, SeedBook.to_code(actual_seed),
		"  daily %s" % _daily_key if not _daily_key.is_empty() else ""])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"bb_menu"):
		if _setup != null and not _setup.is_open():
			_setup.open(_profile, _catalogue, _current_seed)
		return
	if _setup != null and _setup.is_open():
		return
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


func _on_touch_camera() -> void:
	if _camera != null:
		_camera.toggle_view()


func _on_touch_setup() -> void:
	if _setup != null and not _setup.is_open():
		_setup.open(_profile, _catalogue, _current_seed)


func _on_touch_new_run() -> void:
	_end_recording(&"abandoned")
	new_run(0)


## Steps the run from a tool or a test, bypassing input. Visual QA uses this.
func debug_advance() -> void:
	_advance()


## True while the draft is waiting on a choice. For tools and tests.
func debug_shop_open() -> bool:
	return _shop != null and _shop.is_open()


## Leaves the draft without buying. For tools and tests.
func debug_leave_shop() -> void:
	_on_leave_requested()


## Opens the run-setup panel. For tools and tests.
func debug_open_setup() -> void:
	if _setup != null:
		_setup.open(_profile, _catalogue, _current_seed)


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
	_set_prompt("ANTE DUE  %d     CASH %d     %s\n%s" % [
		ante, state.economy.cash, verdict,
		TouchBar.hint("SPACE to settle", "TAP to settle")])
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


func _on_start_requested(run_seed: int, daily_key: String) -> void:
	if _setup != null:
		_setup.close()
	_end_recording(&"abandoned")
	new_run(run_seed, daily_key)


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
			_finish_run(String(payload.get("end_reason", "")))
		_:
			pass
	# The sign and the machine's own monitor track the run on every event, so
	# they can never disagree with the HUD about where the player is.
	_refresh_diegetic()


## Writes the run's state onto the two surfaces in the world that carry it: the
## floor sign on the back wall, and the debt readout on the machine's monitor.
func _refresh_diegetic() -> void:
	if state == null:
		return
	var floor_def: FloorDef = state.current_floor()
	var floor_name: String = floor_def.display_name if floor_def != null else ""
	if _floor_sign != null:
		_floor_sign.text = "FLOOR %d: %s" % [state.floor_index, floor_name.to_upper()]
	if _slot_view != null:
		_slot_view.set_readout(state.economy.debt, floor_name)


## Folds the finished run into the profile and the local board, and tells the
## player what it earned them.
func _finish_run(reason: String) -> void:
	var earned: Array[UnlockDef] = _profile.record_run(state, _catalogue.unlocks)
	_profile.save()
	var entry: Dictionary = _board.submit(state, _daily_key)
	_board.save()
	var rank: int = _board.rank_of(int(entry["score"]), String(entry["ruleset"]))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("RUN OVER — %s" % reason)
	lines.append("%s     score %d     rank %d on this ruleset" % [
		SeedBook.to_code(state.seed_value), int(entry["score"]), rank])
	if not earned.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for unlock: UnlockDef in earned:
			names.append(unlock.display_name)
		lines.append("UNLOCKED: %s" % ", ".join(names))
	lines.append(TouchBar.hint("F5 for a new run     F2 for setup",
			"New run / Setup — the buttons top right"))
	_set_prompt("\n".join(lines))
	_end_recording(StringName(reason))


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
