## The game's type, in one place.
##
## Three faces, and a rule for each. The art handover asked for one display
## face and one readable body face; the House's paperwork asked for a third.
##
## - **Display** (Bebas Neue): condensed industrial caps. The wordmark, the
##   floor sign, every plate and caption stamped into metal. Caps only —
##   the face has no lowercase, which is exactly right for a thing painted
##   on a machine.
## - **Body** (IBM Plex Sans): everything a person reads at length — the
##   forms, the offers, the callouts. Chosen for the obvious reason: it is
##   the typeface of a company that sold counting machines to firms like
##   the House.
## - **Mono** (IBM Plex Mono): the paperwork and the counters. The receipt,
##   the statement, the ledger's tube, the Nixie digits — anything printed
##   by a machine or set in a column that has to line up.
##
## All three are SIL Open Font License 1.1; the licences ship beside them in
## `assets/fonts/`. Nothing here is fetched at runtime.
class_name Type
extends RefCounted

const DISPLAY_PATH: String = "res://assets/fonts/BebasNeue-Regular.ttf"
const BODY_PATH: String = "res://assets/fonts/IBMPlexSans.ttf"
const MONO_PATH: String = "res://assets/fonts/IBMPlexMono-Regular.ttf"

static var _cache: Dictionary = {}


static func display() -> Font:
	return _face(DISPLAY_PATH)


static func body() -> Font:
	return _face(BODY_PATH)


static func mono() -> Font:
	return _face(MONO_PATH)


## Dresses a [Label3D] in one of the three faces. Named rather than passed
## so a caller says what a label is for, not which file to open.
static func face(label: Label3D, role: StringName) -> void:
	match role:
		&"display":
			label.font = display()
		&"mono":
			label.font = mono()
		_:
			label.font = body()


static func _face(path: String) -> Font:
	if not _cache.has(path):
		# A missing face is not fatal: the engine's default is ugly, not
		# broken, and a build that lost its fonts should still be playable.
		_cache[path] = load(path) as Font
	return _cache[path] as Font
