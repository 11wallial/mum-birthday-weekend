## Choosing what run to play: a typed seed, the daily challenge, or a fresh one.
##
## Also where the meta lives — unlock progress, starter and difficulty — because
## those are decisions made between runs, not during one.
class_name RunSetupPanel
extends CanvasLayer

signal start_requested(run_seed: int, daily_key: String)
signal starter_changed(starter_id: StringName)
signal difficulty_changed(difficulty_id: StringName)
signal challenge_changed(challenge_id: StringName)

@export var seed_field_path: NodePath = ^"Panel/Rows/SeedRow/SeedField"
@export var status_path: NodePath = ^"Panel/Rows/Status"
@export var unlocks_path: NodePath = ^"Panel/Rows/Unlocks"
@export var ruleset_path: NodePath = ^"Panel/Rows/Ruleset"

var _seed_field: LineEdit
var _status: Label
var _unlocks: Label
var _ruleset: Label
var _profile: PlayerProfile
var _catalogue: MetaCatalogue
var _open: bool = false


## Puts the panel in the same clothes as the draft and the room. Applied from
## code rather than authored per-scene so the four panels cannot drift apart.
func _dress() -> void:
	var panel: PanelContainer = get_node_or_null(^"Panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override(&"panel", UiSkin.panel())
	var buttons: Node = get_node_or_null(^"Panel/Rows/Buttons")
	if buttons != null:
		for child: Node in buttons.get_children():
			var button: Button = child as Button
			if button != null:
				UiSkin.dress_button(button)
				button.custom_minimum_size = Vector2(0.0, 46.0)
	for path: NodePath in [^"Panel/Rows/Title", ^"Panel/Rows/Ruleset"]:
		var label: Label = get_node_or_null(path) as Label
		if label != null:
			label.add_theme_color_override(&"font_color", UiSkin.AMBER)
	for path: NodePath in [^"Panel/Rows/Status", ^"Panel/Rows/Unlocks", ^"Panel/Rows/Footer"]:
		var label: Label = get_node_or_null(path) as Label
		if label != null:
			label.add_theme_color_override(&"font_color", UiSkin.INK_MUTED)
	var seed_label: Label = get_node_or_null(^"Panel/Rows/SeedRow/SeedLabel") as Label
	if seed_label != null:
		seed_label.add_theme_color_override(&"font_color", UiSkin.INK)
	var field: LineEdit = get_node_or_null(seed_field_path) as LineEdit
	if field != null:
		field.add_theme_stylebox_override(&"normal", UiSkin.button(&"normal"))
		field.add_theme_stylebox_override(&"focus", UiSkin.button(&"hover"))
		field.add_theme_color_override(&"font_color", UiSkin.INK)
		field.add_theme_color_override(&"caret_color", UiSkin.AMBER)


func _ready() -> void:
	_seed_field = get_node_or_null(seed_field_path) as LineEdit
	_status = get_node_or_null(status_path) as Label
	_unlocks = get_node_or_null(unlocks_path) as Label
	_ruleset = get_node_or_null(ruleset_path) as Label
	visible = false
	var start: Button = get_node_or_null(^"Panel/Rows/Buttons/Start") as Button
	if start != null:
		start.pressed.connect(_on_start_pressed)
	var daily: Button = get_node_or_null(^"Panel/Rows/Buttons/Daily") as Button
	if daily != null:
		daily.pressed.connect(_on_daily_pressed)
	var random: Button = get_node_or_null(^"Panel/Rows/Buttons/Random") as Button
	if random != null:
		random.pressed.connect(_on_random_pressed)
	var cycle_starter: Button = get_node_or_null(^"Panel/Rows/Buttons/Starter") as Button
	if cycle_starter != null:
		cycle_starter.pressed.connect(_on_cycle_starter)
	var cycle_difficulty: Button = get_node_or_null(^"Panel/Rows/Buttons/Difficulty") as Button
	if cycle_difficulty != null:
		cycle_difficulty.pressed.connect(_on_cycle_difficulty)
	# Built here rather than authored: the row is dressed as a set below, and a
	# button the scene did not know about still has to be in it.
	var buttons: Node = get_node_or_null(^"Panel/Rows/Buttons")
	if buttons != null:
		var cycle_challenge: Button = Button.new()
		cycle_challenge.name = "Challenge"
		cycle_challenge.text = "Cycle challenge"
		buttons.add_child(cycle_challenge)
		cycle_challenge.pressed.connect(_on_cycle_challenge)
	# Escape and F2 both close this, and a touch device has neither.
	var close_button: Button = get_node_or_null(^"Panel/Rows/Buttons/Close") as Button
	if close_button != null:
		close_button.pressed.connect(close)
	_dress()
	var footer: Label = get_node_or_null(^"Panel/Rows/Footer") as Label
	if footer != null:
		footer.text = TouchBar.hint("F2 close     ENTER start typed seed",
				"Close, or start a run with a button above")


func is_open() -> bool:
	return _open


func open(profile: PlayerProfile, catalogue: MetaCatalogue, last_seed: int) -> void:
	_profile = profile
	_catalogue = catalogue
	_open = true
	visible = true
	if _seed_field != null:
		_seed_field.text = SeedBook.to_code(last_seed)
		_seed_field.grab_focus()
	_redraw()


func close() -> void:
	_open = false
	visible = false


func _redraw() -> void:
	if _profile == null:
		return
	if _status != null:
		var favourite: StringName = _profile.favourite_artifact()
		_status.text = "\n".join([
			"RUNS %d     WINS %d     BEST FLOOR %d     EARNED %d     DEBT CLEARED %d" % [
				_profile.runs_played, _profile.wins, _profile.best_floor,
				_profile.lifetime_earned, _profile.debt_cleared],
			"SPINS %d     BIGGEST SPIN %d     VIG PAID TO THE HOUSE %d     AFTER HOURS %d     FAVOURITE %s" % [
				_profile.total_spins, _profile.biggest_spin, _profile.vig_paid,
				_profile.deepest_after_hours,
				String(favourite).capitalize() if favourite != &"" else "—"],
		])
	if _ruleset != null:
		_ruleset.text = "STARTER  %s        DIFFICULTY  %s        CHALLENGE  %s        TODAY  %s" % [
			_name_of(MetaCatalogue.STARTERS, _profile.selected_starter),
			_difficulty_name(_profile.selected_difficulty),
			_challenge_name(_profile.selected_challenge),
			SeedBook.to_code(SeedBook.today_seed())]
	if _unlocks != null and _catalogue != null:
		_unlocks.text = _unlock_text()


## Shows what is earned and, for the rest, exactly what it would take. A locked
## list with no requirements is just a list of things you do not have.
func _unlock_text() -> String:
	var earned: Array[String] = []
	var pending: Array[Dictionary] = []
	var stats: Dictionary = _profile.stats()
	for unlock: UnlockDef in _catalogue.unlocks:
		if _profile.has_unlock(unlock.id):
			earned.append(unlock.display_name)
		else:
			pending.append({
				"text": "%s — %s" % [unlock.display_name, unlock.requirement_text()],
				# "Next" has to mean nearest, or the list is just a subset.
				"remaining": unlock.remaining(stats),
			})
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["remaining"]) < int(b["remaining"]))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("UNLOCKED (%d/%d): %s" % [
		earned.size(), _catalogue.unlocks.size(),
		", ".join(earned) if not earned.is_empty() else "nothing yet"])
	for i: int in mini(pending.size(), 4):
		lines.append("   next: %s" % String(pending[i]["text"]))
	return "\n".join(lines)


func _name_of(table: Dictionary, id: StringName) -> String:
	if table.has(id):
		return String((table[id] as Dictionary)["name"])
	return String(id)


## The rung's name and where it sits on the ladder.
func _difficulty_name(id: StringName) -> String:
	var rung: DifficultyDef = _catalogue.difficulty_by_id(id) if _catalogue != null else null
	if rung == null:
		return String(id).capitalize()
	return "%s (%d of %d)" % [rung.display_name, rung.tier, _catalogue.difficulties.size()]


func _challenge_name(id: StringName) -> String:
	if id == &"":
		return "—"
	var challenge: ChallengeDef = _catalogue.challenge_by_id(id) if _catalogue != null else null
	return challenge.display_name if challenge != null else String(id).capitalize()


func _on_start_pressed() -> void:
	var text: String = _seed_field.text if _seed_field != null else ""
	var parsed: int = SeedBook.parse(text)
	start_requested.emit(parsed if parsed >= 0 else randi(), "")


func _on_daily_pressed() -> void:
	start_requested.emit(SeedBook.today_seed(), SeedBook.today_key())


func _on_random_pressed() -> void:
	start_requested.emit(randi(), "")


func _on_cycle_starter() -> void:
	var options: Array[StringName] = _catalogue.available_starters(_profile)
	_profile.selected_starter = _next(options, _profile.selected_starter)
	_profile.save()
	starter_changed.emit(_profile.selected_starter)
	_redraw()


func _on_cycle_difficulty() -> void:
	var options: Array[StringName] = _catalogue.available_difficulties(_profile)
	_profile.selected_difficulty = _next(options, _profile.selected_difficulty)
	_profile.save()
	difficulty_changed.emit(_profile.selected_difficulty)
	_redraw()


## Cycles through the challenges the profile has opened, with "none" first:
## the ordinary game is always one press away.
func _on_cycle_challenge() -> void:
	var options: Array[StringName] = [&""]
	options.append_array(_catalogue.available_challenges(_profile))
	_profile.selected_challenge = _next(options, _profile.selected_challenge)
	_profile.save()
	challenge_changed.emit(_profile.selected_challenge)
	_redraw()


static func _next(options: Array[StringName], current: StringName) -> StringName:
	if options.is_empty():
		return current
	var index: int = options.find(current)
	return options[(index + 1) % options.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var typing: bool = _seed_field != null and _seed_field.has_focus()
	if event.is_action_pressed(&"bb_confirm") and typing:
		# Enter in the seed field starts that seed rather than spinning behind.
		_on_start_pressed()
	elif event.is_action_pressed(&"bb_cancel") or event.is_action_pressed(&"bb_menu"):
		# Escape backs out one step at a time: out of the seed field first, then
		# out of the panel. Closing straight from a half-typed seed loses it.
		if typing:
			_seed_field.release_focus()
		else:
			close()
	# Whatever the key was, it stops here. A modal panel owns the keyboard while
	# it is up: unhandled input propagates in reverse tree order, so this panel
	# sees a key before the draft does, and anything it lets past reaches the
	# draft underneath — a number typed over the setup panel was buying an
	# artifact the player could not even see. Controls inside the panel are
	# unaffected, because a focused LineEdit takes its keys through _gui_input,
	# which runs before this and never reaches here at all.
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
