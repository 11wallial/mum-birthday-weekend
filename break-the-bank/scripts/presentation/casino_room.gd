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
@export var deck_path: NodePath = ^"ControlDeck"
@export var contract_path: NodePath = ^"ContractPanel"
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
var _deck: ControlDeck
var _contracts: ContractPanel
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
	_setup = get_node_or_null(setup_path) as RunSetupPanel
	_touch = get_node_or_null(touch_bar_path) as TouchBar
	_deck = get_node_or_null(deck_path) as ControlDeck
	_contracts = get_node_or_null(contract_path) as ContractPanel
	var room_root: Node3D = get_node_or_null(room_set_path) as Node3D
	if room_root != null:
		_room_parts = RoomSet.new().build(room_root)
		_floor_sign = _room_parts.get("sign", null) as Label3D
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
	if _setup != null:
		_setup.start_requested.connect(_on_start_requested)
	if _slot_view != null and _audio != null:
		_slot_view.set_audio(_audio)
	if _slot_view != null:
		_slot_view.result_judged.connect(_on_result_judged)
	if _shop != null:
		_shop.buy_requested.connect(_on_buy_requested)
		_shop.leave_requested.connect(_on_leave_requested)
		_shop.market_requested.connect(_on_market_requested)
	if _deck != null:
		_deck.action_requested.connect(_on_deck_action)
		# The machine's physical buttons render the deck's model and their
		# clicks come back through the same handler: one model, two renderers,
		# one intent path.
		if _slot_view != null:
			_deck.reels_modelled.connect(_slot_view.set_reel_controls)
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
	# back exactly where it was closed.
	if run_seed != 0 or not _resume_saved_run():
		new_run(run_seed)


## Starts a run. Pass 0 for a random seed.
func new_run(chosen_seed: int, daily_key: String = "") -> void:
	var actual_seed: int = chosen_seed if chosen_seed != 0 else randi()
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
	if _shop != null:
		_shop.close()
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
	if event.is_action_pressed(&"bb_menu"):
		if _setup != null and not _setup.is_open():
			_setup.open(_profile, _catalogue, _current_seed)
			_sync_deck()
		return
	if _setup != null and _setup.is_open():
		return
	if event.is_action_pressed(&"bb_new_run"):
		_end_recording(&"abandoned")
		new_run(0)
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
				engine.nudge(state, reel)
			elif state.decision == RunState.Decision.NONE:
				engine.toggle_hold(state, reel)
			_after_input()
			return
		# Doubling is the deliberate press. Space is always the safe one, so a
		# player tapping through cannot gamble a win away by rhythm.
		if state.decision == RunState.Decision.GAMBLE \
				and event.is_action_pressed(&"bb_confirm"):
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
	# Only now does the machine offer its decision. The simulation knew what the
	# board owed before a single reel had stopped; offering it then would ask the
	# player to nudge symbols they had not been shown.
	if _deck != null:
		_deck.set_busy(false)
		_deck.refresh()
	_prompt_decision()
	if _camera == null:
		return
	match result:
		SlotView3D.Result.JACKPOT:
			_camera.shake(1.0)
		SlotView3D.Result.GOOD:
			_camera.shake(0.45)
		_:
			pass


func _on_touch_camera() -> void:
	if _camera != null:
		_camera.toggle_view()


func _on_touch_setup() -> void:
	if _setup != null and not _setup.is_open():
		_setup.open(_profile, _catalogue, _current_seed)
		_sync_deck()


func _on_touch_new_run() -> void:
	_end_recording(&"abandoned")
	new_run(0)


## Steps the run from a tool or a test, bypassing input. Visual QA uses this.
func debug_advance() -> void:
	# A tool driving the run has no hands to sign with, so the office is closed
	# for it and the first contract taken.
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


## Opens the run-setup panel. For tools and tests.
func debug_open_setup() -> void:
	if _setup != null:
		_setup.open(_profile, _catalogue, _current_seed)
		_sync_deck()


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
	if _contracts != null:
		_contracts.close()
	if _setup != null:
		_setup.close()
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
			or (_setup != null and _setup.is_open()))
	_deck.shelve(modal)


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
	lines.append("ANTE DUE  %d     CASH %d     %s" % [ante, state.economy.cash, verdict])
	# The one thing that can still be done about a shortfall, said at the one
	# moment it matters. A reserve the player has forgotten about is a reserve
	# that loses them the run.
	if short > 0 and state.economy.vault > 0:
		var reaching: int = int(floor(float(state.economy.vault)
				* (1.0 - state.config.vault_break_percent / 100.0)))
		lines.append("The vault holds %d — breaking it now returns %d." % [
			state.economy.vault, reaching])
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


func _on_leave_requested() -> void:
	if state == null or state.phase != RunState.Phase.SHOPPING:
		return
	if _recorder != null:
		_recorder.record_leave_shop(state)
	if _shop != null:
		_shop.close()
	# Back to the machine. Opening the draft pulls the camera out to survey the
	# room; leaving it has to put the camera back, or the whole rest of the run
	# is played from the far framing the draft borrowed.
	if _camera != null:
		_camera.set_view(CameraController.View.MACHINE)
	engine.leave_shop(state)


func _on_start_requested(run_seed: int, daily_key: String) -> void:
	if _setup != null:
		_setup.close()
	_sync_deck()
	_end_recording(&"abandoned")
	new_run(run_seed, daily_key)


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		# PAYOUT_CALCULATED is not shaken on: it arrives in the same frame as the
		# spin request, so the camera kicked before the reels had turned. The
		# view emits result_judged when they actually land.
		EffectBus.Event.FLOOR_STARTED:
			FloorMood.apply(StringName(payload.get("environment", &"")),
					_room_parts, _environment, self)
			_announce_floor(payload)
		EffectBus.Event.SPIN_STARTED:
			if _deck != null:
				_deck.set_busy(true)
		EffectBus.Event.SHOP_OPENED:
			# A callout left over from the floor that just ended would sit on
			# top of the panel the player is being asked to read.
			_clear_prompt()
			if _shop != null:
				_shop.open(state)
			if _camera != null:
				_camera.set_view(CameraController.View.ROOM)
		EffectBus.Event.CONTRACTS_OFFERED:
			_clear_prompt()
			if _contracts != null:
				_contracts.open(state)
			if _camera != null:
				_camera.set_view(CameraController.View.ROOM)
		EffectBus.Event.SYSTEM_GRANTED:
			# Held rather than shown: SYSTEM_GRANTED arrives a moment before the
			# floor it belongs to, and two callouts in two frames means the
			# first one is never read.
			_granted.append(payload)
		EffectBus.Event.RUN_ENDED:
			_finish_run(String(payload.get("end_reason", "")))
		EffectBus.Event.TABLE_KEPT:
			_clear_prompt()
			if _camera != null:
				_camera.set_view(CameraController.View.MACHINE)
		_:
			pass
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
	var floor_name: String = floor_def.display_name if floor_def != null else ""
	if _floor_sign != null:
		_floor_sign.text = "FLOOR %d: %s" % [state.floor_index, floor_name.to_upper()]
		# The glow shells are the same text, softened; a sign whose halo spells
		# the previous floor has broken the trick.
		for child: Node in _floor_sign.get_children():
			if child is Label3D:
				(child as Label3D).text = _floor_sign.text
	if _slot_view != null:
		# The boss's rule stays on the ledger for the whole floor; the House's
		# memos wait for a floor with nobody on it.
		var memo: String = state.boss.tell if state.boss != null \
				else (_memos.memo_for(state) if _memos != null else "")
		_slot_view.set_readout(state.economy.debt, floor_name, memo)


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
			lines.append("DAWN — the House closes. After hours %d, and you walk out." % after_hours)
		else:
			lines.append("THE HOUSE KEPT YOU — after hours %d" % after_hours)
		lines.append("%s     score %d     rank %d on this ruleset" % [
			SeedBook.to_code(state.seed_value), int(stayed["score"]),
			_board.rank_of(int(stayed["score"]), String(stayed["ruleset"]))])
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
	lines.append("RUN OVER — %s" % reason)
	lines.append("%s     score %d     rank %d on this ruleset" % [
		SeedBook.to_code(state.seed_value), int(entry["score"]), rank])
	if not earned.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for unlock: UnlockDef in earned:
			names.append(unlock.display_name)
		lines.append("UNLOCKED: %s" % ", ".join(names))
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
	if _hud != null and _hud.has_method("set_prompt"):
		_hud.call("set_prompt", text, centred)


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
	match action:
		ControlDeck.SPIN:
			_advance()
		ControlDeck.HOLD:
			_record(action, {"reel": index,
					"held": engine.toggle_hold(state, index)})
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
		ControlDeck.STAKE_DOWN:
			if engine.set_stake(state, state.stake - 1):
				_record(action, {"stake": state.stake})
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
		_:
			pass
	if _deck != null:
		_deck.refresh()
	_prompt_decision()
	_mark_save()


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
				_set_prompt("NUDGE — %d left.  Each paid nudge costs a spin."
						% board.nudges)
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
	var boss_name: String = String(payload.get("boss_name", ""))
	if boss_name != "":
		lines.append("%s — %s" % [boss_name.to_upper(), String(payload.get("boss_intro", ""))])
		lines.append(String(payload.get("boss_tell", "")))
	if state != null and state.floor_at(state.floor_index + 1) == null \
			and state.economy.debt > 0:
		lines.append("LAST FLOOR — ante %d, and you still owe %d." % [
			int(payload.get("ante", 0)), state.economy.debt])
		lines.append("Clear both, or the House keeps you.")
	if lines.is_empty():
		return
	lines.append(TouchBar.hint("SPACE to begin", "TAP to begin"))
	_set_prompt("\n".join(lines))
