## One chit: a slip of the House's paper, bought at the draft for chips,
## carried in the pocket, spent once.
##
## The roadmap's consumable class — the tarot layer, in the House's
## register. Hardware is the engine and stays; a chit is a decision you buy
## in advance and take at the moment it matters: a reel respun, the count
## vented, a vig deferred, a symbol marked, the next line peeked at. Five
## kinds, a closed vocabulary resolved in [SimEngine._do_use_chit]; content
## sets the price, the floor and the size.
class_name ChitDef
extends Resource

enum Kind {
	## Respin the last drum while a decision is on the table.
	RESPIN,
	## Vent [member magnitude] off the count.
	VENT,
	## The floor's vig is added to the principal instead of charged.
	DEFERRAL,
	## The last drum lands on [member symbol] next spin.
	MARKER,
	## The next line is printed on the ledger before it is spun.
	PEEK,
	## Adds [member magnitude] nudges to the board on the table. Paper that
	## buys control of a board that has already landed, rather than another
	## board.
	NUDGE_TICKET,
	## Adds [member magnitude] spins to the floor's allowance. The only thing
	## in the pocket that buys time.
	SPIN_TICKET,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Chips.
@export var cost: int = 3
@export var kind: Kind = Kind.RESPIN
@export var magnitude: float = 0.0
## The symbol a marker lands, by id.
@export var symbol: StringName = &""
## The first floor whose draft may offer it.
@export var min_floor: int = 2
