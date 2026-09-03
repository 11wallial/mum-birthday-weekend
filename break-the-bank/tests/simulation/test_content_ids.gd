extends GdUnitTestSuite

## Ids, across every kind of content there is.
##
## Nothing had ever asserted that an artifact and a contract cannot share an
## id. They nearly did: a lane writing artifacts reached for `danger_money`
## and `the_float`, which are a contract and a floor skin, and only noticed
## because it happened to read the other files. The save journal, the
## profile's collection and every telemetry key are strings, so a collision
## is silent and lands in someone's save.


func _ids(defs: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: Resource in defs:
		out.append(StringName(def.get("id")))
	return out


func test_no_two_pieces_of_content_share_an_id() -> void:
	# The six kinds a run meets. They share the collection, the bus payloads
	# and every telemetry dictionary keyed by id, and two of them answering
	# to the same name is a thing nobody can read a report about.
	#
	# The ruleset ids — machine, difficulty, challenge — are deliberately not
	# here: each lives in its own labelled field of RunOptions and its own
	# position in the ruleset key, so The Standard the machine and Standard
	# the first rung cannot be confused by anything but a person.
	var content: ContentDB = ContentDB.shared()
	var kinds: Dictionary = {
		"artifact": _ids(content.artifacts), "symbol": _ids(content.symbols),
		"contract": _ids(content.contracts), "chit": _ids(content.chits),
		"boss": _ids(content.bosses), "skin": _ids(content.skins),
	}
	var seen: Dictionary = {}
	for kind: String in kinds:
		for id: StringName in kinds[kind]:
			var key: String = String(id)
			assert_bool(seen.has(key)).override_failure_message(
					"%s %s is also a %s" % [kind, key, seen.get(key, "")]).is_false()
			seen[key] = kind


func test_nothing_is_shipped_without_an_id_or_a_name() -> void:
	var content: ContentDB = ContentDB.shared()
	for defs: Array in [content.artifacts, content.symbols, content.contracts,
			content.chits, content.bosses, content.skins]:
		for def: Resource in defs:
			assert_str(String(def.get("id"))).override_failure_message(
					"a piece of content has no id").is_not_empty()
			assert_str(String(def.get("display_name"))).override_failure_message(
					"%s has no name" % def.get("id")).is_not_empty()


func test_every_symbol_has_drum_art() -> void:
	# The gap this closes: six symbols shipped this session with no entry in
	# SymbolArt._build_ops and no room in ReelPrint.CELLS. They rendered as
	# bare glyph-text plates on the drum — a real regression that passed
	# every other gate (import, the lab, both balance bands, voice, the
	# pseudolocale check) because none of them look at what a symbol draws
	# as. Caught this time by a fresh storyboard render and a second,
	# independent pass over the source; a symbol added without art should
	# fail here before it reaches either.
	var content: ContentDB = ContentDB.shared()
	for symbol: SymbolDef in content.symbols:
		assert_bool(SymbolArt.ops_for(symbol.id).is_empty()).override_failure_message(
				"%s has no drawing in SymbolArt._build_ops" % symbol.id).is_false()


func test_every_symbol_has_a_cell_on_the_drum() -> void:
	var content: ContentDB = ContentDB.shared()
	assert_int(ReelPrint.CELLS).override_failure_message(
			"ReelPrint.CELLS (%d) is smaller than the content set (%d) — some symbols will never be printed on the drum" % [
					ReelPrint.CELLS, content.symbols.size()]).is_greater_equal(content.symbols.size())
	for symbol: SymbolDef in content.symbols:
		assert_bool(ReelPrint.PREFERRED.has(symbol.id)).override_failure_message(
				"%s is not in ReelPrint.PREFERRED — it will still get a cell (the fallback loop fills unclaimed ones) but not the deliberate, spread-out placement every other symbol was given" % symbol.id).is_true()
