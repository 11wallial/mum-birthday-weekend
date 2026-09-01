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

## Base value a symbol has to reach before the automated policy will pay to
## hold a pair of it. Bells and up; fruit is not worth a lock.
const HOLD_FLOOR: int = 4

var _content: ContentDB
var _bus: EffectBus


func _init(content: ContentDB = null, bus: EffectBus = null) -> void:
	_content = content if content != null else ContentDB.shared()
	_bus = bus if bus != null else EffectBus.new()
	shop_policy = Callable(SimEngine, "default_shop_policy")
	nudge_policy = Callable(SimEngine, "default_nudge_policy")
	gamble_policy = Callable(SimEngine, "default_gamble_policy")
	stake_policy = Callable(SimEngine, "default_stake_policy")
	hold_policy = Callable(SimEngine, "default_hold_policy")


func get_bus() -> EffectBus:
	return _bus


## Builds a fresh run without playing it. Use this when the presentation layer
## drives spins interactively.
func start_run(run_seed: int, options: RunOptions = null) -> RunState:
	var state: RunState = RunState.new(run_seed, _content, _bus, options)
	state.phase = RunState.Phase.SETUP
	_bus.emit_event(EffectBus.Event.RUN_STARTED, {
		"seed": run_seed, "cash": state.economy.cash, "debt": state.economy.debt,
	})
	begin_floor(state)
	return state


## Plays a run to its end and returns the final state.
func simulate_run(run_seed: int, options: RunOptions = null) -> RunState:
	var state: RunState = start_run(run_seed, options)
	var guard: int = 0
	while not state.is_over():
		step(state)
		guard += 1
		if guard > 100000:
			push_error("SimEngine: run %d failed to terminate" % run_seed)
			_end_run(state, RunState.Phase.LOST, &"nonterminating")
			break
	return state


## Advances the run by one unit of play: one spin, or one floor transition.
func step(state: RunState) -> void:
	if state.is_over():
		return
	if state.phase == RunState.Phase.SHOPPING:
		leave_shop(state)
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
	if stake_policy.is_valid():
		set_stake(state, int(stake_policy.call(state)))
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
	state.spins_remaining = (floor_def.spins + ArtifactEngine.spin_bonus(state)
			+ state.options.bonus_spins)
	# Announced before FLOOR_STARTED so the interface can put the new verb on
	# screen as the floor opens rather than a beat into it.
	for granted: StringName in floor_def.grants:
		if state.grant_system(granted):
			_bus.emit_event(EffectBus.Event.SYSTEM_GRANTED, {
				"system": String(granted),
				"title": Systems.title(granted),
				"brief": Systems.brief(granted),
				"floor": floor_def.index,
			})
	_bus.emit_event(EffectBus.Event.FLOOR_STARTED, {
		"floor": floor_def.index,
		"name": floor_def.display_name,
		"ante": _ante_for(state, floor_def),
		"spins": state.spins_remaining,
		"environment": floor_def.environment_id,
		"description": floor_def.description,
	})


## Takes a single spin. Assumes the player can afford it.
##
## The reels stopping is no longer the end of a spin. The board can owe the
## player nudges, and a paying board can be doubled instead of banked, so this
## leaves the run at a decision point and [method collect] is what actually
## moves the credits. When the run has neither system yet — floor one, before
## the machine has taught anyone anything — the two happen in the same call and
## a spin behaves exactly as it always did.
func spin(state: RunState) -> SpinBoard:
	state.economy.debit(state.spin_price(), &"spin_cost")
	if ArtifactEngine.refunds_spin(state):
		_bus.emit_event(EffectBus.Event.ARTIFACT_TRIGGERED, {
			"artifact": &"spin_refund", "effect": "SPIN_REFUND",
			"spins_remaining": state.spins_remaining,
		})
	else:
		state.spins_remaining -= 1
	state.spins_taken += 1
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


## Fills the three rows, redrawing every reel the player has not held.
##
## The payline draws from the reel stream and the band from its own, so holding,
## nudging or widening the window can never move what the payline itself drew.
func _draw_board(state: RunState) -> void:
	var board: SpinBoard = state.board
	board.resize(state.config.reel_count)
	var reel: Array[Probability.ReelEntry] = state.reel()
	for i: int in board.reel_count():
		if board.is_held(i):
			continue
		var middle: SymbolDef = Probability.draw_symbol(reel, state.reel_rng)
		if middle == null:
			break
		board.set_column(i,
				Probability.draw_symbol(reel, state.band_rng),
				middle,
				Probability.draw_symbol(reel, state.band_rng))
	# Holds are spent by the spin they bought. Leaving them set would let one
	# lucky pair be held for the rest of the floor for free.
	board.clear_holds()
	board.nudges = 0
	board.free_nudges = 0
	board.nudges_used = 0
	board.gamble_rung = 0


## Scores the payline as it currently stands and writes the result onto the
## board. Called again, quietly, after every nudge.
func _resolve_board(state: RunState, announce: bool) -> void:
	var board: SpinBoard = state.board
	board.pattern = Probability.detect_pattern(board.line)
	var ctx: ArtifactEngine.SpinContext = ArtifactEngine.evaluate_spin(
			state, board.line, board.pattern, announce)
	var stake: int = maxi(1, state.stake)
	board.multiplier = ctx.multiplier * float(stake)
	board.payout = ctx.total() * stake
	board.breakdown = {
		"base": ctx.base_payout,
		"flat_bonus": ctx.flat_bonus,
		"multiplier": board.multiplier,
		"triggered": ctx.triggered,
		"stake": stake,
	}


## Tells everyone watching what is standing on the machine.
func _announce_board(state: RunState) -> void:
	if not _bus.is_live():
		return
	var board: SpinBoard = state.board
	for i: int in board.reel_count():
		_bus.emit_event(EffectBus.Event.SYMBOL_LANDED, _reel_payload(board, i))
	_bus.emit_event(EffectBus.Event.PATTERN_MATCHED,
			{"pattern": Probability.pattern_name(board.pattern)})
	_bus.emit_event(EffectBus.Event.SPIN_RESOLVED, {
		"payout": board.payout,
		"multiplier": board.multiplier,
		"pattern": Probability.pattern_name(board.pattern),
		"stake": maxi(1, state.stake),
	})


## One reel's whole column, with the glyphs and tints riding along so the view
## never has to look a symbol back up.
func _reel_payload(board: SpinBoard, index: int) -> Dictionary:
	var middle: SymbolDef = board.line[index]
	var top: SymbolDef = board.above[index]
	var bottom: SymbolDef = board.below[index]
	return {
		"reel": index,
		"symbol": middle.id if middle != null else &"",
		"value": middle.base_value if middle != null else 0,
		"glyph": middle.glyph if middle != null else "",
		"color": middle.color if middle != null else Color.WHITE,
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
	board.free_nudges = ArtifactEngine.nudge_bonus(state)
	if state.stake >= 3:
		board.free_nudges += 1
	board.free_nudges = mini(board.free_nudges, board.nudges)


## Locks or unlocks [param reel] for the next spin. Returns the new state.
##
## Never every reel: a machine you can freeze whole is a machine that pays the
## same line forever, and the one thing a hold must cost is a spin off the clock.
func toggle_hold(state: RunState, reel: int) -> bool:
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
	if state.decision != RunState.Decision.NUDGE:
		return false
	var board: SpinBoard = state.board
	if not board.can_nudge(reel):
		return false
	var before: int = board.payout
	var free: bool = board.next_nudge_is_free()
	board.nudge(reel, Probability.draw_symbol(state.reel(), state.band_rng))
	if not free:
		state.spins_remaining = maxi(0, state.spins_remaining - 1)
	_resolve_board(state, false)
	_bus.emit_event(EffectBus.Event.REEL_NUDGED, {
		"reel": reel,
		"nudges": board.nudges,
		"free": free,
		"spins_remaining": state.spins_remaining,
		"gained": board.payout - before,
		"column": _reel_payload(board, reel),
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
	if state.decision != RunState.Decision.NUDGE:
		return
	state.board.nudges = 0
	_offer_gamble(state)
	if state.decision == RunState.Decision.NONE:
		collect(state)


## Climbs one rung of the ladder: the board doubles, or it is lost outright.
func gamble(state: RunState) -> bool:
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
	var board: SpinBoard = state.board
	state.last_line = board.line.duplicate()
	state.last_pattern = board.pattern
	state.last_payout = board.payout
	state.decision = RunState.Decision.NONE
	state.economy.credit(board.payout, &"payout")
	if not _bus.is_live():
		return
	var payload: Dictionary = board.breakdown.duplicate()
	payload["payout"] = board.payout
	payload["pattern"] = Probability.pattern_name(board.pattern)
	payload["nudges_used"] = board.nudges_used
	payload["gamble_rung"] = board.gamble_rung
	_bus.emit_event(EffectBus.Event.PAYOUT_CALCULATED, payload)


## Sets the wager for the next spin, clamped to what the machine allows.
func set_stake(state: RunState, level: int) -> bool:
	if not state.has_system(Systems.STAKE) or state.is_deciding():
		return false
	var wanted: int = clampi(level, 1, maxi(1, state.config.max_stake))
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
	# The vig comes first: debt is serviced out of the same cash the ante needs,
	# which is what makes carrying it a real decision rather than a late bill.
	var serviced: int = 0
	if state.floors_cleared >= state.config.debt_grace_floors:
		serviced = state.economy.service_debt(
				state.config.debt_service_percent, state.config.debt_default_penalty_percent)
	var ante: int = _ante_for(state, floor_def)
	if not state.economy.settle_ante(ante):
		_end_run(state, RunState.Phase.LOST, &"ante_unpaid")
		return
	state.economy.accrue_debt_interest(floor_def.debt_interest_percent)
	ArtifactEngine.apply_debt_paydown(state)
	state.floors_cleared += 1
	_bus.emit_event(EffectBus.Event.FLOOR_CLEARED, {
		"floor": floor_def.index,
		"cash": state.economy.cash,
		"debt": state.economy.debt,
		"serviced": serviced,
	})
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
	if state.economy.debt > 0:
		if state.economy.cash < state.economy.debt:
			_end_run(state, RunState.Phase.LOST, &"debt_unpaid")
			return
		state.economy.debit(state.economy.debt, &"debt_repaid")
		state.economy.debt = 0
	_end_run(state, RunState.Phase.WON, &"cleared_all_floors")


func _end_run(state: RunState, phase: RunState.Phase, reason: StringName) -> void:
	state.phase = phase
	state.end_reason = reason
	_bus.emit_event(EffectBus.Event.RUN_ENDED, state.snapshot())


func _ante_for(state: RunState, floor_def: FloorDef) -> int:
	var discount: float = ArtifactEngine.ante_discount_percent(state)
	var ante: float = float(floor_def.ante) * state.options.ante_scale
	return maxi(0, int(round(ante * (1.0 - discount / 100.0))))


## Buys offer [param index]. Returns true when the purchase happened.
##
## This is the whole purchase API: the UI calls it on a click, and the headless
## shop policy calls it too, so an automated batch and a human play the same
## code path rather than two implementations that drift apart.
func buy_offer(state: RunState, index: int) -> bool:
	if not state.can_buy(index):
		return false
	state.economy.debit(state.shop_prices[index], &"artifact")
	state.acquire(state.shop_offers[index])
	state.shop_offers.remove_at(index)
	state.shop_prices.remove_at(index)
	return true


## Closes the shop and moves to the next floor.
func leave_shop(state: RunState) -> void:
	if state.phase != RunState.Phase.SHOPPING:
		return
	state.shop_offers.clear()
	state.shop_prices.clear()
	_advance_floor(state)


func _run_shop(state: RunState, floor_def: FloorDef) -> void:
	var offers: Array[ArtifactDef] = _roll_offers(state, floor_def)
	state.shop_offers = offers
	state.shop_prices = []
	for artifact: ArtifactDef in offers:
		state.shop_prices.append(
				state.economy.price_of(artifact, state.config, state.floors_cleared))
	var offer_ids: Array[String] = []
	for artifact: ArtifactDef in offers:
		offer_ids.append(String(artifact.id))
	_bus.emit_event(EffectBus.Event.SHOP_OPENED, {
		"floor": floor_def.index, "offers": offer_ids, "prices": state.shop_prices.duplicate(),
	})
	# With no policy the shop stays open for a player to work; a batch run hands
	# it to the policy immediately.
	if not shop_policy.is_valid():
		return
	while not state.shop_offers.is_empty():
		var choice: int = int(shop_policy.call(state, state.shop_offers, state.shop_prices))
		if not buy_offer(state, choice):
			break


## Picks this floor's shop stock, without repeats, from the shop stream.
func _roll_offers(state: RunState, floor_def: FloorDef) -> Array[ArtifactDef]:
	var pool: Array[ArtifactDef] = []
	for artifact: ArtifactDef in _content.artifacts:
		if (artifact.min_floor <= floor_def.index and not state.owns(artifact.id)
				and state.options.allows(artifact)):
			pool.append(artifact)
	var offers: Array[ArtifactDef] = []
	var slots: int = mini(floor_def.shop_slots, pool.size())
	for i: int in slots:
		var index: int = state.shop_rng.next_int(0, pool.size() - 1)
		offers.append(pool[index])
		pool.remove_at(index)
	return offers


## Buys the most expensive artifact it can afford, keeping a one-spin reserve.
## Deliberately naive: the balance lab measures the floor a mediocre player hits,
## not the ceiling an optimal one reaches.
static func default_shop_policy(state: RunState, offers: Array[ArtifactDef], prices: Array[int]) -> int:
	var best: int = -1
	var best_price: int = -1
	var reserve: int = state.config.spin_cost
	for i: int in offers.size():
		if prices[i] > state.economy.cash - reserve:
			continue
		if prices[i] > best_price:
			best_price = prices[i]
			best = i
	return best


## Nudges the reel that gains the most, and only when the gain beats what the
## spin it costs would have been worth.
##
## Deliberately greedy rather than optimal: it looks one nudge ahead at the
## window it can see, which is what a person reading the machine actually does.
static func default_nudge_policy(state: RunState, board: SpinBoard) -> int:
	# A free nudge only has to be an improvement; a paid one has to be worth a
	# spin, which is the price the machine is actually charging for it.
	var floor_gain: int = 0 if board.next_nudge_is_free() else int(ceil(_par(state)))
	var best: int = -1
	var best_gain: int = floor_gain
	for i: int in board.reel_count():
		if not board.can_nudge(i):
			continue
		var gain: int = ArtifactEngine.score_line(state, board.preview_nudge(i)) \
				* maxi(1, state.stake) - board.payout
		if gain > best_gain:
			best_gain = gain
			best = i
	return best


## Climbs one rung when the board has not paid its way, and never twice.
##
## Not an optimal gambler and not a teetotaller: the lab has to exercise the
## ladder to measure it, but a policy that climbed to the top every time would
## report the variance of a slot machine played by a maniac.
static func default_gamble_policy(state: RunState, board: SpinBoard) -> bool:
	if board.gamble_rung > 0:
		return false
	return board.payout < _par(state)


## Raises the stake only when the floor is nearly out and the ante is not met —
## the desperation raise, which is the one every player actually makes.
static func default_stake_policy(state: RunState) -> int:
	if not state.has_system(Systems.STAKE):
		return 1
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null or state.spins_remaining > 3:
		return 1
	if state.economy.cash >= floor_def.ante:
		return 1
	return mini(2, maxi(1, state.config.max_stake))


## What one spin has to be worth for the floor to be cleared on time.
static func _par(state: RunState) -> float:
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null or floor_def.spins <= 0:
		return 1.0
	return maxf(1.0, float(floor_def.ante) / float(floor_def.spins))


## Holds the reels making up the best group on the board, so the spin that
## follows only redraws what is not already working.
##
## Never on a full line — there would be nothing left to redraw — and never on a
## board that pays nothing, where holding a lone symbol is superstition rather
## than strategy.
static func default_hold_policy(state: RunState, board: SpinBoard) -> PackedInt32Array:
	var keep: PackedInt32Array = PackedInt32Array()
	if board.pattern != Probability.Pattern.PAIR \
			and board.pattern != Probability.Pattern.TRIPLE:
		return keep
	# Two lemons are not worth paying to keep. A fresh line might be two sevens,
	# and locks are charged for, so holding cheap fruit is the classic mistake
	# this policy has to not make if the lab is to mean anything.
	if not state.economy.can_afford(state.spin_price() * 2):
		return keep
	var groups: Dictionary = {}
	for i: int in board.reel_count():
		var symbol: SymbolDef = board.line[i]
		if symbol == null:
			continue
		var key: StringName = symbol.family if symbol.family != &"" else symbol.id
		var members: PackedInt32Array = groups.get(key, PackedInt32Array())
		members.append(i)
		groups[key] = members
	for key: StringName in groups:
		var members: PackedInt32Array = groups[key]
		if members.size() <= keep.size() or members.size() >= board.reel_count():
			continue
		var symbol: SymbolDef = board.line[members[0]]
		if symbol == null or symbol.is_curse or symbol.base_value < HOLD_FLOOR:
			continue
		keep = members
	return keep
