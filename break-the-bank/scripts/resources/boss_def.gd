## One of the House's people, sent to a floor with a rule of their own.
##
## A boss is not a bigger ante. It is a telegraphed change to how the floor
## plays — a symbol taken off the reel, the locks priced up, the vig charged
## early — announced as the floor opens and torn up as it closes. The rules
## are a closed vocabulary resolved in one place ([BossEngine]), for the same
## reason artifacts are: so a floor can be restaffed without touching code,
## and so the lab can say which of them kills.
class_name BossDef
extends Resource

enum Rule {
	## [member symbol] leaves the reel for the floor.
	SYMBOL_BANNED,
	## Every lock costs [member magnitude] times what it did.
	HOLDS_COST_MORE,
	## No nudge is free, whatever the hardware or the stake says.
	NO_FREE_NUDGES,
	## The vig is charged a second time halfway through the floor.
	VIG_MID_FLOOR,
	## Lines of [member pattern] pay [member magnitude] of what they would.
	PATTERN_TAXED,
	## [member symbol] gains [member magnitude] draw weight for the floor.
	SYMBOL_HEAVY,
	## The ante rises [member magnitude] percent for every spin taken on the floor.
	ANTE_CREEPS,
	## The good symbols at half weight, as the count's cold deck.
	COLD_REELS,
	## [member magnitude] fewer spins on the floor.
	SHORT_FLOOR,
	## The stake stays at one.
	STAKE_FROZEN,
	## [member magnitude] percent off every payout, on top of whatever the count takes.
	SKIMMED,
}

@export var id: StringName = &""
@export var display_name: String = ""
## What the House says as the floor opens.
@export_multiline var intro: String = ""
## The rule in one line, printed on the ledger for the whole floor.
@export_multiline var tell: String = ""
## The floor this boss can be sent to. Floors past the last authored one draw
## from the last floor's pool.
@export var floor: int = 2
@export var rule: Rule = Rule.SYMBOL_BANNED
@export var magnitude: float = 0.0
## The symbol SYMBOL_BANNED and SYMBOL_HEAVY are about.
@export var symbol: StringName = &""
## The [enum Probability.Pattern] PATTERN_TAXED is about. -1 is every line.
@export var pattern: int = -1
