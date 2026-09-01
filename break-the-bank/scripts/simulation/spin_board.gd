## The three rows of symbols currently standing on the machine, and what they pay.
##
## A slot machine is read vertically as well as horizontally. The band above and
## below the payline used to be decoration; a nudge pulls it down onto the line,
## so all three rows are simulation state and every row here is authoritative.
##
## Pure data plus pure transforms: nothing in this file draws, emits or waits.
class_name SpinBoard
extends RefCounted

## Row indices, top to bottom. The payline is the middle row.
enum Row { ABOVE, PAYLINE, BELOW }

## Symbols standing on each row, indexed by reel.
var above: Array[SymbolDef] = []
var line: Array[SymbolDef] = []
var below: Array[SymbolDef] = []
## Reels the player has locked for the next spin.
var held: Array[bool] = []
## Nudges the machine will allow on this board. Taking one costs a spin off the
## floor's allowance unless a free one is left, which is the whole reason a
## nudge is a decision rather than a free look.
var nudges: int = 0
## Nudges on this board that cost nothing, from hardware and from a raised stake.
var free_nudges: int = 0
## Nudges already spent, so the machine can show what it cost.
var nudges_used: int = 0
## Pattern and payout of the payline as it currently stands.
var pattern: Probability.Pattern = Probability.Pattern.NONE
var payout: int = 0
## Multiplier the payout was reached through. Presentation reads it.
var multiplier: float = 1.0
## The scoring breakdown behind [member payout], for telemetry and the readout.
var breakdown: Dictionary = {}
## Rungs climbed on the gamble ladder for this board.
var gamble_rung: int = 0


func reel_count() -> int:
	return line.size()


## Resizes every row to [param count] reels, keeping what is already standing.
func resize(count: int) -> void:
	_fit(above, count)
	_fit(line, count)
	_fit(below, count)
	while held.size() < count:
		held.append(false)
	while held.size() > count:
		held.remove_at(held.size() - 1)


## True when [param reel] is locked for the next spin.
func is_held(reel: int) -> bool:
	return reel >= 0 and reel < held.size() and held[reel]


func held_count() -> int:
	var total: int = 0
	for locked: bool in held:
		if locked:
			total += 1
	return total


func clear_holds() -> void:
	for i: int in held.size():
		held[i] = false


## The whole column standing on [param reel], top to bottom.
func column(reel: int) -> Array[SymbolDef]:
	var out: Array[SymbolDef] = []
	if reel < 0 or reel >= line.size():
		return out
	out.append(above[reel] if reel < above.size() else null)
	out.append(line[reel])
	out.append(below[reel] if reel < below.size() else null)
	return out


## Sets one reel's whole column at once.
func set_column(reel: int, top: SymbolDef, middle: SymbolDef, bottom: SymbolDef) -> void:
	if reel < 0 or reel >= line.size():
		return
	above[reel] = top
	line[reel] = middle
	below[reel] = bottom


## The payline as it would read if [param reel] were nudged once, without
## drawing the replacement or touching this board.
##
## Nudging has to be previewable: an automated policy — and the machine's own
## hint lamp — needs to know whether a nudge helps before spending it, and a
## preview that mutated the board would consume a draw every time it looked.
func preview_nudge(reel: int) -> Array[SymbolDef]:
	var hypothetical: Array[SymbolDef] = line.duplicate()
	if reel >= 0 and reel < above.size() and above[reel] != null:
		hypothetical[reel] = above[reel]
	return hypothetical


## True when nudging [param reel] is a legal move on this board.
func can_nudge(reel: int) -> bool:
	return (nudges > 0 and reel >= 0 and reel < above.size()
			and above[reel] != null)


## True when the next nudge is on the house.
func next_nudge_is_free() -> bool:
	return free_nudges > 0


## Drops one reel by a stop: the band above falls onto the payline, the payline
## falls into the band below, and [param incoming] appears at the top.
func nudge(reel: int, incoming: SymbolDef) -> void:
	if not can_nudge(reel):
		return
	below[reel] = line[reel]
	line[reel] = above[reel]
	above[reel] = incoming
	nudges -= 1
	nudges_used += 1
	free_nudges = maxi(0, free_nudges - 1)


func _fit(row: Array[SymbolDef], count: int) -> void:
	while row.size() < count:
		row.append(null)
	while row.size() > count:
		row.remove_at(row.size() - 1)
