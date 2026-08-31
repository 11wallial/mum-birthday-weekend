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

var _content: ContentDB
var _bus: EffectBus


func _init(content: ContentDB = null, bus: EffectBus = null) -> void:
	_content = content if content != null else ContentDB.shared()
	_bus = bus if bus != null else EffectBus.new()
	shop_policy = Callable(SimEngine, "default_shop_policy")


func get_bus() -> EffectBus:
	return _bus


## Builds a fresh run without playing it. Use this when the presentation layer
## drives spins interactively.
func start_run(run_seed: int) -> RunState:
	var state: RunState = RunState.new(run_seed, _content, _bus)
	state.phase = RunState.Phase.SETUP
	_bus.emit_event(EffectBus.Event.RUN_STARTED, {"seed": run_seed, "cash": state.economy.cash})
	begin_floor(state)
	return state


## Plays a run to its end and returns the final state.
func simulate_run(run_seed: int) -> RunState:
	var state: RunState = start_run(run_seed)
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
		_advance_floor(state)
		return
	if state.spins_remaining <= 0:
		_close_floor(state)
		return
	if not state.economy.can_afford(state.config.spin_cost):
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
	state.spins_remaining = floor_def.spins + ArtifactEngine.spin_bonus(state)
	_bus.emit_event(EffectBus.Event.FLOOR_STARTED, {
		"floor": floor_def.index,
		"name": floor_def.display_name,
		"ante": _ante_for(state, floor_def),
		"spins": state.spins_remaining,
		"environment": floor_def.environment_id,
	})


## Takes a single spin. Assumes the player can afford it.
func spin(state: RunState) -> ArtifactEngine.SpinContext:
	state.economy.debit(state.config.spin_cost, &"spin_cost")
	state.spins_remaining -= 1
	state.spins_taken += 1
	_bus.emit_event(EffectBus.Event.SPIN_STARTED, {
		"spin": state.spins_taken,
		"spins_remaining": state.spins_remaining,
		"cash": state.economy.cash,
	})

	var line: Array[SymbolDef] = Probability.spin_line(state.reel(), state.config.reel_count, state.reel_rng)
	for i: int in line.size():
		_bus.emit_event(EffectBus.Event.SYMBOL_LANDED, {
			"reel": i, "symbol": line[i].id, "value": line[i].base_value,
		})

	var pattern: Probability.Pattern = Probability.detect_pattern(line)
	_bus.emit_event(EffectBus.Event.PATTERN_MATCHED, {"pattern": Probability.pattern_name(pattern)})

	var ctx: ArtifactEngine.SpinContext = ArtifactEngine.evaluate_spin(state, line, pattern)
	var payout: int = ctx.total()
	state.last_line = line
	state.last_pattern = pattern
	state.last_payout = payout
	state.economy.credit(payout, &"payout")
	_bus.emit_event(EffectBus.Event.PAYOUT_CALCULATED, {
		"payout": payout,
		"base": ctx.base_payout,
		"flat_bonus": ctx.flat_bonus,
		"multiplier": ctx.multiplier,
		"pattern": Probability.pattern_name(pattern),
		"triggered": ctx.triggered,
	})
	return ctx


## Settles the ante and either ends the run or opens the shop.
func _close_floor(state: RunState) -> void:
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		_finish_run(state)
		return
	ArtifactEngine.apply_floor_interest(state)
	var ante: int = _ante_for(state, floor_def)
	if not state.economy.settle_ante(ante):
		_end_run(state, RunState.Phase.LOST, &"ante_unpaid")
		return
	state.economy.accrue_debt_interest(floor_def.debt_interest_percent)
	state.floors_cleared += 1
	_bus.emit_event(EffectBus.Event.FLOOR_CLEARED, {
		"floor": floor_def.index,
		"cash": state.economy.cash,
		"debt": state.economy.debt,
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
	return maxi(0, int(round(float(floor_def.ante) * (1.0 - discount / 100.0))))


func _run_shop(state: RunState, floor_def: FloorDef) -> void:
	var offers: Array[ArtifactDef] = _roll_offers(state, floor_def)
	var prices: Array[int] = []
	for artifact: ArtifactDef in offers:
		prices.append(state.economy.price_of(artifact, state.config, state.floors_cleared))
	var offer_ids: Array[String] = []
	for artifact: ArtifactDef in offers:
		offer_ids.append(String(artifact.id))
	_bus.emit_event(EffectBus.Event.SHOP_OPENED, {
		"floor": floor_def.index, "offers": offer_ids, "prices": prices,
	})
	if offers.is_empty() or not shop_policy.is_valid():
		return
	var choice: int = int(shop_policy.call(state, offers, prices))
	while choice >= 0 and choice < offers.size() and state.economy.can_afford(prices[choice]):
		state.economy.debit(prices[choice], &"artifact")
		state.acquire(offers[choice])
		offers.remove_at(choice)
		prices.remove_at(choice)
		if offers.is_empty():
			break
		choice = int(shop_policy.call(state, offers, prices))


## Picks this floor's shop stock, without repeats, from the shop stream.
func _roll_offers(state: RunState, floor_def: FloorDef) -> Array[ArtifactDef]:
	var pool: Array[ArtifactDef] = []
	for artifact: ArtifactDef in _content.artifacts:
		if artifact.min_floor <= floor_def.index and not state.owns(artifact.id):
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
