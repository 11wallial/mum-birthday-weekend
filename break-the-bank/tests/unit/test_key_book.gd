extends GdUnitTestSuite

## Moving a key, and getting it back.
##
## The bindings ship in project.godot, which is read-only at runtime, so the
## whole feature is: keep the shipped ones, put the player's over them, write
## back only the difference, and never let a bad row cost a profile.

const MOVED: StringName = &"bb_camera"

var _shipped: Array = []


func before_test() -> void:
	KeyBook.remember_defaults()
	_shipped = InputMap.action_get_events(MOVED).duplicate()


func after_test() -> void:
	KeyBook.reset_all()


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	return event


func test_a_key_replaces_the_key_and_leaves_the_pad_alone() -> void:
	var pads_before: int = 0
	for event: InputEvent in _shipped:
		if event is InputEventJoypadButton:
			pads_before += 1
	assert_bool(KeyBook.rebind(MOVED, _key(KEY_J))).is_true()
	var keys: int = 0
	var pads: int = 0
	for event: InputEvent in InputMap.action_get_events(MOVED):
		if event is InputEventKey:
			keys += 1
			assert_int(int((event as InputEventKey).physical_keycode)).is_equal(int(KEY_J))
		elif event is InputEventJoypadButton:
			pads += 1
	assert_int(keys).override_failure_message("a rebind should leave one key").is_equal(1)
	assert_int(pads).override_failure_message("a rebind took the pad button with it").is_equal(pads_before)


func test_the_action_answers_to_the_new_key() -> void:
	KeyBook.rebind(MOVED, _key(KEY_J))
	var pressed: InputEventKey = _key(KEY_J)
	pressed.pressed = true
	assert_bool(pressed.is_action_pressed(MOVED)).is_true()


func test_putting_the_keys_back_restores_what_shipped() -> void:
	KeyBook.rebind(MOVED, _key(KEY_J))
	KeyBook.reset(MOVED)
	assert_str(KeyBook.describe(MOVED)).is_equal(_describe(_shipped))


func test_only_what_moved_is_written_down() -> void:
	assert_int(KeyBook.to_dict().size()).override_failure_message(
			"an untouched profile should carry no bindings").is_zero()
	KeyBook.rebind(MOVED, _key(KEY_J))
	var written: Dictionary = KeyBook.to_dict()
	assert_array(written.keys()).is_equal([String(MOVED)])
	assert_str(JSON.stringify(written[String(MOVED)])).contains(str(int(KEY_J)))


func test_what_was_written_down_comes_back() -> void:
	KeyBook.rebind(MOVED, _key(KEY_J))
	var written: Dictionary = KeyBook.to_dict()
	KeyBook.reset_all()
	KeyBook.apply(written)
	assert_str(KeyBook.describe(MOVED)).contains("J")


func test_a_wrecked_binding_is_skipped_rather_than_fatal() -> void:
	# The same rule as every other loader here: a broken save is not worth
	# taking the game down for, and a broken binding is not worth a profile.
	for wreckage: Variant in [{"bb_camera": "not a list"}, {"bb_camera": []},
			{"bb_camera": [{"key": "J"}]}, {"bb_camera": [42]},
			{"no_such_action": [{"key": 74}]}, {"bb_camera": [{}]}]:
		KeyBook.apply(wreckage as Dictionary)
		assert_str(KeyBook.describe(MOVED)).override_failure_message(
				"%s emptied the action" % wreckage).is_not_equal("—")


func test_every_action_the_door_lists_exists_and_reads() -> void:
	for row: Array in KeyBook.ACTIONS:
		assert_bool(InputMap.has_action(row[0])).override_failure_message(
				"%s is on the door and not in the project" % row[0]).is_true()
		assert_str(KeyBook.describe(row[0])).override_failure_message(
				"%s has nothing on it" % row[0]).is_not_equal("—")


func _describe(events: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for event: InputEvent in events:
		var name: String = KeyBook.name_of(event)
		if name != "" and not parts.has(name):
			parts.append(name)
	return "  ".join(parts)
