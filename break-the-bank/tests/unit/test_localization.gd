extends GdUnitTestSuite

## The strings go through tr(): the keys are the English, a row per caption
## in resources/locale/strings.csv, and a translation added for a locale is
## what the door shows in it.
##
## Content copy — an artifact's name, a boss's tell, a floor's sign — lives in
## .tres and is drawn as data, so it goes through [Copy] at the moment it
## becomes words. Its rows are put in the table by tools/text/extract.py, which
## CI runs with --check.


func test_the_english_table_is_loaded_and_keys_are_themselves() -> void:
	var caption: String = TranslationServer.translate("PULL THE LEVER")
	assert_str(caption).is_equal("PULL THE LEVER")
	assert_bool(TranslationServer.get_loaded_locales().has("en")).is_true()


func test_a_translation_for_another_locale_is_honoured() -> void:
	var french: Translation = Translation.new()
	french.locale = "fr"
	french.add_message("PULL THE LEVER", "TIREZ LE LEVIER")
	TranslationServer.add_translation(french)
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	assert_str(TranslationServer.translate("PULL THE LEVER")).is_equal("TIREZ LE LEVIER")
	# A caption with no row comes back as itself, so numbers and seeds are safe.
	assert_str(TranslationServer.translate("OTTER-QUARRY-TILT")).is_equal("OTTER-QUARRY-TILT")
	TranslationServer.set_locale(before)
	TranslationServer.remove_translation(french)


func test_content_copy_is_translated_where_it_is_drawn() -> void:
	var content: ContentDB = ContentDB.shared()
	var artifact: ArtifactDef = content.artifacts[0]
	var french: Translation = Translation.new()
	french.locale = "fr"
	french.add_message(artifact.display_name, "LE DISPOSITIF")
	TranslationServer.add_translation(french)
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	assert_str(Copy.of(artifact.display_name)).is_equal("LE DISPOSITIF")
	# Cased after translation, never before: the other order shouts in English.
	assert_str(Copy.upper(artifact.display_name)).is_equal("LE DISPOSITIF")
	assert_str(Copy.lower(artifact.display_name)).is_equal("le dispositif")
	TranslationServer.set_locale(before)
	TranslationServer.remove_translation(french)


func test_a_name_with_no_row_comes_back_as_itself() -> void:
	# Which is what a seed, a number, or a floor invented past the last one does.
	assert_str(Copy.of("After Hours 3")).is_equal("After Hours 3")
	assert_str(Copy.of("")).is_equal("")


func test_a_sentence_is_filled_after_its_shape_is_translated() -> void:
	var french: Translation = Translation.new()
	french.locale = "fr"
	french.add_message("Noticed. %s is coming.", "Repéré. %s arrive.")
	TranslationServer.add_translation(french)
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	assert_str(Copy.filled("Noticed. %s is coming.", ["le comptable"])).is_equal(
			"Repéré. le comptable arrive.")
	TranslationServer.set_locale(before)
	TranslationServer.remove_translation(french)


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
