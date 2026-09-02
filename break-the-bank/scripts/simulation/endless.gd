## The floors past the last one, for a run that stays at the table.
##
## The House's counter-offer. A run that clears the seventh floor and repays
## the debt has beaten the game; the House offers the debt back, and a chair,
## and the floors go on — each ante compounding on the last, the shop still
## open, the back office still signing — until an ante is missed. There is no
## floor eight in the content because there is no end to these: they are made
## from the last authored floor and the growth rate in [BalanceConfig], so the
## balance loop can tune how fast the table gets expensive without authoring
## a floor nobody will ever see.
class_name Endless
extends RefCounted


## What the run owes when it stays: the reason there is still a clock.
const OFFER: String = "The House offers your debt back, and a chair."


## True when [param index] is past every authored floor.
static func is_beyond(content: ContentDB, index: int) -> bool:
	return content.floors.size() > 0 and index > content.floors[content.floors.size() - 1].index


## A floor made from the last authored one. Null when the content has none.
static func floor_for(content: ContentDB, index: int) -> FloorDef:
	if content.floors.is_empty():
		return null
	var last: FloorDef = content.floors[content.floors.size() - 1]
	if index <= last.index:
		return content.floor_at(index)
	var beyond: int = index - last.index
	var floor_def: FloorDef = FloorDef.new()
	floor_def.index = index
	floor_def.display_name = "After Hours %d" % beyond
	floor_def.description = "The House keeps the lights on."
	floor_def.ante = maxi(1, int(round(float(last.ante)
			* pow(maxf(content.balance.endless_ante_growth, 1.0), float(beyond)))))
	floor_def.spins = last.spins + content.balance.endless_spins_bonus
	floor_def.debt_interest_percent = last.debt_interest_percent
	floor_def.shop_slots = last.shop_slots
	floor_def.payout_scale = last.payout_scale
	floor_def.environment_id = last.environment_id
	floor_def.grants = []
	return floor_def
