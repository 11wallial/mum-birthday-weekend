## One of the house's standing offers: a rule rewrite you sign for a floor.
##
## Every contract gives and every contract takes. That is the whole design: a
## draft of pure upgrades is a shopping list, and a floor whose only decision is
## "which number goes up" is not a floor. The two halves are declared as data so
## the back office can be restaffed without touching executable code.
class_name ContractDef
extends Resource

enum Clause {
	## Declares nothing. Used by a contract that only gives, or only takes.
	NONE,
	## Adds [code]magnitude[/code] spins to the floor's allowance.
	SPINS,
	## Shifts the floor's ante by [code]magnitude[/code] percent.
	ANTE_PERCENT,
	## Shifts every payout on the floor by [code]magnitude[/code] percent.
	PAYOUT_PERCENT,
	## Shifts the multiplier for the named pattern by [code]magnitude[/code].
	PATTERN_MULT,
	## Shifts the named symbol's paid value by [code]magnitude[/code] credits.
	SYMBOL_VALUE,
	## Curses pay [code]magnitude[/code] each instead of costing the penalty.
	CURSE_PAYS,
	## Shifts this floor's debt interest by [code]magnitude[/code] percent.
	DEBT_INTEREST,
	## Adds [code]magnitude[/code] free nudges to every award.
	NUDGES,
	## Shifts the named symbol's draw weight by [code]magnitude[/code].
	WEIGHT,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Earliest floor this contract may be offered on.
@export var min_floor: int = 5

@export_group("What it gives")
@export var boon: Clause = Clause.NONE
@export var boon_magnitude: float = 0.0
## Restricts a SYMBOL_VALUE or WEIGHT boon to one symbol id.
@export var boon_symbol: StringName = &""
## Restricts a PATTERN_MULT boon to one [enum Probability.Pattern]. -1 is every.
@export var boon_pattern: int = -1

@export_group("What it takes")
@export var toll: Clause = Clause.NONE
@export var toll_magnitude: float = 0.0
@export var toll_symbol: StringName = &""
@export var toll_pattern: int = -1


## Both halves as uniform records, so a reader never has to know which is which.
func clauses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if boon != Clause.NONE:
		out.append({
			"clause": boon, "magnitude": boon_magnitude,
			"symbol": boon_symbol, "pattern": boon_pattern, "gives": true,
		})
	if toll != Clause.NONE:
		out.append({
			"clause": toll, "magnitude": toll_magnitude,
			"symbol": toll_symbol, "pattern": toll_pattern, "gives": false,
		})
	return out


## One line per half, for the paper the player signs.
func terms() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in clauses():
		lines.append("%s  %s" % ["+" if bool(entry["gives"]) else "−",
				phrase(entry)])
	return lines


## Plain words for one clause. The player is signing a contract; it should read
## like one, not like a row of enum names.
static func phrase(entry: Dictionary) -> String:
	var amount: float = float(entry["magnitude"])
	var symbol: String = String(entry["symbol"])
	match int(entry["clause"]):
		Clause.SPINS:
			return "%+d spins on the floor" % int(amount)
		Clause.ANTE_PERCENT:
			return "%+d%% on the ante" % int(round(amount))
		Clause.PAYOUT_PERCENT:
			return "%+d%% on every payout" % int(round(amount))
		Clause.PATTERN_MULT:
			var pattern: int = int(entry["pattern"])
			var named: String = ("every line" if pattern < 0
					else Probability.pattern_name(pattern as Probability.Pattern)
							.capitalize().to_lower())
			return "%+.1fx on %s" % [amount, named]
		Clause.SYMBOL_VALUE:
			return "%+d credits on every %s" % [int(amount), symbol]
		Clause.CURSE_PAYS:
			return "skulls pay %d each" % int(amount)
		Clause.DEBT_INTEREST:
			return "%+d%% debt interest this floor" % int(round(amount))
		Clause.NUDGES:
			return "%+d free nudges per award" % int(amount)
		Clause.WEIGHT:
			return "%+d draw weight on %s" % [int(amount), symbol]
		_:
			return ""
