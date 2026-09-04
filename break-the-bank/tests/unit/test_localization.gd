extends GdUnitTestSuite

## The strings go through tr(): the keys are the English, a row per caption
## in resources/locale/strings.csv, and a translation added for a locale is
## what the door shows in it.
##
## Content copy — an artifact's name, a boss's tell, a floor's sign — lives in
## .tres and is drawn as data, so it goes through [Copy] at the moment it
## becomes words. Its rows are put in the table by tools/text/extract.py, which
## CI runs with --check.
##
## The tests above register their own throwaway Translation to check the
## mechanism; they use the locale "qx", which nothing ships as, because a
## real shipped locale sharing a key with an ad-hoc test Translation put two
## Translations claiming the same locale and key in TranslationServer at
## once — it did not pick one, it returned a spliced-together corruption of
## both. The test below is the one that exercises the real, shipped French.


func test_the_english_table_is_loaded_and_keys_are_themselves() -> void:
	var caption: String = TranslationServer.translate("PULL THE LEVER")
	assert_str(caption).is_equal("PULL THE LEVER")
	assert_bool(TranslationServer.get_loaded_locales().has("en")).is_true()


func test_a_translation_for_another_locale_is_honoured() -> void:
	# A locale nothing ships as, on purpose: the project now loads a real
	# fr translation at boot, and adding a second Translation for "fr" here
	# with an overlapping key ("PULL THE LEVER" is a real row now that
	# French exists) put two same-locale Translations in the server at
	# once. TranslationServer.translate() does not pick one — it returned a
	# corrupted splice of both. This suite tests the mechanism, not the
	# shipped French, so it needs a locale nobody else is using.
	var pretend: Translation = Translation.new()
	pretend.locale = "qx"
	pretend.add_message("PULL THE LEVER", "TIREZ LE LEVIER")
	TranslationServer.add_translation(pretend)
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("qx")
	assert_str(TranslationServer.translate("PULL THE LEVER")).is_equal("TIREZ LE LEVIER")
	# A caption with no row comes back as itself, so numbers and seeds are safe.
	assert_str(TranslationServer.translate("OTTER-QUARRY-TILT")).is_equal("OTTER-QUARRY-TILT")
	TranslationServer.set_locale(before)
	TranslationServer.remove_translation(pretend)


func test_content_copy_is_translated_where_it_is_drawn() -> void:
	var content: ContentDB = ContentDB.shared()
	var artifact: ArtifactDef = content.artifacts[0]
	# See the note on the locale above: "qx", never "fr", now that "fr" is
	# real and this artifact's own name is already a row in it.
	var pretend: Translation = Translation.new()
	pretend.locale = "qx"
	pretend.add_message(artifact.display_name, "LE DISPOSITIF")
	TranslationServer.add_translation(pretend)
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("qx")
	assert_str(Copy.of(artifact.display_name)).is_equal("LE DISPOSITIF")
	# Cased after translation, never before: the other order shouts in English.
	assert_str(Copy.upper(artifact.display_name)).is_equal("LE DISPOSITIF")
	assert_str(Copy.lower(artifact.display_name)).is_equal("le dispositif")
	TranslationServer.set_locale(before)
	TranslationServer.remove_translation(pretend)


func test_a_name_with_no_row_comes_back_as_itself() -> void:
	# Which is what a seed, a number, or a floor invented past the last one does.
	assert_str(Copy.of("After Hours 3")).is_equal("After Hours 3")
	assert_str(Copy.of("")).is_equal("")


func test_a_sentence_is_filled_after_its_shape_is_translated() -> void:
	# "qx" again: "Noticed. %s is coming." is a real row in the shipped
	# French now too.
	var pretend: Translation = Translation.new()
	pretend.locale = "qx"
	pretend.add_message("Noticed. %s is coming.", "Repéré. %s arrive.")
	TranslationServer.add_translation(pretend)
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("qx")
	assert_str(Copy.filled("Noticed. %s is coming.", ["le comptable"])).is_equal(
			"Repéré. le comptable arrive.")
	TranslationServer.set_locale(before)
	TranslationServer.remove_translation(pretend)


func test_every_content_string_has_a_row() -> void:
	# The table is what a translator is handed; a name with no row ships in
	# English. It has to be read as a file: the importer compresses the table,
	# and a compressed Translation cannot list what is in it — translate()
	# returns the key either way, which is exactly the case being checked.
	# tools/text/extract.py --check is the same test over the whole content
	# set, and CI runs it.
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://resources/locale/strings.csv", FileAccess.READ)
	assert_object(file).is_not_null()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 0 and row[0] != "":
			rows[row[0]] = true
	file.close()
	var content: ContentDB = ContentDB.shared()
	for artifact: ArtifactDef in content.artifacts:
		assert_bool(rows.has(artifact.display_name)).override_failure_message(
				"%s has no row in the table" % artifact.display_name).is_true()
		assert_bool(rows.has(artifact.description)).override_failure_message(
				"%s has no row for its description" % artifact.display_name).is_true()
	for boss: BossDef in content.bosses:
		assert_bool(rows.has(boss.display_name)).override_failure_message(
				"%s has no row in the table" % boss.display_name).is_true()
	for chit: ChitDef in content.chits:
		assert_bool(rows.has(chit.display_name)).override_failure_message(
				"%s has no row in the table" % chit.display_name).is_true()


func test_the_shipped_french_actually_translates() -> void:
	# Real French, loaded the way the game loads it — project.godot's
	# locale/translations, not a test's own Translation object — actually
	# changes what a caption reads as. This is the regression the throwaway
	# tests above cannot catch: they prove the mechanism works, not that the
	# shipped column does.
	if not TranslationServer.get_loaded_locales().has("fr"):
		return
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	var lever: String = TranslationServer.translate("PULL THE LEVER")
	assert_str(lever).override_failure_message(
			"PULL THE LEVER did not translate into French").is_not_equal("PULL THE LEVER")
	assert_bool(lever.is_empty()).override_failure_message(
			"PULL THE LEVER translated to an empty string in French").is_false()
	TranslationServer.set_locale(before)
