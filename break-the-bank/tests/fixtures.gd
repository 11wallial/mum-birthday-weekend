## Hand-built content for unit tests.
##
## Tests that assert on numbers use these fixtures rather than the shipped .tres
## files, so a balance change never turns a correctness test red.
class_name TestFixtures
extends RefCounted


static func symbol(id: StringName, value: int, weight: int, family: StringName = &"",
		wild: bool = false, curse: bool = false) -> SymbolDef:
	var def: SymbolDef = SymbolDef.new()
	def.id = id
	def.display_name = String(id)
	def.base_value = value
	def.base_weight = weight
	def.family = family
	def.is_wild = wild
	def.is_curse = curse
	return def


static func artifact(id: StringName, effect: ArtifactDef.Effect, magnitude: float,
		trigger: ArtifactDef.Trigger = ArtifactDef.Trigger.PAYOUT_CALCULATED) -> ArtifactDef:
	var def: ArtifactDef = ArtifactDef.new()
	def.id = id
	def.display_name = String(id)
	def.effect = effect
	def.trigger = trigger
	def.magnitude = magnitude
	return def


static func floor_def(index: int, ante: int, spins: int) -> FloorDef:
	var def: FloorDef = FloorDef.new()
	def.index = index
	def.display_name = "Test Floor %d" % index
	def.ante = ante
	def.spins = spins
	def.debt_interest_percent = 0.0
	def.shop_slots = 0
	def.chips = 3
	return def


## A floor that hands the player systems as it opens.
static func floor_granting(index: int, ante: int, spins: int,
		grants: Array[StringName]) -> FloorDef:
	var def: FloorDef = floor_def(index, ante, spins)
	def.grants = grants
	return def


static func config() -> BalanceConfig:
	var cfg: BalanceConfig = BalanceConfig.new()
	cfg.reel_count = 3
	cfg.starting_cash = 10
	cfg.starting_debt = 0
	cfg.spin_cost = 1
	cfg.base_multiplier = 1.0
	cfg.pattern_multipliers = PackedFloat32Array([0.0, 0.5, 2.0, 4.0, 1.5])
	cfg.curse_penalty = 2
	cfg.synergy_bonus = 0.5
	cfg.synergy_threshold = 3
	cfg.starting_chips = 0
	cfg.chips_per_spin_left = 1
	cfg.chips_spin_left_cap = 5
	cfg.chip_interest_per = 5
	cfg.chip_interest_cap = 3
	cfg.chip_credit_rate_percent = 3.0
	cfg.reroll_base_cost = 2
	cfg.sellback_percent = 50.0
	cfg.max_stake = 5
	cfg.max_nudges = 3
	cfg.gamble_odds = PackedFloat32Array([0.5, 0.4])
	return cfg


## A three-symbol content set: cherry (common), seven (rare), skull (curse).
static func content() -> ContentDB:
	var db: ContentDB = ContentDB.new()
	db.balance = config()
	db.symbols.assign([
		symbol(&"cherry", 2, 20, &"fruit"),
		symbol(&"seven", 10, 5),
		symbol(&"skull", 0, 5, &"", false, true),
	])
	db.artifacts.clear()
	db.floors.assign([floor_def(1, 5, 4), floor_def(2, 10, 4)])
	return db


## Fixture content with a stocked shop, for exercising the draft.
## Kept separate from [method content] so existing suites keep their empty shop.
static func content_with_shop() -> ContentDB:
	var db: ContentDB = content()
	var cheap: ArtifactDef = artifact(&"cheap_charm", ArtifactDef.Effect.FLAT_BONUS, 1.0)
	cheap.cost = 2
	var dear: ArtifactDef = artifact(&"dear_engine", ArtifactDef.Effect.MULT_BONUS, 1.0)
	dear.cost = 9999
	db.artifacts.assign([cheap, dear])
	# The plain fixture floors carry no shop slots; a draft needs some.
	for floor_def: FloorDef in db.floors:
		floor_def.shop_slots = 2
	return db


## An RNG stream that always draws at the bottom of its range, so a chance test
## can assert on the branch instead of on a seed that happens to take it.
static func always_wins() -> RngStream:
	return RiggedStream.new(0.0)


## The same, always drawing at the top.
static func always_loses() -> RngStream:
	return RiggedStream.new(0.999999)


class RiggedStream extends RngStream:
	var _value: float

	func _init(value: float) -> void:
		super._init(0, &"rigged")
		_value = value

	func next_float() -> float:
		return _value


## A run wired to the fixture content, ready to spin.
static func run_state(run_seed: int = 42, db: ContentDB = null) -> RunState:
	var content_db: ContentDB = db if db != null else content()
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	return RunState.new(run_seed, content_db, bus)
