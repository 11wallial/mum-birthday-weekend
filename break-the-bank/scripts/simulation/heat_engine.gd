## The House's count, and what it does about it.
##
## Floor seven's mechanic, and the only system in the game that plays against
## the player rather than for them. The count rises with what you win and falls
## with every spin you do not, so the floor is not "win harder" — it is a
## question about how loudly you are willing to win, asked once per spin.
class_name HeatEngine
extends RefCounted

## What the House is currently doing about the count. Ordered, so a caller can
## compare: every measure implies the ones below it.
enum Measure {
	## Nobody has looked up.
	NONE,
	## A share of every payout goes back over the bar.
	SKIM,
	## The good symbols are quietly taken off the reel.
	COLD_DECK,
	## Someone has come over. The ante goes up and the count is only half reset.
	PIT_BOSS,
}

const NAMES: Array[String] = [
	"", "THE SKIM", "THE COLD DECK", "THE PIT BOSS",
]

## Symbols the cold deck takes off the reel, and the share of their weight it
## takes. The expensive ones: cooling the fruit would be a rounding error, and
## the whole threat has to be legible in the window the player is watching.
const COLD_SYMBOLS: Array[StringName] = [&"seven", &"diamond", &"double_bar", &"wild"]
const COLD_SHARE: float = 0.5


## What the House is doing at [param heat].
static func measure_at(config: BalanceConfig, heat: float) -> Measure:
	if heat >= config.heat_boss_at:
		return Measure.PIT_BOSS
	if heat >= config.heat_cold_at:
		return Measure.COLD_DECK
	if heat >= config.heat_skim_at:
		return Measure.SKIM
	return Measure.NONE


static func measure_name(measure: Measure) -> String:
	return NAMES[int(measure)]


## The count the run is actually being watched at. Zero until the floor that
## starts the counting, so the number can be shown from the moment it matters
## and never before.
static func heat_of(state: RunState) -> float:
	if not state.has_system(Systems.HEAT):
		return 0.0
	return state.heat


static func current(state: RunState) -> Measure:
	if not state.has_system(Systems.HEAT):
		return Measure.NONE
	return measure_at(state.config, state.heat)


## Share taken off every payout, in 0.0..1.0.
static func skim(state: RunState) -> float:
	if current(state) < Measure.SKIM:
		return 0.0
	return clampf(state.config.heat_skim_percent / 100.0, 0.0, 0.9)


## Draw-weight deltas the cold deck imposes, keyed by symbol id.
static func weight_shifts(state: RunState) -> Dictionary:
	var out: Dictionary = {}
	if current(state) < Measure.COLD_DECK:
		return out
	for symbol: SymbolDef in state.content.symbols:
		if COLD_SYMBOLS.has(symbol.id):
			out[symbol.id] = -int(floor(float(symbol.base_weight) * COLD_SHARE))
	return out


## Folds one settled spin into the count. Returns the measure now in force, so
## the caller can announce a change without recomputing it.
static func observe(state: RunState, payout: int, par: float) -> Measure:
	if not state.has_system(Systems.HEAT):
		return Measure.NONE
	var config: BalanceConfig = state.config
	var before: Measure = measure_at(config, state.heat)
	var gained: float = (float(payout) / maxf(par, 1.0)) * config.heat_per_par
	gained *= 1.0 - ArtifactEngine.heat_shield(state)
	state.heat = maxf(0.0, state.heat + gained - config.heat_decay)
	var after: Measure = measure_at(config, state.heat)
	if after == Measure.PIT_BOSS:
		# Someone comes over exactly once per visit: the ante goes up for the
		# rest of the floor and the count drops back to just under the line, so
		# the next visit is earned rather than automatic.
		state.heat_ante_percent += config.heat_boss_ante_percent
		state.heat = maxf(config.heat_cold_at, config.heat_boss_at * 0.55)
		after = measure_at(config, state.heat)
	if after != before:
		state.mark_reel_dirty()
	return after


## Credits it costs to have a word with someone.
static func launder_price(state: RunState) -> int:
	return maxi(1, int(ceil(heat_of(state) * state.config.launder_cost)))
