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
}

var seed_value: int = 0
var content: ContentDB
var config: BalanceConfig
var economy: CoreEconomy
var bus: EffectBus

var phase: Phase = Phase.SETUP
## 1-based index of the floor being played.
var floor_index: int = 1
var spins_remaining: int = 0
var spins_taken: int = 0
var floors_cleared: int = 0
var owned: Array[ArtifactDef] = []
## Flat draw-weight deltas keyed by symbol id, accumulated from WEIGHT_SHIFT artifacts.
var weight_shifts: Dictionary = {}
## Payout of the most recent spin, after every modifier.
var last_payout: int = 0
var last_line: Array[SymbolDef] = []
var last_pattern: Probability.Pattern = Probability.Pattern.NONE
## Reason the run ended, e.g. &"ante_unpaid" or &"cleared_all_floors".
var end_reason: StringName = &""
## Artifacts on offer while [member phase] is SHOPPING, and what each costs.
## Both are cleared when the shop closes.
var shop_offers: Array[ArtifactDef] = []
var shop_prices: Array[int] = []

var reel_rng: RngStream
var shop_rng: RngStream

var _reel_cache: Array[Probability.ReelEntry] = []
var _reel_cache_dirty: bool = true


func _init(p_seed: int, p_content: ContentDB, p_bus: EffectBus) -> void:
	seed_value = p_seed
	content = p_content
	config = p_content.balance
	bus = p_bus
	economy = CoreEconomy.new(config, p_bus)
	reel_rng = RngStream.new(p_seed, &"reels")
	shop_rng = RngStream.new(p_seed, &"shop")


## True when [param index] names an offer the player can currently afford.
func can_buy(index: int) -> bool:
	if phase != Phase.SHOPPING or index < 0 or index >= shop_offers.size():
		return false
	return economy.can_afford(shop_prices[index])


func current_floor() -> FloorDef:
	return content.floor_at(floor_index)


func is_over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


## The reel for the current run, rebuilt only when the weight shifts change.
func reel() -> Array[Probability.ReelEntry]:
	if _reel_cache_dirty:
		_reel_cache = Probability.build_reel(content.symbols, weight_shifts)
		_reel_cache_dirty = false
	return _reel_cache


func add_weight_shift(symbol_id: StringName, delta: int) -> void:
	weight_shifts[symbol_id] = int(weight_shifts.get(symbol_id, 0)) + delta
	_reel_cache_dirty = true


func acquire(artifact: ArtifactDef) -> void:
	owned.append(artifact)
	if artifact.effect == ArtifactDef.Effect.WEIGHT_SHIFT:
		add_weight_shift(artifact.symbol_filter, int(artifact.magnitude))
	bus.emit_event(EffectBus.Event.ARTIFACT_ACQUIRED, {"artifact": artifact.id, "floor": floor_index})


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
		"reel_draws": reel_rng.draws,
	}
	data.merge(economy.snapshot())
	return data
