extends GdUnitTestSuite

## The strings go through tr(): the keys are the English, a row per caption
## in resources/locale/strings.csv, and a translation added for a locale is
## what the door shows in it.


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
