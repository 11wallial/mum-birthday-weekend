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
## The contract signed for the floor being played, or null on a floor played
## under house rules. Torn up when the floor ends.
var contract: ContractDef = null
## Contracts on the table while [member phase] is SIGNING.
var contract_offers: Array[ContractDef] = []

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
	economy.debt = maxi(0, int(round(float(economy.debt) * maxf(options.debt_scale, 0.0)))
			+ options.bonus_debt)
	reel_rng = RngStream.new(p_seed, &"reels")
	shop_rng = RngStream.new(p_seed, &"shop")
	tempo_rng = RngStream.new(p_seed, &"tempo")
	band_rng = RngStream.new(p_seed, &"band")
	gamble_rng = RngStream.new(p_seed, &"gamble")
	board.resize(config.reel_count)


## True when [param index] names an offer the player can currently afford.
func can_buy(index: int) -> bool:
	if phase != Phase.SHOPPING or index < 0 or index >= shop_offers.size():
		return false
	return economy.can_afford(shop_prices[index])


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
	return maxi(0, config.spin_cost * maxi(1, stake) * (1 + locks))


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
		for source: Dictionary in [ContractEngine.weight_shifts(self),
				HeatEngine.weight_shifts(self)]:
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
	return true


## What the next reroll of the open draft costs.
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
	}
	data.merge(economy.snapshot())
	return data
