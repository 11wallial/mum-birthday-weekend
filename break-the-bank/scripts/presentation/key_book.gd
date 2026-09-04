## What every key does, and how to change it.
##
## The actions live in project.godot, which ships read-only: a player who
## wants the lever somewhere else has had no way to say so. This keeps the
## project's own bindings as the defaults, applies a profile's changes over
## them at boot, and writes a change back as data — a keycode, a pad button —
## rather than a serialised InputEvent, so a save from an older build is
## readable and a save from a newer one is ignorable.
##
## Presentation, not simulation: the machine does not know what a key is.
class_name KeyBook
extends RefCounted

## The actions a player may move, in the order the door lists them. The reel
## keys (1 to 5) are left alone on purpose: they are positional, and a player
## who moves them has no way to know which reel is which.
const ACTIONS: Array = [
	[&"bb_advance", "SPIN / ADVANCE"],
	[&"bb_confirm", "CONFIRM"],
	[&"bb_cancel", "BACK"],
	[&"bb_leave_shop", "LEAVE THE DRAFT"],
	[&"bb_camera", "CAMERA"],
	[&"bb_view_prev", "VIEW LEFT"],
	[&"bb_view_next", "VIEW RIGHT"],
	[&"bb_menu", "THE DOOR"],
	[&"bb_new_run", "NEW RUN"],
	[&"bb_run_back", "RUN THE SEED BACK"],
]

## The project's own bindings, taken once before anything is changed, so
## "back to how it was" means the shipped game and not the last edit.
static var _defaults: Dictionary = {}


## Remembers the shipped bindings. Safe to call more than once.
static func remember_defaults() -> void:
	if not _defaults.is_empty():
		return
	for row: Array in ACTIONS:
		var action: StringName = row[0]
		if InputMap.has_action(action):
			_defaults[String(action)] = InputMap.action_get_events(action).duplicate()


## Puts one action back to the key and the button it shipped with.
static func reset(action: StringName) -> void:
	remember_defaults()
	if not _defaults.has(String(action)) or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in _defaults[String(action)]:
		InputMap.action_add_event(action, event)


static func reset_all() -> void:
	for row: Array in ACTIONS:
		reset(row[0])


## Puts [param event] on [param action], replacing whatever was there of the
## same kind — a key replaces the key, a pad button replaces the pad button —
## so rebinding the keyboard never costs a player their controller.
static func rebind(action: StringName, event: InputEvent) -> bool:
	if not InputMap.has_action(action) or not _is_bindable(event):
		return false
	for existing: InputEvent in InputMap.action_get_events(action):
		if _same_kind(existing, event):
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)
	return true


## True when an event is something a player can be asked to press: a key, a
## pad button, a mouse button. A stick's drift is not a binding.
static func _is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).physical_keycode != 0
	return event is InputEventJoypadButton or event is InputEventMouseButton


static func _same_kind(a: InputEvent, b: InputEvent) -> bool:
	return ((a is InputEventKey and b is InputEventKey)
			or (a is InputEventJoypadButton and b is InputEventJoypadButton)
			or (a is InputEventMouseButton and b is InputEventMouseButton))


## How this action reads on the door: the key first, because that is what
## most players are looking for, then the pad button if there is one.
## The first binding only, for places that name a key rather than list the
## ways to press it. [method describe] joins every event on the action —
## keyboard, pad and mouse — which is right for the keys panel and far too
## long for a hint sitting in a fixed box in the corner of the screen.
static func primary(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	for event: InputEvent in InputMap.action_get_events(action):
		var name: String = name_of(event)
		if name != "":
			return name
	return "—"


static func describe(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var parts: PackedStringArray = PackedStringArray()
	for event: InputEvent in InputMap.action_get_events(action):
		var name: String = name_of(event)
		if name != "" and not parts.has(name):
			parts.append(name)
	return "  ".join(parts) if not parts.is_empty() else "—"


## One event, in words. The pad buttons are named for the face they carry on
## a standard pad rather than by number, because a number is not a button.
##
## A key's name comes from the keyboard the player is typing on — Godot asks
## the OS for it, and the OS answers in the layout's own language — so it is
## not the string table's business. The words this game supplies for a pad or
## a mouse are.
static func name_of(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: Key = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code)).to_upper()
	if event is InputEventJoypadButton:
		var button: JoyButton = (event as InputEventJoypadButton).button_index
		var names: Dictionary = {
			JOY_BUTTON_A: "PAD A", JOY_BUTTON_B: "PAD B", JOY_BUTTON_X: "PAD X",
			JOY_BUTTON_Y: "PAD Y", JOY_BUTTON_BACK: "PAD BACK",
			JOY_BUTTON_START: "PAD START", JOY_BUTTON_LEFT_SHOULDER: "PAD L",
			JOY_BUTTON_RIGHT_SHOULDER: "PAD R", JOY_BUTTON_DPAD_LEFT: "PAD ←",
			JOY_BUTTON_DPAD_RIGHT: "PAD →", JOY_BUTTON_DPAD_UP: "PAD ↑",
			JOY_BUTTON_DPAD_DOWN: "PAD ↓",
		}
		return Copy.of(String(names.get(button, "PAD %d" % int(button))))
	if event is InputEventMouseButton:
		var index: MouseButton = (event as InputEventMouseButton).button_index
		return Copy.of("CLICK") if index == MOUSE_BUTTON_LEFT \
				else Copy.filled("MOUSE %d", [int(index)])
	return ""


## The bindings a profile carries: only what differs from the shipped ones,
## as plain numbers.
static func to_dict() -> Dictionary:
	remember_defaults()
	var out: Dictionary = {}
	for row: Array in ACTIONS:
		var action: StringName = row[0]
		if not InputMap.has_action(action):
			continue
		var rows: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			var written: Dictionary = _written(event)
			if not written.is_empty():
				rows.append(written)
		if rows != _shipped_rows(action):
			out[String(action)] = rows
	return out


## Applies what a profile carries. Anything unreadable is skipped rather than
## fatal: a binding is not worth a lost profile.
static func apply(bindings: Dictionary) -> void:
	remember_defaults()
	for key: Variant in bindings:
		var action: StringName = StringName(String(key))
		if not InputMap.has_action(action):
			continue
		var rows: Variant = bindings[key]
		if not (rows is Array) or (rows as Array).is_empty():
			continue
		var events: Array[InputEvent] = []
		for entry: Variant in rows:
			var event: InputEvent = _read(entry)
			if event != null:
				events.append(event)
		if events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in events:
			InputMap.action_add_event(action, event)


static func _shipped_rows(action: StringName) -> Array:
	var out: Array = []
	for event: InputEvent in _defaults.get(String(action), []):
		var written: Dictionary = _written(event)
		if not written.is_empty():
			out.append(written)
	return out


static func _written(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return {"key": int(key.physical_keycode if key.physical_keycode != 0 else key.keycode)}
	if event is InputEventJoypadButton:
		return {"pad": int((event as InputEventJoypadButton).button_index)}
	if event is InputEventMouseButton:
		return {"mouse": int((event as InputEventMouseButton).button_index)}
	return {}


static func _read(entry: Variant) -> InputEvent:
	if not (entry is Dictionary):
		return null
	var row: Dictionary = entry
	if row.has("key") and (row["key"] is int or row["key"] is float):
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = int(row["key"]) as Key
		return key
	if row.has("pad") and (row["pad"] is int or row["pad"] is float):
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = int(row["pad"]) as JoyButton
		return pad
	if row.has("mouse") and (row["mouse"] is int or row["mouse"] is float):
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = int(row["mouse"]) as MouseButton
		return mouse
	return null
