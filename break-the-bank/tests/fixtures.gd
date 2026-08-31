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
	cfg.shop_inflation_percent = 0.0
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


## A run wired to the fixture content, ready to spin.
static func run_state(run_seed: int = 42, db: ContentDB = null) -> RunState:
	var content_db: ContentDB = db if db != null else content()
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	return RunState.new(run_seed, content_db, bus)
