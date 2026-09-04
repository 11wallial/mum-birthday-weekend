## The shipped builds, held to their shape: every archetype has enablers,
## amplifiers and a capstone, every partner exists, every tag counted is a
## tag worth counting, and the lab can see all of it.
extends GdUnitTestSuite

var _content: ContentDB


func before_test() -> void:
	_content = ContentDB.shared()


func test_the_vocabulary_is_closed_at_twenty_nine() -> void:
	# Growing it is a design decision, not a convenience. Move this number
	# with the reason in the commit, and give ArtifactEngine the new verb.
	assert_int(ArtifactDef.Effect.size()).is_equal(29)


func test_every_build_has_enablers_amplifiers_and_a_capstone() -> void:
	assert_int(_content.archetypes.size()).is_equal(8)
	for archetype: ArchetypeDef in _content.archetypes:
		var members: Array[ArtifactDef] = _content.artifacts_of(archetype.id)
		var roles: Dictionary = {}
		for artifact: ArtifactDef in members:
			roles[artifact.role()] = true
		assert_int(members.size()).override_failure_message(
				"%s has only %d artifacts" % [archetype.id, members.size()]).is_greater_equal(4)
		for role: StringName in [&"enabler", &"amplifier", &"capstone"]:
			assert_bool(roles.has(role)).override_failure_message(
					"%s has no %s" % [archetype.id, role]).is_true()
		assert_str(archetype.brief).is_not_empty()
		assert_str(archetype.counter).override_failure_message(
				"%s has nothing pushing back" % archetype.id).is_not_empty()


func test_every_artifact_names_a_build_that_exists_or_none() -> void:
	for artifact: ArtifactDef in _content.artifacts:
		if artifact.archetype == &"":
			continue
		assert_object(_content.archetype_by_id(artifact.archetype)).override_failure_message(
				"%s belongs to %s, which is not a build" % [artifact.id, artifact.archetype]).is_not_null()


func test_partners_tags_and_filters_name_real_things() -> void:
	var tag_counts: Dictionary = {}
	for artifact: ArtifactDef in _content.artifacts:
		for tag: StringName in artifact.tags:
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
	var families: Dictionary = {}
	for symbol: SymbolDef in _content.symbols:
		if symbol.family != &"":
			families[symbol.family] = true
	for artifact: ArtifactDef in _content.artifacts:
		match artifact.effect:
			ArtifactDef.Effect.PARTNER_MULT:
				assert_bool(artifact.partner != &"" and artifact.partner != artifact.id
						and _content.artifact_by_id(artifact.partner) != null) \
						.override_failure_message("%s wants a partner that does not exist"
						% artifact.id).is_true()
			ArtifactDef.Effect.MULT_PER_TAG:
				assert_int(int(tag_counts.get(artifact.tag_filter, 0))).override_failure_message(
						"%s counts a tag almost nothing carries" % artifact.id).is_greater_equal(3)
			ArtifactDef.Effect.MULT_PER_SEEN, ArtifactDef.Effect.MULT_PER_STREAK, \
			ArtifactDef.Effect.MULT_PER_SPIN_LEFT, ArtifactDef.Effect.AWAKENED_MULT:
				assert_float(artifact.cap).override_failure_message(
						"%s scales without a cap" % artifact.id).is_greater(0.0)
			_:
				pass
		if artifact.symbol_filter != &"":
			assert_bool(_content.symbol_by_id(artifact.symbol_filter) != null
					or families.has(artifact.symbol_filter)).override_failure_message(
					"%s filters on %s, which is neither symbol nor family"
					% [artifact.id, artifact.symbol_filter]).is_true()


func test_ids_are_unique_and_every_artifact_has_its_words() -> void:
	var seen: Dictionary = {}
	for artifact: ArtifactDef in _content.artifacts:
		assert_bool(seen.has(artifact.id)).override_failure_message(
				"%s is defined twice" % artifact.id).is_false()
		seen[artifact.id] = true
		assert_str(artifact.display_name).is_not_empty()
		assert_str(artifact.description).is_not_empty()
		assert_int(artifact.min_floor).is_between(1, _content.floors.size())
		assert_int(artifact.cost).is_greater(0)


func test_the_lab_reports_the_builds_and_the_picks() -> void:
	var report: Dictionary = CasinoLab.run_batch(300, 7)
	var builds: Dictionary = report["archetype_win_rates"]
	assert_bool(builds.is_empty()).override_failure_message(
			"no build was assembled in 300 runs").is_false()
	var picks: Dictionary = report["pick_rates"]
	assert_int(picks.size()).is_greater(40)
	var known: Array[String] = ["fair", "trap", "auto", "sleeper", "dead", "unmeasured"]
	for key: String in picks:
		var row: Dictionary = picks[key]
		assert_bool(known.has(String(row["verdict"]))).is_true()
		assert_int(int(row["taken"])).is_less_equal(int(row["offered"]))
