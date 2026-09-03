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
## Share of the coming ante this player wants in hand, over the vig and the
## ante of the floor it is on, before it will consider settling the floor
## early. The spins it gives up are credits it will not have upstairs.
const SETTLE_RESERVE: float = 0.25
## The reserve in force, so the sweep can move it without editing this file.
static var settle_reserve: float = SETTLE_RESERVE
## Most of the purse a reroll may cost before the draft is simply left as it
## is, and the fewest chips this player rerolls on at all.
const REROLL_SHARE: float = 0.5
const REROLL_FLOOR: int = 4
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
## What the slate may put on the debt, as a share of the coming ante, and how
## far the whole debt may stand above that ante before this player stops
## signing. Modest, because the slate is the one move in the game that turns
## future trouble into present power, and a policy that leaned on it would
## report the win rate of a run that ends on the final bill every time.
const SLATE_SHARE: float = 0.5
const SLATE_DEBT_ANTES: float = 2.0
## How much dearer an offer from the build this player has already started
## looks to it, as a share of its price. A lean, not a rule: it only ever
## decides between things the purse could cover anyway.
const BUILD_LEAN: float = 0.5

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
	&"stay_at_table": &"stay",
	&"settle_floor": &"settle",
	&"press": &"press_jobs",
	&"pay_doorman": &"doorman",
	&"buy_chit": &"chits",
	&"use_chit": &"use_chits",
}


## Buys the most expensive artifact it can afford while keeping a share of the
## coming ante in hand, leaning towards the build it has already started.
##
## Not an optimal buyer, but not a spendthrift either. It used to keep back a
## single credit, which meant it arrived on every floor with nothing and made
## the vault and the works unreachable in every batch the lab ever ran — so the
## numbers it reported were for a game with three of its systems switched off.
## The lean is what a person does after their second purchase: chase the thing
## they are making. A buyer that went by price alone would assemble a machine
## at random, and the lab would be reporting the win rate of no build at all.
static func shop(state: RunState, offers: Array[ArtifactDef], prices: Array[int]) -> int:
	var best: int = -1
	var best_score: float = -1.0
	var chased: StringName = chased_archetype(state)
	for i: int in offers.size():
		# Chips buy nothing but the draft, so nothing is held back from it.
		if prices[i] > state.economy.chips:
			continue
		var score: float = float(prices[i])
		if chased != &"" and offers[i].archetype == chased:
			score *= 1.0 + BUILD_LEAN
		if score > best_score:
			best_score = score
			best = i
	return best


## The build this run has the most of, or empty before it has started one.
## Ties go to the earlier name, so a batch is reproducible.
static func chased_archetype(state: RunState) -> StringName:
	var counts: Dictionary = {}
	for artifact: ArtifactDef in state.owned:
		if artifact.archetype != &"":
			counts[artifact.archetype] = int(counts.get(artifact.archetype, 0)) + 1
	var best: StringName = &""
	var best_count: int = 0
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		if int(counts[id]) > best_count:
			best_count = int(counts[id])
			best = id
	return best


## True when the run owns any artifact with [param effect].
static func owns_effect(state: RunState, effect: ArtifactDef.Effect) -> bool:
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == effect:
			return true
	return false


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
		var gain: int = ArtifactEngine.score_line(state, board.preview_nudge(i), true) \
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
## the desperation raise, which is the one every player actually makes — unless
## the machine pays for the wager itself, in which case it plays at whatever
## stake the purse can carry for the rest of the floor with the ante still
## covered. Without that, a batch owning the whale's hardware would report
## the win rate of a whale who never raised.
static func stake(state: RunState) -> int:
	if not state.has_system(Systems.STAKE):
		return 1
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		return 1
	var carried: int = _stake_carried(state, floor_def)
	if carried > 1:
		if owns_effect(state, ArtifactDef.Effect.MULT_PER_STAKE):
			return carried
		# Without hardware, a level costs its premium every spin and pays one
		# more helping of what the machine pays. Only a machine paying better
		# than the premium should raise — which is the decision the stake is.
		var pays: float = float(state.economy.lifetime_earned) / float(maxi(1, state.spins_taken))
		if pays > float(state.premium_at(2)):
			return carried
	if state.spins_remaining > 3:
		return 1
	if state.economy.cash >= floor_def.ante:
		return 1
	return mini(2, maxi(1, state.config.max_stake))


## The highest stake the purse can hold for the rest of the floor with the
## ante still covered from what is in hand, or 1.
static func _stake_carried(state: RunState, floor_def: FloorDef) -> int:
	var spare: int = state.economy.cash - floor_def.ante
	var spins: int = maxi(1, state.spins_remaining)
	var carried: int = 1
	for level: int in range(2, maxi(1, state.config.max_stake) + 1):
		var per_spin: int = state.config.spin_cost * level + state.premium_at(level)
		if per_spin * spins > spare:
			break
		carried = level
	return carried




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
		if symbol == null or symbol.is_curse or symbol.base_value < _hold_floor(state):
			continue
		keep = members
	return keep


## What a symbol has to be worth before a pair of it is held. Anything at all
## once the machine pays per reel held: the hold is then the point, not the pair.
static func _hold_floor(state: RunState) -> int:
	if owns_effect(state, ArtifactDef.Effect.MULT_PER_HOLD):
		return 1
	return HOLD_FLOOR


## Signs whichever contract reads best, priced in spins.
##
## It used to sign whichever added the most spins and otherwise the first,
## which meant two of the House's standing offers were never signed once in
## two and a half thousand runs — the lab could not see them at all, and a
## contract nobody signs is a contract nobody has measured. This prices every
## clause in the one unit a floor is actually spent in: a spin. The weights
## are rough on purpose. A signatory who reads the terms perfectly is not
## what the lab is for; a signatory who can tell a good deal from a bad one
## is the least it can be.
const CLAUSE_WORTH: Dictionary = {
	ContractDef.Clause.SPINS: 1.0,
	ContractDef.Clause.ANTE_PERCENT: -0.06,
	ContractDef.Clause.PAYOUT_PERCENT: 0.04,
	ContractDef.Clause.SYMBOL_VALUE: 0.06,
	ContractDef.Clause.CURSE_PAYS: 0.15,
	ContractDef.Clause.DEBT_INTEREST: -0.02,
	ContractDef.Clause.NUDGES: 1.2,
	ContractDef.Clause.WEIGHT: 0.08,
}
## A pattern's multiplier is worth what the pattern is worth landing: a pair
## happens most spins, the whole line almost never.
const PATTERN_WORTH: Array = [0.0, 0.8, 0.4, 0.25, 0.2]


static func contract(_state: RunState, offers: Array[ContractDef]) -> int:
	var best: int = 0
	var best_worth: float = -INF
	for i: int in offers.size():
		var worth: float = 0.0
		for entry: Dictionary in offers[i].clauses():
			worth += _clause_worth(entry)
		if worth > best_worth:
			best_worth = worth
			best = i
	return best


## What one clause is worth, in spins.
static func _clause_worth(entry: Dictionary) -> float:
	var clause: int = int(entry["clause"])
	var magnitude: float = float(entry["magnitude"])
	if clause == int(ContractDef.Clause.PATTERN_MULT):
		var pattern: int = int(entry.get("pattern", -1))
		var worth: float = float(PATTERN_WORTH[pattern]) if pattern >= 0 \
				and pattern < PATTERN_WORTH.size() else 0.4
		return magnitude * worth
	if clause == int(ContractDef.Clause.WEIGHT) \
			and String(entry.get("symbol", "")) == "skull":
		# More skulls printed is not a gift, whatever sign the number carries.
		return -absf(magnitude) * 0.08
	return magnitude * float(CLAUSE_WORTH.get(clause, 0.0))


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
	var next_floor: FloorDef = state.floor_at(state.floor_index + 1)
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
	# Chips left and nothing on the table they reach: one reroll, then shop
	# again. What a person does with change in hand and a draft of dear
	# things — the shop policy has already taken what it could afford.
	if (state.shop_rerolls == 0 and state.economy.chips >= REROLL_FLOOR
			and _dearest_affordable(state) < 0
			and state.reroll_price() <= int(float(state.economy.chips) * REROLL_SHARE)):
		if engine.reroll_shop(state):
			var choice: int = shop(state, state.shop_offers, state.shop_prices)
			while choice >= 0 and engine.buy_offer(state, choice):
				choice = shop(state, state.shop_offers, state.shop_prices)
	var wanted: int = _dearest_offer(state)
	if wanted < 0:
		return
	var short: int = state.shop_prices[wanted] - state.economy.chips
	# Only for the thing the purse nearly covers. Nobody signs for what they
	# could not have afforded half of.
	if short <= 0 or short * 2 > state.shop_prices[wanted]:
		return
	# A trinket from floors ago, sold to close the gap.
	var stale: int = _stalest_owned(state)
	if stale >= 0 and state.sellback_of(state.owned[stale]) >= short:
		if engine.sell(state, stale) > 0 and engine.buy_offer(state, wanted):
			return
	# Or the slate, once, when the bill it adds stays small next to the ante.
	var owed: int = state.slate_price(wanted)
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


## Index of the dearest offer the chips cover, or -1.
static func _dearest_affordable(state: RunState) -> int:
	var best: int = -1
	for i: int in state.shop_offers.size():
		if state.shop_prices[i] > state.economy.chips:
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


## Has a word once the House has started taking the good symbols off the reel.
## Skimming is survivable; a cold deck is what actually ends the run.
static func launder(state: RunState) -> bool:
	if HeatEngine.current(state) < HeatEngine.Measure.COLD_DECK:
		return false
	var price: int = HeatEngine.launder_price(state)
	var floor_def: FloorDef = state.current_floor()
	var reserve: int = floor_def.ante if floor_def != null else 0
	return state.economy.cash - price >= reserve


## Settles the floor early once the purse covers the vig, the ante and a
## little of the next floor's, and there is at least a spin's worth of chips
## in it. The trade every player is asked to make from the basement: the
## spins left are credits upstairs would have had, the chips are the draft.
## A person weighs it on the machine's numbers; this player takes it whenever
## the reserve is there, so the lab measures a game in which it is taken.
static func settle(state: RunState) -> bool:
	if not state.can_settle_early():
		return false
	var bonus: int = state.settle_bonus(state.spins_remaining)
	if bonus <= 0:
		return false
	var due: int = state.vig_due() + state.ante_due()
	var reserve: int = int(round(float(_next_ante(state)) * settle_reserve))
	if state.economy.cash < due + reserve:
		return false
	# The trade itself: a spin not taken is worth what the House pays for it
	# in scrip, at the House's own rate; a spin taken is worth what this
	# machine has been paying. Settle only when the House pays better — a
	# machine paying above its keep should keep spinning, because the ante
	# upstairs is what its credits are for, and the lab's first try at this
	# (settle whenever covered) lost twenty points of win rate to exactly that.
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null:
		return false
	var per_spin: float = float(state.economy.lifetime_earned) / float(maxi(1, state.spins_taken))
	var house_pays: float = float(CoreEconomy.chip_value(state.config, floor_def.ante)) \
			* float(bonus) / float(maxi(1, state.spins_remaining))
	return house_pays > per_spin


## Works the press with the chips the draft left: a strike on the skull
## first, then a print of the dearest symbol on the table, then a gilding of
## whatever this machine already leans on. One job a draft at most — the
## draft is the build, the press is its edge, and a player who spent every
## chip on the reel would own no hardware to spin it with.
## Pays the doorman when the purse can stand it: the notice's watcher is a
## floor of a second rule, and a person with chips to spare buys their way
## out of it before they buy hardware — but not at the cost of the draft.
## Three times the price in hand, or the watcher comes: at twice, the bot
## paid its way out of a rule it could have carried and starved the draft
## for it, and the batch lost two points.
static func doorman(engine: SimEngine, state: RunState) -> void:
	if not state.can_pay_doorman():
		return
	if state.economy.chips >= state.doorman_price() * 3:
		engine.pay_doorman(state)


## Buys the draft's chit when the pocket has room and the purse is not
## emptied by it: paper is bought with change, hardware with the draft.
static func chits(engine: SimEngine, state: RunState) -> void:
	if not state.can_buy_chit():
		return
	# Before the draft only when flush — at a smaller margin the paper
	# starved the hardware and the batch lost eight points — and after it
	# with whatever change the draft left.
	var after_draft: bool = state.shop_offers.is_empty()
	if state.economy.chips >= state.chit_offer.cost + (0 if after_draft else 14):
		engine.buy_chit(state)


## Spends chits at their moments: a respin on a board under par, a vent when
## the count is near a measure, a deferral when the close would fall short,
## a marker on the last spins of a short floor, a peek whenever it is held.
static func use_chits(engine: SimEngine, state: RunState) -> void:
	if state.phase != RunState.Phase.SPINNING:
		return
	for i: int in range(state.pocket.size() - 1, -1, -1):
		if not state.can_use_chit(i):
			continue
		var chit: ChitDef = state.pocket[i]
		var take: bool = false
		match chit.kind:
			ChitDef.Kind.RESPIN:
				take = state.board.payout < SimEngine.par_for(state)
			ChitDef.Kind.VENT:
				take = state.heat >= state.config.heat_skim_at * 0.8
			ChitDef.Kind.DEFERRAL:
				take = state.spins_remaining <= 2 \
						and state.economy.cash < state.vig_due() + state.ante_due()
			ChitDef.Kind.MARKER:
				take = state.spins_remaining <= 2 \
						and state.economy.cash < state.vig_due() + state.ante_due()
			ChitDef.Kind.PEEK:
				take = true
		if take:
			engine.use_chit(state, i)


static func press_jobs(engine: SimEngine, state: RunState) -> void:
	if state.phase != RunState.Phase.SHOPPING or state.press_offers.is_empty():
		return
	var best: int = -1
	var best_score: float = 0.0
	for i: int in state.press_offers.size():
		if not state.can_press(i):
			continue
		var job: Dictionary = state.press_offers[i]
		var symbol: SymbolDef = state.content.symbol_by_id(StringName(String(job["symbol"])))
		var score: float = 0.0
		match String(job["kind"]):
			"strike":
				score = 3.0 if symbol != null and symbol.is_curse else 0.0
			"print":
				score = float(symbol.base_value) / 10.0 if symbol != null else 0.0
			"gild":
				score = 1.0 if state.count_tag(&"fruit") > 0 \
						or String(job["symbol"]) == "fruit" else 0.6
		if score > best_score:
			best_score = score
			best = i
	if best >= 0:
		engine.press(state, best)


## Stays at the table when the batch has been told to. There is no judgement
## in it: a person weighs the offer at the machine, the lab measures what
## happens to a run that takes it, and the default batch keeps measuring the
## game that ends.
static func stay(state: RunState) -> bool:
	return state.options.stay_at_table


## The ante waiting on the next floor, or this one when there is no next.
static func _next_ante(state: RunState) -> int:
	var next_floor: FloorDef = state.floor_at(state.floor_index + 1)
	if next_floor == null:
		next_floor = state.current_floor()
	return next_floor.ante if next_floor != null else 0
