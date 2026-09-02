## Drives a whole run, headless, from a seed.
##
## This is the entry point the balance lab, the tests and the 3D game all use.
## The engine never yields, never awaits and never touches the scene tree: a run
## is a function call that returns a finished [RunState].
class_name SimEngine
extends RefCounted

## Chooses what to buy from a shop offer. Signature:
## [code]func(state: RunState, offers: Array[ArtifactDef], prices: Array[int]) -> int[/code],
## returning an index into [param offers], or -1 to buy nothing.
var shop_policy: Callable = Callable()

## Chooses which reel to nudge. Signature:
## [code]func(state: RunState, board: SpinBoard) -> int[/code], returning a reel
## index or -1 to stop nudging.
var nudge_policy: Callable = Callable()
## Decides whether to climb the gamble ladder. Signature:
## [code]func(state: RunState, board: SpinBoard) -> bool[/code].
var gamble_policy: Callable = Callable()
## Picks the stake for the coming spin. Signature:
## [code]func(state: RunState) -> int[/code].
var stake_policy: Callable = Callable()
## Picks which reels to hold for the coming spin. Signature:
## [code]func(state: RunState, board: SpinBoard) -> PackedInt32Array[/code].
var hold_policy: Callable = Callable()
## Picks which contract to sign. Signature:
## [code]func(state: RunState, offers: Array[ContractDef]) -> int[/code].
var contract_policy: Callable = Callable()
## Works the vault, banking between floors and breaking it in a pinch.
## Signature: [code]func(engine: SimEngine, state: RunState) -> void[/code].
var vault_policy: Callable = Callable()
## Decides whether to have a word with someone. Signature:
## [code]func(state: RunState) -> bool[/code].
var launder_policy: Callable = Callable()
## Fits reels and rows when the machine can be paid for. Signature:
## [code]func(engine: SimEngine, state: RunState) -> void[/code].
var works_policy: Callable = Callable()
## Works the market once the draft has been shopped — sells, signs the slate,
## rerolls. Signature: [code]func(engine: SimEngine, state: RunState) -> void[/code].
var market_policy: Callable = Callable()
## Works the press once the draft has been shopped. Signature:
## [code]func(engine: SimEngine, state: RunState) -> void[/code].
var press_policy: Callable = Callable()
## Decides whether a won run takes the House's offer and stays at the table.
## Signature: [code]func(state: RunState) -> bool[/code].
var stay_policy: Callable = Callable()
## Decides whether to settle the floor now, with spins still on the clock,
## and take the chips for them. Signature:
## [code]func(state: RunState) -> bool[/code].
var settle_policy: Callable = Callable()

## Where the verbs go when a run is being kept: null in a batch, a [RunJournal]
## when a person is playing and the run has to survive the app closing. Only
## the outermost public call is written down — see [method _enter].
var journal: RunJournal = null
var _depth: int = 0

## Every verb a player's hands can reach that needs an opinion behind it, named
## by the public method that is the verb. [constant AutoPlayer.COVERAGE] has to
## name an opinion for each, and a batch has to be seen using each, or the lab
## is measuring a game with that verb switched off. The parity suite holds the
## two lists together.
const PLAYER_VERBS: Array[StringName] = [
	&"toggle_hold", &"nudge", &"gamble", &"set_stake",
	&"deposit", &"withdraw", &"buy_reel", &"buy_row", &"launder",
	&"buy_offer", &"reroll_shop", &"sell", &"buy_on_slate", &"sign_contract",
	&"stay_at_table", &"settle_floor", &"press",
]

## Jobs the press puts on the table with every draft, and what they do to the
## reel. A strike takes weight off a symbol, a print adds it, gilding adds to
## what a symbol pays. Weight per job and credits per gilding are the
## magnitudes; the prices are chips.
const PRESS_JOBS: int = 2
const PRESS_STRIKE_WEIGHT: int = 4
const PRESS_PRINT_WEIGHT: int = 4
const PRESS_GILD_CREDITS: int = 2
const PRESS_STRIKE_PRICE: int = 3
const PRESS_PRINT_PRICE: int = 3
const PRESS_GILD_PRICE: int = 4

## Contracts put on the table before a floor once the back office is open.
const CONTRACT_SLOTS: int = 3

## Draw weight for an artifact the current floor has only just unlocked, and how
## much that weight drops for every floor of age after it.
const FRESH_WEIGHT: int = 10
const STALE_STEP: int = 2

var _content: ContentDB
var _bus: EffectBus


func _init(content: ContentDB = null, bus: EffectBus = null) -> void:
	_content = content if content != null else ContentDB.shared()
	_bus = bus if bus != null else EffectBus.new()
	shop_policy = Callable(AutoPlayer, "shop")
	nudge_policy = Callable(AutoPlayer, "nudge")
	gamble_policy = Callable(AutoPlayer, "gamble")
	stake_policy = Callable(AutoPlayer, "stake")
	hold_policy = Callable(AutoPlayer, "hold")
	contract_policy = Callable(AutoPlayer, "contract")
	vault_policy = Callable(AutoPlayer, "vault")
	launder_policy = Callable(AutoPlayer, "launder")
	works_policy = Callable(AutoPlayer, "works")
	market_policy = Callable(AutoPlayer, "market")
	stay_policy = Callable(AutoPlayer, "stay")
	settle_policy = Callable(AutoPlayer, "settle")
	press_policy = Callable(AutoPlayer, "press_jobs")


## Hands every decision back to whoever is calling.
##
## A human is the policy when a person is playing, and an engine still holding
## its automated ones would answer the nudge trail and the ladder before the
## reels had stopped turning.
func clear_policies() -> void:
	shop_policy = Callable()
	nudge_policy = Callable()
	gamble_policy = Callable()
	stake_policy = Callable()
	hold_policy = Callable()
	contract_policy = Callable()
	vault_policy = Callable()
	works_policy = Callable()
	launder_policy = Callable()
	market_policy = Callable()
	stay_policy = Callable()
	settle_policy = Callable()
	press_policy = Callable()


func get_bus() -> EffectBus:
	return _bus


## Marks the start of a public verb, and writes it to the journal when it came
## from outside. Only the outermost call counts: a spin that banks itself calls
## collect, step calls half the engine, and the shop policy buys through
## buy_offer — none of that is the player's doing, and a log that recorded it
## would replay every inner call twice.
func _enter(verb: StringName, args: Array) -> void:
	if _depth == 0 and journal != null:
		journal.record(verb, args)
	_depth += 1


func _leave() -> void:
	_depth -= 1


## Tells everyone watching where a resumed run stands, as the events they would
## have seen had they been watching all along — the facts, not the ceremonies.
## A system being granted and a spin landing are moments, and a resumed run has
## already had them: hardware is refitted, cleared floors are recorded, the
## board is shown standing rather than spun, and whatever the machine was
## waiting on — a nudge, the ladder, the draft, a signature — is put back on
## the table. Every payload carries "resumed" so a listener can tell the two
## apart, which is how the audio stays quiet through it.
func announce(state: RunState) -> void:
	if not _bus.is_live():
		return
	_bus.emit_event(EffectBus.Event.RUN_STARTED, {
		"seed": state.seed_value, "cash": state.economy.cash,
		"debt": state.economy.debt, "resumed": true,
	})
	for artifact: ArtifactDef in state.owned:
		_bus.emit_event(EffectBus.Event.ARTIFACT_ACQUIRED, {
			"artifact": artifact.id, "floor": state.floor_index, "resumed": true,
		})
	if state.extra_reels > 0 or state.extra_rows > 0:
		_bus.emit_event(EffectBus.Event.WORKS_FITTED, {
			"kind": "reel", "paid": 0, "reels": state.machine_reels(),
			"rows": state.scoring_rows(), "resumed": true,
		})
	for cleared: int in range(1, state.floors_cleared + 1):
		_bus.emit_event(EffectBus.Event.FLOOR_CLEARED, {
			"floor": cleared, "cash": state.economy.cash,
			"debt": state.economy.debt, "serviced": 0, "resumed": true,
		})
	var floor_def: FloorDef = state.current_floor()
	if floor_def != null:
		var standing: Dictionary = {
			"floor": floor_def.index, "name": floor_def.display_name,
			"ante": _ante_for(state, floor_def), "spins": state.spins_remaining,
			"environment": floor_def.environment_id,
			"description": floor_def.description, "resumed": true,
		}
		standing.merge(boss_payload(state))
		_bus.emit_event(EffectBus.Event.FLOOR_STARTED, standing)
	if state.notice_pending != null:
		var noticed: Dictionary = notice_payload(state)
		noticed["resumed"] = true
		_bus.emit_event(EffectBus.Event.HOUSE_NOTICED, noticed)
	_bus.emit_event(EffectBus.Event.CASH_CHANGED, {
		"delta": 0, "cash": state.economy.cash, "reason": &"resumed", "resumed": true,
	})
	_bus.emit_event(EffectBus.Event.CHIPS_CHANGED, {
		"delta": 0, "chips": state.economy.chips, "reason": &"resumed", "resumed": true,
	})
	if state.economy.vault > 0:
		_bus.emit_event(EffectBus.Event.VAULT_CHANGED, {
			"vault": state.economy.vault, "cash": state.economy.cash,
			"delta": 0, "interest": 0, "resumed": true,
		})
	if state.has_system(Systems.HEAT):
		var measure: HeatEngine.Measure = HeatEngine.current(state)
		_bus.emit_event(EffectBus.Event.HEAT_CHANGED, {
			"heat": state.heat, "measure": int(measure),
			"name": HeatEngine.measure_name(measure), "changed": false,
			"launder_price": HeatEngine.launder_price(state),
			"ante": ante_for(state), "resumed": true,
		})
	if not Probability.drawn(state.board.line).is_empty():
		for i: int in state.board.reel_count():
			var landed: Dictionary = reel_payload(state.board, i)
			landed["resumed"] = true
			_bus.emit_event(EffectBus.Event.SYMBOL_LANDED, landed)
	match state.decision:
		RunState.Decision.NUDGE:
			_bus.emit_event(EffectBus.Event.NUDGES_AWARDED, {
				"nudges": state.board.nudges, "free": state.board.free_nudges,
				"pattern": Probability.pattern_name(state.board.pattern), "resumed": true,
			})
		RunState.Decision.GAMBLE:
			var odds: PackedFloat32Array = state.config.gamble_odds
			_bus.emit_event(EffectBus.Event.GAMBLE_OFFERED, {
				"payout": state.board.payout, "rung": state.board.gamble_rung,
				"odds": odds[clampi(state.board.gamble_rung, 0, odds.size() - 1)],
				"resumed": true,
			})
		_:
			pass
	match state.phase:
		RunState.Phase.SHOPPING:
			_bus.emit_event(EffectBus.Event.SHOP_OPENED, {
				"floor": state.floor_index, "offers": _offer_ids(state),
				"prices": state.shop_prices.duplicate(),
				"reroll_price": state.reroll_price(),
				"market": state.has_system(Systems.MARKET), "resumed": true,
			})
		RunState.Phase.SIGNING:
			var offered: Array[String] = []
			for contract: ContractDef in state.contract_offers:
				offered.append(String(contract.id))
			_bus.emit_event(EffectBus.Event.CONTRACTS_OFFERED, {
				"floor": state.floor_index + 1, "contracts": offered, "resumed": true,
			})
		_:
			pass


## Builds a fresh run without playing it. Use this when the presentation layer
## drives spins interactively.
func start_run(run_seed: int, options: RunOptions = null) -> RunState:
	var state: RunState = RunState.new(run_seed, _content, _bus, options)
	state.phase = RunState.Phase.SETUP
	_bus.emit_event(EffectBus.Event.RUN_STARTED, {
		"seed": run_seed, "cash": state.economy.cash, "debt": state.economy.debt,
	})
	# The machine as it ships: hardware already bolted on, the reel already
	# leaned. Through acquire, so the room fits the modules and the tallies
	# start, and before the floor opens so the first draw is on this reel.
	for fitted: StringName in state.options.starting_artifacts:
		var artifact: ArtifactDef = _content.artifact_by_id(fitted)
		if artifact != null and not state.owns(fitted):
			state.acquire(artifact)
	for key: Variant in state.options.weight_shifts:
		state.add_weight_shift(StringName(String(key)), int(state.options.weight_shifts[key]))
	# A challenge can hand a verb over before any floor does. Announced the
	# way a floor would, so the interface puts it on screen the same way.
	for early: StringName in state.options.early_systems:
		if Systems.ORDER.has(early) and state.options.allows_system(early) \
				and state.grant_system(early):
			_bus.emit_event(EffectBus.Event.SYSTEM_GRANTED, {
				"system": String(early), "title": Systems.title(early),
				"brief": Systems.brief(early), "floor": state.floor_index,
			})
	begin_floor(state)
	return state


## Plays a run to its end and returns the final state.
##
## A won run is put the House's offer, through [member stay_policy]; a batch
## told to stay plays on past the last floor until an ante is missed.
func simulate_run(run_seed: int, options: RunOptions = null) -> RunState:
	var state: RunState = start_run(run_seed, options)
	var guard: int = 0
	while true:
		while not state.is_over():
			step(state)
			guard += 1
			if guard > 100000:
				push_error("SimEngine: run %d failed to terminate" % run_seed)
				_end_run(state, RunState.Phase.LOST, &"nonterminating")
				return state
		if (state.phase == RunState.Phase.WON and stay_policy.is_valid()
				and bool(stay_policy.call(state)) and stay_at_table(state)):
			continue
		break
	return state


## Advances the run by one unit of play: one spin, or one floor transition.
func step(state: RunState) -> void:
	_enter(&"step", [])
	_do_step(state)
	_leave()


func _do_step(state: RunState) -> void:
	if state.is_over():
		return
	if state.phase == RunState.Phase.SHOPPING:
		leave_shop(state)
		return
	if state.phase == RunState.Phase.SIGNING:
		var choice: int = 0
		if contract_policy.is_valid():
			choice = int(contract_policy.call(state, state.contract_offers))
		if not sign_contract(state, choice):
			sign_contract(state, 0)
		return
	# A board mid-decision is the next unit of play, not the next spin: an
	# automated run has to work the nudges and the ladder through the same
	# public calls a player would, or the lab measures a game nobody plays.
	if state.decision == RunState.Decision.NUDGE:
		_run_nudges(state)
		return
	if state.decision == RunState.Decision.GAMBLE:
		_run_gamble(state)
		return
	if state.spins_remaining <= 0:
		_close_floor(state)
		return
	if launder_policy.is_valid() and bool(launder_policy.call(state)):
		launder(state)
	if vault_policy.is_valid():
		vault_policy.call(self, state)
	if works_policy.is_valid():
		works_policy.call(self, state)
	if stake_policy.is_valid():
		set_stake(state, int(stake_policy.call(state)))
	# The floor can be left before the clock runs out, for chips. Asked before
	# the spin, because the spin is what the settlement gives up.
	if settle_policy.is_valid() and state.can_settle_early() \
			and bool(settle_policy.call(state)):
		settle_floor(state)
		return
	if hold_policy.is_valid() and state.has_system(Systems.HOLD):
		state.board.clear_holds()
		for reel: int in PackedInt32Array(hold_policy.call(state, state.board)):
			toggle_hold(state, reel)
	if not state.economy.can_afford(state.spin_price()):
		# Give up the luxuries before giving up the run. Being unable to afford
		# the stake and the reel locks you happened to be sitting on is not the
		# same as being out of money, and ending a run on it would be a
		# bookkeeping death rather than a defeat.
		if state.stake > 1:
			set_stake(state, 1)
		if not state.economy.can_afford(state.spin_price()):
			state.board.clear_holds()
		if not state.economy.can_afford(state.spin_price()):
			_close_floor(state)
			return
	spin(state)


## Sets up the floor named by [member RunState.floor_index].
func begin_floor(state: RunState) -> void:
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		_finish_run(state)
		return
	state.phase = RunState.Phase.SPINNING
	state.decision = RunState.Decision.NONE
	state.board.clear_holds()
	# Who the House sends comes before the allowance is counted, because some
	# of them come for the allowance. The watcher it decided on last floor
	# arrives first; the boss is drawn after, and never the same person.
	state.watcher = state.notice_pending
	state.notice_pending = null
	state.boss = BossEngine.choose(state, floor_def)
	if state.boss != null and state.watcher != null and state.boss.id == state.watcher.id:
		state.boss = BossEngine.choose(state, floor_def)
		if state.boss != null and state.boss.id == state.watcher.id:
			state.boss = null
	state.bosses_faced.append(state.boss.id if state.boss != null else &"")
	state.floor_spins = 0
	state.boss_collected = false
	if BossEngine.stake_frozen(state):
		state.stake = 1
	state.mark_reel_dirty()
	state.spins_remaining = maxi(1, floor_def.spins + ArtifactEngine.spin_bonus(state)
			+ state.options.bonus_spins + ContractEngine.spins_delta(state)
			+ BossEngine.spins_delta(state))
	state.floor_spins_total = state.spins_remaining
	# Announced before FLOOR_STARTED so the interface can put the new verb on
	# screen as the floor opens rather than a beat into it.
	for granted: StringName in floor_def.grants:
		# A challenge can keep a verb from ever arriving. The floor opens all
		# the same; it simply has nothing new to hand over.
		if not state.options.allows_system(granted):
			continue
		if state.grant_system(granted):
			_bus.emit_event(EffectBus.Event.SYSTEM_GRANTED, {
				"system": String(granted),
				"title": Systems.title(granted),
				"brief": Systems.brief(granted),
				"floor": floor_def.index,
			})
	var opened: Dictionary = {
		"floor": floor_def.index,
		"name": floor_def.display_name,
		"ante": _ante_for(state, floor_def),
		"spins": state.spins_remaining,
		"environment": floor_def.environment_id,
		"description": floor_def.description,
	}
	opened.merge(boss_payload(state))
	_bus.emit_event(EffectBus.Event.FLOOR_STARTED, opened)


## Who is on the floor, for the payload that opens it. Empty strings when
## nobody was sent, so a listener can read the keys without checking first.
func boss_payload(state: RunState) -> Dictionary:
	var boss: BossDef = state.boss
	var watcher: BossDef = state.watcher
	return {
		"boss": String(boss.id) if boss != null else "",
		"boss_name": boss.display_name if boss != null else "",
		"boss_intro": boss.intro if boss != null else "",
		"boss_tell": boss.tell if boss != null else "",
		"watcher": String(watcher.id) if watcher != null else "",
		"watcher_name": watcher.display_name if watcher != null else "",
		"watcher_intro": watcher.intro if watcher != null else "",
		"watcher_tell": watcher.tell if watcher != null else "",
	}


## Takes a single spin. Assumes the player can afford it.
##
## The reels stopping is no longer the end of a spin. The board can owe the
## player nudges, and a paying board can be doubled instead of banked, so this
## leaves the run at a decision point and [method collect] is what actually
## moves the credits. When the run has neither system yet — floor one, before
## the machine has taught anyone anything — the two happen in the same call and
## a spin behaves exactly as it always did.
func spin(state: RunState) -> SpinBoard:
	_enter(&"spin", [])
	var out: SpinBoard = _do_spin(state)
	_leave()
	return out


func _do_spin(state: RunState) -> SpinBoard:
	state.economy.debit(state.spin_price(), &"spin_cost")
	if ArtifactEngine.refunds_spin(state):
		_bus.emit_event(EffectBus.Event.ARTIFACT_TRIGGERED, {
			"artifact": &"spin_refund", "effect": "SPIN_REFUND",
			"spins_remaining": state.spins_remaining,
		})
	else:
		state.spins_remaining -= 1
	state.spins_taken += 1
	state.floor_spins += 1
	if BossEngine.collects_now(state):
		_collect_mid_floor(state)
	if _bus.is_live():
		_bus.emit_event(EffectBus.Event.SPIN_STARTED, {
			"spin": state.spins_taken,
			"spins_remaining": state.spins_remaining,
			"cash": state.economy.cash,
			"stake": state.stake,
			"held": state.board.held.duplicate(),
		})

	_draw_board(state)
	_resolve_board(state, true)
	_announce_board(state)
	_offer_decision(state)
	if state.decision == RunState.Decision.NONE:
		collect(state)
	return state.board


## The collector's round: the vig, charged again halfway through the floor,
## out of the same cash the ante needs. No grace applies — the grace is the
## House's ordinary manners, and this is not one of its ordinary people.
func _collect_mid_floor(state: RunState) -> void:
	state.boss_collected = true
	var serviced: int = state.economy.service_debt(
			state.config.debt_service_percent * maxf(state.options.debt_service_scale, 0.0),
			state.config.debt_default_penalty_percent)
	var collector: BossDef = BossEngine._who(state, BossDef.Rule.VIG_MID_FLOOR)
	_bus.emit_event(EffectBus.Event.BOSS_ACTED, {
		"boss": String(collector.id) if collector != null else "",
		"name": collector.display_name if collector != null else "",
		"serviced": serviced, "cash": state.economy.cash, "debt": state.economy.debt,
	})


## Fills the three rows, redrawing every reel the player has not held.
##
## The payline draws from the reel stream and the band from its own, so holding,
## nudging or widening the window can never move what the payline itself drew.
func _draw_board(state: RunState) -> void:
	var board: SpinBoard = state.board
	board.resize(state.machine_reels())
	var reel: Array[Probability.ReelEntry] = state.reel()
	var weights: PackedInt32Array = state.reel_weights()
	for i: int in board.reel_count():
		if board.is_held(i):
			continue
		var middle: SymbolDef = Probability.draw_weighted(reel, weights, state.reel_rng)
		if middle == null:
			break
		board.set_column(i,
				Probability.draw_weighted(reel, weights, state.band_rng),
				middle,
				Probability.draw_weighted(reel, weights, state.band_rng))
	# Holds are spent by the spin they bought. Leaving them set would let one
	# lucky pair be held for the rest of the floor for free. What they were is
	# kept on the board, because hardware pays for them after the fact.
	board.holds_used = board.held_count()
	board.clear_holds()
	board.nudges = 0
	board.free_nudges = 0
	board.nudges_used = 0
	board.gamble_rung = 0


## Scores the payline as it currently stands and writes the result onto the
## board. Called again, quietly, after every nudge.
func _resolve_board(state: RunState, announce: bool) -> void:
	var board: SpinBoard = state.board
	var rows: Array = board.scoring_rows(state.extra_rows)
	var stake: int = maxi(1, state.stake)
	var total: int = 0
	var base: int = 0
	var flat: float = 0.0
	var chips: int = 0
	var triggered: Array[StringName] = []
	var steps: Array[Dictionary] = []
	# The payline is the row the machine is read by, so its pattern and its
	# multiplier are the ones reported; the bought rows add to the number
	# without taking over what the spin is called.
	board.pattern = Probability.detect_pattern(board.line)
	board.multiplier = 1.0
	for i: int in rows.size():
		var row: Array[SymbolDef] = rows[i]
		var pattern: Probability.Pattern = (board.pattern if i == 0
				else Probability.detect_pattern(row))
		var ctx: ArtifactEngine.SpinContext = ArtifactEngine.evaluate_spin(
				state, row, pattern, announce and i == 0)
		total += ctx.total()
		base += ctx.base_payout
		flat += ctx.flat_bonus
		# The bank pays scrip wherever it stands on a paying row, unmultiplied:
		# the wager is the player's, the scrip is the House's.
		for symbol: SymbolDef in row:
			if symbol != null:
				chips += maxi(0, symbol.chip_value)
		if i == 0:
			board.multiplier = ctx.multiplier * float(stake)
			triggered = ctx.triggered
			steps = ctx.steps.duplicate()
		else:
			# A bought row is one line on the receipt: what it added, not its
			# own arithmetic all over again.
			steps.append({"kind": "row", "label": "Row %d, %s" % [i + 1,
					ArtifactEngine._pattern_label(pattern).to_lower()],
					"text": "+%d" % ctx.total()})
	if stake > 1:
		steps.append({"kind": "stake", "label": "The stake", "text": "x%d" % stake})
	board.payout = total * stake
	board.chips = chips
	board.breakdown = {
		"base": base,
		"flat_bonus": flat,
		"multiplier": board.multiplier,
		"triggered": triggered,
		"stake": stake,
		"rows": rows.size(),
		"chips": chips,
		"steps": steps,
	}


## Tells everyone watching what is standing on the machine.
func _announce_board(state: RunState) -> void:
	if not _bus.is_live():
		return
	var board: SpinBoard = state.board
	for i: int in board.reel_count():
		_bus.emit_event(EffectBus.Event.SYMBOL_LANDED, reel_payload(board, i))
	_bus.emit_event(EffectBus.Event.PATTERN_MATCHED,
			{"pattern": Probability.pattern_name(board.pattern)})
	_bus.emit_event(EffectBus.Event.SPIN_RESOLVED, {
		"payout": board.payout,
		"multiplier": board.multiplier,
		"pattern": Probability.pattern_name(board.pattern),
		"stake": maxi(1, state.stake),
		"chips": board.chips,
	})


## One reel's whole column, with the glyphs and tints riding along so the view
## never has to look a symbol back up. Public: a resumed run announces its
## standing board through it.
func reel_payload(board: SpinBoard, index: int) -> Dictionary:
	var middle: SymbolDef = board.line[index]
	var top: SymbolDef = board.above[index]
	var bottom: SymbolDef = board.below[index]
	return {
		"reel": index,
		"symbol": middle.id if middle != null else &"",
		"value": middle.base_value if middle != null else 0,
		"chip_value": middle.chip_value if middle != null else 0,
		"glyph": middle.glyph if middle != null else "",
		"color": middle.color if middle != null else Color.WHITE,
		"color2": middle.second_color() if middle != null else Color.WHITE,
		"above": top.id if top != null else &"",
		"above_color": top.color if top != null else Color.WHITE,
		"below": bottom.id if bottom != null else &"",
		"below_color": bottom.color if bottom != null else Color.WHITE,
	}


## Works out what the machine owes the player before it pays anything out.
func _offer_decision(state: RunState) -> void:
	var board: SpinBoard = state.board
	if state.has_system(Systems.HOLD):
		_award_nudges(state, board)
		if board.nudges > 0:
			state.decision = RunState.Decision.NUDGE
			_bus.emit_event(EffectBus.Event.NUDGES_AWARDED, {
				"nudges": board.nudges,
				"free": board.free_nudges,
				"pattern": Probability.pattern_name(board.pattern),
			})
			return
	_offer_gamble(state)


## Offers the ladder, or settles when there is nothing to climb with.
func _offer_gamble(state: RunState) -> void:
	var board: SpinBoard = state.board
	if (state.has_system(Systems.GAMBLE) and board.payout > 0
			and board.gamble_rung < state.config.gamble_odds.size()):
		state.decision = RunState.Decision.GAMBLE
		_bus.emit_event(EffectBus.Event.GAMBLE_OFFERED, {
			"payout": board.payout,
			"rung": board.gamble_rung,
			"odds": state.config.gamble_odds[board.gamble_rung],
		})
		return
	state.decision = RunState.Decision.NONE


## Opens the nudge trail on a board that is one symbol short of the whole thing,
## which on a three-reel machine is exactly a pair.
##
## The machine offers every nudge it has; what rations them is the price. Taking
## one costs a spin off the floor's allowance, so a nudge is only worth it when
## the window says it is — and the window is right there, which is the entire
## point of showing three rows instead of one.
static func _award_nudges(state: RunState, board: SpinBoard) -> void:
	board.nudges = 0
	board.free_nudges = 0
	if (board.pattern != Probability.Pattern.PAIR
			and board.pattern != Probability.Pattern.TRIPLE):
		return
	board.nudges = maxi(0, state.config.max_nudges)
	# A bigger wager runs the machine hotter, and hardware can put the trail on
	# the house. This is what makes a raised stake more than a flat multiple of
	# a number you were getting anyway.
	board.free_nudges = ArtifactEngine.nudge_bonus(state) \
			+ ContractEngine.nudge_delta(state)
	if state.stake >= 3:
		board.free_nudges += 1
	board.free_nudges = maxi(0, board.free_nudges)
	board.free_nudges = mini(board.free_nudges, board.nudges)
	if not BossEngine.free_nudges_allowed(state):
		board.free_nudges = 0


## Locks or unlocks [param reel] for the next spin. Returns the new state.
##
## Never every reel: a machine you can freeze whole is a machine that pays the
## same line forever, and the one thing a hold must cost is a spin off the clock.
func toggle_hold(state: RunState, reel: int) -> bool:
	_enter(&"toggle_hold", [reel])
	var out: bool = _do_toggle_hold(state, reel)
	_leave()
	return out


func _do_toggle_hold(state: RunState, reel: int) -> bool:
	if not state.has_system(Systems.HOLD) or state.phase != RunState.Phase.SPINNING:
		return false
	if state.is_deciding() or reel < 0 or reel >= state.board.reel_count():
		return false
	var board: SpinBoard = state.board
	var wanted: bool = not board.held[reel]
	if wanted and board.held_count() >= board.reel_count() - 1:
		return false
	board.held[reel] = wanted
	return wanted


## Spends one nudge on [param reel]. Returns true when the reel actually moved.
##
## A paid nudge takes a spin off the floor's allowance. It can take the last one:
## a player who nudges away their final spin to chase a jackpot has made a real
## decision, and the machine should let them make it.
func nudge(state: RunState, reel: int) -> bool:
	_enter(&"nudge", [reel])
	var out: bool = _do_nudge(state, reel)
	_leave()
	return out


func _do_nudge(state: RunState, reel: int) -> bool:
	if state.decision != RunState.Decision.NUDGE:
		return false
	var board: SpinBoard = state.board
	if not board.can_nudge(reel):
		return false
	var before: int = board.payout
	var free: bool = board.next_nudge_is_free()
	board.nudge(reel, Probability.draw_weighted(
			state.reel(), state.reel_weights(), state.band_rng))
	if not free:
		state.spins_remaining = maxi(0, state.spins_remaining - 1)
	_resolve_board(state, false)
	_bus.emit_event(EffectBus.Event.REEL_NUDGED, {
		"reel": reel,
		"nudges": board.nudges,
		"free": free,
		"spins_remaining": state.spins_remaining,
		"gained": board.payout - before,
		"column": reel_payload(board, reel),
		"payout": board.payout,
		"pattern": Probability.pattern_name(board.pattern),
	})
	if board.nudges <= 0:
		_offer_gamble(state)
		if state.decision == RunState.Decision.NONE:
			collect(state)
	return true


## Walks away from the nudges still owed and moves the spin along.
func decline_nudges(state: RunState) -> void:
	_enter(&"decline_nudges", [])
	_do_decline_nudges(state)
	_leave()


func _do_decline_nudges(state: RunState) -> void:
	if state.decision != RunState.Decision.NUDGE:
		return
	state.board.nudges = 0
	_offer_gamble(state)
	if state.decision == RunState.Decision.NONE:
		collect(state)


## Climbs one rung of the ladder: the board doubles, or it is lost outright.
func gamble(state: RunState) -> bool:
	_enter(&"gamble", [])
	var out: bool = _do_gamble(state)
	_leave()
	return out


func _do_gamble(state: RunState) -> bool:
	if state.decision != RunState.Decision.GAMBLE:
		return false
	var board: SpinBoard = state.board
	var odds: PackedFloat32Array = state.config.gamble_odds
	var rung: int = clampi(board.gamble_rung, 0, odds.size() - 1)
	var chance: float = odds[rung]
	var won: bool = state.gamble_rng.next_float() < chance
	var staked: int = board.payout
	if won:
		board.payout = staked * 2
		board.gamble_rung += 1
	else:
		board.payout = 0
	_bus.emit_event(EffectBus.Event.GAMBLE_RESOLVED, {
		"won": won, "staked": staked, "payout": board.payout,
		"rung": board.gamble_rung, "odds": chance,
	})
	if not won:
		state.decision = RunState.Decision.NONE
		collect(state)
		return false
	_offer_gamble(state)
	if state.decision == RunState.Decision.NONE:
		collect(state)
	return true


## Banks whatever the board is worth and ends the spin.
func collect(state: RunState) -> void:
	_enter(&"collect", [])
	_do_collect(state)
	_leave()


func _do_collect(state: RunState) -> void:
	var board: SpinBoard = state.board
	state.last_line = board.line.duplicate()
	state.last_pattern = board.pattern
	state.last_payout = board.payout
	state.best_payout = maxi(state.best_payout, board.payout)
	state.decision = RunState.Decision.NONE
	state.economy.credit(board.payout, &"payout")
	state.economy.credit_chips(board.chips, &"symbols")
	# The ledgers move only now, with the credits: a spin previewed, nudged
	# and rescored a dozen times is still one spin to the hardware counting.
	var lit: Array[ArtifactDef] = ArtifactEngine.record_spin(state, board)
	_observe_heat(state, board.payout)
	_observe_notice(state, board.payout)
	if not _bus.is_live():
		return
	for artifact: ArtifactDef in lit:
		_bus.emit_event(EffectBus.Event.ARTIFACT_TRIGGERED, {
			"artifact": artifact.id, "effect": "AWAKENED",
			"multiplier": artifact.magnitude, "flat_bonus": 0.0,
		})
	var payload: Dictionary = board.breakdown.duplicate()
	payload["payout"] = board.payout
	payload["pattern"] = Probability.pattern_name(board.pattern)
	payload["nudges_used"] = board.nudges_used
	payload["gamble_rung"] = board.gamble_rung
	_bus.emit_event(EffectBus.Event.PAYOUT_CALCULATED, payload)


## The House notices a loud spin — [member BalanceConfig.notice_par_multiple]
## pars in one — and answers by sending one more of its people to the next
## floor, decided and announced now so the player can see it coming, and
## can point at the spin that caused it. One notice at a time: a floor with
## a watcher already promised is not promised another. The House acts
## against success, not on a schedule; this is where "rigged" is mechanical.
func _observe_notice(state: RunState, payout: int) -> void:
	if state.options.no_bosses or state.notice_pending != null:
		return
	if float(payout) < par_for(state) * state.config.notice_par_multiple:
		return
	var next_floor: FloorDef = state.floor_at(state.floor_index + 1)
	if next_floor == null:
		return
	var pool: Array[BossDef] = BossEngine.pool_for(_content, next_floor.index)
	if pool.is_empty():
		return
	state.notice_pending = pool[state.boss_rng.next_int(0, pool.size() - 1)]
	state.notices += 1
	state.noticed_floor = state.floor_index
	state.noticed_payout = payout
	if not _bus.is_live():
		return
	_bus.emit_event(EffectBus.Event.HOUSE_NOTICED, notice_payload(state))


## What the House has decided, for the event and for a resumed run.
func notice_payload(state: RunState) -> Dictionary:
	var who: BossDef = state.notice_pending
	return {
		"watcher": String(who.id) if who != null else "",
		"name": who.display_name if who != null else "",
		"intro": who.intro if who != null else "",
		"tell": who.tell if who != null else "",
		"floor": state.floor_index + 1,
		"payout": state.noticed_payout,
		"notices": state.notices,
		"ante": ante_for(state),
	}


## Folds a settled spin into the House's count and announces what it changed.
func _observe_heat(state: RunState, payout: int) -> void:
	if not state.has_system(Systems.HEAT):
		return
	var before: HeatEngine.Measure = HeatEngine.current(state)
	var after: HeatEngine.Measure = HeatEngine.observe(state, payout, par_for(state))
	if not _bus.is_live():
		return
	_bus.emit_event(EffectBus.Event.HEAT_CHANGED, {
		"heat": state.heat,
		"measure": int(after),
		"name": HeatEngine.measure_name(after),
		"changed": after != before,
		"launder_price": HeatEngine.launder_price(state),
		# The pit boss puts the ante up mid-floor, so the number every readout
		# is showing has to travel with the event that changed it.
		"ante": ante_for(state),
	})


## Has a word with someone. Costs cash and buys the count back down.
##
## The floor's only lever that is not "win less": a player who has built a
## machine that cannot help winning big can still pay to keep the room calm.
func launder(state: RunState) -> bool:
	_enter(&"launder", [])
	var out: bool = _do_launder(state)
	_leave()
	return out


func _do_launder(state: RunState) -> bool:
	if not state.has_system(Systems.HEAT) or state.is_deciding():
		return false
	if state.heat <= 0.0:
		return false
	var price: int = HeatEngine.launder_price(state)
	if not state.economy.can_afford(price):
		return false
	state.economy.debit(price, &"launder")
	var before: HeatEngine.Measure = HeatEngine.current(state)
	state.heat = maxf(0.0, state.heat - state.config.launder_relief)
	if HeatEngine.current(state) != before:
		state.mark_reel_dirty()
	_bus.emit_event(EffectBus.Event.HEAT_CHANGED, {
		"heat": state.heat,
		"measure": int(HeatEngine.current(state)),
		"name": HeatEngine.measure_name(HeatEngine.current(state)),
		"changed": true,
		"paid": price,
		"launder_price": HeatEngine.launder_price(state),
	})
	return true


## Bolts another reel onto the machine. Permanent, and priced off the ante so
## the works stay a serious decision however deep the run has got.
##
## Fitted between spins as readily as between floors. The engine room is every
## machine on the floor wired to yours, and stripping one for parts halfway
## through a floor — with the ante still to find — is the decision that floor is
## made of. Confined to the draft it would have been a mechanic the player got
## to use exactly once.
func buy_reel(state: RunState) -> bool:
	_enter(&"buy_reel", [])
	var out: bool = _do_buy_reel(state)
	_leave()
	return out


func _do_buy_reel(state: RunState) -> bool:
	return _buy_works(state, true)


## Widens the window so another row of the band pays.
func buy_row(state: RunState) -> bool:
	_enter(&"buy_row", [])
	var out: bool = _do_buy_row(state)
	_leave()
	return out


func _do_buy_row(state: RunState) -> bool:
	return _buy_works(state, false)


func _buy_works(state: RunState, is_reel: bool) -> bool:
	if not state.has_system(Systems.EXPANSION) or state.is_deciding():
		return false
	if state.phase != RunState.Phase.SHOPPING and state.phase != RunState.Phase.SPINNING:
		return false
	var owned: int = state.extra_reels if is_reel else state.extra_rows
	var ceiling: int = (state.config.max_extra_reels if is_reel
			else state.config.max_extra_rows)
	if owned >= ceiling:
		return false
	var price: int = works_price(state, is_reel)
	if not state.economy.can_afford(price):
		return false
	state.economy.debit(price, &"works")
	if is_reel:
		state.extra_reels += 1
		state.board.resize(state.machine_reels())
	else:
		state.extra_rows += 1
	_bus.emit_event(EffectBus.Event.WORKS_FITTED, {
		"kind": "reel" if is_reel else "row",
		"paid": price,
		"reels": state.machine_reels(),
		"rows": state.scoring_rows(),
	})
	return true


## What the next reel or row costs, as a share of the ante in front of the
## player right now.
func works_price(state: RunState, is_reel: bool) -> int:
	var floor_def: FloorDef = state.current_floor()
	var ante: float = float(floor_def.ante) if floor_def != null else 100.0
	var owned: int = state.extra_reels if is_reel else state.extra_rows
	var percent: float = (state.config.reel_cost_percent if is_reel
			else state.config.row_cost_percent)
	return maxi(1, int(round(ante * percent / 100.0 * float(1 + owned))))


## Sets the wager for the next spin, clamped to what the machine allows.
func set_stake(state: RunState, level: int) -> bool:
	_enter(&"set_stake", [level])
	var out: bool = _do_set_stake(state, level)
	_leave()
	return out


func _do_set_stake(state: RunState, level: int) -> bool:
	if not state.has_system(Systems.STAKE) or state.is_deciding():
		return false
	var wanted: int = clampi(level, 1, maxi(1, state.config.max_stake))
	if wanted > 1 and BossEngine.stake_frozen(state):
		return false
	if wanted == state.stake:
		return false
	state.stake = wanted
	return true


## Spends every nudge the policy wants, then moves the spin along.
func _run_nudges(state: RunState) -> void:
	var guard: int = 0
	while (state.decision == RunState.Decision.NUDGE
			and state.board.nudges > 0 and guard < 8):
		guard += 1
		var reel: int = -1
		if nudge_policy.is_valid():
			reel = int(nudge_policy.call(state, state.board))
		if reel < 0 or not nudge(state, reel):
			break
	if state.decision == RunState.Decision.NUDGE:
		decline_nudges(state)


func _run_gamble(state: RunState) -> void:
	var guard: int = 0
	while state.decision == RunState.Decision.GAMBLE and guard < 8:
		guard += 1
		var climb: bool = false
		if gamble_policy.is_valid():
			climb = bool(gamble_policy.call(state, state.board))
		if not climb:
			collect(state)
			return
		if not gamble(state):
			return


## Settles the ante and either ends the run or opens the shop.
func _close_floor(state: RunState) -> void:
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		_finish_run(state)
		return
	ArtifactEngine.apply_floor_interest(state)
	# The vault compounds before the bills, so a floor's deposit is working by
	# the time the vig is charged rather than a floor behind it.
	var vault_earned: int = state.economy.accrue_vault_interest(
			state.config.vault_interest_percent
			+ ArtifactEngine.vault_yield_bonus(state))
	if vault_earned > 0:
		_announce_vault(state, 0, vault_earned)
	# The vig comes first: debt is serviced out of the same cash the ante needs,
	# which is what makes carrying it a real decision rather than a late bill.
	var serviced: int = 0
	var grace: int = 0 if state.options.no_grace else state.config.debt_grace_floors
	if state.floors_cleared >= grace:
		serviced = state.economy.service_debt(
				state.config.debt_service_percent * maxf(state.options.debt_service_scale, 0.0),
				state.config.debt_default_penalty_percent)
	var ante: int = _ante_for(state, floor_def)
	if not state.economy.settle_ante(ante):
		_end_run(state, RunState.Phase.LOST, &"ante_unpaid")
		return
	state.economy.accrue_debt_interest(maxf(0.0, floor_def.debt_interest_percent
			+ ContractEngine.debt_interest_percent(state) + state.options.interest_delta))
	ArtifactEngine.apply_debt_paydown(state)
	# The House pays the floor in its own scrip: the stipend, a chip for every
	# spin the player did not need, and interest on what was held over. This
	# is the whole of what the draft is bought with.
	var spins_left: int = state.spins_left_at_settle
	state.spins_left_at_settle = 0
	var stipend: int = maxi(0, floor_def.chips)
	var bonus: int = state.settle_bonus(spins_left)
	state.economy.credit_chips(stipend, &"floor")
	state.economy.credit_chips(bonus, &"settle")
	var interest: int = state.economy.accrue_chip_interest(
			state.config.chip_interest_per, state.config.chip_interest_cap)
	state.floors_cleared += 1
	state.set_contract(null)
	state.boss = null
	state.watcher = null
	# The count is a floor's worth of attention. A new floor is a new room —
	# unless the audit says the House remembers.
	state.heat *= clampf(state.options.heat_carry, 0.0, 1.0)
	state.heat_ante_percent = 0.0
	state.mark_reel_dirty()
	_bus.emit_event(EffectBus.Event.FLOOR_CLEARED, {
		"floor": floor_def.index,
		"cash": state.economy.cash,
		"debt": state.economy.debt,
		"serviced": serviced,
		"chips": state.economy.chips,
		"stipend": stipend,
		"chips_bonus": bonus,
		"chips_interest": interest,
		"spins_left": spins_left,
	})
	# Dawn. The House closes after so many floors after hours, and a run still
	# standing walks out: the win the table could not take back.
	if state.endless and state.floors_cleared - _content.floors.size() \
			>= state.config.endless_floors_max:
		_end_run(state, RunState.Phase.WON, &"dawn")
		return
	state.phase = RunState.Phase.SHOPPING
	_run_shop(state, floor_def)


func _advance_floor(state: RunState) -> void:
	state.floor_index += 1
	if state.current_floor() == null:
		_finish_run(state)
		return
	begin_floor(state)


## The run is out of floors: the player wins only by clearing the debt.
func _finish_run(state: RunState) -> void:
	# The vault opens when the run does. Credits locked away still count towards
	# clearing the debt; they simply could never have paid an ante on the way.
	if state.economy.vault > 0:
		state.economy.withdraw(state.economy.vault)
		_announce_vault(state, 0, 0)
	if state.economy.debt > 0:
		if state.economy.cash < state.economy.debt:
			_end_run(state, RunState.Phase.LOST, &"debt_unpaid")
			return
		state.debt_repaid = state.economy.debt
		state.economy.debit(state.economy.debt, &"debt_repaid")
		state.economy.debt = 0
	_end_run(state, RunState.Phase.WON, &"cleared_all_floors")


## Takes the House's offer: the debt back, and the floors past the last.
##
## Only a run that has won can stay — the offer is the counter-offer to
## clearing the debt — and only once. What was just repaid is lent again, so
## the vig resumes and the clock keeps running, and the floors from here are
## made by [Endless], each ante compounding on the last, until one is missed.
## What the leaderboard then measures is how long a run lasted at a table
## that gets dearer every floor.
func stay_at_table(state: RunState) -> bool:
	_enter(&"stay_at_table", [])
	var out: bool = _do_stay_at_table(state)
	_leave()
	return out


func _do_stay_at_table(state: RunState) -> bool:
	if state.phase != RunState.Phase.WON or state.endless:
		return false
	if state.end_reason != &"cleared_all_floors":
		return false
	state.endless = true
	state.end_reason = &""
	state.earned_at_win = state.economy.lifetime_earned
	state.economy.debt = state.debt_repaid
	_bus.emit_event(EffectBus.Event.TABLE_KEPT, {
		"debt": state.economy.debt,
		"floor": state.floor_index,
		"floors_cleared": state.floors_cleared,
	})
	begin_floor(state)
	return true


## Leaves the floor with spins still on the clock, and is paid in chips for
## every one of them. The one move that ends a floor on purpose.
##
## Only when the purse already covers the vig and the ante: settling is not
## a way to skip a bill, it is a way to stop chasing credits the run does not
## need and take the House's scrip instead. The spins given up are credits
## the next floor will not have; the chips are the draft it will. That trade
## is the reason there are two currencies at all.
func settle_floor(state: RunState) -> bool:
	_enter(&"settle_floor", [])
	var out: bool = _do_settle_floor(state)
	_leave()
	return out


func _do_settle_floor(state: RunState) -> bool:
	if not state.can_settle_early():
		return false
	state.spins_left_at_settle = state.spins_remaining
	state.floors_settled_early += 1
	_bus.emit_event(EffectBus.Event.FLOOR_SETTLED_EARLY, {
		"floor": state.floor_index,
		"spins_left": state.spins_remaining,
		"chips": state.settle_bonus(state.spins_remaining),
		"cash": state.economy.cash,
	})
	state.spins_remaining = 0
	_close_floor(state)
	return true


func _end_run(state: RunState, phase: RunState.Phase, reason: StringName) -> void:
	state.phase = phase
	state.end_reason = reason
	_bus.emit_event(EffectBus.Event.RUN_ENDED, state.snapshot())


## What the floor in front of the player actually costs, with every contract
## clause and everything the House has added since the floor opened.
##
## Public because the interface has to name the same number the simulation will
## charge. It used to work it out again from the floor's authored ante and a
## discount, which meant a contract or a pit boss left the prompt quoting a
## price nobody was going to be charged.
func ante_for(state: RunState) -> int:
	return state.ante_due()


func _ante_for(state: RunState, floor_def: FloorDef) -> int:
	return state.ante_due_for(floor_def)


## Buys offer [param index]. Returns true when the purchase happened.
##
## This is the whole purchase API: the UI calls it on a click, and the headless
## shop policy calls it too, so an automated batch and a human play the same
## code path rather than two implementations that drift apart.
func buy_offer(state: RunState, index: int) -> bool:
	_enter(&"buy_offer", [index])
	var out: bool = _do_buy_offer(state, index)
	_leave()
	return out


func _do_buy_offer(state: RunState, index: int) -> bool:
	if not state.can_buy(index):
		return false
	state.economy.debit_chips(state.shop_prices[index], &"artifact")
	state.acquire(state.shop_offers[index])
	state.shop_offers.remove_at(index)
	state.shop_prices.remove_at(index)
	return true


## Closes the shop and moves to the next floor.
func leave_shop(state: RunState) -> void:
	_enter(&"leave_shop", [])
	_do_leave_shop(state)
	_leave()


func _do_leave_shop(state: RunState) -> void:
	if state.phase != RunState.Phase.SHOPPING:
		return
	state.chips_left_at_drafts.append(state.economy.chips)
	state.shop_offers.clear()
	state.shop_prices.clear()
	state.press_offers.clear()
	# The back office sits between the draft and the stairs. Nobody goes up to
	# the next floor without signing for it.
	if _office_is_open(state):
		_offer_contracts(state)
		if not state.contract_offers.is_empty():
			state.phase = RunState.Phase.SIGNING
			return
	_advance_floor(state)


## True when the coming floor has to be signed for.
##
## Also true on the way *into* the floor that opens the office. Waiting for the
## system to be granted meant the first signature happened on the way out of
## that floor rather than into it, which cost the mechanic a third of the run it
## gets to exist for — the back office is that floor's whole idea, and it was
## being used twice.
func _office_is_open(state: RunState) -> bool:
	var next_floor: FloorDef = state.floor_at(state.floor_index + 1)
	if next_floor == null:
		return false
	return (state.has_system(Systems.CONTRACTS)
			or next_floor.grants.has(Systems.CONTRACTS))


## Puts three of the house's standing offers on the table.
func _offer_contracts(state: RunState) -> void:
	var next_index: int = state.floor_index + 1
	var pool: Array[ContractDef] = []
	for contract: ContractDef in _content.contracts:
		if contract.min_floor <= next_index:
			pool.append(contract)
	state.contract_offers = []
	for i: int in mini(CONTRACT_SLOTS, pool.size()):
		var index: int = state.shop_rng.next_int(0, pool.size() - 1)
		state.contract_offers.append(pool[index])
		pool.remove_at(index)
	if state.contract_offers.is_empty():
		return
	var offered: Array[String] = []
	for contract: ContractDef in state.contract_offers:
		offered.append(String(contract.id))
	_bus.emit_event(EffectBus.Event.CONTRACTS_OFFERED, {
		"floor": next_index, "contracts": offered,
	})


## Signs offer [param index] and opens the floor it was signed for.
func sign_contract(state: RunState, index: int) -> bool:
	_enter(&"sign_contract", [index])
	var out: bool = _do_sign_contract(state, index)
	_leave()
	return out


func _do_sign_contract(state: RunState, index: int) -> bool:
	if state.phase != RunState.Phase.SIGNING:
		return false
	if index < 0 or index >= state.contract_offers.size():
		return false
	var signed: ContractDef = state.contract_offers[index]
	state.set_contract(signed)
	state.contract_offers.clear()
	_bus.emit_event(EffectBus.Event.CONTRACT_SIGNED, {
		"contract": signed.id,
		"name": signed.display_name,
		"terms": signed.terms(),
	})
	_advance_floor(state)
	return true


func _run_shop(state: RunState, floor_def: FloorDef) -> void:
	state.shop_rerolls = 0
	_stock_shop(state, floor_def)
	_bus.emit_event(EffectBus.Event.SHOP_OPENED, {
		"floor": floor_def.index,
		"offers": _offer_ids(state),
		"prices": state.shop_prices.duplicate(),
		"reroll_price": state.reroll_price(),
		"market": state.has_system(Systems.MARKET),
	})
	# With no policy the shop stays open for a player to work; a batch run hands
	# it to the policy immediately.
	if not shop_policy.is_valid():
		return
	# Banking comes before buying. The collateral competes with the draft for the
	# same credits, and a policy that shopped first would only ever bank what
	# the draft could not find a use for — which in this economy is nothing.
	if vault_policy.is_valid():
		vault_policy.call(self, state)
	while not state.shop_offers.is_empty():
		var choice: int = int(shop_policy.call(state, state.shop_offers, state.shop_prices))
		if not buy_offer(state, choice):
			break
	# The market is a second pass over the same draft: a stale trinket sold to
	# afford what is on the table, the slate when the purse cannot, one reroll
	# when nothing was worth having. A batch that never did any of those was
	# measuring floor two with its verb switched off.
	if market_policy.is_valid():
		market_policy.call(self, state)
	if press_policy.is_valid():
		press_policy.call(self, state)
	if works_policy.is_valid():
		works_policy.call(self, state)


## Fills the draft's slots and prices them, and sets the press's jobs.
func _stock_shop(state: RunState, floor_def: FloorDef) -> void:
	state.shop_offers = _roll_offers(state, floor_def)
	state.shop_prices = []
	for artifact: ArtifactDef in state.shop_offers:
		state.shop_prices.append(price_for(state, artifact))
		state.offers_seen[artifact.id] = int(state.offers_seen.get(artifact.id, 0)) + 1
	state.press_offers = _roll_press(state)


## Two jobs for the press, from the shop's own stream: a strike, a print or
## a gilding, each naming a symbol. The skull is only ever struck; the wild
## is never printed more; gilding names a family where there is one, so the
## fruit is gilded together.
func _roll_press(state: RunState) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	var symbols: Array[SymbolDef] = _content.symbols
	if symbols.is_empty():
		return jobs
	var guard: int = 0
	while jobs.size() < PRESS_JOBS and guard < 12:
		guard += 1
		var symbol: SymbolDef = symbols[state.shop_rng.next_int(0, symbols.size() - 1)]
		var roll: int = state.shop_rng.next_int(0, 2)
		var job: Dictionary = {}
		if symbol.is_curse or roll == 0:
			# Striking a symbol the reel barely carries is a job with nothing
			# in it; the press only offers to strike what is there.
			if Probability.symbol_chance(state.reel(), symbol.id) < 0.03:
				continue
			job = {"kind": "strike", "symbol": String(symbol.id),
					"magnitude": PRESS_STRIKE_WEIGHT, "price": PRESS_STRIKE_PRICE}
		elif roll == 1 and not symbol.is_wild:
			job = {"kind": "print", "symbol": String(symbol.id),
					"magnitude": PRESS_PRINT_WEIGHT, "price": PRESS_PRINT_PRICE}
		else:
			var target: StringName = symbol.family if symbol.family != &"" else symbol.id
			job = {"kind": "gild", "symbol": String(target),
					"magnitude": PRESS_GILD_CREDITS, "price": PRESS_GILD_PRICE}
		var repeat: bool = false
		for other: Dictionary in jobs:
			if other["kind"] == job["kind"] and other["symbol"] == job["symbol"]:
				repeat = true
		if not repeat:
			jobs.append(job)
	return jobs


## Runs the press job at [param index]: strikes a symbol off the reel a
## little, prints more of one, or gilds what one pays. Permanent for the run,
## like the works, and paid in chips, like the draft. The reel is the
## player's to edit; this is the verb that edits it.
func press(state: RunState, index: int) -> bool:
	_enter(&"press", [index])
	var out: bool = _do_press(state, index)
	_leave()
	return out


func _do_press(state: RunState, index: int) -> bool:
	if not state.can_press(index):
		return false
	var job: Dictionary = state.press_offers[index]
	var symbol: StringName = StringName(String(job.get("symbol", "")))
	var magnitude: int = int(job.get("magnitude", 0))
	var kind: String = String(job.get("kind", ""))
	match kind:
		"strike":
			state.add_weight_shift(symbol, -magnitude)
		"print":
			state.add_weight_shift(symbol, magnitude)
		"gild":
			state.symbol_value_shifts[symbol] = int(state.symbol_value_shifts.get(symbol, 0)) \
					+ magnitude
		_:
			return false
	state.economy.debit_chips(int(job.get("price", 0)), &"press")
	state.press_offers.remove_at(index)
	state.press_jobs += 1
	_bus.emit_event(EffectBus.Event.PRESS_RUN, {
		"kind": kind, "symbol": String(symbol), "magnitude": magnitude,
		"chance": Probability.symbol_chance(state.reel(), symbol),
		"floor": state.floor_index,
	})
	return true


## What [param artifact] costs this run today, in chips. Public so the
## interface and the market quote the same number the engine charges.
func price_for(state: RunState, artifact: ArtifactDef) -> int:
	return state.price_of(artifact)


func _offer_ids(state: RunState) -> Array[String]:
	var ids: Array[String] = []
	for artifact: ArtifactDef in state.shop_offers:
		ids.append(String(artifact.id))
	return ids


## Picks this floor's shop stock, without repeats, from the shop stream.
##
## Weighted towards what this floor has only just made available. A flat draw
## from everything unlocked so far means that by floor six the stock is mostly
## floor-one trinkets, and the draft stops being the thing you were looking
## forward to on the way up the stairs.
func _roll_offers(state: RunState, floor_def: FloorDef) -> Array[ArtifactDef]:
	var pool: Array[ArtifactDef] = []
	var weights: PackedInt32Array = PackedInt32Array()
	for artifact: ArtifactDef in _content.artifacts:
		if (artifact.min_floor <= floor_def.index and not state.owns(artifact.id)
				and state.options.allows(artifact)):
			pool.append(artifact)
			weights.append(maxi(1, FRESH_WEIGHT
					- (floor_def.index - artifact.min_floor) * STALE_STEP))
	var offers: Array[ArtifactDef] = []
	var slots: int = mini(floor_def.shop_slots, pool.size())
	for i: int in slots:
		var index: int = state.shop_rng.weighted_index(weights)
		if index < 0:
			break
		offers.append(pool[index])
		pool.remove_at(index)
		weights.remove_at(index)
	return offers


## Buys a fresh set of offers. Each reroll in the same draft costs more than the
## last, so rerolling is a budget you spend rather than a button you hold.
func reroll_shop(state: RunState) -> bool:
	_enter(&"reroll_shop", [])
	var out: bool = _do_reroll_shop(state)
	_leave()
	return out


func _do_reroll_shop(state: RunState) -> bool:
	if not state.has_system(Systems.MARKET) or state.phase != RunState.Phase.SHOPPING:
		return false
	var price: int = state.reroll_price()
	if not state.economy.can_afford_chips(price):
		return false
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		return false
	state.economy.debit_chips(price, &"reroll")
	state.shop_rerolls += 1
	state.rerolls_total += 1
	_stock_shop(state, floor_def)
	_bus.emit_event(EffectBus.Event.SHOP_REROLLED, {
		"paid": price,
		"next_price": state.reroll_price(),
		"offers": _offer_ids(state),
		"prices": state.shop_prices.duplicate(),
	})
	return true


## Sells owned hardware back for a fraction of its chip price.
##
## Half at most, and exactly the inverse of acquiring it: a build has to be
## able to change its mind, but not for free, and a permanent reel change must
## not be launderable through the market for chips.
func sell(state: RunState, index: int) -> int:
	_enter(&"sell", [index])
	var out: int = _do_sell(state, index)
	_leave()
	return out


func _do_sell(state: RunState, index: int) -> int:
	if not state.has_system(Systems.MARKET) or state.phase != RunState.Phase.SHOPPING:
		return 0
	if index < 0 or index >= state.owned.size():
		return 0
	var artifact: ArtifactDef = state.owned[index]
	var refund: int = state.sellback_of(artifact)
	if not state.release(artifact):
		return 0
	state.economy.credit_chips(refund, &"sellback")
	_bus.emit_event(EffectBus.Event.ARTIFACT_SOLD, {
		"artifact": artifact.id, "refund": refund, "floor": state.floor_index,
	})
	return refund


## Locks cash away where it earns interest and cannot settle an ante.
##
## The whole decision is liquidity. Every credit in the vault is a credit that
## cannot cover the ante that is about to fall due, and it competes with buying
## hardware and with paying down a debt compounding faster than the vault pays.
func deposit(state: RunState, amount: int) -> int:
	_enter(&"deposit", [amount])
	var out: int = _do_deposit(state, amount)
	_leave()
	return out


func _do_deposit(state: RunState, amount: int) -> int:
	if not state.has_system(Systems.VAULT) or state.is_deciding():
		return 0
	var moved: int = state.economy.deposit(amount)
	if moved > 0:
		_announce_vault(state, moved, 0)
	return moved


## Takes cash back out. Between floors it comes out whole; mid-floor the house
## keeps a share, which is the price of having changed your mind in a panic.
func withdraw(state: RunState, amount: int) -> int:
	_enter(&"withdraw", [amount])
	var out: int = _do_withdraw(state, amount)
	_leave()
	return out


func _do_withdraw(state: RunState, amount: int) -> int:
	if not state.has_system(Systems.VAULT) or state.is_deciding():
		return 0
	var fee: float = (0.0 if state.phase == RunState.Phase.SHOPPING
			else state.config.vault_break_percent)
	var reaching: int = state.economy.withdraw(amount, fee)
	if reaching > 0:
		_announce_vault(state, -reaching, 0)
	return reaching


func _announce_vault(state: RunState, delta: int, interest: int) -> void:
	_bus.emit_event(EffectBus.Event.VAULT_CHANGED, {
		"vault": state.economy.vault,
		"cash": state.economy.cash,
		"delta": delta,
		"interest": interest,
	})


## Takes an offer without paying for it and puts the bill on the debt with a
## markup: the one way in the game to turn future trouble into present power.
func buy_on_slate(state: RunState, index: int) -> bool:
	_enter(&"buy_on_slate", [index])
	var out: bool = _do_buy_on_slate(state, index)
	_leave()
	return out


func _do_buy_on_slate(state: RunState, index: int) -> bool:
	if not state.has_system(Systems.MARKET) or state.phase != RunState.Phase.SHOPPING:
		return false
	if index < 0 or index >= state.shop_offers.size():
		return false
	var artifact: ArtifactDef = state.shop_offers[index]
	# A chip price, converted to the House's money at the House's rate, with
	# the markup on top: the one way to turn chips you do not have into debt.
	var owed: int = state.slate_price(index)
	state.economy.debt += owed
	state.acquire(artifact)
	state.shop_offers.remove_at(index)
	state.shop_prices.remove_at(index)
	_bus.emit_event(EffectBus.Event.SLATE_SIGNED, {
		"artifact": artifact.id, "owed": owed, "debt": state.economy.debt,
	})
	return true


## What one spin has to be worth for the floor to be cleared on time.
##
## Public because the count is measured against it as well as the automated
## player's decisions, and both have to be reading the same number.
static func par_for(state: RunState) -> float:
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null or floor_def.spins <= 0:
		return 1.0
	return maxf(1.0, float(floor_def.ante) / float(floor_def.spins))
