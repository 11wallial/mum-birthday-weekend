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
@export var touch_bar_path: NodePath = ^"TouchBar"
@export var room_set_path: NodePath = ^"RoomSet"
@export var deck_path: NodePath = ^"ControlDeck"
@export var contract_path: NodePath = ^"ContractPanel"
@export var title_path: NodePath = ^"TitleScreen"
@export var tutorial_path: NodePath = ^"TutorialDirector"
@export var receipt_path: NodePath = ^"PayoutReceipt"
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
var _touch: TouchBar
var _deck: ControlDeck
var _contracts: ContractPanel
var _title: TitleScreen
## The Clerk on the tannoy, for a first run. Owns the prompt while it talks.
var _tutorial: TutorialDirector
## The printed arithmetic of the last spin.
var _receipt: PayoutReceipt
## The statement of account, on the clipboard when the run is over.
var _recap: RecapPanel
## The grade over the world, and the render's degradation with the surety.
var _film: Node
## The card that answers "what is this?" about anything on the machine.
var _inspector: Inspector
## The draft's hardware, laid out on the desk beside the form.
var _draft_cards: DraftCards
## The clipboard's viewport: the draft and the back office are drawn into it
## and the paper in the room wears it.
var _board_viewport: SubViewport
var _clipboard: MeshInstance3D
const BOARD_PX: Vector2i = Vector2i(920, 500)
## The wall sign naming the current floor. Diegetic: the player reads where they
## are off the room, not off an overlay.
var _floor_sign: Label3D
## The room's lights, handed back by [RoomSet] so [FloorMood] can reach them.
var _room_parts: Dictionary = {}
## The environment the mood pass tweens. Held rather than looked up each floor.
var _environment: Environment
var _recorder: PlaytestRecorder
var _profile: PlayerProfile
var _catalogue: MetaCatalogue
var _board: Leaderboard
## What the House prints on the ledger, chosen from where the run stands.
var _memos: MemoBook
## Daily-challenge key for the current run, empty for an ordinary run.
var _daily_key: String = ""
## Seed of the run in progress, so the setup panel can offer it back.
var _current_seed: int = 0
## True once the floor's spins are gone and the ante has not yet been settled.
var _ante_pending: bool = false
## Systems granted since the last floor opened, waiting to be announced with it.
var _granted: Array[Dictionary] = []
## True while a save is waiting for the end of the frame. Every move marks it;
## one write happens.
var _save_pending: bool = false
## What the Clerk last said, kept so a prompt the room clears can be put
## back while the lesson still owns the screen.
var _tutorial_line: String = ""
var _tutorial_hint: String = ""
## True once this run's win has gone into the profile and the board. A run
## that stays at the table ends a second time, and that ending is a record of
## how far it got, not a second run.
var _won_recorded: bool = false


func _ready() -> void:
	_slot_view = get_node_or_null(slot_view_path) as SlotView3D
	_camera = get_node_or_null(camera_path) as CameraController
	_hud = get_node_or_null(hud_path)
	_audio = get_node_or_null(audio_path) as AudioDirector
	_dressing = get_node_or_null(dressing_path) as RoomDressing
	_shop = get_node_or_null(shop_path) as ShopPanel
	_touch = get_node_or_null(touch_bar_path) as TouchBar
	_deck = get_node_or_null(deck_path) as ControlDeck
	_contracts = get_node_or_null(contract_path) as ContractPanel
	_title = get_node_or_null(title_path) as TitleScreen
	_receipt = get_node_or_null(receipt_path) as PayoutReceipt
	_film = get_node_or_null(^"FilmOverlay")
	_recap = get_node_or_null(^"RecapPanel") as RecapPanel
	_inspector = get_node_or_null(^"Inspector") as Inspector
	if _receipt != null and _audio != null:
		_receipt.set_audio(_audio)
	_tutorial = get_node_or_null(tutorial_path) as TutorialDirector
	if _tutorial != null:
		_tutorial.spoke.connect(_on_clerk_spoke)
		_tutorial.finished.connect(_on_lesson_finished)
	var room_root: Node3D = get_node_or_null(room_set_path) as Node3D
	if room_root != null:
		_room_parts = RoomSet.new().build(room_root)
		_floor_sign = _room_parts.get("sign", null) as Label3D
		_mount_board()
	var world: WorldEnvironment = get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if world != null:
		# Duplicated, because the mood pass tweens it: without this the run would
		# write its lighting changes back into the .tres on disk.
		_environment = world.environment.duplicate() as Environment
		world.environment = _environment
	_profile = PlayerProfile.load_or_new()
	_catalogue = MetaCatalogue.new()
	_catalogue.load_all()
	_memos = MemoBook.new()
	_memos.load_all()
	# A profile from an older build may already meet newer conditions.
	_profile.evaluate(_catalogue.unlocks)
	_board = Leaderboard.load_or_new()
	if _title != null:
		_title.start_requested.connect(_on_start_requested)
		_title.resume_requested.connect(_on_resume_requested)
		_title.abandon_requested.connect(_on_abandon_requested)
		_title.tutorial_requested.connect(_on_tutorial_requested)
		_title.skip_requested.connect(_on_skip_requested)
		_title.setting_changed.connect(_apply_setting)
	_apply_settings()
	if _slot_view != null and _audio != null:
		_slot_view.set_audio(_audio)
	if _slot_view != null:
		_slot_view.result_judged.connect(_on_result_judged)
		_slot_view.scoring_started.connect(_on_scoring_started)
		_slot_view.inspect_hovered.connect(_on_inspect)
		_slot_view.pause_started.connect(_on_pause_started)
	if _shop != null:
		_shop.buy_requested.connect(_on_buy_requested)
		_shop.leave_requested.connect(_on_leave_requested)
		_shop.market_requested.connect(_on_market_requested)
		_shop.press_requested.connect(_on_press_requested)
		_shop.doorman_requested.connect(_on_doorman_requested)
		_shop.chit_requested.connect(_on_chit_requested)
	# The cards are a second view onto the same three offers the panel used
	# to draw as rows. They emit the same intent, so both reach the engine
	# by the one path the headless shop policy also takes.
	_draft_cards = DraftCards.new()
	_draft_cards.name = "DraftCards"
	add_child(_draft_cards)
	_draft_cards.card_pressed.connect(_on_buy_requested)
	# After the room has been built, not with it: the props are the room's
	# and this runs later in _ready than the build does.
	_draft_cards.attach(_room_parts.get("cards", null) as Node3D)
	if _deck != null:
		_deck.action_requested.connect(_on_deck_action)
		# The machine's physical buttons render the deck's model and their
		# clicks come back through the same handler: one model, two renderers,
		# one intent path.
		if _slot_view != null:
			_deck.reels_modelled.connect(_slot_view.set_reel_controls)
			_deck.actions_modelled.connect(_slot_view.set_action_controls)
	if _slot_view != null:
		_slot_view.control_pressed.connect(_on_deck_action)
	if _contracts != null:
		_contracts.sign_requested.connect(_on_sign_requested)
	# The bar reaches the same entry points as the keys it stands in for, so a
	# tap and a keypress cannot drift apart.
	if _touch != null:
		_touch.camera_requested.connect(_on_touch_camera)
		_touch.setup_requested.connect(_on_touch_setup)
		_touch.new_run_requested.connect(_on_touch_new_run)
	# A seed set in the inspector is a bug report being reproduced, and it wins
	# over whatever was left on the table. Otherwise the run in progress comes
	# back exactly where it was closed — behind the door, which is where every
	# session starts: the machine idling under its lamp, the title over it,
	# and nothing spinning until the player says so.
	if run_seed != 0:
		new_run(run_seed)
		return
	var resumed: bool = _resume_saved_run()
	if not resumed:
		new_run(0)
	_open_door(resumed)


## Starts a run. Pass 0 for a random seed.
func new_run(chosen_seed: int, daily_key: String = "") -> void:
	var actual_seed: int = chosen_seed if chosen_seed != 0 else randi()
	if _recap != null:
		_recap.close()
	# A new run replaces the one on the table. Whatever was saved is gone the
	# moment this is asked for, not when the new one first writes.
	RunSave.clear()
	_current_seed = actual_seed
	_daily_key = daily_key
	_won_recorded = false
	engine = SimEngine.new()
	# A human is every policy here. An engine still holding its automated ones
	# would answer the nudge trail and the ladder before the reels had stopped.
	engine.clear_policies()
	_bind_viewers(engine.get_bus(), actual_seed)
	var options: RunOptions = _catalogue.options_for(_profile, ContentDB.shared())
	# The journal is the save: every verb from here on is written down, and the
	# run is rebuilt from the seed and the log when the game next opens.
	var journal: RunJournal = RunJournal.new()
	journal.seed_value = actual_seed
	journal.daily_key = daily_key
	journal.options = options
	engine.journal = journal
	state = engine.start_run(actual_seed, options)
	if _deck != null:
		_deck.bind(state)
	# Every event of the run's opening fired before there was a state to draw
	# from, so the sign and the ledger have to be drawn now, or they show the
	# scene's placeholders until the first spin.
	_refresh_diegetic()
	if _tutorial != null:
		_tutorial.bind(engine.get_bus(), state)
	print("Break the Bank — seed %d (%s)%s" % [
		actual_seed, SeedBook.to_code(actual_seed),
		"  daily %s" % _daily_key if not _daily_key.is_empty() else ""])


## Rebuilds the run that was on the table when the game last closed, by
## replaying its journal headlessly, then tells the room where it stands.
## Returns false when there is nothing to resume — or nothing that still
## replays to a live run, which is what a balance change since the save looks
## like from inside it. That is said, and the game starts fresh.
func _resume_saved_run() -> bool:
	var journal: RunJournal = RunSave.read(ContentDB.shared())
	if journal == null:
		return false
	var replayer: SimEngine = SimEngine.new()
	replayer.clear_policies()
	var bus: EffectBus = replayer.get_bus()
	# Replayed in silence. Two hundred spins' worth of events is a light show
	# nobody asked for; the viewers only need to know where it ended.
	bus.muted = true
	var replayed: RunState = replayer.start_run(journal.seed_value, journal.options)
	var stopped: int = RunJournal.replay(replayer, replayed, journal.entries)
	bus.muted = false
	# A run closed at the win screen, offer unanswered, is still on the table.
	var offered: bool = replayed.phase == RunState.Phase.WON and not replayed.endless
	if stopped >= 0 or (replayed.is_over() and not offered):
		push_warning("CasinoRoom: the saved run no longer replays past move %d; starting fresh"
				% (stopped if stopped >= 0 else journal.entries.size()))
		RunSave.clear()
		return false
	engine = replayer
	state = replayed
	engine.journal = journal
	_current_seed = journal.seed_value
	_daily_key = journal.daily_key
	# A resumed run that has stayed at the table had its win recorded before
	# the game closed.
	_won_recorded = state.endless
	_bind_viewers(bus, journal.seed_value)
	engine.announce(state)
	if _slot_view != null:
		_slot_view.show_standing()
		_slot_view.set_holds(state.board.held)
	if _deck != null:
		_deck.bind(state)
	_sync_deck()
	_refresh_diegetic()
	_prompt_decision()
	if offered:
		# The win was recorded before the game closed. Put the offer back up.
		_won_recorded = true
		_set_prompt("\n".join([
			"RUN OVER — cleared_all_floors",
			Endless.OFFER,
			TouchBar.hint("SPACE to stay at the table     F5 for a new run     F2 for setup",
					"TAP to stay at the table — or New run / Setup, top right"),
		]), true)
	print("Break the Bank — resumed seed %d (%s) on floor %d, %d moves in" % [
		journal.seed_value, SeedBook.to_code(journal.seed_value),
		state.floor_index, journal.entries.size()])
	return true


## Points every viewer at a run's bus and clears what the last run left up.
func _bind_viewers(bus: EffectBus, run_seed: int) -> void:
	bus.event_emitted.connect(_on_event)
	if _slot_view != null:
		_slot_view.bind(bus)
	if _hud != null and _hud.has_method("bind"):
		_hud.call("bind", bus)
	if _audio != null:
		_audio.bind(bus)
	if _dressing != null:
		_dressing.bind(bus)
	if _receipt != null:
		_receipt.bind(bus)
	if _shop != null:
		_shop.close()
	if _draft_cards != null:
		_draft_cards.clear()
	if _contracts != null:
		_contracts.close()
	_ante_pending = false
	if record_playtest:
		_recorder = PlaytestRecorder.new()
		add_child(_recorder)
		# A resumed run's recording starts at the resume. The compare tool
		# replays the seed with the policy from the top regardless, so a partial
		# record still diffs; it just cannot say what the player did before.
		_recorder.begin(run_seed)


func _unhandled_input(event: InputEvent) -> void:
	if _title != null and _title.is_open():
		return
	if event.is_action_pressed(&"bb_menu"):
		_pause()
		return
	if event.is_action_pressed(&"bb_new_run"):
		_end_recording(&"abandoned")
		new_run(0)
		return
	# Run it back: the same seed, the same reel, the same people — the
	# statement's findings tested against the fork the player just found.
	if event.is_action_pressed(&"bb_run_back") and state != null and state.is_over():
		new_run(state.seed_value, _daily_key)
		return
	if event.is_action_pressed(&"bb_camera") and _camera != null:
		_camera.toggle_view()
	# Pulled back, the arrows walk the ring of room viewpoints. At the machine
	# they stay free for whatever the machine grows next.
	if _camera != null and _camera.current_view == CameraController.View.ROOM:
		if event.is_action_pressed(&"bb_view_prev"):
			_camera.cycle_room_view(-1)
		elif event.is_action_pressed(&"bb_view_next"):
			_camera.cycle_room_view(1)
		return
	# The draft and the back office consume their own input while open.
	if _shop != null and _shop.is_open():
		return
	if _contracts != null and _contracts.is_open():
		return
	if state != null and state.phase == RunState.Phase.SPINNING \
			and not (_slot_view != null and _slot_view.is_busy()):
		# The number keys reach the reels: hold them between spins, nudge them
		# while the trail is open. One key per reel, and which of the two it
		# means is whatever the machine is currently offering — the deck shows
		# the same thing, so the two can never say different things.
		for reel: int in mini(state.reel_count(), ShopPanel.MAX_SLOTS):
			if not event.is_action_pressed(StringName("bb_slot_%d" % (reel + 1))):
				continue
			if state.decision == RunState.Decision.NUDGE:
				if _allowed(&"nudge", reel):
					engine.nudge(state, reel)
			elif state.decision == RunState.Decision.NONE:
				if _allowed(&"hold", reel) and engine.toggle_hold(state, reel) \
						and _tutorial != null:
					_tutorial.note_hold(reel)
			_after_input()
			return
		# Doubling is the deliberate press. Space is always the safe one, so a
		# player tapping through cannot gamble a win away by rhythm.
		if state.decision == RunState.Decision.GAMBLE \
				and event.is_action_pressed(&"bb_confirm") and _allowed(&"gamble"):
			engine.gamble(state)
			_after_input()
			return
	if event.is_action_pressed(&"bb_advance") or event.is_action_pressed(&"bb_confirm"):
		_advance()


## Kicks the camera by how the spin went, once the reels have actually landed.
##
## Only a spin worth having moves the camera. Shaking on every payout above zero
## made the machine twitch constantly and told the player nothing.
func _on_result_judged(result: SlotView3D.Result, payout: int, settled: bool) -> void:
	if _hud != null and _hud.has_method("mark_result"):
		_hud.call("mark_result", result, payout, settled)
	# A standing board prints its receipt once the reels have shown the line
	# it describes. A banked one printed in time with the performance.
	if _receipt != null and state != null and not settled:
		_receipt.print_board(state.board.breakdown, payout, state.board.chips, false)
	# Only now does the machine offer its decision. The simulation knew what the
	# board owed before a single reel had stopped; offering it then would ask the
	# player to nudge symbols they had not been shown.
	if _deck != null:
		_deck.set_busy(false)
		_deck.refresh()
	_prompt_decision()
	if not settled:
		return
	_settle_surety()
	# The tier's package, in the room: what a spin of this size does to
	# everything around the machine. The machine's own part played already.
	if _camera != null and not SlotView3D.steady:
		match result:
			SlotView3D.Result.OVERLOAD:
				_camera.shake(1.0)
				_camera.push_in(0.14, 1.2)
			SlotView3D.Result.HEAVY:
				_camera.shake(1.0)
				_camera.push_in(0.1, 0.9)
			SlotView3D.Result.STRONG:
				_camera.shake(0.45)
				_camera.push_in(0.06, 0.6)
			SlotView3D.Result.PAID:
				_camera.shake(0.2)
			SlotView3D.Result.DEAD:
				# The opposite of the lean: the room draws back a couple of
				# centimetres and returns. A dead spin used to fall through
				# this match entirely, so the camera — which leans in on
				# anything that pays — sat perfectly still on the outcome
				# the player gets most often. No shake: a shake is a thing
				# landing, and nothing landed.
				_camera.push_in(-0.022, 0.75)
			_:
				pass
	if result >= SlotView3D.Result.HEAVY and not SlotView3D.steady:
		_swing_lamp()
		# Sustained: a second kick as the first dies, so the shake reads as
		# the machine straining rather than a single knock.
		if _camera != null:
			var again: Tween = create_tween()
			again.tween_callback(func() -> void: _camera.shake(0.7)).set_delay(0.3)
	if result == SlotView3D.Result.OVERLOAD and not SlotView3D.steady:
		_flicker_room(0.9)
		if _audio != null:
			_audio.overload(0.9)
	_remark_on(result)


## The performance is starting: the receipt prints in time with it, and the
## deck stays closed until the total has landed.
func _on_scoring_started(plan: Dictionary) -> void:
	if _deck != null:
		_deck.set_busy(true)
	if _receipt != null and state != null:
		_receipt.print_board(state.board.breakdown, state.board.payout, state.board.chips,
				true, "", float(plan.get("end", 0.0)), int(plan.get("tier", -1)))


## The pause before the total: the room's own light dims and the room drops
## to its own tone, for exactly as long as the machine holds.
func _on_pause_started(seconds: float) -> void:
	if _audio != null:
		_audio.hush(seconds)
	var key: Light3D = _room_parts.get("key", null) as Light3D
	if key == null:
		return
	var resting: float = key.light_energy
	var dim: Tween = create_tween()
	dim.tween_property(key, "light_energy", resting * 0.35, 0.05)
	dim.tween_property(key, "light_energy", resting, 0.16).set_delay(maxf(seconds - 0.05, 0.0))


## The pendant swings on a heavy spin, and the key light — which lives at the
## bulb — swings with it, so the shadows in the room move with the fixture.
func _swing_lamp() -> void:
	var bulb: Node3D = _room_parts.get("bulb", null) as Node3D
	var key: Node3D = _room_parts.get("key", null) as Node3D
	var pendant: Node3D = bulb.get_parent() as Node3D if bulb != null else null
	for node: Node3D in [pendant, key]:
		if node == null:
			continue
		var rest: float = node.rotation.z
		var swing: Tween = create_tween()
		var amplitude: float = 0.05
		for i: int in 4:
			swing.tween_property(node, "rotation:z", rest + amplitude, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			swing.tween_property(node, "rotation:z", rest - amplitude, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			amplitude *= 0.6
		swing.tween_property(node, "rotation:z", rest, 0.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Tier five: the room's lights flicker for [param seconds]. The House is in
## trouble and the building knows it.
func _flicker_room(seconds: float) -> void:
	for part: String in ["key", "cold", "wash"]:
		var light: Light3D = _room_parts.get(part, null) as Light3D
		if light == null:
			continue
		var resting: float = light.light_energy
		var flicker: Tween = create_tween()
		var ticks: int = int(seconds / 0.05)
		for i: int in ticks:
			flicker.tween_callback(func() -> void:
				light.light_energy = resting * randf_range(0.2, 1.4)).set_delay(0.05)
		flicker.tween_property(light, "light_energy", resting, 0.15)


## Puts the clipboard's viewport on the paper in the room and moves the two
## forms into it. The texture is bound here, after the set is in the tree —
## fetched at construction it never resolves.
func _mount_board() -> void:
	_clipboard = _room_parts.get("board", null) as MeshInstance3D
	if _clipboard == null:
		return
	_board_viewport = SubViewport.new()
	_board_viewport.name = "BoardViewport"
	_board_viewport.disable_3d = true
	_board_viewport.transparent_bg = false
	_board_viewport.size = BOARD_PX
	_board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The pointer is pushed in by hand from the board's pick area, so the
	# viewport must not also try to read it from the window.
	_board_viewport.handle_input_locally = true
	_board_viewport.gui_disable_input = false
	add_child(_board_viewport)
	# The paper wears the form: the viewport's texture as the albedo of a
	# shaded material, so the desk lamp and the floor's mood light the page.
	var paper: StandardMaterial3D = StandardMaterial3D.new()
	paper.albedo_texture = _board_viewport.get_texture()
	# Cream, not white: with the desk lamp and the key on it a white page
	# crosses the bloom threshold and the type on it vanishes.
	paper.albedo_color = Color(0.8, 0.78, 0.74)
	paper.roughness = 0.92
	paper.metallic = 0.0
	paper.metallic_specular = 0.2
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_clipboard.material_override = paper
	if _shop != null:
		_shop.mount(_board_viewport)
	if _contracts != null:
		_contracts.mount(_board_viewport)
	if _recap != null:
		_recap.mount(_board_viewport)
	var pick: Area3D = _room_parts.get("board_pick", null) as Area3D
	if pick != null:
		pick.input_event.connect(_on_board_input)


## The pointer, through the paper: a click on the clipboard in the room lands
## on the form drawn into it, at the same place. Keys never come this way —
## the forms read them on their own layers.
func _on_board_input(_camera: Node, event: InputEvent, position: Vector3,
		_normal: Vector3, _shape: int) -> void:
	if _board_viewport == null or _clipboard == null:
		return
	var local: Vector3 = _clipboard.to_local(position)
	var uv: Vector2 = Vector2(local.x / RoomSet.BOARD_SIZE.x + 0.5,
			0.5 - local.y / RoomSet.BOARD_SIZE.y)
	var pixel: Vector2 = uv * Vector2(_board_viewport.size)
	var forwarded: InputEvent = null
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = (event as InputEventMouseButton).duplicate()
		click.position = pixel
		click.global_position = pixel
		forwarded = click
	elif event is InputEventMouseMotion:
		var move: InputEventMouseMotion = (event as InputEventMouseMotion).duplicate()
		move.position = pixel
		move.global_position = pixel
		forwarded = move
	if forwarded != null:
		_board_viewport.push_input(forwarded)


## What the pointer is resting on, in the House's words: the number, what
## it is worth right now, and where it comes from. The machine says which
## thing was pointed at; this is the only place that knows what it means.
func _on_inspect(id: StringName) -> void:
	if _inspector == null:
		return
	if id == &"" or state == null:
		_inspector.hide_card()
		return
	var lines: PackedStringArray = PackedStringArray()
	var title: String = ""
	var parts: PackedStringArray = String(id).split(":")
	match parts[0]:
		"counter":
			match parts[1] if parts.size() > 1 else "":
				"cash":
					title = "Cash"
					lines.append(Copy.filled("%d credits in hand.", [state.economy.cash]))
					lines.append(Copy.filled("A spin costs %d. The close of this floor charges the vig of %d and then the ante of %d.", [
							state.spin_price(), state.vig_due(), state.ante_due()]))
					lines.append("Credits never buy hardware — that is what the chips are for.")
				"ante":
					title = "Ante"
					var floor_def: FloorDef = state.current_floor()
					lines.append(Copy.filled("%d due when the spins run out.", [state.ante_due()]))
					if floor_def != null and state.ante_due() != floor_def.ante:
						lines.append(Copy.filled("%s asks %d; the rest is what the House has added since — its people, the count, the contract, and %d notice%s.", [
								Copy.of(floor_def.display_name), floor_def.ante, state.notices,
								"" if state.notices == 1 else "s"]))
					lines.append("Miss it and the House keeps the table.")
				"spins":
					title = "Spins"
					lines.append(Copy.filled("%d left of the %d this floor allows.", [
							state.spins_remaining, state.floor_spins_total]))
					lines.append("A paid nudge costs one of them.")
					if state.config.quick_clear_share > 0.0:
						lines.append(Copy.filled("Settle with %d or more still on the clock and the scrip pays double.", [int(
								ceil(float(state.floor_spins_total) * state.config.quick_clear_share))]))
				"chips":
					title = "Chips"
					lines.append(Copy.filled("%d of the House's scrip.", [state.economy.chips]))
					lines.append("It buys the draft, the reroll, the press and a word with the doorman. It settles nothing.")
					if state.has_system(Systems.MARKET):
						lines.append(Copy.filled("A reroll costs %d.", [state.reroll_price()]))
		"heat":
			title = "The count"
			var measure: HeatEngine.Measure = HeatEngine.current(state)
			lines.append(Copy.filled("%d of 100.", [int(round(HeatEngine.heat_of(state)))]))
			if not state.has_system(Systems.HEAT):
				lines.append("Nobody is counting yet. The House starts on its own floor.")
			elif measure == HeatEngine.Measure.NONE:
				lines.append(Copy.filled("Nobody has looked up. The skim starts at %d.", [int(state.config.heat_skim_at)]))
			else:
				lines.append(Copy.filled("%s. A word costs %d credits.", [
						HeatEngine.measure_name(measure), HeatEngine.launder_price(state)]))
			lines.append("It rises with what you win and falls with every spin you do not.")
		"surety":
			title = "Surety"
			lines.append(Copy.filled("The House holds %d%% of you.", [int(round(state.surety() * 100.0))]))
			lines.append("Nothing while the close is covered; all of it when the spins left cannot reach what is owed.")
			lines.append("A dead spin puts it up by the spin it wasted. A paying one brings it down by what it paid.")
		"odds":
			title = "Multiplier"
			lines.append(Copy.filled("x%.2f on the line standing.", [state.board.multiplier]))
			var devices: int = (state.board.breakdown.get("triggered", []) as Array).size()
			lines.append(Copy.filled("%s, %d device%s, and a stake of %d.", [
					Probability.pattern_name(state.board.pattern).capitalize(),
					devices, "" if devices == 1 else "s", maxi(1, state.stake)]))
			lines.append("The receipt prints every part of it as the spin scores.")
		"reel":
			var index: int = int(parts[1]) if parts.size() > 1 else 0
			if index < state.board.line.size() and state.board.line[index] != null:
				var symbol: SymbolDef = state.board.line[index]
				title = Copy.of(symbol.display_name)
				var gilt: int = state.symbol_bonus(symbol)
				if symbol.is_curse:
					lines.append(Copy.filled("Costs %d, and voids the pattern unless something is warding it.", [state.config.curse_penalty]))
				else:
					lines.append(Copy.filled("Pays %d%s.", [maxi(0, symbol.base_value + gilt),
							" (%d gilt on)" % gilt if gilt > 0 else ""]))
				lines.append(Copy.filled("Lands %.1f%% of the time on this reel as it stands.", [(
						Probability.symbol_chance(state.reel(), symbol.id) * 100.0)]))
				if symbol.chip_value > 0:
					lines.append(Copy.filled("Pays %d chip%s wherever it stands on a scoring row.", [
							symbol.chip_value, "" if symbol.chip_value == 1 else "s"]))
				if symbol.family != &"":
					lines.append(Copy.filled("One of the %s.", [String(symbol.family)]))
	if title.is_empty():
		_inspector.hide_card()
		return
	_inspector.show_card(id, title, lines)


## The survey is lit to be surveyed. At the machine the room falls to
## near-black around the one bulb, which is the value structure the art
## handover asked for; pulled back, that same room is a black frame with a
## lit island in it and the things the run has accumulated — the stacks,
## the plaques, each floor's dressing — cannot be seen. The washes come up
## while the camera stands back, and go down again as it returns.
func _on_view_changed(view: CameraController.View) -> void:
	# Godot only re-runs physics picking on input events, so walking the
	# camera off the machine with the pointer still fires no mouse_exited
	# and a card raised by hover survives the move onto the clipboard.
	if _inspector != null:
		_inspector.hide_card()
	var survey: bool = view == CameraController.View.ROOM
	# The survey is the only framing that can show what a run has built: six
	# floors of dressing live down the left of the room and along the back
	# wall, well outside the machine's own framing. At the old lift the room
	# still read as a void with a bright island in it, so a floor-seven room
	# and a floor-one room were the same photograph. The house lights come up
	# properly when the player stands back, and go down again when they lean in.
	for entry: Array in [["wash", 0.8, 6.2], ["ceiling", 0.55, 4.1],
			["cold", 1.0, 4.4], ["sign_spill", 0.85, 1.6]]:
		var light: Light3D = _room_parts.get(String(entry[0]), null) as Light3D
		if light == null:
			continue
		var target: float = float(entry[2]) if survey else float(entry[1])
		var tween: Tween = create_tween()
		tween.tween_property(light, "light_energy", target, 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## How long the House takes to go dark after the account is settled.
const ENDING_SECONDS: float = 3.4


## The ending the premise promised: the payout is enough to collapse the
## House that paid it. The room's lights die over three seconds, the sign
## gutters, the machine's tubes go out one by one and its column drains,
## and the score falls to nothing — then the desk lamp is the only light
## left and the statement is on the clipboard under it.
func _settled_ending() -> void:
	# Watched from the machine: the last draft left the camera at the desk,
	# and the House going dark is the thing the run was for.
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)
	if _audio != null:
		_audio.hush(ENDING_SECONDS)
		_audio.set_loop_volume(&"music_bed_loop", -60.0, ENDING_SECONDS)
	for part: String in ["key", "cold", "wash", "ceiling", "sign_spill"]:
		var light: Light3D = _room_parts.get(part, null) as Light3D
		if light == null:
			continue
		var die: Tween = create_tween()
		die.tween_property(light, "light_energy", light.light_energy * 0.08, ENDING_SECONDS * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var sign_label: Label3D = _room_parts.get("sign", null) as Label3D
	if sign_label != null:
		var gutter: Tween = create_tween()
		for i: int in 6:
			gutter.tween_property(sign_label, "modulate:a", 0.15 if i % 2 == 0 else 0.9, 0.12)
		gutter.tween_property(sign_label, "modulate:a", 0.0, 0.6)
	if _slot_view != null:
		_slot_view.blackout(ENDING_SECONDS)
	if _film != null and _film.has_method("set_strain"):
		_film.call("set_strain", 0.0)


## How long the House takes to close the table on a run that ended owing.
## Shorter than the settled ending: that one is an event, this one is the
## House getting on with its evening.
const SEIZED_SECONDS: float = 2.0


## The other ending, and the one most runs reach: the account is short and
## the House keeps the table.
##
## Where [method _settled_ending] is a collapse — every light dying together
## over three and a half seconds because the payout broke the House — this is
## an eviction. The machine is cut first and all at once, the way a machine
## is cut when the floor is done with it; the room's own lights stay up,
## because the room is not finished, only this run is. Then the sign goes,
## and the desk lamp is what is left to read the statement by.
func _seized_ending() -> void:
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)
	if _slot_view != null:
		_slot_view.blackout(SEIZED_SECONDS * 0.55)
	if _audio != null:
		_audio.hush(SEIZED_SECONDS)
		_audio.set_loop_volume(&"music_bed_loop", -60.0, SEIZED_SECONDS * 0.8)
		# The drawer, then the door. Two sounds, and the second one is late
		# enough to be a separate thought.
		var drawer: Tween = create_tween()
		drawer.tween_callback(func() -> void: _audio.play_at(&"cash_thud")) \
				.set_delay(SEIZED_SECONDS * 0.42)
	# The machine's own lights go; the room's are dimmed, not killed.
	for part: String in ["key", "cold", "wash", "ceiling"]:
		var light: Light3D = _room_parts.get(part, null) as Light3D
		if light == null:
			continue
		var down: Tween = create_tween()
		down.tween_property(light, "light_energy", light.light_energy * 0.42,
				SEIZED_SECONDS * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var spill: Light3D = _room_parts.get("sign_spill", null) as Light3D
	if spill != null:
		var out: Tween = create_tween()
		out.tween_property(spill, "light_energy", 0.0, SEIZED_SECONDS * 0.5)
	var sign_label: Label3D = _room_parts.get("sign", null) as Label3D
	if sign_label != null:
		# One stutter and out. The settled ending gutters six times because
		# the House is failing; here the floor is simply closed.
		var gutter: Tween = create_tween()
		gutter.tween_property(sign_label, "modulate:a", 0.2, 0.1)
		gutter.tween_property(sign_label, "modulate:a", 0.8, 0.08)
		gutter.tween_property(sign_label, "modulate:a", 0.0, 0.5)


## What the House says about a spin, and how rarely it says anything.
##
## Only two outcomes are worth a word: a payout big enough to hurt the House,
## and a loss that was nearly a win. Everything between them is the machine
## doing its job, and a creditor who remarks on every spin is a mascot.
## RESTRAINT is the whole design of this: at one spin in six the House reads
## as watching, and at one in one it reads as chatty.
const REMARK_GAP: int = 6
## How long a remark stands before the standing memo comes back.
const REMARK_SECONDS: float = 4.5

var _remark: String = ""
var _spins_since_remark: int = 99


func _remark_on(result: SlotView3D.Result) -> void:
	_spins_since_remark += 1
	var lines: PackedStringArray = PackedStringArray()
	if result >= SlotView3D.Result.HEAVY:
		lines = PackedStringArray(["We saw that.", "That was ours.",
				"Noted, and counted."])
	elif result == SlotView3D.Result.DEAD and _slot_view != null and _slot_view.was_tense():
		lines = PackedStringArray(["Close. We keep close.",
				"Nearly. We are patient.", "Not this one."])
	if lines.is_empty() or _spins_since_remark < REMARK_GAP:
		return
	_spins_since_remark = 0
	# Deterministic per seed and spin, so a run replays the same.
	var pick: int = RngStream.derive_seed(state.seed_value,
			StringName("remark/%d" % state.spins_remaining)) % lines.size()
	_remark = Copy.of(lines[pick])
	_refresh_diegetic()
	var fade: Tween = create_tween()
	fade.tween_interval(REMARK_SECONDS)
	fade.tween_callback(func() -> void:
		_remark = ""
		_refresh_diegetic())


## The House's own words, explained the first time each one is used.
##
## The game speaks a vocabulary — the vig, scrip, the press — and only ever
## explained one term of it. The surety gets a line from the Clerk and "the
## works" gets one at grant; the rest a player was left to infer from
## context, while the log said things like "the vig, again" on a floor where
## the word had never been defined. The profile already tracks first
## sightings for hardware, bosses, contracts and chits, so the words go in
## the same book and are said once each, ever, in the House's register.
const WORDS: Dictionary = {
	&"vig": "The vig is the interest. It is charged on the whole debt, every floor, whether or not you clear it.",
	&"scrip": "Chips are the House's scrip. They spend at the machine and nowhere else, and they do not settle the ante.",
	&"press": "The press re-cuts the drums. What it strikes comes off the reels; what it prints goes on.",
}


func _teach_word(word: StringName) -> void:
	if _profile == null or not WORDS.has(word):
		return
	if not _profile.note_seen("words", word):
		return
	_profile.save()
	if _hud != null and _hud.has_method("push_line"):
		_hud.call("push_line", Copy.of(String(WORDS[word])))


## The surety — how much of the player the House holds — onto the column on
## the machine and into the render. The machine holds the value through a
## spin and moves it on the spin's beat; the render degrades with it, which
## is the job the frame has: the game is being played from inside a
## simulation, and the simulation is what the stake is burning.
func _settle_surety() -> void:
	if state == null:
		return
	var held: float = state.surety()
	if _slot_view != null:
		_slot_view.set_surety(held)
	# A finished run holds the surety entirely, but the statement is read
	# in the office: the picture steadies so the account can be read.
	if _film != null and _film.has_method("set_strain"):
		_film.call("set_strain", 0.0 if SlotView3D.steady else (0.2 if state.is_over() else held))
	if _audio != null and not state.is_over():
		_audio.set_tension(held)


func _on_touch_camera() -> void:
	if _camera != null:
		_camera.toggle_view()


func _on_touch_setup() -> void:
	_pause()


## Puts the door up over the room. [param resumed] says a run is on the
## table, so CONTINUE is offered and the machine behind shows its board.
func _open_door(resumed: bool) -> void:
	if _title == null:
		return
	_title.open_title(_profile, _catalogue, resumed, _current_seed)
	# The overlay comes down while the door is up: the title is the whole of
	# the screen, and a ledger showing through it is two screens at once.
	_show_overlay(false)
	if _camera != null:
		_camera.desk_board = _clipboard
		_camera.desk_cards = _room_parts.get("cards", null) as Node3D
		if not _camera.view_changed.is_connected(_on_view_changed):
			_camera.view_changed.connect(_on_view_changed)
		_camera.set_view(CameraController.View.DOOR, true)
	_sync_deck()


## Shows or hides the run's own overlay — the gauges, the log, the hint and
## the callout — as one thing.
func _show_overlay(shown: bool) -> void:
	if _hud != null and _hud is CanvasLayer:
		(_hud as CanvasLayer).visible = shown
	if _touch != null:
		_touch.visible = shown and (_touch.force_visible or TouchBar.is_touch_device())


## The Clerk walks a debtor through the basement once: on the first run of a
## profile that has not seen the lesson, from the first spin.
func _begin_lesson_if_new() -> void:
	if _tutorial == null or state == null or _profile.tutorial_seen:
		return
	if state.spins_taken > 0 or not _daily_key.is_empty() or not state.has_system(Systems.HOLD):
		return
	_tutorial.begin()
	_clear_prompt()
	_on_clerk_spoke(_tutorial_line, _tutorial_hint)


## Pauses the run under the same door, with the pause's words on it.
func _pause() -> void:
	if _title == null or _title.is_open() or state == null:
		return
	_title.lesson_running = _lesson_running()
	_title.open_pause(_profile, _catalogue, _current_seed)
	_sync_deck()


func _on_resume_requested() -> void:
	var was_title: bool = _title != null and _title.mode() == TitleScreen.Mode.TITLE
	if _title != null:
		_title.close()
	_show_overlay(true)
	_sync_deck()
	if _camera != null and _camera.is_pulled_back() \
			and not (_shop != null and _shop.is_open()) \
			and not (_contracts != null and _contracts.is_open()):
		_camera.set_view(CameraController.View.MACHINE)
	if _deck != null:
		_deck.refresh()
	if was_title:
		_begin_lesson_if_new()


func _on_abandon_requested() -> void:
	_end_recording(&"abandoned")
	new_run(0)
	_open_door(false)


func _on_tutorial_requested() -> void:
	_profile.tutorial_seen = false
	_profile.save()
	if _title != null:
		_title.close()
	_show_overlay(true)
	_sync_deck()
	_end_recording(&"abandoned")
	new_run(0)
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)
	_begin_lesson_if_new()


## Reads every setting off the profile into the buses and the reels.
func _apply_settings() -> void:
	for key: String in ["master", "music", "sfx", "ambience", "pace", "overlay", "steady",
			"ui_scale", "fullscreen", "vsync", "render_scale"]:
		_apply_setting(StringName(key), float(_profile.settings.get(key, _default_of(key))))
	# The keys the player has moved, over the bindings the project ships.
	KeyBook.remember_defaults()
	KeyBook.apply(_profile.bindings)
	# The language is a name, not a number, so it does not go through the
	# same door as the rest.
	var locale: String = String(_profile.settings.get("locale", ""))
	if locale != "" and TranslationServer.get_loaded_locales().has(locale):
		TranslationServer.set_locale(locale)


## What a setting is worth before anyone has touched it.
func _default_of(key: String) -> float:
	match key:
		"pace", "ui_scale", "vsync", "render_scale":
			return 1.0
		_:
			return 0.0


func _apply_setting(key: StringName, value: float) -> void:
	_profile.settings[String(key)] = value
	_profile.save()
	match key:
		&"pace":
			SlotView3D.pace = clampf(value, 0.25, 4.0)
		&"steady":
			SlotView3D.steady = value > 0.5
			_settle_surety()
		&"ui_scale":
			# Every overlay refits on a resize; the setting is a resize.
			RunHUD.user_scale = clampf(value, 0.5, 2.0)
			get_viewport().size_changed.emit()
		&"overlay":
			# The machine carries its own controls and counters; the overlay
			# repeats them on the screen for whoever wants that.
			if _deck != null:
				_deck.show_overlay(value > 0.5)
			if _hud != null and _hud.has_method("show_gauges"):
				_hud.call("show_gauges", value > 0.5)
		&"fullscreen":
			# Borderless full screen: the machine is a dark room, and a
			# window's chrome around it is a light on in the room.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN
					if value > 0.5 else DisplayServer.WINDOW_MODE_WINDOWED)
		&"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED
					if value > 0.5 else DisplayServer.VSYNC_DISABLED)
		&"render_scale":
			# The room is rendered at a fraction and scaled up; the overlays
			# and every word on them stay at the screen's own resolution.
			get_viewport().scaling_3d_scale = clampf(value, 0.5, 1.0)
		&"master":
			_set_bus("Master", value)
		&"music":
			_set_bus("Music", value)
		&"sfx":
			_set_bus("SFX", value)
			_set_bus("UI", value)
		&"ambience":
			_set_bus("Ambience", value)
		_:
			pass


## Moves a bus relative to what the layout authored, so the mix's own
## balance survives the sliders.
func _set_bus(bus: String, offset_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	if not has_meta(StringName("bus_base_" + bus)):
		set_meta(StringName("bus_base_" + bus), AudioServer.get_bus_volume_db(index))
	var base: float = float(get_meta(StringName("bus_base_" + bus), 0.0))
	AudioServer.set_bus_volume_db(index, base + offset_db)


func _on_touch_new_run() -> void:
	_end_recording(&"abandoned")
	new_run(0)


## Steps the run from a tool or a test, bypassing input. Visual QA uses this.
func debug_advance() -> void:
	# A tool driving the run has no hands to sign with, so the office is closed
	# for it and the first contract taken — and no ears for the Clerk, whose
	# lesson would otherwise hold the lever until a hold nobody makes.
	if _tutorial != null and _tutorial.is_active():
		_tutorial.skip()
	if _title != null and _title.is_open():
		_on_resume_requested()
	if state != null and state.phase == RunState.Phase.SIGNING and _contracts != null:
		_contracts.close()
	_advance()


## True while the draft is waiting on a choice. For tools and tests.
func debug_shop_open() -> bool:
	return _shop != null and _shop.is_open()


## Buys everything in the draft the run can afford, cheapest first, then
## leaves. Visual QA needs a machine that has actually been built up: driving
## through the draft without buying meant every screenshot showed a bare frame,
## which is the one state a real run spends the least time in.
func debug_buy_what_it_can() -> void:
	if _shop == null or not _shop.is_open() or state == null:
		return
	# Held back, because the next ante is due before the next payout. Spending
	# the float bought a well-stocked machine and then lost the run on floor one,
	# which made every screenshot a game-over screen.
	var floor_def: FloorDef = state.current_floor()
	var reserve: int = floor_def.ante if floor_def != null else 0
	var guard: int = 0
	while guard < 8:
		guard += 1
		var best: int = -1
		var best_price: int = 0
		for i: int in state.shop_offers.size():
			if not state.can_buy(i):
				continue
			if state.economy.cash - state.shop_prices[i] < reserve:
				continue
			if best < 0 or state.shop_prices[i] < best_price:
				best = i
				best_price = state.shop_prices[i]
		if best < 0:
			break
		_on_buy_requested(best)
	_on_leave_requested()


## Leaves the draft without buying. For tools and tests.
func debug_leave_shop() -> void:
	_on_leave_requested()


## Closes the floor now, with the ante covered, so the draft opens. Visual QA
## only: a run driven blind rarely covers the first ante, and a storyboard
## that could not reach the draft was checking the game without its shop.
func debug_open_draft() -> bool:
	if state == null or engine == null or state.phase != RunState.Phase.SPINNING:
		return _shop != null and _shop.is_open()
	_forget_save()
	if _tutorial != null and _tutorial.is_active():
		_tutorial.skip()
	if _slot_view != null and _slot_view.is_busy():
		return false
	state.economy.cash = maxi(state.economy.cash, engine.ante_for(state) * 2)
	state.economy.chips = maxi(state.economy.chips, 12)
	state.spins_remaining = 0
	state.decision = RunState.Decision.NONE
	_ante_pending = false
	_clear_prompt()
	engine.step(state)
	_after_input()
	return _shop != null and _shop.is_open()


## Fits the named artifacts' hardware to the machine without buying any of it.
## Visual QA only — the run's state is untouched, so this shows the frame, not
## a game.
func debug_fit_modules(ids: PackedStringArray) -> void:
	if _slot_view == null:
		return
	for id: String in ids:
		_slot_view.debug_fit(StringName(id))


## Dresses the room as though [param floors] floors had been cleared and
## [param cash] banked, and lights it as [param mood]. Visual QA only: the run's
## state is untouched. A real run reaches a full room slowly, and the full room
## is the one worth looking at.
func debug_dress_room(floors: int, cash: int, mood: StringName) -> void:
	if _dressing != null:
		for i: int in floors:
			_dressing.call("_add_floor_marker", i + 1)
		_dressing.call("_sync_stacks", cash)
	FloorMood.apply(mood, _room_parts, _environment, self)


## Opens the door — the title — over the run. For tools and tests.
func debug_open_setup() -> void:
	if _title != null:
		_open_door(state != null)


## Opens the door and walks through to the counter. For the storyboard.
func debug_open_counter() -> void:
	if _title == null:
		return
	_open_door(state != null)
	_title.debug_open_counter()


## Opens the door on its settings. For the storyboard.
func debug_open_settings(keys: bool = false) -> void:
	debug_open_setup()
	if _title != null and _title.has_method("debug_open_settings"):
		_title.call("debug_open_settings", keys)


## Closes the door. For tools and tests.
func debug_close_door() -> void:
	if _title != null and _title.is_open():
		_on_resume_requested()


## Drops the run onto [param floor_index] with everything that floor would have
## handed over, and enough cash to work with.
##
## Visual QA only. Six of the seven systems only appear on floors a real run
## takes several minutes to reach, and a storyboard that could only ever show
## floor one was showing the game with six of its mechanics switched off.
func debug_jump_to_floor(floor_index: int, cash: int = 4000) -> void:
	if state == null or engine == null:
		return
	_forget_save()
	if _shop != null:
		_shop.close()
	if _draft_cards != null:
		_draft_cards.clear()
	if _contracts != null:
		_contracts.close()
	if _title != null:
		_title.close()
	state.floor_index = clampi(floor_index, 1, 7)
	state.floors_cleared = state.floor_index - 1
	state.economy.cash = cash
	state.phase = RunState.Phase.SPINNING
	engine.begin_floor(state)
	if _deck != null:
		_deck.bind(state)
	# Back to the machine: a jump made to look at a wider machine is no use
	# from the framing that surveys the room.
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)
	_sync_deck()
	_refresh_diegetic()


## Fits works and banks a reserve without paying for either. Visual QA only.
func debug_fit_works(reels: int, rows: int, vault: int) -> void:
	if state == null:
		return
	_forget_save()
	state.extra_reels = clampi(reels, 0, state.config.max_extra_reels)
	state.extra_rows = clampi(rows, 0, state.config.max_extra_rows)
	state.economy.vault = maxi(vault, 0)
	state.board.resize(state.machine_reels())
	engine.get_bus().emit_event(EffectBus.Event.WORKS_FITTED, {
		"kind": "reel", "paid": 0,
		"reels": state.machine_reels(), "rows": state.scoring_rows(),
	})
	if _deck != null:
		_deck.refresh()


## Puts the back office on the table without clearing a floor. Visual QA only.
## Signs the contract at [param index] from a tool, as the panel would.
func debug_sign(index: int) -> void:
	if state == null or state.phase != RunState.Phase.SIGNING:
		return
	_on_sign_requested(index)


## Where the run stands, for the headless full-run check: over or not, and
## whether the statement is on the clipboard.
func debug_run_summary() -> Dictionary:
	return {
		"over": state != null and state.is_over(),
		"phase": String(RunState.Phase.keys()[state.phase]) if state != null else "",
		"floor": state.floor_index if state != null else 0,
		"recap_open": _recap != null and _recap.is_open(),
		"view": _camera.current_view if _camera != null else -1,
	}


## Wins the run on the spot: for the storyboard's ending frame.
func debug_win() -> void:
	if state == null or engine == null:
		return
	if state.is_over():
		# After a losing frame: a fresh run, the door closed, and this one won.
		new_run(0)
		debug_close_door()
	state.floor_index = ContentDB.shared().floors.size()
	state.floors_cleared = state.floor_index - 1
	state.economy.debt = 0
	state.economy.cash = 1000000
	state.spins_remaining = 0
	state.decision = RunState.Decision.NONE
	engine.step(state)
	# The last floor's draft still opens; the win is declared on leaving it.
	if state.phase == RunState.Phase.SHOPPING:
		if _shop != null:
			_shop.close()
		engine.leave_shop(state)
	_after_input()


## Asks the machine about one of its parts, as a hover would. Visual QA.
func debug_inspect(id: String) -> void:
	_on_inspect(StringName(id))


## Ends the run on the spot, unpaid: for the storyboard's statement frame.
func debug_lose() -> void:
	if state == null or engine == null or state.is_over():
		return
	state.economy.cash = 0
	state.spins_remaining = 0
	state.decision = RunState.Decision.NONE
	engine.step(state)
	_after_input()


func debug_open_contracts() -> void:
	if state == null or engine == null:
		return
	_forget_save()
	state.grant_system(Systems.CONTRACTS)
	engine._offer_contracts(state)
	if not state.contract_offers.is_empty():
		state.phase = RunState.Phase.SIGNING
		if _contracts != null:
			_contracts.open(state)
		_sync_deck()


## Drops the journal and the save. A tool that has moved the run outside its
## verbs has made a run the journal cannot describe, and a save of it would
## resume somewhere else.
func _forget_save() -> void:
	if engine != null:
		engine.journal = null
	RunSave.clear()


## Writes the run to disk once per frame that changed it, so closing the game
## at any moment loses nothing that was decided. Every move marks it; the
## write is deferred so a spin's dozen events cost one file, not twelve.
func _mark_save() -> void:
	if _save_pending or engine == null or engine.journal == null:
		return
	_save_pending = true
	_flush_save.call_deferred()


func _flush_save() -> void:
	_save_pending = false
	if state == null or engine == null or engine.journal == null:
		return
	# A won run stays on the table while the House's offer is open; any other
	# ending is nothing to come back to.
	if state.is_over() and not (state.phase == RunState.Phase.WON and not state.endless):
		RunSave.clear()
		return
	RunSave.write(engine.journal, ContentDB.shared())


## Forces a camera framing by [enum CameraController.View] index.
func debug_set_view(view: int) -> void:
	if _camera != null:
		_camera.set_view(view as CameraController.View)


func _advance() -> void:
	if state == null:
		return
	if state.is_over():
		# The House's offer is answered with the same key as everything else.
		# Refused for a lost run, or a run that has already stayed, so the key
		# that ends a run cannot start one by accident.
		if engine.stay_at_table(state):
			_after_input()
		return
	# The guard belongs here rather than only in _unhandled_input: a tool or a
	# test calling debug_advance() must not be able to step past an open draft.
	if _shop != null and _shop.is_open():
		return
	# The back office is a choice, never a default. Stepping the engine here
	# would reach the policy fallback and sign the first contract on the table
	# on the player's behalf.
	if state.phase == RunState.Phase.SIGNING:
		if _contracts != null and _contracts.is_open():
			return
		# No panel — a tool driving the run headless. Signing the first offer is
		# the obvious next thing, which is what debug_advance means.
		engine.sign_contract(state, 0)
		return
	# Never let the run outrun the reels: a second press mid-spin would show a
	# payout for symbols the player has not been shown yet.
	if _slot_view != null and _slot_view.is_busy():
		return
	# A board mid-decision is answered through the deck, or through the safe
	# default: taking the nudges you have not spent, or collecting a win rather
	# than doubling it. Stepping the engine here would hand the decision to a
	# policy that has deliberately been cleared.
	if state.decision == RunState.Decision.NUDGE:
		engine.decline_nudges(state)
		_after_input()
		return
	if state.decision == RunState.Decision.GAMBLE:
		engine.collect(state)
		_after_input()
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
	var spinning: bool = (state.phase == RunState.Phase.SPINNING
			and state.spins_remaining > 0
			and state.economy.can_afford(state.spin_price()))
	# The lesson holds the lever until the move it is teaching has been made.
	if spinning and not _allowed(&"spin"):
		return
	# Only an actual spin goes in the log. Settling the ante happens in the
	# spinning phase too, and recording it as a spin put a phantom pull in the
	# record at the end of every floor.
	if _recorder != null and spinning:
		_recorder.record_spin(state)
	if spinning:
		engine.spin(state)
	else:
		engine.step(state)
	_after_input()


## Clears the deck whenever a panel owns the screen.
##
## Derived from what is actually open rather than tracked by whoever opened it:
## shelving on open and un-shelving on close left the deck hidden for the rest
## of the run down every path that closed a panel some other way.
func _sync_deck() -> void:
	if _deck == null:
		return
	var modal: bool = ((_shop != null and _shop.is_open())
			or (_contracts != null and _contracts.is_open())
			or (_title != null and _title.is_open()))
	_deck.shelve(modal)
	# The panels are painted onto a quad in the room, so they never cover the
	# Inspector and never steal its pointer — it has to be dismissed by hand.
	if modal and _inspector != null:
		_inspector.hide_card()


## Redraws the deck, the lamps and the prompt after a hand-made move.
func _after_input() -> void:
	_sync_deck()
	if _deck != null:
		_deck.refresh()
	# The machine carries the same state the deck does. A hold that only lit a
	# button at the bottom of the screen would leave the player translating
	# between a panel and the drum it is talking about.
	if _slot_view != null and state != null:
		_slot_view.set_holds(state.board.held)
	_prompt_decision()
	_mark_save()


func _prompt_ante() -> void:
	_ante_pending = true
	if state.current_floor() == null:
		return
	var ante: int = engine.ante_for(state)
	var short: int = ante - state.economy.cash
	var verdict: String = "you are %d short" % short if short > 0 else "you can cover it"
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Copy.filled("ANTE DUE  %d     CASH %d     %s", [ante, state.economy.cash, verdict]))
	# The one thing that can still be done about a shortfall, said at the one
	# moment it matters. A reserve the player has forgotten about is a reserve
	# that loses them the run.
	if short > 0 and state.economy.vault > 0:
		var reaching: int = int(floor(float(state.economy.vault)
				* (1.0 - state.config.vault_break_percent / 100.0)))
		lines.append(Copy.filled("The vault holds %d — breaking it now returns %d.", [
			state.economy.vault, reaching]))
	lines.append(TouchBar.hint("SPACE to settle", "TAP to settle"))
	_set_prompt("\n".join(lines))
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
	# A purchase moves the prices and what the rest of the draft can afford,
	# so the cards are dealt again rather than left showing the state the
	# player bought out of.
	if _draft_cards != null and state.phase == RunState.Phase.SHOPPING:
		_draft_cards.deal(state)


func _on_leave_requested() -> void:
	if state == null or state.phase != RunState.Phase.SHOPPING:
		return
	if _recorder != null:
		_recorder.record_leave_shop(state)
	if _shop != null:
		_shop.close()
	if _draft_cards != null:
		_draft_cards.clear()
	# Back to the machine. Opening the draft pulls the camera out to survey the
	# room; leaving it has to put the camera back, or the whole rest of the run
	# is played from the far framing the draft borrowed.
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)
	engine.leave_shop(state)


func _on_start_requested(run_seed: int, daily_key: String) -> void:
	if _title != null:
		_title.close()
	_show_overlay(true)
	_sync_deck()
	_end_recording(&"abandoned")
	new_run(run_seed, daily_key)
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)
	_begin_lesson_if_new()


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		# PAYOUT_CALCULATED is not shaken on: it arrives in the same frame as the
		# spin request, so the camera kicked before the reels had turned. The
		# view emits result_judged when they actually land.
		EffectBus.Event.FLOOR_STARTED:
			var mood_id: StringName = StringName(payload.get("environment", &""))
			FloorMood.apply(mood_id, _room_parts, _environment, self)
			if _receipt != null and FloorMood.MOODS.has(mood_id):
				_receipt.set_light((FloorMood.MOODS[mood_id] as Dictionary)["key"] as Color)
			_announce_floor(payload)
			_settle_surety()
		EffectBus.Event.SPIN_STARTED:
			if _deck != null:
				_deck.set_busy(true)
		EffectBus.Event.REEL_NUDGED:
			# The line changed under the receipt; print what stands now.
			if _receipt != null and state != null:
				_receipt.print_board(state.board.breakdown, state.board.payout,
						state.board.chips, false)
		EffectBus.Event.SHOP_OPENED:
			# The first draft that offers the press is where the press gets
			# explained: the header is the only place the word has ever
			# appeared, over two buttons whose verbs assume it.
			if state != null and not state.press_offers.is_empty():
				_teach_word(&"press")
			# A callout left over from the floor that just ended would sit on
			# top of the form the player is being asked to read. The camera
			# walks to the desk: the draft is a form on the clipboard.
			_clear_prompt()
			if _shop != null:
				_shop.open(state)
			if _draft_cards != null:
				_draft_cards.deal(state)
			if _camera != null:
				_camera.set_view(CameraController.View.DRAFT)
			_settle_surety()
		EffectBus.Event.CONTRACTS_OFFERED:
			_clear_prompt()
			if _contracts != null:
				_contracts.open(state)
			if _camera != null:
				_camera.set_view(CameraController.View.DESK)
			_settle_surety()
		EffectBus.Event.SYSTEM_GRANTED:
			# Held rather than shown: SYSTEM_GRANTED arrives a moment before the
			# floor it belongs to, and two callouts in two frames means the
			# first one is never read.
			_granted.append(payload)
		EffectBus.Event.RUN_ENDED:
			_finish_run(String(payload.get("end_reason", "")))
		EffectBus.Event.CHIT_BOUGHT:
			if _profile != null and _profile.note_seen("chits", StringName(payload.get("chit", ""))):
				_profile.save()
				if _hud != null and _hud.has_method("push_line"):
					_hud.call("push_line", "First seen: %s" % Copy.of(String(payload.get("name", ""))))
		EffectBus.Event.ARTIFACT_ACQUIRED, EffectBus.Event.SHOP_OPENED:
			# First sightings go in the collection as they happen, and the
			# log says so once: the discovery is the run's, not the
			# statement's.
			if _profile != null and state != null and not bool(payload.get("resumed", false)):
				var fresh: PackedStringArray = PackedStringArray()
				for offered: StringName in state.offers_seen:
					if _profile.note_seen("artifacts", offered):
						var seen_def: ArtifactDef = ContentDB.shared().artifact_by_id(offered)
						fresh.append(Copy.of(seen_def.display_name) if seen_def != null else String(offered))
				if not fresh.is_empty():
					_profile.save()
					if _hud != null and _hud.has_method("push_line"):
						_hud.call("push_line", "First seen: %s" % ", ".join(fresh))
		EffectBus.Event.HOUSE_NOTICED:
			# Said the moment it is decided, naming the spin: the player
			# should be able to point at it and say the House did that.
			if not bool(payload.get("resumed", false)):
				_set_prompt(Copy.filled("THE HOUSE HAS NOTICED — %d in one spin.\n%s will be on floor %d: %s\nEvery ante from here is %d%% dearer.", [
					int(payload.get("payout", 0)), Copy.of(String(payload.get("name", ""))).to_upper(),
					int(payload.get("floor", 0)), String(payload.get("tell", "")),
					int(round(float(payload.get("notices", 1))
							* state.config.notice_ante_percent))]))
		EffectBus.Event.TABLE_KEPT:
			_clear_prompt()
			if _camera != null:
				_camera.set_view(CameraController.View.MACHINE)
		_:
			pass
	# The surety moves with the money: at a run's start and end, a floor's
	# close and an ante settled. Outside the match, because an arm that
	# listed RUN_ENDED once shadowed the arm that ends the run.
	if kind in [EffectBus.Event.RUN_STARTED, EffectBus.Event.FLOOR_CLEARED,
			EffectBus.Event.RUN_ENDED, EffectBus.Event.ANTE_SETTLED]:
		_settle_surety()
	# The two words the run itself teaches. Outside the match for the same
	# reason the surety is: an arm that already listed one of these events
	# would shadow the arm that handles it.
	if kind == EffectBus.Event.CHIPS_CHANGED and state != null \
			and state.economy.chips > 0:
		_teach_word(&"scrip")
	if kind == EffectBus.Event.FLOOR_CLEARED and state != null \
			and state.economy.debt > 0:
		_teach_word(&"vig")
	# The sign and the machine's own monitor track the run on every event, so
	# they can never disagree with the HUD about where the player is.
	_refresh_diegetic()
	_sync_deck()
	if _deck != null:
		_deck.refresh()
	_mark_save()


## Writes the run's state onto the two surfaces in the world that carry it: the
## floor sign on the back wall, and the debt readout on the machine's monitor.
func _refresh_diegetic() -> void:
	if state == null:
		return
	var floor_def: FloorDef = state.current_floor()
	var floor_index: int = state.floor_index
	if floor_def == null and state.is_over():
		# A won run has stepped past the last floor; the sign keeps the
		# floor it was won on rather than naming one that does not exist.
		var floors: Array[FloorDef] = ContentDB.shared().floors
		if not floors.is_empty():
			floor_def = floors[floors.size() - 1]
			floor_index = floor_def.index
	var floor_name: String = Copy.of(floor_def.display_name) if floor_def != null else ""
	if _floor_sign != null:
		# Two lines: the long lens crops the right of the frame, and a floor
		# name on one line ran off it from the third floor on.
		_floor_sign.text = Copy.filled("FLOOR %d\n%s", [floor_index, floor_name.to_upper()])
		# The glow shells are the same text, softened; a sign whose halo spells
		# the previous floor has broken the trick.
		for child: Node in _floor_sign.get_children():
			if child is Label3D:
				(child as Label3D).text = _floor_sign.text
	if _slot_view != null:
		# The boss's rule stays on the ledger for the whole floor; the House's
		# memos wait for a floor with nobody on it.
		var memo: String = ""
		for person: BossDef in BossEngine.people(state):
			memo += ("  " if not memo.is_empty() else "") + Copy.of(person.tell)
		if memo.is_empty() and state.notice_pending != null:
			memo = Copy.filled("Noticed. %s is coming.", [Copy.of(state.notice_pending.display_name)])
		# The peek: the next line, on the ledger, until it is spun.
		if not state.peeked_line.is_empty():
			var names: PackedStringArray = PackedStringArray()
			for symbol_id: StringName in state.peeked_line:
				var symbol: SymbolDef = ContentDB.shared().symbol_by_id(symbol_id)
				names.append(Copy.lower(symbol.display_name) if symbol != null else "?")
			memo = Copy.filled("NEXT: %s", [" · ".join(names)]) \
					+ ("\n" + memo if not memo.is_empty() else "")
		if memo.is_empty():
			memo = Copy.of(_memos.memo_for(state)) if _memos != null else ""
		# What the House just said about the last spin, over the standing
		# memo while it stands. The ledger is the only thing on screen that
		# is the House talking, and it never once acknowledged a spin.
		if not _remark.is_empty():
			memo = _remark
		var log: PackedStringArray = PackedStringArray()
		if _hud != null and _hud.has_method("recent_lines"):
			log = _hud.call("recent_lines", 2)
		var terms: String = Copy.of(state.contract.display_name) \
				if state.contract != null else ""
		_slot_view.set_readout(state.economy.debt, floor_name, memo, log,
				state.economy.vault, terms)
		# The counters across the chassis: the four numbers the overlay used
		# to carry. The view holds a payout back until the drums land.
		_slot_view.set_counter("cash", state.economy.cash)
		_slot_view.set_counter("chips", state.economy.chips)
		_slot_view.set_counter("spins", state.spins_remaining)
		_slot_view.set_counter("ante", engine.ante_for(state) if engine != null else 0)
		# The crown's two dials, which the machine has always had and never
		# used. Against the ceiling the run can actually reach, so a dial at
		# its stop means the stake is at its stop.
		var ceiling: int = maxi(1, state.config.max_stake) if state.config != null else 1
		_slot_view.set_dials(float(state.stake - 1) / float(maxi(1, ceiling - 1)),
				clampf(state.heat / 100.0, 0.0, 1.0))


## The statement of account on the clipboard, and the camera over it: the
## run is diagnosed at the desk, not read off a line over the machine.
func _show_statement(score_line: String) -> void:
	if _recap == null or state == null:
		return
	if _inspector != null:
		_inspector.hide_card()
	var entries: Array = engine.journal.entries if engine != null and engine.journal != null else []
	if state.phase == RunState.Phase.WON and not state.endless:
		# The account settled: the House goes dark first, and the statement
		# is read by the desk lamp alone.
		_settled_ending()
		var later: Tween = create_tween()
		later.tween_callback(func() -> void:
			_recap.open(RunRecap.build(state, entries), SeedBook.to_code(state.seed_value),
					score_line)
			if _receipt != null:
				_receipt.clear()
			if _camera != null:
				_camera.set_view(CameraController.View.DESK)).set_delay(ENDING_SECONDS)
		return
	# A run that ended owed gets its own ending. It used to get none: the
	# camera walked to the desk and the statement was simply there, while a
	# win got three and a half seconds of the House going dark. The loss is
	# the ending most players will actually see.
	if state.is_over():
		_seized_ending()
		var settle: Tween = create_tween()
		settle.tween_callback(func() -> void:
			_recap.open(RunRecap.build(state, entries),
					SeedBook.to_code(state.seed_value), score_line)
			if _receipt != null:
				_receipt.clear()
			if _camera != null:
				_camera.set_view(CameraController.View.DESK)).set_delay(SEIZED_SECONDS)
		return
	_recap.open(RunRecap.build(state, entries), SeedBook.to_code(state.seed_value), score_line)
	if _receipt != null:
		_receipt.clear()
	if _camera != null:
		_camera.set_view(CameraController.View.DESK)


## Folds the finished run into the profile and the local board, and tells the
## player what it earned them.
func _finish_run(reason: String) -> void:
	var lines: PackedStringArray = PackedStringArray()
	if _won_recorded:
		# The win already counted. This is how far the run stayed.
		var floors: int = ContentDB.shared().floors.size()
		_profile.record_stayed(state, floors)
		_profile.save()
		var stayed: Dictionary = _board.submit(state, _daily_key)
		_board.save()
		var after_hours: int = state.floors_cleared - floors
		if reason == "dawn":
			lines.append(Copy.filled("DAWN — the House closes. After hours %d, and you walk out.", [after_hours]))
		else:
			lines.append(Copy.filled("THE HOUSE KEPT YOU — after hours %d", [after_hours]))
		lines.append(Copy.filled("%s     score %d     rank %d on this ruleset", [
			SeedBook.to_code(state.seed_value), int(stayed["score"]),
			_board.rank_of(int(stayed["score"]), String(stayed["ruleset"]))]))
		lines.append(TouchBar.hint("F5 for a new run     F2 for setup",
				"New run / Setup — the buttons top right"))
		_set_prompt("\n".join(lines), true)
		_end_recording(StringName(reason))
		return
	var earned: Array[UnlockDef] = _profile.record_run(state, _catalogue.unlocks)
	_profile.save()
	var entry: Dictionary = _board.submit(state, _daily_key)
	_board.save()
	var rank: int = _board.rank_of(int(entry["score"]), String(entry["ruleset"]))
	# The ending, in the House's own terms: the surety kept or returned.
	# The headline is the outcome; the reason code stays on the statement.
	lines.append("THE ACCOUNT IS SETTLED" if state.phase == RunState.Phase.WON
			else "THE HOUSE KEEPS THE SURETY")
	var outcome: Dictionary = RunRecap.outcome(state)
	lines.append(Copy.filled(String(outcome["shape"]), outcome["values"] as Array))
	lines.append(Copy.filled("%s     score %d     rank %d on this ruleset", [
		SeedBook.to_code(state.seed_value), int(entry["score"]), rank]))
	_show_statement(Copy.filled("score %d     rank %d on this ruleset", [int(entry["score"]), rank]))
	if not earned.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for unlock: UnlockDef in earned:
			names.append(Copy.of(unlock.display_name))
		lines.append(Copy.filled("UNLOCKED: %s", [", ".join(names)]))
	if state.phase == RunState.Phase.WON and not state.endless:
		# The counter-offer. Only to a run that has beaten the House, and the
		# key that takes it is the key that spins.
		_won_recorded = true
		lines.append(Endless.OFFER)
		lines.append(TouchBar.hint(
				"SPACE to stay at the table     F5 for a new run     F2 for setup",
				"TAP to stay at the table — or New run / Setup, top right"))
	else:
		lines.append(TouchBar.hint("F5 for a new run     F2 for setup",
				"New run / Setup — the buttons top right"))
	# The one message that gets the middle of the screen. There is nothing left
	# on the machine worth looking past it at.
	_set_prompt("\n".join(lines), true)
	_end_recording(StringName(reason))
	# A lost run is nothing to come back to; a won one keeps its offer open.
	_mark_save()


func _end_recording(reason: StringName) -> void:
	if _recorder == null:
		return
	_recorder.finish(state, reason)
	_recorder.queue_free()
	_recorder = null


func _set_prompt(text: String, centred: bool = false) -> void:
	# While the Clerk is talking, the callout is the Clerk's. A floor's
	# announcement or a nudge hint over the top of the lesson is two voices.
	if _lesson_running() and not centred:
		return
	if _hud != null and _hud.has_method("set_prompt"):
		_hud.call("set_prompt", text, centred)


func _lesson_running() -> bool:
	return _tutorial != null and _tutorial.is_active()


func _on_clerk_spoke(body: String, hint: String) -> void:
	# The Clerk's lines are keys of their own: a translator gets each
	# sentence as its row, and a sentence with no row is said as written.
	body = tr(body)
	hint = tr(hint)
	_tutorial_line = body
	_tutorial_hint = hint
	if _hud == null or not _hud.has_method("set_prompt"):
		return
	if body.is_empty():
		_hud.call("set_prompt", "", false)
		return
	_hud.call("set_prompt", body + ("\n" + hint if not hint.is_empty() else ""), false)
	if _audio != null:
		_audio.play(&"intercom_crackle")


func _on_lesson_finished(_skipped: bool) -> void:
	_profile.tutorial_seen = true
	_profile.save()
	_tutorial_line = ""
	_tutorial_hint = ""
	if _title != null:
		_title.lesson_running = false
	_prompt_decision()


func _on_skip_requested() -> void:
	if _tutorial != null:
		_tutorial.skip()
	_on_resume_requested()


## True when the lesson lets [param action] through right now.
func _allowed(action: StringName, index: int = -1) -> bool:
	return _tutorial == null or _tutorial.allows(action, index)


func _clear_prompt() -> void:
	_set_prompt("")


## Turns a press on the deck into the matching simulation call.
##
## Every branch here is one public [SimEngine] method — the same one the
## automated policy calls — so a hand-played run and a batch exercise one code
## path rather than two implementations that drift apart.
func _on_deck_action(action: StringName, index: int) -> void:
	if state == null or state.is_over():
		return
	if _slot_view != null and _slot_view.is_busy():
		return
	if not _allowed(_lesson_verb(action), index):
		return
	match action:
		ControlDeck.SPIN:
			_advance()
		ControlDeck.HOLD:
			var held: bool = engine.toggle_hold(state, index)
			_record(action, {"reel": index, "held": held})
			if _audio != null:
				_audio.play(&"switch_click")
			if held and _tutorial != null:
				_tutorial.note_hold(index)
		ControlDeck.NUDGE:
			var standing: int = state.board.payout
			var free: bool = state.board.next_nudge_is_free()
			if engine.nudge(state, index):
				_record(action, {"reel": index, "free": free,
						"gained": state.board.payout - standing})
		ControlDeck.TAKE:
			_record(action, {"declined": state.board.nudges})
			engine.decline_nudges(state)
		ControlDeck.GAMBLE:
			var rung: int = state.board.gamble_rung
			var staked: int = state.board.payout
			engine.gamble(state)
			_record(action, {"rung": rung, "staked": staked,
					"won": state.board.payout > staked})
		ControlDeck.COLLECT:
			_record(action, {"payout": state.board.payout,
					"rung": state.board.gamble_rung})
			engine.collect(state)
		ControlDeck.STAKE_UP:
			if engine.set_stake(state, state.stake + 1):
				_record(action, {"stake": state.stake})
				if _audio != null:
					_audio.play(&"switch_click")
		ControlDeck.STAKE_DOWN:
			if engine.set_stake(state, state.stake - 1):
				_record(action, {"stake": state.stake})
				if _audio != null:
					_audio.play(&"switch_click")
		ControlDeck.DEPOSIT:
			var banked: int = engine.deposit(state, _float_to_bank())
			if banked > 0:
				_record(action, {"amount": banked, "vault": state.economy.vault})
		ControlDeck.WITHDRAW:
			var taken: int = engine.withdraw(state, state.economy.vault)
			if taken > 0:
				_record(action, {"amount": taken})
		ControlDeck.BUY_ROW:
			var row_price: int = engine.works_price(state, false)
			if engine.buy_row(state):
				_record(action, {"paid": row_price, "rows": state.scoring_rows()})
		ControlDeck.BUY_REEL:
			var reel_price: int = engine.works_price(state, true)
			if engine.buy_reel(state):
				_record(action, {"paid": reel_price, "reels": state.machine_reels()})
		ControlDeck.LAUNDER:
			var price: int = HeatEngine.launder_price(state)
			if engine.launder(state):
				_record(action, {"paid": price, "heat": state.heat})
		ControlDeck.USE_CHIT:
			if index >= 0 and index < state.pocket.size() and _allowed(&"use_chit", index):
				var chit_id: StringName = state.pocket[index].id
				if engine.use_chit(state, index):
					_record(action, {"chit": String(chit_id)})
					if _audio != null:
						_audio.play_at(&"receipt_tear")
		ControlDeck.SETTLE:
			var left: int = state.spins_remaining
			var bonus: int = state.settle_bonus(left)
			if engine.settle_floor(state):
				_record(action, {"spins_left": left, "chips": bonus})
		_:
			pass
	if _deck != null:
		_deck.refresh()
	_prompt_decision()
	_mark_save()


## The lesson's name for a deck action: the deck says "take" for declining
## the nudges and "collect" for banking, and the Clerk allows both by name.
static func _lesson_verb(action: StringName) -> StringName:
	match action:
		ControlDeck.SPIN:
			return &"spin"
		ControlDeck.HOLD:
			return &"hold"
		ControlDeck.NUDGE:
			return &"nudge"
		ControlDeck.TAKE:
			return &"take"
		ControlDeck.COLLECT:
			return &"collect"
		ControlDeck.GAMBLE:
			return &"gamble"
		ControlDeck.SETTLE:
			return &"settle"
		_:
			return action


## How much the BANK button puts away.
##
## Everything the collateral can still use, and never the last of the purse:
## a button that banked the float down to nothing would end runs by itself, and
## the vault is meant to be a bet, not a trap.
func _float_to_bank() -> int:
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		return 0
	var useful: int = int(round(float(floor_def.ante)
			* state.config.vault_collateral_antes * state.config.vault_collateral_cap))
	var keep: int = maxi(state.spin_price() * 3, int(round(float(floor_def.ante) * 0.1)))
	return mini(state.economy.cash - keep, maxi(0, useful - state.economy.vault))


func _record(kind: StringName, detail: Dictionary) -> void:
	if _recorder != null and state != null:
		_recorder.record_move(state, kind, detail)


func _on_sign_requested(index: int) -> void:
	if state == null or state.phase != RunState.Phase.SIGNING:
		return
	var passed: Array[String] = []
	for i: int in state.contract_offers.size():
		if i != index:
			passed.append(String(state.contract_offers[i].id))
	var signed: StringName = state.contract_offers[index].id \
			if index >= 0 and index < state.contract_offers.size() else &""
	if engine.sign_contract(state, index) and _contracts != null:
		_record(&"sign", {"contract": String(signed), "passed": passed})
		_contracts.close()
		if _camera != null:
			_camera.set_view(CameraController.View.MACHINE)


## The draft's chit, from the form.
func _on_chit_requested() -> void:
	if state == null or not state.can_buy_chit():
		return
	var chit_id: StringName = state.chit_offer.id
	if engine.buy_chit(state):
		_record(&"buy_chit", {"chit": String(chit_id)})
		if _shop != null and _shop.is_open():
			_shop.refresh()
		if _audio != null:
			_audio.play(&"ui_chip_place")
		_mark_save()


## A word with the doorman, from the form: the same call the policy makes.
func _on_doorman_requested() -> void:
	if state == null or not state.can_pay_doorman():
		return
	var price: int = state.doorman_price()
	if engine.pay_doorman(state):
		_record(&"pay_doorman", {"paid": price})
		if _shop != null and _shop.is_open():
			_shop.refresh()
		if _audio != null:
			_audio.play(&"ui_chip_stack")
		_mark_save()


func _on_press_requested(index: int) -> void:
	if state == null or state.phase != RunState.Phase.SHOPPING:
		return
	var job: Dictionary = state.press_offers[index] if index >= 0 \
			and index < state.press_offers.size() else {}
	if engine.press(state, index):
		_record(&"press", {"kind": String(job.get("kind", "")),
				"symbol": String(job.get("symbol", "")), "price": int(job.get("price", 0))})
		if _audio != null:
			_audio.play_at(&"works_fitted")
	if _shop != null:
		_shop.refresh()


func _on_market_requested(action: StringName, index: int) -> void:
	if state == null or state.phase != RunState.Phase.SHOPPING:
		return
	match action:
		ShopPanel.REROLL:
			var price: int = state.reroll_price()
			if engine.reroll_shop(state):
				_record(action, {"paid": price})
		ShopPanel.SLATE:
			var wanted: String = String(state.shop_offers[index].id) \
					if index >= 0 and index < state.shop_offers.size() else ""
			if engine.buy_on_slate(state, index):
				_record(action, {"artifact": wanted, "debt": state.economy.debt})
		ShopPanel.SELL:
			var refund: int = engine.sell(state, index)
			if refund > 0:
				_record(action, {"refund": refund})
		_:
			pass
	if _shop != null:
		_shop.refresh()


## Says what the machine is waiting for, in the middle of the screen, whenever
## that is not simply "pull the handle".
func _prompt_decision() -> void:
	if state == null or _ante_pending:
		return
	if _slot_view != null and _slot_view.is_busy():
		return
	match state.decision:
		RunState.Decision.NUDGE:
			# Said once, on the floor that grants it. The buttons carry the
			# count, the cost and what each nudge would bring down, so repeating
			# it across the machine's face every time is a banner, not a hint.
			# All the way through the floor that teaches it. The basement is the
			# tutorial and the trail is its lesson, and a player tapping through
			# on rhythm would otherwise decline every nudge they were owed
			# without ever finding out what the word meant.
			if state.floor_index <= 1:
				var board: SpinBoard = state.board
				_set_prompt(Copy.filled("NUDGE — %d left.  Each paid nudge costs a spin.", [board.nudges]))
			else:
				_clear_prompt()
		RunState.Decision.GAMBLE:
			_set_prompt("")
		_:
			_clear_prompt()


## The one callout a floor gets: what it just handed over, and what it wants.
##
## The last floor also gets told what is still owed. A run that clears the House
## and then loses to a debt nobody mentioned since floor two has been beaten by
## a number, not by the game — and about a fifth of runs end exactly there.
func _announce_floor(payload: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray()
	for granted: Dictionary in _granted:
		lines.append(String(granted.get("title", "")))
		lines.append(String(granted.get("brief", "")))
	_granted.clear()
	# Whoever the House has sent is announced with the floor, rule and all:
	# a twist nobody was told about is not a boss, it is a bug report.
	var skin_name: String = Copy.of(String(payload.get("skin_name", "")))
	if skin_name != "":
		lines.append(Copy.filled("%s — %s", [skin_name.to_upper(), String(payload.get("skin_line", ""))]))
	var boss_name: String = Copy.of(String(payload.get("boss_name", "")))
	if boss_name != "":
		lines.append(Copy.filled("%s — %s", [boss_name.to_upper(), String(payload.get("boss_intro", ""))]))
		lines.append(String(payload.get("boss_tell", "")))
	if state != null and state.floor_index == 1 and not state.ship_lean.is_empty():
		var heavy: SymbolDef = ContentDB.shared().symbol_by_id(state.ship_lean["heavy"])
		var light: SymbolDef = ContentDB.shared().symbol_by_id(state.ship_lean["light"])
		if heavy != null and light != null:
			lines.append(Copy.filled("THE REEL TODAY — %s heavy, %s light.", [
					Copy.lower(heavy.display_name), Copy.lower(light.display_name)]))
	var watcher_name: String = String(payload.get("watcher_name", ""))
	if watcher_name != "":
		lines.append(Copy.filled("%s, BECAUSE THE HOUSE NOTICED — %s", [watcher_name.to_upper(),
				String(payload.get("watcher_intro", ""))]))
		lines.append(String(payload.get("watcher_tell", "")))
	if state != null and state.floor_at(state.floor_index + 1) == null \
			and state.economy.debt > 0:
		lines.append(Copy.filled("LAST FLOOR — ante %d, and you still owe %d.", [
			int(payload.get("ante", 0)), state.economy.debt]))
		lines.append("Clear both, or the House keeps you.")
	if lines.is_empty():
		return
	lines.append(TouchBar.hint("SPACE to begin", "TAP to begin"))
	_set_prompt("\n".join(lines))
