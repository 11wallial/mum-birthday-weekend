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
	## Extra scoring passes over the same line. 1.0 means the line pays twice.
	var retriggers: float = 0.0
	## Ids of the artifacts that contributed, in resolution order.
	var triggered: Array[StringName] = []
	## The arithmetic, one line at a time, in the order it was done: each a
	## dictionary with "label", "kind" (symbol, pattern, artifact, synergy,
	## house, stake) and "text" — the number as the receipt prints it. The
	## first playtest read a nudge that paid nine for no visible match and
	## called the logic buggy; the logic was right and the sum was hidden.
	## Nothing here changes a number; it only says what changed it.
	var steps: Array[Dictionary] = []

	func total() -> int:
		var base: float = (float(base_payout) + flat_bonus) * maxf(multiplier, 0.0)
		return maxi(0, int(floor(base * (1.0 + maxf(retriggers, 0.0)))))

	## [param extra] rides along for whoever plays the receipt back: the reel
	## a symbol stood on, the id of the device that fired.
	func step(kind: StringName, label: String, text: String, extra: Dictionary = {}) -> void:
		var entry: Dictionary = {"kind": String(kind), "label": label, "text": text}
		entry.merge(extra)
		steps.append(entry)


## Scores one line. Returns the context so callers (and tests) can inspect the
## breakdown, not just the number.
## Set [param announce] false to score without emitting: previewing a nudge, or
## rescoring a board the player has changed, must not fill the telemetry with
## artifact triggers that never happened.
## [param extra_nudges] is for a preview of a nudge not yet taken: the hardware
## that pays per nudge has to price the one being considered, or the hint lamp
## and the automated player undervalue every nudge by exactly one.
static func evaluate_spin(state: RunState, line: Array[SymbolDef],
		pattern: Probability.Pattern, announce: bool = true,
		extra_nudges: int = 0) -> SpinContext:
	var config: BalanceConfig = state.config
	var ctx: SpinContext = SpinContext.new()
	ctx.line = line
	ctx.pattern = pattern
	ctx.multiplier = config.base_multiplier

	# A contract can put the skulls on the payroll for a floor exactly as a ward
	# can, and the two take the better of themselves rather than stacking.
	var ward: float = maxf(maxf(_curse_ward(state), ContractEngine.curse_pays(state)),
			state.options.curse_pays)
	var warded: bool = ward > 0.0
	var cursed: bool = Probability.has_curse(line) and not warded
	for reel: int in line.size():
		var symbol: SymbolDef = line[reel]
		if symbol == null:
			continue
		if not symbol.is_curse:
			var gilt: int = state.symbol_bonus(symbol)
			var worth: int = maxi(0, symbol.base_value
					+ ContractEngine.symbol_value(state, symbol.id) + gilt)
			ctx.base_payout += worth
			ctx.step(&"symbol", symbol.display_name + (", gilt" if gilt > 0 else ""),
					"%d" % worth, {"reel": reel})
		elif warded:
			ctx.base_payout += int(ward)
			ctx.step(&"symbol", "%s, on the payroll" % symbol.display_name,
					"%d" % int(ward), {"reel": reel})
		else:
			ctx.base_payout -= config.curse_penalty
			ctx.step(&"symbol", symbol.display_name, "-%d" % config.curse_penalty,
					{"reel": reel})

	# A curse on the line costs the player the pattern bonus entirely, unless a
	# ward has turned the skulls into payroll.
	if cursed:
		ctx.step(&"pattern", "%s — voided by the skull" % _pattern_label(pattern), "x0")
	elif pattern < config.pattern_multipliers.size():
		ctx.multiplier += config.pattern_multipliers[pattern]
		if pattern != Probability.Pattern.NONE:
			ctx.step(&"pattern", _pattern_label(pattern),
					"+%.2fx" % config.pattern_multipliers[pattern])
		else:
			ctx.step(&"pattern", "No pattern", "x%.2f" % config.pattern_multipliers[pattern])
	if not cursed:
		var clause: float = ContractEngine.pattern_mult(state, pattern)
		if not is_zero_approx(clause):
			ctx.multiplier += clause
			ctx.step(&"house", "Contract, on the pattern", "%+.2fx" % clause)

	_apply(state, ArtifactDef.Trigger.SPIN_STARTED, ctx, announce)
	_apply(state, ArtifactDef.Trigger.SYMBOL_LANDED, ctx, announce)
	_apply(state, ArtifactDef.Trigger.PAYOUT_CALCULATED, ctx, announce)

	for tag: StringName in state.active_synergies():
		ctx.multiplier += config.synergy_bonus
		ctx.step(&"synergy", "%s synergy" % String(tag).capitalize(),
				"+%.2fx" % config.synergy_bonus)

	# Scaling effects read the run and the board rather than the line, so they
	# resolve once the per-artifact pass is done and the owned set is known.
	# Each is announced like a trigger when it actually added something, so
	# the hardware that earned the number is the hardware that lights.
	var nudges: int = state.board.nudges_used + maxi(0, extra_nudges)
	var curses: int = _curse_count(line)
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.RETRIGGER:
			if _pattern_allowed(artifact, pattern) and artifact.magnitude > 0.0:
				ctx.retriggers += artifact.magnitude
				_note(state, artifact, ctx, announce,
						"scores the line again x%.1f" % artifact.magnitude)
			continue
		var gained: float = _scaling_gain(state, artifact, nudges, curses)
		if gained > 0.0:
			ctx.multiplier += gained
			_note(state, artifact, ctx, announce, "+%.2fx" % gained)
	# The exchange reads the list every other device has written itself onto,
	# so it goes last and never counts itself. Two of them count each other,
	# which is the point of owning two.
	for artifact: ArtifactDef in state.owned:
		if artifact.effect != ArtifactDef.Effect.MULT_PER_TRIGGER:
			continue
		var others: int = ctx.triggered.size()
		if others <= 0 or artifact.magnitude <= 0.0:
			continue
		ctx.multiplier += artifact.magnitude * float(others)
		_note(state, artifact, ctx, announce,
				"+%.2fx, %d devices" % [artifact.magnitude * float(others), others])

	var collateral: float = vault_collateral(state)
	if collateral > 0.0:
		ctx.multiplier += collateral
		ctx.step(&"house", "The vault, as collateral", "+%.2fx" % collateral)

	var floor_def: FloorDef = state.current_floor()
	if floor_def != null:
		ctx.multiplier *= floor_def.payout_scale
		if not is_equal_approx(floor_def.payout_scale, 1.0):
			ctx.step(&"house", floor_def.display_name, "x%.2f" % floor_def.payout_scale)
	# The House's person on the floor taxes the pattern they were sent for.
	var taxed: float = BossEngine.pattern_scale(state, pattern)
	ctx.multiplier *= taxed
	if not is_equal_approx(taxed, 1.0) and not BossEngine.people(state).is_empty():
		ctx.step(&"house", _staff_names(state), "x%.2f" % taxed)
	# The contract's cut comes off the end, after everything the player built.
	# Signing away a quarter of the payout should cost a quarter of what the
	# machine actually pays, not a quarter of its bare symbols.
	var cut: float = maxf(0.0, 1.0 + ContractEngine.payout_percent(state) / 100.0)
	ctx.multiplier *= cut
	if not is_equal_approx(cut, 1.0) and state.contract != null:
		ctx.step(&"house", state.contract.display_name, "x%.2f" % cut)
	# And the House takes its share off the end of that, which is the order it
	# would take it in: after everything, and off the top of what is left.
	var skim: float = maxf(0.0, 1.0 - HeatEngine.skim(state))
	ctx.multiplier *= skim
	if not is_equal_approx(skim, 1.0):
		ctx.step(&"house", "The skim", "x%.2f" % skim)
	var staff_skim: float = maxf(0.0, 1.0 - BossEngine.skim(state))
	ctx.multiplier *= staff_skim
	if not is_equal_approx(staff_skim, 1.0) and not BossEngine.people(state).is_empty():
		ctx.step(&"house", "%s skims" % _staff_names(state), "x%.2f" % staff_skim)
	# An audit's adjustment to the machine comes last of all.
	ctx.multiplier *= maxf(0.0, state.options.payout_scale)
	if not is_equal_approx(state.options.payout_scale, 1.0):
		ctx.step(&"house", "The audit", "x%.2f" % state.options.payout_scale)
	return ctx


## The pattern, in the receipt's words.
## The House's people on the floor, named on the receipt.
static func _staff_names(state: RunState) -> String:
	var names: PackedStringArray = PackedStringArray()
	for person: BossDef in BossEngine.people(state):
		names.append(person.display_name)
	return " and ".join(names)


static func _pattern_label(pattern: Probability.Pattern) -> String:
	match pattern:
		Probability.Pattern.PAIR:
			return "A pair"
		Probability.Pattern.TRIPLE:
			return "Three of a kind"
		Probability.Pattern.JACKPOT:
			return "Jackpot — the whole line"
		Probability.Pattern.CLEAN_SWEEP:
			return "Clean sweep"
		_:
			return "No pattern"


## What one scaling artifact adds to the multiplier for this line, reading
## the run and the board. Zero when it has nothing to add, which is also
## how the caller knows not to announce it.
static func _scaling_gain(state: RunState, artifact: ArtifactDef, nudges: int,
		curses: int) -> float:
	var mag: float = artifact.magnitude
	match artifact.effect:
		ArtifactDef.Effect.MULT_PER_FLOOR:
			return mag * float(state.floors_cleared)
		ArtifactDef.Effect.MULT_PER_ARTIFACT:
			return mag * float(state.owned.size())
		ArtifactDef.Effect.DEBT_LEVERAGE:
			# Per hundred owed. Capped, because debt compounds and an
			# uncapped multiplier on it would make defaulting the strategy.
			return _capped(mag * (float(state.economy.debt) / 100.0), artifact.cap)
		ArtifactDef.Effect.MULT_PER_SEEN:
			return _capped(mag * state.tally(artifact.id), artifact.cap)
		ArtifactDef.Effect.MULT_PER_CURSE:
			return mag * float(curses)
		ArtifactDef.Effect.MULT_PER_HOLD:
			return mag * float(state.board.holds_used)
		ArtifactDef.Effect.MULT_PER_NUDGE:
			return mag * float(nudges)
		ArtifactDef.Effect.MULT_PER_STAKE:
			return mag * float(maxi(0, state.stake - 1))
		ArtifactDef.Effect.MULT_PER_STREAK:
			return _capped(mag * float(state.streak), artifact.cap)
		ArtifactDef.Effect.MULT_PER_TAG:
			if artifact.tag_filter == &"":
				return 0.0
			return mag * float(state.count_tag(artifact.tag_filter))
		ArtifactDef.Effect.MULT_PER_SPIN_LEFT:
			return _capped(mag * float(maxi(0, state.spins_remaining)), artifact.cap)
		ArtifactDef.Effect.PARTNER_MULT:
			if artifact.partner == &"" or artifact.partner == artifact.id:
				return 0.0
			return mag if state.owns(artifact.partner) else 0.0
		ArtifactDef.Effect.AWAKENED_MULT:
			if artifact.cap <= 0.0:
				return 0.0
			return mag if state.tally(artifact.id) >= artifact.cap else 0.0
		_:
			return 0.0


static func _capped(value: float, cap: float) -> float:
	return minf(value, cap) if cap > 0.0 else value


static func _pattern_allowed(artifact: ArtifactDef, pattern: Probability.Pattern) -> bool:
	return artifact.pattern_filter < 0 or artifact.pattern_filter == int(pattern)


## True when [param symbol] is what [param filter] names: the symbol itself,
## or any symbol of the family, or anything at all when the filter is empty.
static func symbol_matches(symbol: SymbolDef, filter: StringName) -> bool:
	if symbol == null:
		return false
	if filter == &"" or symbol.id == filter:
		return true
	return symbol.family != &"" and symbol.family == filter


static func _curse_count(line: Array[SymbolDef]) -> int:
	var total: int = 0
	for symbol: SymbolDef in line:
		if symbol != null and symbol.is_curse:
			total += 1
	return total


## Folds a settled spin into the run's tallies. Called once per spin, by the
## engine, when the credits move — never by a preview, which is what keeps a
## nudge hint from growing the ledger just by being looked at.
##
## Returns the artifacts that lit on this spin, so the engine can announce
## a boiler catching without the resolver knowing there is anyone to tell.
static func record_spin(state: RunState, board: SpinBoard) -> Array[ArtifactDef]:
	var lit: Array[ArtifactDef] = []
	for artifact: ArtifactDef in state.owned:
		match artifact.effect:
			ArtifactDef.Effect.MULT_PER_SEEN:
				var hits: int = 0
				for symbol: SymbolDef in board.line:
					if symbol_matches(symbol, artifact.symbol_filter):
						hits += 1
				if hits > 0:
					state.add_tally(artifact.id, float(hits))
			ArtifactDef.Effect.AWAKENED_MULT:
				var before: float = state.tally(artifact.id)
				state.add_tally(artifact.id, 1.0)
				if artifact.cap > 0.0 and before < artifact.cap \
						and state.tally(artifact.id) >= artifact.cap:
					lit.append(artifact)
			_:
				pass
	state.streak = state.streak + 1 if board.payout > 0 else 0
	return lit


## Spins settled since [param artifact] was bought, over the spins it needs,
## in 0.0..1.0. Presentation reads it for the gauge; 1.0 once it has lit.
static func awakening(state: RunState, artifact: ArtifactDef) -> float:
	if artifact.effect != ArtifactDef.Effect.AWAKENED_MULT or artifact.cap <= 0.0:
		return 0.0
	return clampf(state.tally(artifact.id) / artifact.cap, 0.0, 1.0)


## Credits each curse pays instead of costing, or 0.0 when unwarded.
static func _curse_ward(state: RunState) -> float:
	var best: float = 0.0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.CURSE_WARD:
			best = maxf(best, artifact.magnitude)
	return best


## What [param line] would be worth to this run, scored silently.
##
## The nudge hint and the automated policy both have to know whether a move
## helps before it is made, and a preview that emitted — or that drew a
## replacement symbol — would change the run just by being looked at.
## [param nudged] prices the line as the result of one more nudge.
static func score_line(state: RunState, line: Array[SymbolDef], nudged: bool = false) -> int:
	var pattern: Probability.Pattern = Probability.detect_pattern(line)
	return evaluate_spin(state, line, pattern, false, 1 if nudged else 0).total()


## Extra nudges the run's hardware adds to every award.
static func nudge_bonus(state: RunState) -> int:
	var total: int = 0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.NUDGE_BONUS:
			total += int(artifact.magnitude)
	return total


## Multiplier the run's reserve is worth, priced against the ante in front of it.
##
## The mirror of DEBT_LEVERAGE: debt pays you for being in trouble, the vault
## pays you for being solid, and both are capped so neither becomes the only
## way to play. What it costs is liquidity — collateral cannot settle an ante,
## and the ante is the only thing that ever has to be settled.
static func vault_collateral(state: RunState) -> float:
	if not state.has_system(Systems.VAULT) or state.economy.vault <= 0:
		return 0.0
	var floor_def: FloorDef = state.current_floor()
	if floor_def == null or floor_def.ante <= 0:
		return 0.0
	var per: float = float(floor_def.ante) * maxf(state.config.vault_collateral_antes, 0.01)
	return minf(float(state.economy.vault) / per, maxf(state.config.vault_collateral_cap, 0.0))


## Percentage points this run's hardware adds to the vault's rate.
static func vault_yield_bonus(state: RunState) -> float:
	var total: float = 0.0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.VAULT_YIELD:
			total += artifact.magnitude
	return total


## Share of the House's attention this run's hardware absorbs, in 0.0..0.9.
static func heat_shield(state: RunState) -> float:
	var total: float = 0.0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.HEAT_SHIELD:
			total += artifact.magnitude
	return clampf(total / 100.0, 0.0, 0.9)


## Extra spins granted for the coming floor.
static func spin_bonus(state: RunState) -> int:
	var total: int = 0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.EXTRA_SPINS:
			total += int(artifact.magnitude)
	return total


## True when a spin should not be counted against the floor's allowance.
##
## Drawn from the run's own named stream rather than the reel stream, so adding
## a refund artifact cannot shift which symbols land — the whole reason the
## streams are named.
static func refunds_spin(state: RunState) -> bool:
	var chance: float = 0.0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect == ArtifactDef.Effect.SPIN_REFUND:
			chance += artifact.magnitude
	if chance <= 0.0:
		return false
	# Capped well short of free: a floor you cannot run out of spins on is a
	# floor with no clock, and the clock is the game.
	return state.tempo_rng.next_float() * 100.0 < minf(chance, 45.0)


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


## Wipes debt for every DEBT_PAYDOWN artifact. Returns the credits of debt cleared.
static func apply_debt_paydown(state: RunState) -> int:
	var cleared: int = 0
	for artifact: ArtifactDef in state.owned:
		if artifact.effect != ArtifactDef.Effect.DEBT_PAYDOWN or state.economy.debt <= 0:
			continue
		var wiped: int = state.economy.forgive_debt(artifact.magnitude)
		if wiped > 0:
			cleared += wiped
			state.bus.emit_event(EffectBus.Event.ARTIFACT_TRIGGERED, {
				"artifact": artifact.id, "effect": "DEBT_PAYDOWN", "amount": wiped,
			})
	return cleared


static func _apply(state: RunState, trigger: ArtifactDef.Trigger, ctx: SpinContext,
		announce: bool) -> void:
	for artifact: ArtifactDef in state.owned:
		if artifact.trigger != trigger:
			continue
		var flat_before: float = ctx.flat_bonus
		var mult_before: float = ctx.multiplier
		if _apply_one(artifact, ctx):
			var text: String = ""
			if ctx.flat_bonus != flat_before:
				text = "+%d" % int(round(ctx.flat_bonus - flat_before))
			if ctx.multiplier != mult_before:
				text += ("  " if not text.is_empty() else "") \
						+ "%+.2fx" % (ctx.multiplier - mult_before)
			_note(state, artifact, ctx, announce, text)


## Writes [param artifact] onto the line's record and the receipt and, when
## asked, tells everyone watching what it did to the numbers so far.
static func _note(state: RunState, artifact: ArtifactDef, ctx: SpinContext,
		announce: bool, text: String = "") -> void:
	ctx.triggered.append(artifact.id)
	ctx.step(&"artifact", artifact.display_name, text, {"id": String(artifact.id)})
	if not announce:
		return
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
				if symbol_matches(symbol, artifact.symbol_filter):
					hits += 1
			if hits == 0:
				return false
			ctx.flat_bonus += artifact.magnitude * float(hits)
			return true
		ArtifactDef.Effect.PATTERN_MULT:
			if not _pattern_allowed(artifact, ctx.pattern):
				return false
			ctx.multiplier += artifact.magnitude
			return true
		_:
			# EXTRA_SPINS, WEIGHT_SHIFT, INTEREST, ANTE_DISCOUNT, CURSE_WARD,
			# DEBT_PAYDOWN, NUDGE_BONUS, VAULT_YIELD, HEAT_SHIELD and the
			# scaling effects all resolve elsewhere: in evaluate_spin after
			# this pass, or in their own helpers above.
			return false
