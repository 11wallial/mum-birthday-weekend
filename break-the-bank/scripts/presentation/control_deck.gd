## The machine's controls: exactly the moves that are legal right now.
##
## Seven floors hand the player seven verbs, and a game that listed all of them
## on the first floor would have taught none of them. The deck is built from the
## run every time the run changes, so a control appears on the floor that grants
## it and a control the player cannot currently use is either absent or visibly
## barred. Nothing here enforces a rule — it emits intent, and [CasinoRoom]
## turns that into the same [SimEngine] calls the automated policies make.
class_name ControlDeck
extends CanvasLayer

## Emitted when the player asks for something. [param index] names a reel for
## the hold and nudge actions and is ignored by the rest.
signal action_requested(action: StringName, index: int)

const SPIN: StringName = &"spin"
const HOLD: StringName = &"hold"
const NUDGE: StringName = &"nudge"
const TAKE: StringName = &"take"
const GAMBLE: StringName = &"gamble"
const COLLECT: StringName = &"collect"
const STAKE_UP: StringName = &"stake_up"
const STAKE_DOWN: StringName = &"stake_down"
const DEPOSIT: StringName = &"deposit"
const WITHDRAW: StringName = &"withdraw"
const BUY_ROW: StringName = &"buy_row"
const BUY_REEL: StringName = &"buy_reel"
const LAUNDER: StringName = &"launder"

## Reel buttons sit above the action row so the two never compete for a thumb,
## and the standing controls — the stake, the vault, the works — sit in a row of
## their own above both. By floor seven there are eight of them, and a single
## row would either overflow a phone or squeeze the one button that matters.
const REEL_HEIGHT: float = 74.0
const ACTION_HEIGHT: float = 58.0
const EXTRA_HEIGHT: float = 44.0

var _reels: HBoxContainer
var _actions: HBoxContainer
var _extras: HBoxContainer
var _status: HBoxContainer
var _state: RunState
var _scale: float = 1.0
## Set while the reels are still turning: the machine must not offer a decision
## about a board the player has not been shown.
var _held_back: bool = false


func _ready() -> void:
	_status = get_node_or_null(^"Root/Column/Status") as HBoxContainer
	_reels = get_node_or_null(^"Root/Column/Reels") as HBoxContainer
	_actions = get_node_or_null(^"Root/Column/Actions") as HBoxContainer
	_extras = get_node_or_null(^"Root/Column/Extras") as HBoxContainer
	_fit()
	get_viewport().size_changed.connect(_fit)


func bind(state: RunState) -> void:
	_state = state
	refresh()


## Holds the deck back while the reels are turning, then lets it offer again.
func set_busy(busy: bool) -> void:
	if _held_back == busy:
		return
	_held_back = busy
	refresh()


func _fit() -> void:
	var window: Window = get_window()
	if window == null or window.size.x <= 0:
		return
	_scale = clampf(RunHUD.DESIGN_WIDTH / float(window.size.x), 1.0, 2.3)
	refresh()


## Rebuilds both rows from the run as it stands.
##
## Rebuilt rather than updated. The set of legal moves changes shape — three
## reel buttons become three nudge buttons, a stake dial appears three floors
## in — and reconciling that in place is how a button ends up wired to the move
## it used to mean.
func refresh() -> void:
	if _reels == null or _actions == null or _status == null or _extras == null:
		return
	_clear(_status)
	_clear(_reels)
	_clear(_extras)
	_clear(_actions)
	if _state == null or _state.is_over():
		return
	_build_status()
	if _state.phase == RunState.Phase.SPINNING:
		_build_reels()
		_build_actions()


func _build_status() -> void:
	if _state.has_system(Systems.STAKE):
		_chip("STAKE", "x%d" % _state.stake, UiSkin.AMBER)
	if _state.has_system(Systems.VAULT):
		var collateral: float = ArtifactEngine.vault_collateral(_state)
		_chip("VAULT", "%d%s" % [_state.economy.vault,
				"   +%.1fx" % collateral if collateral > 0.0 else ""],
				UiSkin.INK if _state.economy.vault > 0 else UiSkin.INK_MUTED)
	if _state.has_system(Systems.EXPANSION):
		_chip("WORKS", "%d reels  %d rows" % [
				_state.machine_reels(), _state.scoring_rows()], UiSkin.INK)
	if _state.contract != null:
		_chip("SIGNED", _state.contract.display_name, UiSkin.AMBER)
	if _state.has_system(Systems.HEAT):
		var measure: HeatEngine.Measure = HeatEngine.current(_state)
		var label: String = HeatEngine.measure_name(measure)
		_chip("COUNT", "%d%s" % [int(_state.heat),
				"   %s" % label if not label.is_empty() else ""],
				UiSkin.DENIED if measure > HeatEngine.Measure.NONE else UiSkin.INK_MUTED)


## One button per reel: hold it for the next spin, or nudge the band down onto
## the payline. The face of the symbol a nudge would bring down is on the button,
## because "nudge reel 3" is a rule and a picture of a seven is a reason.
func _build_reels() -> void:
	var board: SpinBoard = _state.board
	if not _state.has_system(Systems.HOLD):
		return
	var nudging: bool = (_state.decision == RunState.Decision.NUDGE
			and not _held_back)
	if not nudging and (_state.is_deciding() or _held_back):
		return
	for i: int in board.reel_count():
		var incoming: SymbolDef = board.above[i] if i < board.above.size() else null
		var standing: SymbolDef = board.line[i] if i < board.line.size() else null
		if nudging:
			var gain: int = ArtifactEngine.score_line(
					_state, board.preview_nudge(i)) * maxi(1, _state.stake) - board.payout
			_reel_button(NUDGE, i, "NUDGE", incoming,
					("+%d" % gain) if gain > 0 else "no better",
					board.can_nudge(i), gain > 0)
		else:
			var locked: bool = board.is_held(i)
			var barred: bool = (not locked
					and board.held_count() >= board.reel_count() - 1)
			_reel_button(HOLD, i, "HELD" if locked else "HOLD", standing,
					"%d cr" % _state.config.spin_cost if not locked else "locked",
					not barred, locked)


func _build_actions() -> void:
	match _state.decision:
		RunState.Decision.NUDGE:
			if _held_back:
				return
			_action(TAKE, "TAKE IT", "%d cr standing" % _state.board.payout, true, true)
			return
		RunState.Decision.GAMBLE:
			if _held_back:
				return
			var odds: PackedFloat32Array = _state.config.gamble_odds
			var rung: int = clampi(_state.board.gamble_rung, 0, odds.size() - 1)
			_action(GAMBLE, "DOUBLE",
					"%d → %d at %d%%" % [_state.board.payout,
					_state.board.payout * 2, int(round(odds[rung] * 100.0))], true, true)
			_action(COLLECT, "COLLECT", "%d cr" % _state.board.payout, true, false)
			return
		_:
			pass
	if _held_back:
		return
	_action(SPIN, "SPIN", "%d cr" % _state.spin_price(),
			_state.economy.can_afford(_state.spin_price()), true)
	if _state.has_system(Systems.STAKE):
		_extra(STAKE_DOWN, "STAKE −", "", _state.stake > 1)
		_extra(STAKE_UP, "STAKE +", "", _state.stake < _state.config.max_stake)
	if _state.has_system(Systems.VAULT):
		_extra(DEPOSIT, "BANK", "lock the float", _state.economy.cash > 0)
		_extra(WITHDRAW, "BREAK", "−%d%%" % int(_state.config.vault_break_percent),
				_state.economy.vault > 0)
	if _state.has_system(Systems.EXPANSION):
		_works_action(BUY_ROW, "+ ROW", _state.extra_rows, _state.config.max_extra_rows)
		_works_action(BUY_REEL, "+ REEL", _state.extra_reels, _state.config.max_extra_reels)
	if _state.has_system(Systems.HEAT) and _state.heat > 0.0:
		var price: int = HeatEngine.launder_price(_state)
		_extra(LAUNDER, "A WORD", "%d cr" % price, _state.economy.can_afford(price))


func _works_action(action: StringName, label: String, owned: int, ceiling: int) -> void:
	if owned >= ceiling:
		return
	var price: int = _price_for(action)
	_extra(action, label, "%d cr" % price, _state.economy.can_afford(price))


## Mirrors [method SimEngine.works_price] without holding an engine: the deck
## reads the run, and only the run.
func _price_for(action: StringName) -> int:
	var floor_def: FloorDef = _state.current_floor()
	var ante: float = float(floor_def.ante) if floor_def != null else 100.0
	var is_reel: bool = action == BUY_REEL
	var owned: int = _state.extra_reels if is_reel else _state.extra_rows
	var percent: float = (_state.config.reel_cost_percent if is_reel
			else _state.config.row_cost_percent)
	return maxi(1, int(round(ante * percent / 100.0 * float(1 + owned))))


func _chip(caption: String, value: String, tint: Color) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiSkin.row(true))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", int(roundf(8.0 * _scale)))
	row.add_child(_label(caption, 11.0, UiSkin.INK_MUTED))
	row.add_child(_label(value, 14.0, tint))
	panel.add_child(row)
	_status.add_child(panel)


func _reel_button(action: StringName, index: int, label: String,
		symbol: SymbolDef, note: String, enabled: bool, lit: bool) -> void:
	var button: Button = _new_button(enabled)
	button.custom_minimum_size = Vector2(
			maxf(112.0 * _scale, _width_of(note, 11.0) + 46.0 * _scale),
			REEL_HEIGHT * _scale)
	button.pressed.connect(func() -> void: action_requested.emit(action, index))

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 0)

	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override(&"separation", int(roundf(6.0 * _scale)))
	if symbol != null:
		var art: ImageTexture = SymbolArt.texture_for(symbol.id, symbol.color)
		if art != null:
			var icon: TextureRect = TextureRect.new()
			icon.texture = art
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.custom_minimum_size = Vector2(22.0, 22.0) * _scale
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.modulate = Color(1, 1, 1, 1.0 if enabled else 0.45)
			head.add_child(icon)
	head.add_child(_label("%s  %d" % [label, index + 1], 13.0,
			UiSkin.AMBER if lit else (UiSkin.INK if enabled else UiSkin.DENIED)))
	column.add_child(head)
	var caption: Label = _label(note, 11.0, UiSkin.INK_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	button.add_child(column)
	_reels.add_child(button)


func _action(action: StringName, label: String, note: String,
		enabled: bool, primary: bool) -> void:
	var button: Button = _new_button(enabled)
	# A Button is not a container, so nothing sizes it around the labels laid
	# out inside it. Without measuring them the whole row collapsed to zero
	# width and every control printed on top of its neighbour.
	button.custom_minimum_size = Vector2(
			maxf(_width_of(label, 15.0), _width_of(note, 11.0)) + 34.0 * _scale,
			ACTION_HEIGHT * _scale)
	if primary:
		button.add_theme_stylebox_override(&"normal", UiSkin.button(&"pressed"))
	button.pressed.connect(func() -> void: action_requested.emit(action, 0))

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 0)
	var title: Label = _label(label, 15.0,
			UiSkin.AMBER if primary and enabled else
			(UiSkin.INK if enabled else UiSkin.DENIED))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	if not note.is_empty():
		var caption: Label = _label(note, 11.0, UiSkin.INK_MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
	button.add_child(column)
	_actions.add_child(button)


## How wide [param text] draws at [param size], in the deck's own scale.
func _width_of(text: String, size: float) -> float:
	if text.is_empty():
		return 0.0
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return float(text.length()) * size * 0.62 * _scale
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			int(roundf(size * _scale))).x


## A standing control: the stake, the vault, the works, a quiet word. Smaller
## than the spin, and always in the same row, so the eye learns where they live.
func _extra(action: StringName, label: String, note: String, enabled: bool) -> void:
	var button: Button = _new_button(enabled)
	var caption: String = label if note.is_empty() else "%s   %s" % [label, note]
	button.text = caption
	button.add_theme_font_size_override(&"font_size", int(roundf(12.0 * _scale)))
	button.custom_minimum_size = Vector2(
			_width_of(caption, 12.0) + 26.0 * _scale, EXTRA_HEIGHT * _scale)
	button.pressed.connect(func() -> void: action_requested.emit(action, 0))
	_extras.add_child(button)


func _new_button(enabled: bool) -> Button:
	var button: Button = Button.new()
	UiSkin.dress_button(button)
	button.disabled = not enabled
	# The deck sits over the room, and a focus ring left on a button after a tap
	# would eat the next keypress meant for the machine.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = (Control.CURSOR_POINTING_HAND if enabled
			else Control.CURSOR_ARROW)
	return button


func _label(text: String, size: float, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", int(roundf(size * _scale)))
	label.add_theme_color_override(&"font_color", tint)
	return label


func _clear(row: Node) -> void:
	for child: Node in row.get_children():
		# Removed as well as freed: queue_free defers, and a refresh in the same
		# frame as the last would stack a second deck on the first.
		row.remove_child(child)
		child.queue_free()
