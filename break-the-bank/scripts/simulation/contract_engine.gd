## Resolves the contract a run has signed into concrete numbers.
##
## The mirror of [ArtifactEngine], and deliberately its own file: an artifact is
## bought once and kept for the run, a contract is signed for one floor and torn
## up at the end of it, and mixing the two lifetimes in one resolver is how a
## rule ends up outliving the floor it was written for.
class_name ContractEngine
extends RefCounted


## Every clause of the signed contract matching [param clause].
static func _matching(state: RunState, clause: ContractDef.Clause) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state.contract == null:
		return out
	for entry: Dictionary in state.contract.clauses():
		if int(entry["clause"]) == int(clause):
			out.append(entry)
	return out


static func _sum(state: RunState, clause: ContractDef.Clause) -> float:
	var total: float = 0.0
	for entry: Dictionary in _matching(state, clause):
		total += float(entry["magnitude"])
	return total


## Spins the contract adds to, or takes off, the floor's allowance.
static func spins_delta(state: RunState) -> int:
	return int(round(_sum(state, ContractDef.Clause.SPINS)))


## Percentage shift on the floor's ante.
static func ante_percent(state: RunState) -> float:
	return _sum(state, ContractDef.Clause.ANTE_PERCENT)


## Percentage shift on every payout earned on the floor.
static func payout_percent(state: RunState) -> float:
	return _sum(state, ContractDef.Clause.PAYOUT_PERCENT)


## Percentage shift on this floor's debt interest.
static func debt_interest_percent(state: RunState) -> float:
	return _sum(state, ContractDef.Clause.DEBT_INTEREST)


## Free nudges added to every award.
static func nudge_delta(state: RunState) -> int:
	return int(round(_sum(state, ContractDef.Clause.NUDGES)))


## Multiplier shift for [param pattern], from clauses that name it or every line.
static func pattern_mult(state: RunState, pattern: Probability.Pattern) -> float:
	var total: float = 0.0
	for entry: Dictionary in _matching(state, ContractDef.Clause.PATTERN_MULT):
		var wanted: int = int(entry["pattern"])
		if wanted < 0 or wanted == int(pattern):
			total += float(entry["magnitude"])
	return total


## Credit shift on [param symbol_id]'s paid value.
static func symbol_value(state: RunState, symbol_id: StringName) -> int:
	var total: float = 0.0
	for entry: Dictionary in _matching(state, ContractDef.Clause.SYMBOL_VALUE):
		var wanted: StringName = StringName(entry["symbol"])
		if wanted == &"" or wanted == symbol_id:
			total += float(entry["magnitude"])
	return int(round(total))


## Credits each curse pays under the contract, or 0.0 when it says nothing.
static func curse_pays(state: RunState) -> float:
	var best: float = 0.0
	for entry: Dictionary in _matching(state, ContractDef.Clause.CURSE_PAYS):
		best = maxf(best, float(entry["magnitude"]))
	return best


## Draw-weight deltas the contract imposes, keyed by symbol id.
static func weight_shifts(state: RunState) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in _matching(state, ContractDef.Clause.WEIGHT):
		var key: StringName = StringName(entry["symbol"])
		out[key] = int(out.get(key, 0)) + int(round(float(entry["magnitude"])))
	return out
