## The door: the title, the machine to play, the audit to play it under, and
## the run to resume. Also the pause, because a run interrupted comes back to
## the same door with different words on it.
##
## The first playtest opened on a spinning machine with no title, no start and
## no way to choose a difficulty, and said so first. This is the screen that
## sets the room before the first spin: the wordmark over the lit machine, the
## House's one line, and a menu that only offers what the profile has earned.
## The ladder's rungs are all shown and only the ones a win has opened can be
## taken, which is the "harder modes after completing medium" the feedback
## asked for, in the ladder the game already had.
##
## It emits intent and never touches the run: [CasinoRoom] starts, resumes and
## abandons on its say-so, the same way it does for every other panel.
class_name TitleScreen
extends CanvasLayer

## A new run with the profile's current selections, on [param run_seed]
## (0 for a fresh one) and the daily key when it is the daily.
signal start_requested(run_seed: int, daily_key: String)
## The run on the table is to be resumed — the pause is over.
signal resume_requested()
## The run on the table is to be abandoned for the door.
signal abandon_requested()
## The guided first run is wanted, whatever the profile says it has seen.
signal tutorial_requested()
## The lesson in progress is to be skipped.
signal skip_requested()
## A setting changed; the room applies it. Keys: master, music, sfx,
## ambience (dB), pace (a multiplier on the spin's timing).
signal setting_changed(key: StringName, value: float)

enum Mode { TITLE, PAUSE }

## The viewport width the type sizes were chosen at.
const DESIGN_WIDTH: float = 1152.0
## What the House says under the title. Contractual, and true.
const LINES: Array = [
	"Your account is open. The machine is yours until it is not.",
	"Seven floors, one debt, and the House has all the time in the world.",
	"Every floor teaches you something. Every floor charges for it.",
	"The terms are printed. The count is kept. The ante rises.",
]

var _mode: Mode = Mode.TITLE
var _open: bool = false
var _profile: PlayerProfile
var _catalogue: MetaCatalogue
var _has_save: bool = false
var _last_seed: int = 0
var _scale: float = 1.0
## The audio settings as the profile keeps them, in dB per bus.
var _settings: Dictionary = {}
## True while the Clerk is mid-lesson, so the pause can offer to end it.
var lesson_running: bool = false

var _root: Control
var _dim: ColorRect
var _column: VBoxContainer
var _wordmark: Label
var _line: Label
var _menu: VBoxContainer
var _collection_box: VBoxContainer
var _pickers: VBoxContainer
var _seed_field: LineEdit
var _stats: Label
var _settings_box: VBoxContainer
var _settings_open: bool = false
var _collection_open: bool = false
var _line_index: int = 0


func _ready() -> void:
	layer = 6
	visible = false
	_build()
	_fit()
	get_viewport().size_changed.connect(_fit)


func is_open() -> bool:
	return _open


func mode() -> Mode:
	return _mode


## Puts the door up. [param has_save] offers CONTINUE; [param last_seed] is
## what the seed field shows.
func open_title(profile: PlayerProfile, catalogue: MetaCatalogue, has_save: bool,
		last_seed: int) -> void:
	_mode = Mode.TITLE
	_profile = profile
	_catalogue = catalogue
	_has_save = has_save
	_last_seed = last_seed
	_settings = profile.settings.duplicate()
	_line_index = (_line_index + 1) % LINES.size()
	_show()


## Puts the pause up over a run in progress.
func open_pause(profile: PlayerProfile, catalogue: MetaCatalogue, last_seed: int) -> void:
	_mode = Mode.PAUSE
	_profile = profile
	_catalogue = catalogue
	_has_save = true
	_last_seed = last_seed
	_settings = profile.settings.duplicate()
	_show()


func close() -> void:
	_open = false
	visible = false
	_settings_open = false


func _show() -> void:
	_open = true
	visible = true
	_settings_open = false
	_redraw()


# --- building --------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# The room stays visible behind a dark wash: the machine idling under its
	# lamp is the title's picture, and a black screen with a wordmark is a
	# loading screen, not a door.
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.02, 0.018, 0.015, 0.58)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	_root.add_child(_column)

	_wordmark = Label.new()
	_wordmark.name = "Wordmark"
	_wordmark.text = "BREAK THE BANK"
	_wordmark.add_theme_color_override(&"font_color", UiSkin.AMBER)
	_wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_wordmark)

	_line = Label.new()
	_line.name = "Line"
	_line.add_theme_color_override(&"font_color", UiSkin.INK_MUTED)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_line)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override(&"separation", 6)
	_column.add_child(_menu)

	_pickers = VBoxContainer.new()
	_pickers.name = "Pickers"
	_pickers.add_theme_constant_override(&"separation", 4)
	_column.add_child(_pickers)

	_settings_box = VBoxContainer.new()
	_settings_box.name = "Settings"
	_settings_box.add_theme_constant_override(&"separation", 6)
	_settings_box.visible = false
	_column.add_child(_settings_box)

	_collection_box = VBoxContainer.new()
	_collection_box.name = "Collection"
	_collection_box.add_theme_constant_override(&"separation", 6)
	_collection_box.visible = false
	_column.add_child(_collection_box)

	_stats = Label.new()
	_stats.name = "Stats"
	_stats.add_theme_color_override(&"font_color", UiSkin.INK_MUTED)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_stats)


## Scales the type to the real window rather than the design viewport, for the
## same reason the HUD does.
func _fit() -> void:
	var window: Window = get_window()
	if window == null or window.size.x <= 0:
		return
	_scale = clampf(DESIGN_WIDTH / float(window.size.x), 1.0, 2.3) * RunHUD.user_scale
	_column.anchor_left = 0.0
	_column.anchor_right = 0.0
	_column.anchor_top = 0.0
	_column.anchor_bottom = 1.0
	_column.offset_left = 64.0 * _scale
	_column.offset_right = 64.0 * _scale + 620.0 * _scale
	_column.offset_top = 36.0 * _scale
	_column.offset_bottom = -24.0 * _scale
	_wordmark.add_theme_font_size_override(&"font_size", int(roundf(46.0 * _scale)))
	_line.add_theme_font_size_override(&"font_size", int(roundf(16.0 * _scale)))
	_stats.add_theme_font_size_override(&"font_size", int(roundf(12.0 * _scale)))
	if _open:
		_redraw()


# --- drawing ---------------------------------------------------------------

func _redraw() -> void:
	if _profile == null:
		return
	_clear(_menu)
	_clear(_pickers)
	_clear(_settings_box)
	_settings_box.visible = _settings_open
	_clear(_collection_box)
	_collection_box.visible = _collection_open
	_wordmark.text = "BREAK THE BANK" if _mode == Mode.TITLE else "THE FLOOR IS PAUSED"
	_line.text = String(LINES[_line_index]) if _mode == Mode.TITLE \
			else "The House waits. It is good at it."
	if _settings_open:
		_draw_settings()
		_menu.add_child(_button("BACK", "", func() -> void:
			_settings_open = false
			_redraw()))
		_stats.text = ""
		return
	if _collection_open:
		_draw_collection()
		_menu.add_child(_button("BACK", "", func() -> void:
			_collection_open = false
			_redraw()))
		_stats.text = ""
		return
	if _mode == Mode.PAUSE:
		_menu.add_child(_button("RESUME", TouchBar.hint("ESC", ""), func() -> void:
			resume_requested.emit()))
		if lesson_running:
			_menu.add_child(_button("SKIP THE LESSON", "the Clerk goes quiet", func() -> void:
				skip_requested.emit(), false))
		_menu.add_child(_button("SETTINGS", "", func() -> void:
			_settings_open = true
			_redraw()))
		_menu.add_child(_button("ABANDON THE RUN", "the House keeps the table", func() -> void:
			abandon_requested.emit(), false))
		if not OS.has_feature("web"):
			_menu.add_child(_button("QUIT", "", func() -> void: get_tree().quit()))
		_stats.text = ""
		return
	if _has_save:
		_menu.add_child(_button("CONTINUE", "the run on the table", func() -> void:
			resume_requested.emit()))
	_menu.add_child(_button("PULL THE LEVER", "a new run on the machine below", func() -> void:
		start_requested.emit(0, "")))
	_menu.add_child(_button("THE COLLECTION", "%d of %d pieces of hardware seen" % [
			_profile.seen_count("artifacts"), ContentDB.shared().artifacts.size()],
			func() -> void:
				_collection_open = true
				_redraw(), false))
	_menu.add_child(_button("THE DAILY", "%s — one seed, everyone" % SeedBook.today_key(),
			func() -> void:
				start_requested.emit(SeedBook.today_seed(), SeedBook.today_key())))
	_draw_pickers()
	var seed_row: HBoxContainer = HBoxContainer.new()
	seed_row.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	_seed_field = LineEdit.new()
	_seed_field.placeholder_text = "a seed: TILT-MARBLE-COBALT, a number, or any phrase"
	_seed_field.text = SeedBook.to_code(_last_seed) if _last_seed != 0 else ""
	_seed_field.add_theme_stylebox_override(&"normal", UiSkin.button(&"normal"))
	_seed_field.add_theme_stylebox_override(&"focus", UiSkin.button(&"hover"))
	_seed_field.add_theme_color_override(&"font_color", UiSkin.INK)
	_seed_field.add_theme_color_override(&"caret_color", UiSkin.AMBER)
	_seed_field.add_theme_font_size_override(&"font_size", int(roundf(14.0 * _scale)))
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_field.text_submitted.connect(func(_text: String) -> void: _start_seed())
	seed_row.add_child(_seed_field)
	var play_seed: Button = _small("PLAY THIS SEED", func() -> void: _start_seed())
	seed_row.add_child(play_seed)
	_menu.add_child(seed_row)
	var lower: HBoxContainer = HBoxContainer.new()
	lower.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	lower.add_child(_small("HOW TO PLAY", func() -> void: tutorial_requested.emit()))
	lower.add_child(_small("SETTINGS", func() -> void:
		_settings_open = true
		_redraw()))
	if not OS.has_feature("web"):
		lower.add_child(_small("QUIT", func() -> void: get_tree().quit()))
	_menu.add_child(lower)
	_stats.text = _stats_text()


## The machine, the audit and the challenge: each a row with arrows, showing
## the choice and what it does. The audit row draws the whole ladder, with the
## rungs a win has not opened shown barred and priced in the win it takes.
func _draw_pickers() -> void:
	var machines: Array[StringName] = _catalogue.available_starters(_profile)
	if not machines.has(_profile.selected_starter):
		_profile.selected_starter = &"standard"
	_pickers.add_child(_picker_row("MACHINE",
			_machine_name(_profile.selected_starter),
			_machine_note(_profile.selected_starter),
			func(direction: int) -> void:
				_profile.selected_starter = _cycle(machines, _profile.selected_starter, direction)
				_profile.save()
				_redraw()))
	var challenges: Array[StringName] = [&""]
	challenges.append_array(_catalogue.available_challenges(_profile))
	_pickers.add_child(_picker_row("CHALLENGE", _challenge_name(_profile.selected_challenge),
			_challenge_note(_profile.selected_challenge),
			func(direction: int) -> void:
				_profile.selected_challenge = _cycle(challenges, _profile.selected_challenge, direction)
				_profile.save()
				_redraw()))
	_pickers.add_child(_ladder_row())


## The ladder as a row of rungs. Rung one is always open; every other rung
## opens on a win at the one below it.
func _ladder_row() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", int(roundf(4.0 * _scale)))
	box.add_child(_label("THE AUDIT", 11.0, UiSkin.INK_MUTED))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", int(roundf(4.0 * _scale)))
	var open_ids: Array[StringName] = _catalogue.available_difficulties(_profile)
	for rung: DifficultyDef in _catalogue.difficulties:
		var opened: bool = open_ids.has(rung.id)
		var chosen: bool = rung.id == _profile.selected_difficulty
		var plate: Button = Button.new()
		UiSkin.dress_button(plate)
		plate.text = str(rung.tier)
		plate.tooltip_text = rung.display_name if opened else "%s — %s" % [
			rung.display_name, _rung_requirement(rung)]
		plate.disabled = not opened
		plate.focus_mode = Control.FOCUS_NONE
		plate.custom_minimum_size = Vector2(36.0, 34.0) * _scale
		plate.add_theme_font_size_override(&"font_size", int(roundf(13.0 * _scale)))
		if chosen:
			plate.add_theme_stylebox_override(&"normal", UiSkin.button(&"pressed"))
			plate.add_theme_color_override(&"font_color", UiSkin.AMBER)
		var id: StringName = rung.id
		plate.pressed.connect(func() -> void:
			_profile.selected_difficulty = id
			_profile.save()
			_redraw())
		row.add_child(plate)
	box.add_child(row)
	var current: DifficultyDef = _catalogue.difficulty_by_id(_profile.selected_difficulty)
	var caption: String = "Standard — the game as shipped."
	if current != null:
		caption = "%s — %s" % [current.display_name, current.description]
	var next_locked: DifficultyDef = null
	for rung: DifficultyDef in _catalogue.difficulties:
		if not open_ids.has(rung.id):
			next_locked = rung
			break
	if next_locked != null:
		caption += "   Next rung, %s: %s." % [next_locked.display_name,
				_rung_requirement(next_locked)]
	var note: Label = _label(caption, 12.0, UiSkin.INK_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	return box


## What opens [param rung], in the unlock's own words.
func _rung_requirement(rung: DifficultyDef) -> String:
	for unlock: UnlockDef in _catalogue.unlocks:
		if unlock.kind == UnlockDef.Kind.DIFFICULTY and unlock.target_id == rung.id:
			return unlock.requirement_text().to_lower()
	return "win at the rung below"


## The collection: everything the profile has met, and silhouettes for
## everything it has not. Hardware, the House's people, the contracts —
## each a name and its line once seen, a dash until then. What converts a
## content set into a reason to run again.
func _draw_collection() -> void:
	var content: ContentDB = ContentDB.shared()
	_collection_box.add_child(_label("THE COLLECTION", 14.0, UiSkin.AMBER))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600.0 * _scale, 420.0 * _scale)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_box.add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var sections: Array = [
		["HARDWARE", "artifacts", content.artifacts],
		["THE HOUSE'S PEOPLE", "bosses", content.bosses],
		["CONTRACTS", "contracts", content.contracts],
		["CHITS", "chits", content.chits],
	]
	for section: Array in sections:
		var kind: String = String(section[1])
		var defs: Array = section[2]
		rows.add_child(_label("%s   %d of %d" % [String(section[0]),
				_profile.seen_count(kind), defs.size()], 12.0, UiSkin.INK))
		for def: Resource in defs:
			var id: StringName = def.get("id")
			var met: bool = _profile.has_seen(kind, id)
			var line: String = "— · —"
			if met:
				var blurb: String = ""
				if kind == "bosses":
					blurb = String(def.get("tell"))
				else:
					blurb = String(def.get("description"))
				line = "%s — %s" % [String(def.get("display_name")), blurb]
			var entry: Label = _label(line, 11.0, UiSkin.INK if met else UiSkin.INK_MUTED)
			entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_child(entry)


func _draw_settings() -> void:
	_settings_box.add_child(_label("SETTINGS", 14.0, UiSkin.AMBER))
	for bus: Array in [["MASTER", &"master"], ["MUSIC", &"music"],
			["SOUND", &"sfx"], ["ROOM", &"ambience"]]:
		_settings_box.add_child(_slider(String(bus[0]), StringName(bus[1]),
				-30.0, 6.0, float(_settings.get(String(bus[1]), 0.0))))
	# Three steps, not a dial: the handover asked for a persistent speed
	# setting a veteran can set once, and for speeding up to scale the whole
	# performance rather than cut beats out of it. Holding the lever does the
	# rest, per spin.
	_settings_box.add_child(_slider("PACE", &"pace", 0.0, 2.0,
			float(_settings.get("pace", 1.0))))
	_settings_box.add_child(_slider("TEXT", &"ui_scale", 0.8, 1.5,
			float(_settings.get("ui_scale", 1.0))))
	var overlay_on: bool = float(_settings.get("overlay", 0.0)) > 0.5
	var toggle_row: HBoxContainer = HBoxContainer.new()
	toggle_row.add_theme_constant_override(&"separation", int(roundf(10.0 * _scale)))
	var toggle_name: Label = _label("ON SCREEN", 12.0, UiSkin.INK)
	toggle_name.custom_minimum_size = Vector2(80.0 * _scale, 0.0)
	toggle_row.add_child(toggle_name)
	toggle_row.add_child(_small("CONTROLS AND COUNTERS: %s" % ("ON" if overlay_on else "OFF"),
			func() -> void:
				var now: float = 0.0 if overlay_on else 1.0
				_settings["overlay"] = now
				setting_changed.emit(&"overlay", now)
				_redraw()))
	_settings_box.add_child(toggle_row)
	var steady_on: bool = float(_settings.get("steady", 0.0)) > 0.5
	var steady_row: HBoxContainer = HBoxContainer.new()
	steady_row.add_theme_constant_override(&"separation", int(roundf(10.0 * _scale)))
	var steady_name: Label = _label("PICTURE", 12.0, UiSkin.INK)
	steady_name.custom_minimum_size = Vector2(80.0 * _scale, 0.0)
	steady_row.add_child(steady_name)
	steady_row.add_child(_small("STEADY — no flicker, flash, tearing or shake: %s" % ("ON" if steady_on else "OFF"),
			func() -> void:
				var now: float = 0.0 if steady_on else 1.0
				_settings["steady"] = now
				setting_changed.emit(&"steady", now)
				_redraw()))
	_settings_box.add_child(steady_row)
	var about: Label = _label("Pace is how long the reels and the count take; hold the lever, or Space, through a payout to hurry it. The machine carries its controls and its counters; on screen repeats them. Louder than 0 dB is the House's own risk.",
			11.0, UiSkin.INK_MUTED)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_box.add_child(about)


func _slider(caption: String, key: StringName, low: float, high: float,
		value: float) -> Control:
	caption = tr(caption)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", int(roundf(10.0 * _scale)))
	var name_label: Label = _label(caption, 12.0, UiSkin.INK)
	name_label.custom_minimum_size = Vector2(80.0 * _scale, 0.0)
	row.add_child(name_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.1 if key == &"ui_scale" else 1.0
	slider.value = float(SlotView3D.pace_index(value)) if key == &"pace" else value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(240.0 * _scale, 22.0 * _scale)
	slider.focus_mode = Control.FOCUS_NONE
	var readout: Label = _label(_setting_text(key, value), 12.0, UiSkin.INK_MUTED)
	readout.custom_minimum_size = Vector2(64.0 * _scale, 0.0)
	slider.value_changed.connect(func(changed: float) -> void:
		var stored: float = SlotView3D.PACES[int(changed)] if key == &"pace" else changed
		_settings[String(key)] = stored
		readout.text = _setting_text(key, stored)
		setting_changed.emit(key, stored))
	row.add_child(slider)
	row.add_child(readout)
	return row


func _setting_text(key: StringName, value: float) -> String:
	if key == &"pace":
		return SlotView3D.PACE_NAMES[SlotView3D.pace_index(value)]
	if key == &"ui_scale":
		return "%d%%" % int(round(value * 100.0))
	return "%+.0f dB" % value


# --- pieces ----------------------------------------------------------------

func _button(title: String, note: String, pressed: Callable, primary: bool = true) -> Button:
	# Every caption goes through tr(): the keys are the English, in
	# resources/locale/strings.csv, and a string with no row comes back as
	# itself — so a number or a seed is safe here too.
	title = tr(title)
	var button: Button = Button.new()
	UiSkin.dress_button(button)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 44.0 * _scale)
	button.pressed.connect(pressed)
	if primary:
		button.add_theme_stylebox_override(&"normal", UiSkin.button(&"pressed"))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18.0 * _scale
	row.offset_right = -18.0 * _scale
	row.add_theme_constant_override(&"separation", int(roundf(14.0 * _scale)))
	var head: Label = _label(title, 17.0, UiSkin.AMBER if primary else UiSkin.INK)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	if not note.is_empty():
		var caption: Label = _label(note, 12.0, UiSkin.INK_MUTED)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(caption)
	button.add_child(row)
	return button


func _small(title: String, pressed: Callable) -> Button:
	title = tr(title)
	var button: Button = Button.new()
	UiSkin.dress_button(button)
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", int(roundf(12.0 * _scale)))
	button.custom_minimum_size = Vector2(0.0, 32.0 * _scale)
	button.pressed.connect(pressed)
	return button


func _picker_row(caption: String, value: String, note: String, cycle: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", int(roundf(2.0 * _scale)))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	var head: Label = _label(caption, 11.0, UiSkin.INK_MUTED)
	head.custom_minimum_size = Vector2(96.0 * _scale, 0.0)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	row.add_child(_small("‹", func() -> void: cycle.call(-1)))
	var shown: Label = _label(value, 15.0, UiSkin.INK)
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shown.custom_minimum_size = Vector2(220.0 * _scale, 0.0)
	row.add_child(shown)
	row.add_child(_small("›", func() -> void: cycle.call(1)))
	box.add_child(row)
	if not note.is_empty():
		var about: Label = _label(note, 12.0, UiSkin.INK_MUTED)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(about)
	return box


func _label(text: String, size: float, tint: Color) -> Label:
	text = tr(text)
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
	label.add_theme_color_override(&"font_color", tint)
	return label


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- words -----------------------------------------------------------------

func _stats_text() -> String:
	var favourite: StringName = _profile.favourite_artifact()
	return "RUNS %d   WINS %d   BEST FLOOR %d   BIGGEST SPIN %d   VIG PAID %d   AFTER HOURS %d   FAVOURITE %s   UNLOCKED %d of %d" % [
		_profile.runs_played, _profile.wins, _profile.best_floor, _profile.biggest_spin,
		_profile.vig_paid, _profile.deepest_after_hours,
		String(favourite).capitalize() if favourite != &"" else "—",
		_profile.unlocked.size(), _catalogue.unlocks.size()]


func _machine_name(id: StringName) -> String:
	var machine: MachineDef = _catalogue.machine_by_id(id)
	return machine.display_name if machine != null else String(id).capitalize()


## The machine's own line, and how many more there are to open.
func _machine_note(id: StringName) -> String:
	var machine: MachineDef = _catalogue.machine_by_id(id)
	var note: String = machine.brief if machine != null else ""
	var opened: int = _catalogue.available_starters(_profile).size()
	var total: int = _catalogue.machines.size()
	if opened < total:
		var next_locked: String = ""
		for candidate: MachineDef in _catalogue.machines:
			if _catalogue.available_starters(_profile).has(candidate.id):
				continue
			for unlock: UnlockDef in _catalogue.unlocks:
				if unlock.kind == UnlockDef.Kind.STARTER and unlock.target_id == candidate.id:
					next_locked = "%s: %s" % [candidate.display_name,
							unlock.requirement_text().to_lower()]
					break
			if not next_locked.is_empty():
				break
		note += "   %d of %d machines open." % [opened, total]
		if not next_locked.is_empty():
			note += " Next, %s." % next_locked
	return note


func _challenge_name(id: StringName) -> String:
	if id == &"":
		return "None"
	var challenge: ChallengeDef = _catalogue.challenge_by_id(id)
	return challenge.display_name if challenge != null else String(id).capitalize()


func _challenge_note(id: StringName) -> String:
	if id == &"":
		return "The ordinary game. Challenges open through play."
	var challenge: ChallengeDef = _catalogue.challenge_by_id(id)
	return challenge.description if challenge != null else ""


func _name_of(table: Dictionary, id: StringName) -> String:
	if table.has(id):
		return String((table[id] as Dictionary)["name"])
	return String(id).capitalize()


static func _cycle(options: Array[StringName], current: StringName, direction: int) -> StringName:
	if options.is_empty():
		return current
	var index: int = options.find(current)
	return options[posmod(index + direction, options.size())]


func _start_seed() -> void:
	var parsed: int = SeedBook.parse(_seed_field.text if _seed_field != null else "")
	start_requested.emit(parsed if parsed >= 0 else 0, "")


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var typing: bool = _seed_field != null and is_instance_valid(_seed_field) \
			and _seed_field.has_focus()
	if event.is_action_pressed(&"bb_cancel") or event.is_action_pressed(&"bb_menu"):
		if typing:
			_seed_field.release_focus()
		elif _settings_open:
			_settings_open = false
			_redraw()
		elif _mode == Mode.PAUSE:
			resume_requested.emit()
	elif _mode == Mode.TITLE and not typing and event.is_action_pressed(&"bb_confirm"):
		if _has_save:
			resume_requested.emit()
		else:
			start_requested.emit(0, "")
	# A modal panel owns the keyboard while it is up: anything it let past
	# would reach the machine underneath.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
