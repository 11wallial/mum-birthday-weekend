## Everything that changes during a single run.
##
## [RunState] is the boundary object in the architecture: the simulation writes
## it, the presentation layer only ever reads it. It is plain data plus the RNG
## streams, so a run can be snapshotted, diffed or replayed from its seed alone.
class_name RunState
extends RefCounted

enum Phase {
	SETUP,
	SPINNING,
	SHOPPING,
	WON,
	LOST,
	## Between the draft and the next floor, with the back office waiting for a
	## signature. Appended rather than inserted so recorded phase indices from
	## older runs still mean what they meant.
	SIGNING,
}

## What the machine is waiting on. A spin is not over when the reels stop: the
## board can owe the player nudges, and a paying board can be gambled instead of
## banked. Nothing is credited until [member decision] is back to NONE.
enum Decision {
	## Nothing is pending. The machine is ready to be spun.
	NONE,
	## Nudges are on the clock. Spend them or decline them.
	NUDGE,
	## A win is on the table. Take it or double it.
	GAMBLE,
}

## The most a spin can honestly be expected to pay, in pars: where the
## surety reads full.
const SURETY_REACH: float = 3.0

var seed_value: int = 0
var content: ContentDB
var config: BalanceConfig
var economy: CoreEconomy
var bus: EffectBus
## Meta-progression settings for this run. Never null.
var options: RunOptions

var phase: Phase = Phase.SETUP
var decision: Decision = Decision.NONE
## 1-based index of the floor being played.
var floor_index: int = 1
var spins_remaining: int = 0
var spins_taken: int = 0
var floors_cleared: int = 0
var owned: Array[ArtifactDef] = []
## Flat draw-weight deltas keyed by symbol id, accumulated from WEIGHT_SHIFT artifacts.
var weight_shifts: Dictionary = {}
## Counters that grow over the run — symbols seen, spins settled — keyed by
## the id of the artifact keeping them. Only a settled spin moves one, an
## artifact's own tally goes with it when it is sold, and nothing here is
## ever serialised: a replayed journal rebuilds every one of them.
var tallies: Dictionary = {}
## Paying spins in a row, counted before the spin being scored. A dud resets it.
var streak: int = 0
## How many times each artifact has been put on a draft this run, keyed by id.
## Telemetry only: the lab reads it to tell a trap pick from an auto-pick.
var offers_seen: Dictionary = {}
## How many times each symbol has landed on the payline this run, keyed by id,
## counted once per settled spin. Telemetry only, like the offers above: the
## lab reads it to compare the reel a run actually saw against the reel the
## content authored, which is the only way to see how far the presses, the
## skins, the contracts and the House's own weight shifts have bent it.
var symbols_landed: Dictionary = {}
## The three rows currently standing on the machine, and what they pay.
var board: SpinBoard = SpinBoard.new()
## Systems the run has been handed, keyed by [Systems] name. A floor grants one;
## it is never taken away again.
var systems: Dictionary = {}
## Credits wagered per spin, as a multiple of [member BalanceConfig.spin_cost].
## Costs that multiple and pays it back on the multiplier.
var stake: int = 1
## Reels and scoring rows bolted on beyond what the machine shipped with.
var extra_reels: int = 0
var extra_rows: int = 0
## The House's count, and the ante it has added by sending someone over. Both
## reset with the floor: the count is a floor's worth of attention, not a run's.
var heat: float = 0.0
var heat_ante_percent: float = 0.0
## Payout of the most recent spin, after every modifier.
var last_payout: int = 0
## The single biggest spin of the run. The profile keeps the biggest ever.
var best_payout: int = 0
var last_line: Array[SymbolDef] = []
var last_pattern: Probability.Pattern = Probability.Pattern.NONE
## Reason the run ended, e.g. &"ante_unpaid" or &"cleared_all_floors".
var end_reason: StringName = &""
## True once the run has taken the House's offer and stayed past the last
## authored floor. The floors from there are made by [Endless].
var endless: bool = false
## The debt repaid at the win, which is what the House lends back to a run
## that stays. Zero until then.
var debt_repaid: int = 0
## Lifetime earnings at the moment the run won, so the profile can count what
## an endless run earned after that without counting the win twice.
var earned_at_win: int = 0
## Floors made for an endless run, kept so each is built once.
var _endless_floors: Dictionary = {}
## Artifacts on offer while [member phase] is SHOPPING, and what each costs.
## Both are cleared when the shop closes.
var shop_offers: Array[ArtifactDef] = []
var shop_prices: Array[int] = []
## Rerolls already bought in the draft currently open. Reset when it opens.
var shop_rerolls: int = 0
## Rerolls bought over the whole run, and the chips still in hand each time
## a draft was left: the balance guide's two tells for a loose economy —
## mitigation that is always affordable, and resources unspent at the end
## of a shop phase. Read by the lab; never by the game.
var rerolls_total: int = 0
var chips_left_at_drafts: PackedInt32Array = PackedInt32Array()
## The press's jobs on offer while the draft is open: each a dictionary with
## "kind" (strike, print, gild), "symbol", "magnitude" and "price" in chips.
## The reel is the player's to edit — CloverPit's lesson, the review's ask —
## and the press is where the editing is bought. Cleared with the draft.
var press_offers: Array[Dictionary] = []
## Credits added to what each symbol pays this run, keyed by symbol id or
## family: the gilding the press has done. Kept for the run, like the works.
var symbol_value_shifts: Dictionary = {}
## Jobs the press has run this run. Telemetry.
var press_jobs: int = 0
## The contract signed for the floor being played, or null on a floor played
## under house rules. Torn up when the floor ends.
var contract: ContractDef = null
## Contracts on the table while [member phase] is SIGNING.
var contract_offers: Array[ContractDef] = []
## Every contract signed this run, by id, for the collection.
var contracts_signed: Array[StringName] = []
## The pocket: chits bought and not yet spent, at most [constant POCKET].
var pocket: Array[ChitDef] = []
## The chit on this draft's table, or null.
var chit_offer: ChitDef = null
## What spent chits have set up: a vig deferred to the principal, a symbol
## the last drum lands next spin, and the line the ledger has been shown.
var vig_deferred: bool = false
var forced_symbol: StringName = &""
var peeked_line: Array[StringName] = []
var chits_used: int = 0
var chits_bought: int = 0
const POCKET: int = 2
## The House's person on this floor, or null on a floor nobody was sent to.
## Chosen as the floor opens, torn up as it closes, like a contract.
var boss: BossDef = null
## How this floor is running: drawn as it opens, torn up as it closes.
var skin: FloorSkinDef = null
## Every skin this run has been dealt, by id, for the collection and the lab.
var skins_seen: Array[StringName] = []
## The second of the House's people on the floor: sent because the House
## noticed a spin on the floor before, announced then, arrived now. Torn
## up with the boss when the floor closes. The House acting against
## success rather than on a schedule is what makes "rigged" mechanical.
var watcher: BossDef = null
## Who the House has decided to send to the next floor, once it noticed.
var notice_pending: BossDef = null
## How many times the House has noticed this run, and the last spin it
## noticed: the floor and the payout, so the player can point at it.
var notices: int = 0
var noticed_floor: int = 0
var noticed_payout: int = 0
## Times the doorman has been paid this run: the price climbs with it.
var doormen_paid: int = 0
## Who was sent to each floor so far, by floor order, empty where nobody
## was. Telemetry: the lab reads it to say which of them kills.
var bosses_faced: Array[StringName] = []
## Spins taken on the floor being played, and the allowance it opened with.
var floor_spins: int = 0
var floor_spins_total: int = 0
## Whether the collector has already been round this floor.
var boss_collected: bool = false
## Spins still on the clock when the floor was settled early, so the close
## can pay for them. Zero on a floor played to its last spin.
var spins_left_at_settle: int = 0
## Floors this run left with spins still on the clock. Telemetry.
var floors_settled_early: int = 0

var reel_rng: RngStream
var shop_rng: RngStream
## Draws for anything that changes the run's pacing rather than its contents.
var tempo_rng: RngStream
## Draws for the symbols either side of the payline, and for the replacements a
## nudge pulls in behind them. Separate from the reel stream so that showing —
## and nudging — more of the reels can never move what the payline itself drew.
var band_rng: RngStream
## Draws for the gamble ladder, so a player who never gambles gets the same
## reels as one who gambles every spin.
var gamble_rng: RngStream
## Draws for who the House sends to a floor, so restaffing a floor can never
## move the reels, the shop or the ladder.
var boss_rng: RngStream
## The floor's own state, off its own stream: a skin drawn today cannot
## move the reels of a seed played yesterday.
var skin_rng: RngStream
## The day's lean on the reel, drawn once at the start and never again.
var lean_rng: RngStream
## The symbols the reel ships heavy and light on this seed, by id, or empty.
var ship_lean: Dictionary = {}

var _reel_cache: Array[Probability.ReelEntry] = []
var _reel_weight_cache: PackedInt32Array = PackedInt32Array()
var _reel_cache_dirty: bool = true


func _init(p_seed: int, p_content: ContentDB, p_bus: EffectBus,
		p_options: RunOptions = null) -> void:
	seed_value = p_seed
	content = p_content
	config = p_content.balance
	bus = p_bus
	options = p_options if p_options != null else RunOptions.new()
	economy = CoreEconomy.new(config, p_bus)
	economy.cash += options.bonus_cash
	economy.chips = maxi(0, economy.chips + options.bonus_chips)
	economy.debt = maxi(0, int(round(float(economy.debt) * maxf(options.debt_scale, 0.0)))
			+ options.bonus_debt)
	reel_rng = RngStream.new(p_seed, &"reels")
	shop_rng = RngStream.new(p_seed, &"shop")
	tempo_rng = RngStream.new(p_seed, &"tempo")
	band_rng = RngStream.new(p_seed, &"band")
	gamble_rng = RngStream.new(p_seed, &"gamble")
	boss_rng = RngStream.new(p_seed, &"boss")
	skin_rng = RngStream.new(p_seed, &"skin")
	lean_rng = RngStream.new(p_seed, &"lean")
	board.resize(config.reel_count)


## True when [param index] names an offer the player can currently afford.
## The draft is paid in chips, never in the cash the ante needs.
func can_buy(index: int) -> bool:
	if phase != Phase.SHOPPING or index < 0 or index >= shop_offers.size():
		return false
	return economy.can_afford_chips(shop_prices[index])


## What [param artifact] costs this run, in chips: the authored price, scaled
## by the audit. Public so the draft, the market and the engine quote the
## same number.
func price_of(artifact: ArtifactDef) -> int:
	return maxi(1, int(round(float(artifact.cost) * maxf(options.price_scale, 0.0))))


## Chips the market hands back for [param artifact] today.
func sellback_of(artifact: ArtifactDef) -> int:
	return maxi(1, int(floor(float(price_of(artifact))
			* config.sellback_percent / 100.0)))


## Credits the slate puts on the debt for offer [param index]: the chip price
## at the House's exchange rate, with the markup on top.
func slate_price(index: int) -> int:
	if index < 0 or index >= shop_prices.size():
		return 0
	var floor_def: FloorDef = current_floor()
	var rate: int = CoreEconomy.chip_value(config, floor_def.ante if floor_def != null else 0)
	return maxi(1, int(ceil(float(shop_prices[index] * rate)
			* (1.0 + config.slate_markup_percent / 100.0))))


## The vig the close of this floor will charge, in cash, before the ante.
## Zero while the House is still extending its grace.
func vig_due() -> int:
	var grace: int = 0 if options.no_grace else config.debt_grace_floors
	if economy.debt <= 0 or floors_cleared < grace:
		return 0
	var percent: float = config.debt_service_percent * maxf(options.debt_service_scale, 0.0)
	if percent <= 0.0:
		return 0
	return int(ceil(float(economy.debt) * percent / 100.0))


## What the floor in front of the player costs to leave, with every contract
## clause and everything the House has added since it opened. One number,
## computed in one place, so no prompt ever quotes a price nobody is charged.
func ante_due() -> int:
	var floor_def: FloorDef = current_floor()
	return ante_due_for(floor_def) if floor_def != null else 0


func ante_due_for(floor_def: FloorDef) -> int:
	var discount: float = ArtifactEngine.ante_discount_percent(self)
	var ante: float = float(floor_def.ante) * options.ante_scale
	ante *= maxf(0.0, 1.0 + ContractEngine.ante_percent(self) / 100.0)
	ante *= 1.0 + heat_ante_percent / 100.0
	ante *= 1.0 + BossEngine.ante_percent(self) / 100.0
	ante *= 1.0 + float(notices) * config.notice_ante_percent / 100.0
	if skin != null:
		ante *= maxf(0.0, 1.0 + skin.ante_percent / 100.0)
	return maxi(0, int(round(ante * (1.0 - discount / 100.0))))


## True when the floor can be settled now, with spins still on the clock:
## the purse covers the vig and the ante, and the machine owes no decision.
## Settling early is the trade the chips exist for — the spins not taken are
## paid for in scrip — and it is the one move that ends a floor on purpose.
func can_settle_early() -> bool:
	if phase != Phase.SPINNING or decision != Decision.NONE or spins_remaining <= 0:
		return false
	return economy.cash >= vig_due() + ante_due()


## How much of the surety the House holds, in 0..1.
##
## The player's own life is the surety on the account. Stated once at the
## door it would be forgotten by the second floor, so it is a number the
## machine carries and reads on every spin: zero while the purse covers what
## the floor's close will charge, one when what is still owed cannot be
## reached by the spins left. Between the two it is what each remaining spin
## would have to pay, against the most a spin can honestly be expected to —
## [constant SURETY_REACH] times par — so a dead spin moves it up by exactly
## the spin it wasted, and a paying one moves it down by what it paid.
## Between floors the House holds nothing; a lost run is held entirely.
func surety() -> float:
	if phase == Phase.LOST:
		return 1.0
	if phase != Phase.SPINNING:
		return 0.0
	var owed: int = vig_due() + ante_due()
	var shortfall: int = maxi(0, owed - economy.cash)
	if shortfall <= 0:
		return 0.0
	if spins_remaining <= 0:
		return 1.0
	var floor_def: FloorDef = current_floor()
	var par: float = maxf(1.0, float(ante_due()) / float(maxi(1,
			floor_def.spins if floor_def != null else 1)))
	var needed: float = float(shortfall) / float(spins_remaining)
	return clampf(needed / (SURETY_REACH * par), 0.0, 1.0)


## Chips [param spins_left] unused spins would be worth at the close.
func settle_bonus(spins_left: int) -> int:
	if spins_left <= 0 or config.chips_per_spin_left <= 0:
		return 0
	var bonus: int = mini(spins_left * config.chips_per_spin_left,
			maxi(0, config.chips_spin_left_cap))
	return bonus * 2 if is_quick_clear(spins_left) else bonus


## True when settling with [param spins_left] is a quick clear: at least
## [member BalanceConfig.quick_clear_share] of the floor's spins unspent.
func is_quick_clear(spins_left: int) -> bool:
	var total: int = maxi(1, floor_spins_total)
	return config.quick_clear_share > 0.0 \
			and float(spins_left) >= float(total) * config.quick_clear_share


## True once a floor has handed this run [param id]. See [Systems].
func has_system(id: StringName) -> bool:
	return bool(systems.get(id, false))


## Hands the run a system. Returns true the first time, so a floor can announce
## it without the caller tracking what it has already said.
func grant_system(id: StringName) -> bool:
	if has_system(id):
		return false
	systems[id] = true
	return true


## Reels this run's machine is currently turning.
func reel_count() -> int:
	return maxi(1, board.reel_count())


## Reels the machine should be turning, hardware included.
func machine_reels() -> int:
	return maxi(1, config.reel_count + extra_reels)


## Rows that pay: the payline, plus every row the works have been widened to.
func scoring_rows() -> int:
	return 1 + clampi(extra_rows, 0, 2)


## Credits one spin costs at the current stake, with the reel locks it carries.
##
## A held reel is charged for. Holding is otherwise strictly better than not
## holding whenever a pair is showing, and a move with no cost is not a decision
## — it is a thing the player learns to do without thinking about it.
func spin_price() -> int:
	var locks: int = board.held_count()
	var base: int = config.spin_cost * maxi(1, stake)
	var lock_cost: int = int(round(float(base) * float(locks) * BossEngine.lock_multiplier(self)))
	return maxi(0, base + lock_cost + stake_premium())


## What the wager above the first level costs on top of the spin, per spin:
## a share of the floor's ante for every level raised. This is what makes the
## stake a decision rather than a multiple — see
## [member BalanceConfig.stake_ante_percent].
func stake_premium() -> int:
	return premium_at(stake)


## The premium [param level] would carry on this floor.
func premium_at(level: int) -> int:
	if level <= 1 or config.stake_ante_percent <= 0.0:
		return 0
	var floor_def: FloorDef = current_floor()
	if floor_def == null:
		return 0
	return int(round(float(floor_def.ante) * config.stake_ante_percent / 100.0
			* float(level - 1)))


## True when the machine is mid-decision and must not be spun again.
func is_deciding() -> bool:
	return decision != Decision.NONE


func current_floor() -> FloorDef:
	return floor_at(floor_index)


## The floor at [param index]: authored while there is one, made by [Endless]
## past the last once the run has stayed at the table, and null otherwise —
## which is how a run that has not stayed knows it is over.
func floor_at(index: int) -> FloorDef:
	var authored: FloorDef = content.floor_at(index)
	if authored != null or not endless:
		return authored
	if not _endless_floors.has(index):
		_endless_floors[index] = Endless.floor_for(content, index)
	return _endless_floors[index]


func is_over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


## The reel for the current run, rebuilt only when the weight shifts change.
##
## A contract's weight clause is folded in here rather than written into
## [member weight_shifts], so tearing the contract up at the end of the floor
## restores the reel without having to remember what it changed.
func reel() -> Array[Probability.ReelEntry]:
	if _reel_cache_dirty:
		var shifts: Dictionary = weight_shifts.duplicate()
		var from_skin: Dictionary = skin.weight_shifts if skin != null else {}
		for source: Dictionary in [ContractEngine.weight_shifts(self),
				HeatEngine.weight_shifts(self), BossEngine.weight_shifts(self),
				from_skin]:
			for key: StringName in source:
				shifts[key] = int(shifts.get(key, 0)) + int(source[key])
		_reel_cache = Probability.build_reel(content.symbols, shifts)
		_reel_weight_cache = Probability.reel_weights(_reel_cache)
		_reel_cache_dirty = false
	return _reel_cache


## The current reel's draw weights, cached beside it.
func reel_weights() -> PackedInt32Array:
	reel()
	return _reel_weight_cache


## Signs [param signed] for the coming floor, or tears the last one up when null.
func set_contract(signed: ContractDef) -> void:
	contract = signed
	_reel_cache_dirty = true


## Forces the reel to be rebuilt. Called when something outside the weight
## table — a contract, or the House cooling the deck — changes what is on it.
func mark_reel_dirty() -> void:
	_reel_cache_dirty = true


## Credits the press has added to what [param symbol] pays: its own gilding
## plus its family's. Read where a symbol's value is read, and nowhere else.
func symbol_bonus(symbol: SymbolDef) -> int:
	if symbol == null:
		return 0
	var total: int = int(symbol_value_shifts.get(symbol.id, 0))
	if symbol.family != &"":
		total += int(symbol_value_shifts.get(symbol.family, 0))
	return total


## True when the press job at [param index] can be bought now.
func can_press(index: int) -> bool:
	if phase != Phase.SHOPPING or index < 0 or index >= press_offers.size():
		return false
	return economy.can_afford_chips(int(press_offers[index].get("price", 0)))


## True when the draft's chit can be bought: the draft open, room in the
## pocket, the chips.
func can_buy_chit() -> bool:
	return phase == Phase.SHOPPING and chit_offer != null and pocket.size() < POCKET \
			and economy.can_afford_chips(chit_offer.cost)


## True when the chit at [param index] can be spent now. Each kind has its
## moment: a respin needs a decision on the table, a marker and a peek a
## machine ready to spin, a vent a count, a deferral a floor still open.
func can_use_chit(index: int) -> bool:
	if index < 0 or index >= pocket.size() or phase != Phase.SPINNING:
		return false
	match pocket[index].kind:
		ChitDef.Kind.RESPIN:
			return is_deciding()
		ChitDef.Kind.VENT:
			return has_system(Systems.HEAT) and heat > 0.0 and not is_deciding()
		ChitDef.Kind.DEFERRAL:
			return not vig_deferred and not is_deciding() and vig_due() > 0
		ChitDef.Kind.MARKER:
			return forced_symbol == &"" and not is_deciding() and spins_remaining > 0
		ChitDef.Kind.PEEK:
			return peeked_line.is_empty() and not is_deciding() and spins_remaining > 0
		ChitDef.Kind.NUDGE_TICKET:
			# Only against a board that is still on the table: nudges handed
			# to a settled board are nudges nobody can spend.
			return decision == Decision.NUDGE and board != null and not board.line.is_empty()
		ChitDef.Kind.SPIN_TICKET:
			# Not while a decision stands, and not past the floor: a spin
			# added after the ante is due is a spin on the next floor's clock.
			return not is_deciding() and floor_spins_total > 0
	return false


## Chips the doorman wants to send nobody after the notice in hand.
func doorman_price() -> int:
	return maxi(1, config.doorman_chips + doormen_paid * config.doorman_step)


## True when there is a notice to answer and the draft is open: the doorman
## is spoken to at the desk, between floors, and only while someone is
## actually on their way.
func can_pay_doorman() -> bool:
	return phase == Phase.SHOPPING and notice_pending != null \
			and economy.can_afford_chips(doorman_price())


## The counter [param artifact_id] has built up this run.
func tally(artifact_id: StringName) -> float:
	return float(tallies.get(artifact_id, 0.0))


func add_tally(artifact_id: StringName, delta: float) -> void:
	tallies[artifact_id] = tally(artifact_id) + delta


func add_weight_shift(symbol_id: StringName, delta: int) -> void:
	weight_shifts[symbol_id] = int(weight_shifts.get(symbol_id, 0)) + delta
	_reel_cache_dirty = true


func acquire(artifact: ArtifactDef) -> void:
	owned.append(artifact)
	if artifact.effect == ArtifactDef.Effect.WEIGHT_SHIFT:
		add_weight_shift(artifact.symbol_filter, int(artifact.magnitude))
	bus.emit_event(EffectBus.Event.ARTIFACT_ACQUIRED, {"artifact": artifact.id, "floor": floor_index})


## Gives an artifact back, undoing anything it changed about the run.
##
## Selling has to be exactly the inverse of acquiring or a build could launder a
## permanent reel change through the market for cash.
func release(artifact: ArtifactDef) -> bool:
	var index: int = owned.find(artifact)
	if index < 0:
		return false
	owned.remove_at(index)
	if artifact.effect == ArtifactDef.Effect.WEIGHT_SHIFT:
		add_weight_shift(artifact.symbol_filter, -int(artifact.magnitude))
	# A tally is the artifact's, not the run's: bought back later it starts
	# again, or the market would be a way to keep a ledger without its keeper.
	tallies.erase(artifact.id)
	return true


## What the next reroll of the open draft costs, in chips.
func reroll_price() -> int:
	return maxi(1, int(round(float(config.reroll_base_cost)
			* pow(maxf(config.reroll_growth, 1.0), float(shop_rerolls)))))


func owns(artifact_id: StringName) -> bool:
	for artifact: ArtifactDef in owned:
		if artifact.id == artifact_id:
			return true
	return false


## Owned artifacts carrying [param tag].
func count_tag(tag: StringName) -> int:
	var total: int = 0
	for artifact: ArtifactDef in owned:
		if artifact.has_tag(tag):
			total += 1
	return total


## Tags that have reached the synergy threshold, sorted for stable telemetry.
func active_synergies() -> Array[StringName]:
	var counts: Dictionary = {}
	for artifact: ArtifactDef in owned:
		for tag: StringName in artifact.tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	var out: Array[StringName] = []
	for tag: StringName in counts:
		if int(counts[tag]) >= config.synergy_threshold:
			out.append(tag)
	out.sort()
	return out


## A flat, JSON-safe record of the run for telemetry and replay.
func snapshot() -> Dictionary:
	var owned_ids: Array[String] = []
	for artifact: ArtifactDef in owned:
		owned_ids.append(String(artifact.id))
	var data: Dictionary = {
		"seed": seed_value,
		"phase": String(Phase.keys()[phase]),
		"floor": floor_index,
		"floors_cleared": floors_cleared,
		"spins_taken": spins_taken,
		"spins_remaining": spins_remaining,
		"owned": owned_ids,
		"synergies": active_synergies().map(func(t: StringName) -> String: return String(t)),
		"end_reason": String(end_reason),
		"ruleset": options.ruleset_key(),
		"systems": Systems.ORDER.filter(
				func(id: StringName) -> bool: return has_system(id)).map(
				func(id: StringName) -> String: return String(id)),
		"reel_draws": reel_rng.draws,
		"contract": String(contract.id) if contract != null else "",
		"extra_reels": extra_reels,
		"extra_rows": extra_rows,
		"endless": endless,
		"best_payout": best_payout,
		"streak": streak,
		"boss": String(boss.id) if boss != null else "",
		"bosses_faced": bosses_faced.map(func(id: StringName) -> String: return String(id)),
		"floors_settled_early": floors_settled_early,
		"artifacts_owned": owned.size(),
		"press_jobs": press_jobs,
	}
	data.merge(economy.snapshot())
	return data
