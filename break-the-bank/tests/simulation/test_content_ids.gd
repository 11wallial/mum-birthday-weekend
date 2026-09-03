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
