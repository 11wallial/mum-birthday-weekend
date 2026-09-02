## What a competent player does, so the lab measures the game people play.
##
## Every one of these drives the same public [SimEngine] calls a person's hands
## do — [method SimEngine.toggle_hold], [method SimEngine.nudge], the ladder,
## the vault, the works — which is what stops a batch measuring a stripped-down
## version of the game. [method SimEngine.clear_policies] hands them all back
## when a human is at the machine.
##
## Not an optimal player, and not a naive one either. It used to keep back a
## single credit in the draft, which meant it arrived on every floor with
## nothing and left three of the seven systems switched off in every batch the
## lab ever ran — so the numbers it reported were for a different game.
class_name AutoPlayer
extends RefCounted

## Base value a symbol has to reach before this player will pay to hold a pair
## of it. Bells and up; fruit is not worth a lock.
const HOLD_FLOOR: int = 4
## Share of the coming ante kept out of the draft. Small: in this economy cash
## does not compound and a bought artifact does, so a buyer who hoards loses to
## one who spends. The slack is there for the vault and the works, not safety.
const SHOP_RESERVE: float = 0.05
## Share of the coming ante kept liquid: enough to spin for the ante with, not
## enough to cover it. Covering it in cash would mean never banking anything,
## which is how the vault ends up as scenery.
const VAULT_LIQUIDITY: float = 0.35
## Spins left on the floor before paying the fee to break the vault.
const VAULT_PANIC_SPINS: int = 3
## Share of the ante in play held back before fitting works. Well under the
## whole thing: the machine is expected to earn the rest of it, which is the bet
## the engine room is asking the player to make.
const WORKS_RESERVE: float = 0.55
## Floors an artifact has to be behind the run before this player will sell it
## to afford something on the table. Three: the machine has outgrown it.
const STALE_FLOORS: int = 3
## Most of the purse a reroll may cost before the draft is simply left as it is.
const REROLL_SHARE: float = 0.1
## What the slate may put on the debt, as a share of the coming ante, and how
## far the whole debt may stand above that ante before this player stops
## signing. Modest, because the slate is the one move in the game that turns
## future trouble into present power, and a policy that leaned on it would
## report the win rate of a run that ends on the final bill every time.
const SLATE_SHARE: float = 0.5
const SLATE_DEBT_ANTES: float = 2.0

## Which opinion covers which verb, by the static method that holds it. The
## parity suite holds this to [constant SimEngine.PLAYER_VERBS]: a verb added
## to the engine without a row here fails the build, because a batch would
## otherwise measure a game with that verb switched off — which is exactly how
## the vault and the works went unplayed for every batch before Milestone 2.
const COVERAGE: Dictionary = {
	&"toggle_hold": &"hold",
	&"nudge": &"nudge",
	&"gamble": &"gamble",
	&"set_stake": &"stake",
	&"deposit": &"vault",
	&"withdraw": &"vault",
	&"buy_reel": &"works",
	&"buy_row": &"works",
	&"launder": &"launder",
	&"buy_offer": &"shop",
	&"reroll_shop": &"market",
	&"sell": &"market",
	&"buy_on_slate": &"market",
	&"sign_contract": &"contract",
}


## Buys the most expensive artifact it can afford while keeping a share of the
## coming ante in hand.
##
## Not an optimal buyer, but not a spendthrift either. It used to keep back a
## single credit, which meant it arrived on every floor with nothing and made
## the vault and the works unreachable in every batch the lab ever ran — so the
## numbers it reported were for a game with three of its systems switched off.
static func shop(state: RunState, offers: Array[ArtifactDef], prices: Array[int]) -> int:
	var best: int = -1
	var best_price: int = -1
	var reserve: int = maxi(state.config.spin_cost,
			int(round(float(_next_ante(state)) * SHOP_RESERVE)))
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
static func nudge(state: RunState, board: SpinBoard) -> int:
	# A free nudge only has to be an improvement; a paid one has to be worth a
	# spin, which is the price the machine is actually charging for it.
	var floor_gain: int = 0 if board.next_nudge_is_free() else int(ceil(SimEngine.par_for(state)))
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
static func gamble(state: RunState, board: SpinBoard) -> bool:
	if board.gamble_rung > 0:
		return false
	return board.payout < SimEngine.par_for(state)


## Raises the stake only when the floor is nearly out and the ante is not met —
## the desperation raise, which is the one every player actually makes.
static func stake(state: RunState) -> int:
	if not state.has_system(Systems.STAKE):
		return 1
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null or state.spins_remaining > 3:
		return 1
	if state.economy.cash >= floor_def.ante:
		return 1
	return mini(2, maxi(1, state.config.max_stake))




## Holds the reels making up the best group on the board, so the spin that
## follows only redraws what is not already working.
##
## Never on a full line — there would be nothing left to redraw — and never on a
## board that pays nothing, where holding a lone symbol is superstition rather
## than strategy.
static func hold(state: RunState, board: SpinBoard) -> PackedInt32Array:
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


## Signs whichever contract adds the most spins, and otherwise the first.
##
## A crude reader of the terms, on purpose: the lab is measuring whether the
## contracts are survivable, not whether an optimal signatory can exploit one.
static func contract(_state: RunState, offers: Array[ContractDef]) -> int:
	var best: int = 0
	var best_spins: int = -99
	for i: int in offers.size():
		var spins: int = 0
		for entry: Dictionary in offers[i].clauses():
			if int(entry["clause"]) == int(ContractDef.Clause.SPINS):
				spins += int(entry["magnitude"])
		if spins > best_spins:
			best_spins = spins
			best = i
	return best


## Banks the ante float between floors, and breaks the vault to save the run.
##
## A player who waits for spare cash never uses the vault, because in this
## economy there is never any: every credit is wanted by the draft. What the
## vault is actually for is the float — the ante money that would otherwise sit
## in the purse doing nothing between being won and being paid. Banked, it buys
## a multiplier on every spin of the floor it is needed for, and the bet is that
## the machine earns the ante back before the ante falls due.
static func vault(engine: SimEngine, state: RunState) -> void:
	if not state.has_system(Systems.VAULT):
		return
	if state.phase == RunState.Phase.SPINNING:
		_break_vault_if_short(engine, state)
		return
	if state.phase != RunState.Phase.SHOPPING:
		return
	# Only while there are floors left to be paid a dividend on. On the last one
	# a deposit is just cash that cannot be spent.
	var next_floor: FloorDef = state.content.floor_at(state.floor_index + 1)
	if next_floor == null:
		return
	# Never past the point the collateral caps out, and never below what it
	# takes to keep spinning towards the ante.
	var useful: int = int(round(float(next_floor.ante)
			* state.config.vault_collateral_antes * state.config.vault_collateral_cap))
	var keep: int = int(round(float(next_floor.ante) * VAULT_LIQUIDITY))
	engine.deposit(state, mini(state.economy.cash - keep,
			maxi(0, useful - state.economy.vault)))


## Takes the collateral back out, fee and all, when the floor is nearly over and
## the ante is still short. Losing a quarter of the reserve beats losing the run.
static func _break_vault_if_short(engine: SimEngine, state: RunState) -> void:
	if state.economy.vault <= 0 or state.spins_remaining > VAULT_PANIC_SPINS:
		return
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		return
	var short: int = floor_def.ante - state.economy.cash
	if short <= 0:
		return
	# Asking for more than the shortfall, because the break fee is taken out of
	# what comes back rather than added to what is asked for.
	engine.withdraw(state, int(ceil(float(short)
			/ maxf(0.05, 1.0 - state.config.vault_break_percent / 100.0))))


## Fits whatever the machine can be paid for without giving up the ante.
##
## Rows before reels: a row pays on every spin that follows it, where a reel
## widens the line and makes the whole thing harder to match.
static func works(engine: SimEngine, state: RunState) -> void:
	if not state.has_system(Systems.EXPANSION):
		return
	# Mid-floor the ante is still to be found, so the whole of it stays covered;
	# between floors the machine has a floor's worth of spins to earn it back.
	var floor_def: FloorDef = state.current_floor()
	var due: int = floor_def.ante if floor_def != null else 0
	var share: float = (WORKS_RESERVE if state.phase == RunState.Phase.SHOPPING
			else 1.0)
	var reserve: int = int(round(float(due) * share))
	var guard: int = 0
	while guard < 4:
		guard += 1
		if state.economy.cash - engine.works_price(state, false) >= reserve \
				and engine.buy_row(state):
			continue
		if state.economy.cash - engine.works_price(state, true) >= reserve \
				and engine.buy_reel(state):
			continue
		break


## Works the market after the draft has been shopped: sells a trinket the run
## has outgrown to afford the thing on the table, signs the slate when the purse
## cannot, and buys one reroll when nothing on offer was worth having.
##
## Three habits a person actually has, each kept modest. The point is not to
## play the market well — it is that a batch which never rerolls, never sells
## and never signs the slate is measuring floor two with its verb switched off,
## and the lab had done exactly that since the market was built.
static func market(engine: SimEngine, state: RunState) -> void:
	if not state.has_system(Systems.MARKET) or state.phase != RunState.Phase.SHOPPING:
		return
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		return
	var reserve: int = maxi(state.config.spin_cost,
			int(round(float(_next_ante(state)) * SHOP_RESERVE)))
	# Nothing bought and nothing affordable: one cheap reroll, then shop again.
	if (state.shop_offers.size() >= floor_def.shop_slots and state.shop_rerolls == 0
			and state.reroll_price() <= int(float(state.economy.cash) * REROLL_SHARE)
			and _dearest_affordable(state, reserve) < 0):
		if engine.reroll_shop(state):
			var choice: int = shop(state, state.shop_offers, state.shop_prices)
			while choice >= 0 and engine.buy_offer(state, choice):
				choice = shop(state, state.shop_offers, state.shop_prices)
	var wanted: int = _dearest_offer(state)
	if wanted < 0:
		return
	var short: int = state.shop_prices[wanted] - (state.economy.cash - reserve)
	# Only for the thing the purse nearly covers. Nobody signs for what they
	# could not have afforded half of.
	if short <= 0 or short * 2 > state.shop_prices[wanted]:
		return
	# A trinket from floors ago, sold to close the gap.
	var stale: int = _stalest_owned(state)
	if stale >= 0 and _sellback(state, state.owned[stale]) >= short:
		if engine.sell(state, stale) > 0 and engine.buy_offer(state, wanted):
			return
	# Or the slate, once, when the bill it adds stays small next to the ante.
	var owed: int = int(ceil(float(state.shop_prices[wanted])
			* (1.0 + state.config.slate_markup_percent / 100.0)))
	var next_ante: int = _next_ante(state)
	if (owed <= int(float(next_ante) * SLATE_SHARE)
			and state.economy.debt + owed <= int(float(next_ante) * SLATE_DEBT_ANTES)):
		engine.buy_on_slate(state, wanted)


## Index of the dearest offer on the table, or -1 with nothing on it.
static func _dearest_offer(state: RunState) -> int:
	var best: int = -1
	for i: int in state.shop_offers.size():
		if best < 0 or state.shop_prices[i] > state.shop_prices[best]:
			best = i
	return best


## Index of the dearest offer the purse can cover past [param reserve], or -1.
static func _dearest_affordable(state: RunState, reserve: int) -> int:
	var best: int = -1
	for i: int in state.shop_offers.size():
		if state.shop_prices[i] > state.economy.cash - reserve:
			continue
		if best < 0 or state.shop_prices[i] > state.shop_prices[best]:
			best = i
	return best


## Index into the owned artifacts of the cheapest one the run has outgrown by
## [constant STALE_FLOORS] floors, or -1 when nothing is that old.
static func _stalest_owned(state: RunState) -> int:
	var best: int = -1
	for i: int in state.owned.size():
		var artifact: ArtifactDef = state.owned[i]
		if artifact.min_floor > state.floors_cleared - STALE_FLOORS:
			continue
		if best < 0 or artifact.cost < state.owned[best].cost:
			best = i
	return best


## What the market would hand back for [param artifact] today.
static func _sellback(state: RunState, artifact: ArtifactDef) -> int:
	var floor_def: FloorDef = state.current_floor()
	var worth: int = state.economy.price_of(artifact, state.config,
			state.floors_cleared, floor_def.ante if floor_def != null else 0)
	return maxi(1, int(floor(float(worth) * state.config.sellback_percent / 100.0)))


## Has a word once the House has started taking the good symbols off the reel.
## Skimming is survivable; a cold deck is what actually ends the run.
static func launder(state: RunState) -> bool:
	if HeatEngine.current(state) < HeatEngine.Measure.COLD_DECK:
		return false
	var price: int = HeatEngine.launder_price(state)
	var floor_def: FloorDef = state.current_floor()
	var reserve: int = floor_def.ante if floor_def != null else 0
	return state.economy.cash - price >= reserve


## The ante waiting on the next floor, or this one when there is no next.
static func _next_ante(state: RunState) -> int:
	var next_floor: FloorDef = state.content.floor_at(state.floor_index + 1)
	if next_floor == null:
		next_floor = state.current_floor()
	return next_floor.ante if next_floor != null else 0
