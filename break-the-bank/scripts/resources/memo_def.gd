## One line from the House, printed on the ledger between floors.
##
## The CRT is the House's side of the conversation, and this is what it says:
## short, exact, and more familiar the more interested the House gets. A memo
## is chosen by where the run stands — the floor, how the debt compares to the
## ante in front of it, what the count is doing, whether the run has stayed —
## and the most specific memo that fits is the one printed. Data, so the
## writing pass never touches code.
class_name MemoDef
extends Resource

@export var id: StringName = &""
## Two short lines at most: the monitor holds about twenty characters a line.
@export_multiline var text: String = ""

@export_group("When it is printed")
## Floors this memo may appear on, inclusive. Zero for either means no bound.
@export var floor_min: int = 0
@export var floor_max: int = 0
## Least the debt has to be, as a multiple of the floor's ante. Zero: any.
@export var debt_ratio_min: float = 0.0
## Most the debt may be, as a multiple of the ante. Zero: any.
@export var debt_ratio_max: float = 0.0
## Least the count has to be, as [enum HeatEngine.Measure]. Zero: any.
@export var heat_min: int = 0
## Only after the run has stayed at the table.
@export var after_hours: bool = false
## Only on the run's last authored floor.
@export var last_floor: bool = false


## How pointed this memo is. The most pointed memo that fits is printed, and
## the weights are the House's priorities: what the count is doing outranks
## everything, a line written for one floor outranks one written for a band
## of them or for the debt, and the debt outranks having nothing to say.
func specificity() -> int:
	var count: int = 0
	if floor_min > 0 and floor_min == floor_max:
		count += 3
	elif floor_min > 0 or floor_max > 0:
		count += 1
	if debt_ratio_min > 0.0 or debt_ratio_max > 0.0:
		count += 1
	if heat_min > 0:
		count += 2 + heat_min
	if after_hours:
		count += 1
	if last_floor:
		count += 2
	return count
