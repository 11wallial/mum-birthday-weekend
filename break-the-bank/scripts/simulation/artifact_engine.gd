## Resolves owned artifacts into concrete numbers.
##
## Artifacts are data, not scripts: this file is the only place that knows what
## an [enum ArtifactDef.Effect] does, which keeps the effect vocabulary small
## enough to reason about and keeps balance edits confined to .tres files.
class_name ArtifactEngine
extends RefCounted

## Working totals for one spin, built up as triggers fire.
class SpinContext extends RefCounted:
	var line: Array[SymbolDef] = []
	var pattern: Probability.Pattern = Probability.Pattern.NONE
	## Sum of the landed symbols' base values, before any modifier.
	var base_payout: int = 0
	## Credits added before multiplication.
	var flat_bonus: float = 0.0
	var multiplier: float = 1.0
	## Ids of the artifacts that contributed, in resolution order.
	var triggered: Array[StringName] = []

	func total() -> int:
		return maxi(0, int(floor((float(base_payout) + flat_bonus) * maxf(multiplier, 0.0))))


## Scores one line. Returns the context so callers (and tests) can inspect the
## breakdown, not just the number.
static func evaluate_spin(state: RunState, line: Array[SymbolDef], pattern: Probability.Pattern) -> SpinContext:
	var config: BalanceConfig = state.config
	var ctx: SpinContext = SpinContext.new()
	ctx.line = line
	ctx.pattern = pattern
	ctx.multiplier = config.base_multiplier

	var cursed: bool = Probability.has_curse(line)
	for symbol: SymbolDef in line:
		if symbol.is_curse:
			ctx.base_payout -= config.curse_penalty
		else:
			ctx.base_payout += symbol.base_value

	# A curse on the line costs the player the pattern bonus entirely.
	if not cursed and pattern < config.pattern_multipliers.size():
		ctx.multiplier += config.pattern_multipliers[pattern]

	_apply(state, ArtifactDef.Trigger.SPIN_STARTED, ctx)
	_apply(state, ArtifactDef.Trigger.SYMBOL_LANDED, ctx)
	_apply(state, ArtifactDef.Trigger.PAYOUT_CALCULATED, ctx)

	for _tag: StringName in state.active_synergies():
		ctx.multiplier += config.synergy_bonus

	var floor_def: FloorDef = state.current_floor()
	if floor_def != null:
		ctx.multiplier *= floor_def.payout_scale
	return ctx


## Extra spins granted for the coming floor.
static func spin_bonus(state: RunState) -> int:
	var total: int = 0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.EXTRA_SPINS:
			total += int(artifact.magnitude)
	return total


## Percentage knocked off the floor's ante, clamped to a survivable 90%.
static func ante_discount_percent(state: RunState) -> float:
	var total: float = 0.0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.ANTE_DISCOUNT:
			total += artifact.magnitude
	return minf(total, 90.0)


## Pays out every INTEREST artifact. Returns the credits paid.
static func apply_floor_interest(state: RunState) -> int:
	var paid: int = 0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect != ArtifactDef.Effect.INTEREST:
			continue
		var amount: int = state.economy.pay_interest(artifact.magnitude, artifact.cap)
		if amount > 0:
			paid += amount
			state.bus.emit_event(EffectBus.Event.ARTIFACT_TRIGGERED, {
				"artifact": artifact.id, "effect": "INTEREST", "amount": amount,
			})
	return paid


static func _apply(state: RunState, trigger: ArtifactDef.Trigger, ctx: SpinContext) -> void:
	for artifact: ArtifactDef in state.owned:
		if artifact.trigger != trigger:
			continue
		var contributed: bool = _apply_one(artifact, ctx)
		if contributed:
			ctx.triggered.append(artifact.id)
			state.bus.emit_event(EffectBus.Event.ARTIFACT_TRIGGERED, {
				"artifact": artifact.id,
				"effect": String(ArtifactDef.Effect.keys()[artifact.effect]),
				"multiplier": ctx.multiplier,
				"flat_bonus": ctx.flat_bonus,
			})


## Returns true when the artifact actually changed the context.
static func _apply_one(artifact: ArtifactDef, ctx: SpinContext) -> bool:
	match artifact.effect:
		ArtifactDef.Effect.FLAT_BONUS:
			ctx.flat_bonus += artifact.magnitude
			return true
		ArtifactDef.Effect.MULT_BONUS:
			ctx.multiplier += artifact.magnitude
			return true
		ArtifactDef.Effect.SYMBOL_BONUS:
			var hits: int = 0
			for symbol: SymbolDef in ctx.line:
				if artifact.symbol_filter == &"" or symbol.id == artifact.symbol_filter:
					hits += 1
			if hits == 0:
				return false
			ctx.flat_bonus += artifact.magnitude * float(hits)
			return true
		ArtifactDef.Effect.PATTERN_MULT:
			if artifact.pattern_filter >= 0 and artifact.pattern_filter != int(ctx.pattern):
				return false
			ctx.multiplier += artifact.magnitude
			return true
		_:
			# EXTRA_SPINS, WEIGHT_SHIFT, INTEREST and ANTE_DISCOUNT resolve
			# outside the spin, in their own helpers above.
			return false
