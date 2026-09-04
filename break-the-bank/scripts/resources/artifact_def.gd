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

## The closed vocabulary. Every artifact is one of these with numbers on it,
## resolved in one place ([ArtifactEngine]); a new entry is a design decision,
## not a convenience. Append, never reorder: the value is written into saves
## and content fingerprints.
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
	## Scores the line [member magnitude] extra times: payout x (1 + magnitude).
	## Honours [member pattern_filter] when one is set.
	RETRIGGER,
	## Curses stop suppressing the pattern bonus and pay [member magnitude] each
	## instead of costing the curse penalty.
	CURSE_WARD,
	## Adds [member magnitude] to the multiplier per floor already cleared.
	MULT_PER_FLOOR,
	## Adds [member magnitude] to the multiplier per artifact owned.
	MULT_PER_ARTIFACT,
	## Wipes [member magnitude] percent of outstanding debt when a floor clears.
	DEBT_PAYDOWN,
	## Adds [member magnitude] to the multiplier per 100 credits of outstanding
	## debt, capped by [member cap]. Debt was only ever a threat; this makes it
	## something a build can be made of, and makes paying it down a real cost
	## rather than an obvious good.
	DEBT_LEVERAGE,
	## [member magnitude] percent chance a spin is not consumed. The pool had no
	## way to buy tempo — only payout — so every artifact competed on the same
	## axis.
	SPIN_REFUND,
	## Adds [member magnitude] nudges to every award the machine makes. Buys
	## control over the board rather than a bigger number off it.
	NUDGE_BONUS,
	## Adds [member magnitude] percentage points to what the vault pays.
	VAULT_YIELD,
	## Cuts the count the House gains by [member magnitude] percent. The only
	## thing in the game that buys down attention rather than buying up power.
	HEAT_SHIELD,
	## Adds [member magnitude] to the multiplier per symbol matching
	## [member symbol_filter] that has landed on the payline since this was
	## bought, capped by [member cap]. The tally lives on the run, grows only
	## with settled spins, and is wiped when the artifact is sold — the first
	## effect that gets stronger the longer it is owned rather than the deeper
	## the run is.
	MULT_PER_SEEN,
	## Adds [member magnitude] to the multiplier per other artifact that
	## triggered on the line. Resolved last, so a build of many small devices
	## has a reason to exist beyond the sum of them.
	MULT_PER_TRIGGER,
	## Adds [member magnitude] to the multiplier per curse standing on the
	## line, warded or not. Skulls as a thing to want.
	MULT_PER_CURSE,
	## Adds [member magnitude] to the multiplier per reel held for the spin.
	## Holding is charged for; this is what makes the charge worth paying.
	MULT_PER_HOLD,
	## Adds [member magnitude] to the multiplier per nudge spent on the board.
	## A paid nudge is a spin off the floor; this is what buys it back.
	MULT_PER_NUDGE,
	## Adds [member magnitude] to the multiplier per stake level above the
	## first. The stake already multiplies the payout; this makes a raised
	## wager superlinear, and the count is what pushes back.
	MULT_PER_STAKE,
	## Adds [member magnitude] to the multiplier per paying spin in a row
	## before this one, capped by [member cap]. A dud resets it.
	MULT_PER_STREAK,
	## Adds [member magnitude] to the multiplier per owned artifact carrying
	## [member tag_filter]. The synergy bonus made tags matter once, at the
	## threshold; this makes every device of a kind matter.
	MULT_PER_TAG,
	## Adds [member magnitude] to the multiplier per spin still left on the
	## floor, capped by [member cap]. Pays for winning early and decays as
	## the floor runs on.
	MULT_PER_SPIN_LEFT,
	## Adds [member magnitude] to the multiplier while [member partner] is
	## also owned, and nothing at all on its own: a combo built on purpose.
	PARTNER_MULT,
	## Nothing until [member cap] spins have been settled since it was
	## bought; then [member magnitude] on every line for the rest of the run.
	## The one effect that transforms rather than scales.
	AWAKENED_MULT,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 5
@export var trigger: Trigger = Trigger.PAYOUT_CALCULATED
@export var effect: Effect = Effect.FLAT_BONUS
@export var magnitude: float = 1.0
## Upper bound for effects that scale without one. Ignored when zero or less.
## For AWAKENED_MULT it is the spins to wait, not a ceiling.
@export var cap: float = 0.0
## Restricts SYMBOL_BONUS / WEIGHT_SHIFT / MULT_PER_SEEN to one symbol id, or
## to every symbol of a family when it names one. Empty means every symbol.
@export var symbol_filter: StringName = &""
## Restricts PATTERN_MULT and RETRIGGER to one [enum Probability.Pattern] value. -1 means every pattern.
@export var pattern_filter: int = -1
## Tags feeding the synergy table, e.g. &"mechanical", &"greed".
@export var tags: Array[StringName] = []
## Earliest floor index (1-based) this artifact may appear in a shop.
@export var min_floor: int = 1
## Scene fragment bolted onto the machine frame when owned. Presentation only.
@export var module_scene_path: String = ""
## The artifact PARTNER_MULT wants to see beside it. Empty otherwise.
@export var partner: StringName = &""
## The tag MULT_PER_TAG counts. Empty otherwise.
@export var tag_filter: StringName = &""
## The build this artifact belongs to, by [ArchetypeDef] id, or empty for a
## device that fits any machine. The lab measures each build's win rate by
## it, and the automated player chases whichever it has the most of.
@export var archetype: StringName = &""


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## Impact tier 1-4, derived from how deep the artifact unlocks. Presentation
## uses it to scale feedback: a floor 7 payoff should not sound, or feel, like a
## floor 1 trinket.
func tier() -> int:
	return clampi(int(ceil(float(min_floor) / 2.0)), 1, 4)


## What this artifact is to its build, read off where it unlocks: an enabler
## on the first two floors, a capstone from the engine room up, an amplifier
## between. Derived rather than authored so the shape of a build is a fact
## about the content and not an opinion written beside it.
func role() -> StringName:
	if min_floor <= 2:
		return &"enabler"
	if min_floor >= 6:
		return &"capstone"
	return &"amplifier"
