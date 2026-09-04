## The palette's ratchet.
##
## The art review's finding was that the overlay ignored the world's palette:
## four near-ambers in play, none of them equal, and a UI built from its own
## literals sitting over a room built from Materials. Fixing the constants
## once does not keep them fixed — the next colour typed straight into a
## drawing function reopens the split, and nothing would have caught it.
##
## So this counts raw Color( literals per file against a budget. The budget is
## what was there when the palette was unified; it may fall and never rise.
## A file over budget means a colour was invented somewhere that should have
## come from [Materials] or [UiSkin], and the failure names the file.
##
## The three files that own colour are exempt: they are where the swatches are
## supposed to live.
extends GdUnitTestSuite

const ROOT: String = "res://scripts/presentation"
## The files allowed to hold raw swatches, because defining them is their job.
const OWNERS: PackedStringArray = ["materials.gd", "ui_skin.gd", "symbol_art.gd"]

## Literals per file at the time the palette was unified. Lower these as the
## room's own constants take over; never raise one to make a build pass.
##
## Two entries are swatch tables rather than debt. floor_mood's MOODS is a
## per-floor palette by definition — seven floors times a key, a fill, an
## ambient, a fog and a cast — and room_dressing's are the colours of one
## floor's own fittings: the neon over the carpet, the firelight off the
## generator. Those grow when a floor gains dressing, and that is the point
## of them. They are still counted, so they cannot grow quietly.
const BUDGET: Dictionary = {
	&"casino_room.gd": 1,
	&"control_deck.gd": 1,
	&"hud.gd": 8,
	&"look/floor_mood.gd": 43,
	&"look/machine_frame.gd": 68,
	&"look/module_factory.gd": 16,
	&"look/proc_textures.gd": 11,
	&"look/room_set.gd": 43,
	&"payout_receipt.gd": 6,
	&"recap_panel.gd": 1,
	&"room_dressing.gd": 22,
	&"shop_panel.gd": 2,
	&"slot_view_3d.gd": 27,
	&"title_screen.gd": 1,
}


func test_no_file_invents_more_colour_than_its_budget() -> void:
	var counts: Dictionary = _count(ROOT, "")
	for key: StringName in counts:
		var found: int = int(counts[key])
		var allowed: int = int(BUDGET.get(key, 0))
		assert_int(found).override_failure_message(
				("%s holds %d Color() literals against a budget of %d. A colour "
				+ "the room already owns should come from Materials or UiSkin; "
				+ "if this one genuinely cannot, raise the budget in the same "
				+ "commit and say why.") % [key, found, allowed]).is_less_equal(allowed)


func test_the_budget_does_not_name_files_that_are_gone() -> void:
	var counts: Dictionary = _count(ROOT, "")
	for key: StringName in BUDGET:
		assert_bool(counts.has(key)).override_failure_message(
				("%s is in the budget but holds no Color() literals any more. "
				+ "Drop the row: a budget nobody spends is a budget nobody "
				+ "notices growing back.") % key).is_true()


## Raw Color( occurrences per file under [param dir], keyed by path relative
## to the presentation root, skipping the files that own the swatches.
func _count(dir: String, prefix: String) -> Dictionary:
	var out: Dictionary = {}
	var listing: DirAccess = DirAccess.open(dir)
	if listing == null:
		return out
	listing.list_dir_begin()
	var entry: String = listing.get_next()
	while entry != "":
		var path: String = "%s/%s" % [dir, entry]
		if listing.current_is_dir():
			out.merge(_count(path, "%s%s/" % [prefix, entry]))
		elif entry.ends_with(".gd") and not OWNERS.has(entry):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if file != null:
				var found: int = file.get_as_text().count("Color(")
				if found > 0:
					out[StringName("%s%s" % [prefix, entry])] = found
		entry = listing.get_next()
	listing.list_dir_end()
	return out
