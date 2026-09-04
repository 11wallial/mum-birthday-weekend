## Resolves the boss on the floor into concrete numbers.
##
## The mirror of [ContractEngine] for the House's side of the table: a
## contract is a rule the player signed for a floor, a boss is a rule the
## House imposed on one, and both are torn up when the floor closes. Every
## helper here answers "what does the boss do to this" and nothing else; the
## engine decides when to ask.
##
## Two of the House's people can be on a floor: the boss, sent on schedule,
## and the watcher, sent because the House noticed a loud spin on the floor
## before. The helpers fold both, so a rule is a rule whoever carries it.
class_name BossEngine
extends RefCounted


## The boss for [param floor_def], drawn from the run's own stream so that
## restaffing a floor can never move the reels. Null when the floor has no
## pool, or the run has been told nobody is coming.
static func choose(state: RunState, floor_def: FloorDef) -> BossDef:
	if floor_def == null or state.options.no_bosses:
		return null
	var pool: Array[BossDef] = pool_for(state.content, floor_def.index)
	if pool.is_empty():
		return null
	return pool[state.boss_rng.next_int(0, pool.size() - 1)]


## The bosses that can be sent to floor [param index]. A floor after hours
## draws from the last authored floor's pool: the House does not hire more
## people for a run that stays, it sends the same ones back.
static func pool_for(content: ContentDB, index: int) -> Array[BossDef]:
	var last: int = content.floors.size()
	return content.bosses_for(mini(index, last) if last > 0 else index)


## Everyone the House has on the floor: the boss it sent on schedule and
## the watcher it sent because it noticed. Every helper below folds both.
static func people(state: RunState) -> Array[BossDef]:
	var out: Array[BossDef] = []
	if state.boss != null:
		out.append(state.boss)
	if state.watcher != null:
		out.append(state.watcher)
	return out


static func _is(state: RunState, rule: BossDef.Rule) -> bool:
	for person: BossDef in people(state):
		if person.rule == rule:
			return true
	return false


## The first person on the floor with [param rule], or null.
static func _who(state: RunState, rule: BossDef.Rule) -> BossDef:
	for person: BossDef in people(state):
		if person.rule == rule:
			return person
	return null


## Draw-weight deltas the boss imposes, keyed by symbol id.
static func weight_shifts(state: RunState) -> Dictionary:
	var out: Dictionary = {}
	for person: BossDef in people(state):
		match person.rule:
			BossDef.Rule.SYMBOL_BANNED:
				# Far below any weight a build could add back: banned is banned.
				out[person.symbol] = -1000000
			BossDef.Rule.SYMBOL_HEAVY:
				out[person.symbol] = int(out.get(person.symbol, 0)) + int(round(person.magnitude))
			BossDef.Rule.COLD_REELS:
				for symbol: SymbolDef in state.content.symbols:
					if HeatEngine.COLD_SYMBOLS.has(symbol.id):
						out[symbol.id] = int(out.get(symbol.id, 0)) \
								- int(floor(float(symbol.base_weight) * HeatEngine.COLD_SHARE))
			_:
				pass
	return out


## What a lock costs, as a multiple of the spin.
static func lock_multiplier(state: RunState) -> float:
	var multiple: float = 1.0
	for person: BossDef in people(state):
		if person.rule == BossDef.Rule.HOLDS_COST_MORE:
			multiple *= maxf(1.0, person.magnitude)
	return multiple


static func free_nudges_allowed(state: RunState) -> bool:
	return not _is(state, BossDef.Rule.NO_FREE_NUDGES)


## Share of what a line of [param pattern] pays under this boss, 0.0..1.0.
static func pattern_scale(state: RunState, pattern: Probability.Pattern) -> float:
	var scale: float = 1.0
	for person: BossDef in people(state):
		if person.rule != BossDef.Rule.PATTERN_TAXED:
			continue
		if person.pattern >= 0 and person.pattern != int(pattern):
			continue
		scale *= clampf(person.magnitude, 0.0, 1.0)
	return scale


## Percentage the boss has added to the floor's ante so far.
static func ante_percent(state: RunState) -> float:
	var percent: float = 0.0
	for person: BossDef in people(state):
		if person.rule == BossDef.Rule.ANTE_CREEPS:
			percent += maxf(0.0, person.magnitude) * float(state.floor_spins)
	return percent


## Spins the boss takes off the floor's allowance.
static func spins_delta(state: RunState) -> int:
	var delta: int = 0
	for person: BossDef in people(state):
		if person.rule == BossDef.Rule.SHORT_FLOOR:
			delta -= int(round(person.magnitude))
	return delta


static func stake_frozen(state: RunState) -> bool:
	return _is(state, BossDef.Rule.STAKE_FROZEN)


## Share taken off every payout, in 0.0..0.9.
static func skim(state: RunState) -> float:
	var kept: float = 1.0
	for person: BossDef in people(state):
		if person.rule == BossDef.Rule.SKIMMED:
			kept *= 1.0 - clampf(person.magnitude / 100.0, 0.0, 0.9)
	return clampf(1.0 - kept, 0.0, 0.9)


## True on the spin the collector arrives: halfway through the floor, once.
static func collects_now(state: RunState) -> bool:
	if not _is(state, BossDef.Rule.VIG_MID_FLOOR) or state.boss_collected:
		return false
	return state.floor_spins >= int(ceil(float(state.floor_spins_total) / 2.0))
