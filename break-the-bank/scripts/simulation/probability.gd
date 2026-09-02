## Reel construction, drawing and pattern detection.
##
## Every function here is static and side-effect free: give it the same reel and
## the same [RngStream] state and it returns the same line. Nothing in this file
## touches a node, a scene or the clock.
class_name Probability
extends RefCounted

enum Pattern {
	## No two symbols on the line match.
	NONE,
	## Exactly two symbols match.
	PAIR,
	## Three or more match, but not the whole line. Unreachable while
	## [member BalanceConfig.reel_count] is 3; it exists for wider machines.
	TRIPLE,
	## Every symbol on the line matches.
	JACKPOT,
	## Every symbol is distinct and none is a curse.
	CLEAN_SWEEP,
}

## One weighted entry on a reel.
class ReelEntry extends RefCounted:
	var symbol: SymbolDef
	var weight: int

	func _init(p_symbol: SymbolDef, p_weight: int) -> void:
		symbol = p_symbol
		weight = p_weight


## Builds a reel from the content set, applying any per-run weight shifts.
## [param weight_shifts] maps a symbol id — or a family name, which shifts
## every symbol of the family — to a flat weight delta; the empty StringName
## key shifts every symbol.
static func build_reel(symbols: Array[SymbolDef], weight_shifts: Dictionary = {}) -> Array[ReelEntry]:
	var reel: Array[ReelEntry] = []
	for symbol: SymbolDef in symbols:
		var weight: int = symbol.base_weight
		if weight_shifts.has(symbol.id):
			weight += int(weight_shifts[symbol.id])
		if symbol.family != &"" and weight_shifts.has(symbol.family):
			weight += int(weight_shifts[symbol.family])
		if weight_shifts.has(&""):
			weight += int(weight_shifts[&""])
		reel.append(ReelEntry.new(symbol, maxi(weight, 0)))
	return reel


static func reel_weights(reel: Array[ReelEntry]) -> PackedInt32Array:
	var weights: PackedInt32Array = PackedInt32Array()
	for entry: ReelEntry in reel:
		weights.append(entry.weight)
	return weights


## Draws one symbol. Returns null only when every weight on the reel is zero.
static func draw_symbol(reel: Array[ReelEntry], rng: RngStream) -> SymbolDef:
	return draw_weighted(reel, reel_weights(reel), rng)


## The same draw against a weight table the caller already has.
##
## A spin now takes three payline draws and six band draws, and rebuilding the
## weight table for each of them was the whole reel walked nine times a spin
## across millions of batch spins. [method RunState.reel_weights] caches it
## beside the reel it belongs to.
static func draw_weighted(reel: Array[ReelEntry], weights: PackedInt32Array,
		rng: RngStream) -> SymbolDef:
	var index: int = rng.weighted_index(weights)
	if index < 0 or index >= reel.size():
		return null
	return reel[index].symbol


## Draws a full line of [param reel_count] symbols.
static func spin_line(reel: Array[ReelEntry], reel_count: int, rng: RngStream) -> Array[SymbolDef]:
	var line: Array[SymbolDef] = []
	for i: int in reel_count:
		var symbol: SymbolDef = draw_symbol(reel, rng)
		if symbol == null:
			break
		line.append(symbol)
	return line


## The symbols either side of the payline on one reel, for the machine to show.
##
## Purely what the player sees: these never score. A slot machine is read
## vertically as well as horizontally — most of the drama is in what nearly
## landed — and a window showing exactly one symbol per reel throws all of that
## away. Each stop is an independent draw from the same weighted reel, which is
## how a virtual-reel machine works, so the near miss the player sees is a real
## one and not a decoration invented by the view.
##
## Drawn from a stream of its own, so a machine that shows more of its reels
## cannot change which symbols land on the payline of an existing seed.
static func spin_band(reel: Array[ReelEntry], rng: RngStream) -> Array[SymbolDef]:
	var band: Array[SymbolDef] = []
	for i: int in 2:
		var symbol: SymbolDef = draw_symbol(reel, rng)
		if symbol == null:
			break
		band.append(symbol)
	return band


## Classifies a line. Wilds join whichever group they can make largest.
##
## A reel with nothing standing on it — a drum bolted on mid-floor, before the
## next spin has drawn for it — counts for nothing rather than crashing the
## scorer. The machine can genuinely be wider than the last line drawn on it.
static func detect_pattern(line: Array[SymbolDef]) -> Pattern:
	var standing: Array[SymbolDef] = drawn(line)
	if standing.size() < 2:
		return Pattern.NONE
	var wilds: int = 0
	var counts: Dictionary = {}
	for symbol: SymbolDef in standing:
		if symbol.is_wild:
			wilds += 1
			continue
		var key: StringName = symbol.family if symbol.family != &"" else symbol.id
		counts[key] = int(counts.get(key, 0)) + 1

	var best: int = 0
	for key: StringName in counts:
		best = maxi(best, int(counts[key]))
	best += wilds
	if wilds == standing.size():
		best = standing.size()

	if best >= standing.size():
		return Pattern.JACKPOT
	if best >= 3:
		return Pattern.TRIPLE
	if best == 2:
		return Pattern.PAIR
	if counts.size() == standing.size() and not has_curse(standing):
		return Pattern.CLEAN_SWEEP
	return Pattern.NONE


## The symbols actually standing on a line, with any empty reel dropped.
static func drawn(line: Array[SymbolDef]) -> Array[SymbolDef]:
	var standing: Array[SymbolDef] = []
	for symbol: SymbolDef in line:
		if symbol != null:
			standing.append(symbol)
	return standing


static func has_curse(line: Array[SymbolDef]) -> bool:
	for symbol: SymbolDef in line:
		if symbol != null and symbol.is_curse:
			return true
	return false


## Chance of drawing [param symbol_id] from [param reel], in 0.0..1.0.
## Used by the balance lab to sanity-check a reel without sampling it.
static func symbol_chance(reel: Array[ReelEntry], symbol_id: StringName) -> float:
	var total: int = 0
	var hits: int = 0
	for entry: ReelEntry in reel:
		total += entry.weight
		if entry.symbol.id == symbol_id:
			hits += entry.weight
	if total <= 0:
		return 0.0
	return float(hits) / float(total)


static func pattern_name(pattern: Pattern) -> String:
	return String(Pattern.keys()[pattern])
