## Definition of an artifact — a permanent, stacking modifier bought in a shop.
##
## Effects are declared as data rather than as per-artifact scripts so that the
## balance loop can rewrite numbers without touching executable code, and so the
## headless simulation never has to load a scene to resolve a trigger.
class_name ArtifactDef
extends Resource

enum Trigger {
	## Fires once before the reels are drawn.
	SPIN_STARTED,
	## Fires once per symbol that lands, with that symbol in context.
	SYMBOL_LANDED,
	## Fires once after the raw line payout is known, before it is banked.
	PAYOUT_CALCULATED,
	## Fires once when a floor's ante has been settled.
	FLOOR_CLEARED,
}

enum Effect {
	## Adds [member magnitude] credits to the payout.
	FLAT_BONUS,
	## Adds [member magnitude] to the payout multiplier.
	MULT_BONUS,
	## Adds [member magnitude] credits per landed symbol matching [member symbol_filter].
	SYMBOL_BONUS,
	## Adds [member magnitude] to the multiplier when the line pattern matches [member pattern_filter].
	PATTERN_MULT,
	## Pays [member magnitude] percent of banked cash, capped by [member cap].
	INTEREST,
	## Grants [member magnitude] extra spins on the floor timer.
	EXTRA_SPINS,
	## Adds [member magnitude] draw weight to reel entries matching [member symbol_filter].
	WEIGHT_SHIFT,
	## Reduces the floor ante by [member magnitude] percent.
	ANTE_DISCOUNT,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 5
@export var trigger: Trigger = Trigger.PAYOUT_CALCULATED
@export var effect: Effect = Effect.FLAT_BONUS
@export var magnitude: float = 1.0
## Upper bound for effects that scale without one. Ignored when zero or less.
@export var cap: float = 0.0
## Restricts SYMBOL_BONUS / WEIGHT_SHIFT to one symbol id. Empty means every symbol.
@export var symbol_filter: StringName = &""
## Restricts PATTERN_MULT to one [enum Probability.Pattern] value. -1 means every pattern.
@export var pattern_filter: int = -1
## Tags feeding the synergy table, e.g. &"mechanical", &"greed".
@export var tags: Array[StringName] = []
## Earliest floor index (1-based) this artifact may appear in a shop.
@export var min_floor: int = 1
## Scene fragment bolted onto the machine frame when owned. Presentation only.
@export var module_scene_path: String = ""


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
