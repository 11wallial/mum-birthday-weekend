## One thing the player can earn across runs.
##
## Unlocks are data so the progression can be retuned without touching code, the
## same rule the artifacts follow.
class_name UnlockDef
extends Resource

enum Condition {
	## Total runs finished, won or lost.
	RUNS_PLAYED,
	## Runs won.
	WINS,
	## Best floor reached in any single run.
	BEST_FLOOR,
	## Credits earned across every run.
	LIFETIME_EARNED,
	## Debt principal cleared across every run, via paydown artifacts.
	DEBT_CLEARED,
	## Runs won at the difficulty named by [member condition_id]. The ladder:
	## each rung is unlocked by a win on the one below it.
	WINS_AT,
	## Floors cleared past the last, on the run that stayed at the table
	## longest.
	AFTER_HOURS,
	## Spins pulled across every run. The one number that only goes up at the
	## rate the player actually plays, which is what a long arc is paced on.
	TOTAL_SPINS,
	## Interest handed to the House across every run.
	VIG_PAID,
}

enum Kind {
	## Adds an artifact to the pool the shop may offer.
	ARTIFACT,
	## Makes a machine selectable. Named for the starter variants it used to
	## open; the value is written into profiles, so the name stays.
	STARTER,
	## Makes a difficulty modifier selectable.
	DIFFICULTY,
	## Makes a challenge run selectable.
	CHALLENGE,
	## Puts a chit in the draft's pool. Appended: the value is written into
	## profiles.
	CHIT,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ARTIFACT
## Artifact id, starter id or difficulty id this unlocks, depending on [member kind].
@export var target_id: StringName = &""
@export var condition: Condition = Condition.RUNS_PLAYED
@export var threshold: int = 1
## What the condition is about, for the conditions that name something: the
## difficulty a win has to be at.
@export var condition_id: StringName = &""


## True when [param stats] meets this unlock's condition.
func is_met(stats: Dictionary) -> bool:
	return int(stats.get(_stat_key(), 0)) >= threshold


func _stat_key() -> String:
	match condition:
		Condition.RUNS_PLAYED:
			return "runs_played"
		Condition.WINS:
			return "wins"
		Condition.BEST_FLOOR:
			return "best_floor"
		Condition.LIFETIME_EARNED:
			return "lifetime_earned"
		Condition.DEBT_CLEARED:
			return "debt_cleared"
		Condition.WINS_AT:
			return "wins_at:%s" % condition_id
		Condition.AFTER_HOURS:
			return "deepest_after_hours"
		Condition.TOTAL_SPINS:
			return "total_spins"
		Condition.VIG_PAID:
			return "vig_paid"
		_:
			return "runs_played"


## How much of the condition is still outstanding. Zero once met.
func remaining(stats: Dictionary) -> int:
	return maxi(0, threshold - int(stats.get(_stat_key(), 0)))


## Human-readable requirement, for the unlock list in the UI.
func requirement_text() -> String:
	match condition:
		Condition.RUNS_PLAYED:
			return "Finish %d runs" % threshold
		Condition.WINS:
			return "Win %d runs" % threshold
		Condition.BEST_FLOOR:
			return "Reach floor %d" % threshold
		Condition.LIFETIME_EARNED:
			return "Earn %s credits in total" % _grouped(threshold)
		Condition.DEBT_CLEARED:
			return "Clear %s of debt principal" % _grouped(threshold)
		Condition.WINS_AT:
			return "Win %d at %s" % [threshold, String(condition_id).capitalize()]
		Condition.AFTER_HOURS:
			return "Last %d floors after hours" % threshold
		Condition.TOTAL_SPINS:
			return "Take %s spins" % _grouped(threshold)
		Condition.VIG_PAID:
			return "Pay %s in interest" % _grouped(threshold)
		_:
			return ""


## A long number with thousands separators, because a requirement is read at a
## glance and 250000 is not read at a glance.
func _grouped(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	for i: int in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out
