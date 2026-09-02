## The statement of account: what a finished run was, in facts a player can
## read their own mistake in.
##
## The balance guide's hardest bar is that four in five players can name
## their mistake after a loss; without that the game reads as random however
## much choice it gave. This builds the material for it from the run itself
## — the outcome in the House's own terms, the numbers, the moves the
## journal recorded, and a short list of findings: things that were true of
## the run and are the usual places a run is lost. Findings are facts, not
## verdicts; the player draws the line.
##
## Pure: a function of the state and the journal's entries. The recap panel
## prints it; the lab could summarise it.
class_name RunRecap
extends RefCounted

## Most findings printed: the House is precise, not exhaustive.
const MAX_FINDINGS: int = 4


## Builds the statement for [param state], with [param entries] as the
## journal's verbs (an array of [verb, arg] arrays, possibly empty).
static func build(state: RunState, entries: Array = []) -> Dictionary:
	var moves: Dictionary = count_moves(entries)
	var floor_def: FloorDef = state.current_floor()
	var recap: Dictionary = {
		"won": state.phase == RunState.Phase.WON or state.endless,
		"reason": String(state.end_reason),
		"outcome": outcome_line(state),
		"floors_cleared": state.floors_cleared,
		"floor_index": state.floor_index,
		"floor_name": floor_def.display_name if floor_def != null else "",
		"spins_taken": state.spins_taken,
		"best_payout": state.best_payout,
		"earned": state.economy.lifetime_earned,
		"chips": state.economy.lifetime_chips,
		"debt": state.economy.debt,
		"cash": state.economy.cash,
		"hardware": _names(state.owned),
		"people": _people(state),
		"notices": state.notices,
		"noticed_floor": state.noticed_floor,
		"noticed_payout": state.noticed_payout,
		"moves": moves,
		"last_payout": state.last_payout,
		"last_steps": (state.board.breakdown.get("steps", []) as Array).duplicate(),
		"findings": findings(state, moves),
	}
	return recap


## The outcome, in the House's register.
static func outcome_line(state: RunState) -> String:
	match String(state.end_reason):
		"ante_unpaid":
			var floor_def: FloorDef = state.current_floor()
			var owed: int = state.ante_due()
			return "The ante on %s was %d. You held %d. The House keeps the table, and the surety." % [
				floor_def.display_name if floor_def != null else "the floor", owed,
				state.economy.cash]
		"debt_unpaid":
			return "Every floor cleared, and %d still on the account. The House keeps the surety." % state.economy.debt
		"cleared_all_floors":
			return "Every floor cleared and the account settled. The surety is returned."
		"dawn":
			return "Dawn. The House closes, and you walk out with what you kept."
		_:
			return "The account is closed."


## How many of each move the journal recorded, keyed by verb.
static func count_moves(entries: Array) -> Dictionary:
	var moves: Dictionary = {}
	for entry: Variant in entries:
		var row: Array = entry as Array
		if row.is_empty():
			continue
		var verb: String = String(row[0])
		moves[verb] = int(moves.get(verb, 0)) + 1
	return moves


## The findings: what was true of the run, in the places runs are lost.
## Facts, each one something the player can point at. At most
## [constant MAX_FINDINGS], the sharpest first.
static func findings(state: RunState, moves: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var lost: bool = state.phase == RunState.Phase.LOST
	if lost and String(state.end_reason) == "ante_unpaid":
		var short: int = maxi(0, state.vig_due() + state.ante_due() - state.economy.cash)
		out.append("Short by %d at the close of floor %d, with the spins gone." % [
				short, state.floor_index])
	if state.notices > 0:
		out.append("The House noticed you %s: %d in one spin on floor %d, and sent someone up." % [
				"once" if state.notices == 1 else "%d times" % state.notices,
				state.noticed_payout, state.noticed_floor])
	var holds: int = int(moves.get("toggle_hold", 0))
	if holds == 0 and state.floors_cleared >= 1 and state.has_system(Systems.HOLD):
		out.append("You never held a reel. A pair held is a third drum spun for the line.")
	var declined: int = int(moves.get("decline_nudges", 0))
	var nudged: int = int(moves.get("nudge", 0))
	if declined > nudged and declined >= 3:
		out.append("You declined nudges %d times and took %d." % [declined, nudged])
	if state.floors_settled_early == 0 and state.floors_cleared >= 2:
		out.append("You never settled a floor early. The House pays scrip for the spins you do not need.")
	var unspent: int = 0
	var drafts: int = 0
	for left: int in state.chips_left_at_drafts:
		drafts += 1
		if left >= 3:
			unspent += 1
	if unspent >= 2:
		out.append("You left three or more chips on the table at %d of %d drafts." % [unspent, drafts])
	if state.has_system(Systems.STAKE) and int(moves.get("set_stake", 0)) == 0 \
			and state.floors_cleared >= 3:
		out.append("The stake stayed at one from the moment it was offered.")
	if state.has_system(Systems.VAULT) and int(moves.get("deposit", 0)) == 0 \
			and state.floors_cleared >= 4:
		out.append("Nothing was ever put in the vault.")
	if lost and String(state.end_reason) == "debt_unpaid":
		out.append("The principal was never paid down; it compounded every floor.")
	if out.size() > MAX_FINDINGS:
		out.resize(MAX_FINDINGS)
	return out


static func _names(artifacts: Array[ArtifactDef]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for artifact: ArtifactDef in artifacts:
		names.append(artifact.display_name)
	return names


static func _people(state: RunState) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for id: StringName in state.bosses_faced:
		if id == &"":
			continue
		var person: BossDef = state.content.boss_by_id(id)
		names.append(person.display_name if person != null else String(id).capitalize())
	return names
