## The Clerk: the voice on the tannoy that walks a new debtor through the
## basement, once.
##
## The first playtest asked for a guided, skippable first run led by someone
## mysterious — the phone guy, the CloverPit voice. The House never speaks in
## person, so this is the Clerk: an intercom on the wall, a dry voice in the
## House's register, and a lamp that lights while it talks. It teaches the
## four things a debtor has to know before the House starts charging for the
## rest — the lever, the nudge, the hold, and what the ante and the chips are —
## by gating the machine to the move being taught until it has been made once.
##
## Presentation only. It reads the bus and the run, tells the room which moves
## are allowed, and never touches the simulation. Skipping it is a key press.
class_name TutorialDirector
extends Node

## A new line from the Clerk, or an empty body when the intercom goes quiet.
signal spoke(body: String, hint: String)
## The lesson is over — played through, or skipped.
signal finished(skipped: bool)

enum Step {
	IDLE,
	## Pull the lever.
	FIRST_PULL,
	## Read the window, pull again.
	SECOND_PULL,
	## A pair stands and nudges are owed: take one, or take the money.
	NUDGE,
	## A pair stands with nothing owed: hold it and spin the third.
	HOLD,
	## Spin the held board.
	HOLD_SPIN,
	## The ante, the settle, the chips.
	ANTE,
	## The draft.
	DRAFT,
	DONE,
}

## Spins the Clerk waits before it explains the ante, when no pair has come.
const PATIENCE: int = 4

var step: Step = Step.IDLE
var _bus: EffectBus
var _state: RunState
var _spins: int = 0
var _held_pair: PackedInt32Array = PackedInt32Array()
var _done_steps: Dictionary = {}


func bind(bus: EffectBus, state: RunState) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_state = state
	_bus.event_emitted.connect(_on_event)


## Starts the lesson on a fresh run.
func begin() -> void:
	step = Step.FIRST_PULL
	_spins = 0
	_done_steps.clear()
	_say(Step.FIRST_PULL)


func is_active() -> bool:
	return step != Step.IDLE and step != Step.DONE


func skip() -> void:
	if not is_active():
		return
	step = Step.DONE
	spoke.emit("", "")
	finished.emit(true)


## True when [param action] on [param index] is a move the lesson allows
## right now. Everything is allowed once the lesson is over; while it runs,
## only the move being taught — and the safe default — get through.
func allows(action: StringName, index: int = -1) -> bool:
	if not is_active():
		return true
	match step:
		Step.FIRST_PULL, Step.SECOND_PULL, Step.ANTE:
			return action == &"spin" or action == &"settle" or action == &"take" \
					or action == &"collect"
		Step.NUDGE:
			return action == &"nudge" or action == &"take" or action == &"collect"
		Step.HOLD:
			return action == &"hold" and _held_pair.has(index)
		Step.HOLD_SPIN:
			return action == &"spin" or action == &"hold" and _held_pair.has(index)
		Step.DRAFT:
			return true
		_:
			return true


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	if not is_active() or _state == null:
		return
	match kind:
		EffectBus.Event.PAYOUT_CALCULATED:
			_spins += 1
			_after_spin()
		EffectBus.Event.NUDGES_AWARDED:
			if not _done_steps.has(Step.NUDGE):
				_move_to(Step.NUDGE)
		EffectBus.Event.SPIN_STARTED:
			if step == Step.HOLD_SPIN:
				_done_steps[Step.HOLD] = true
		EffectBus.Event.SHOP_OPENED:
			_move_to(Step.DRAFT)
		EffectBus.Event.FLOOR_STARTED:
			if int(payload.get("floor", 1)) >= 2 and step != Step.DONE:
				step = Step.DONE
				spoke.emit("", "")
				finished.emit(false)
		_:
			pass


## Where the lesson goes once a spin has settled: the second pull, then a hold
## when a pair is standing, then the ante once the Clerk has waited long enough.
func _after_spin() -> void:
	if step == Step.FIRST_PULL:
		_move_to(Step.SECOND_PULL)
		return
	if step == Step.NUDGE:
		_done_steps[Step.NUDGE] = true
	var board: SpinBoard = _state.board
	if not _done_steps.has(Step.HOLD) and _state.decision == RunState.Decision.NONE \
			and _state.has_system(Systems.HOLD) and _pair_on(board):
		_move_to(Step.HOLD)
		return
	if step == Step.HOLD_SPIN or step == Step.HOLD:
		_done_steps[Step.HOLD] = true
	if not _done_steps.has(Step.ANTE) and (_spins >= PATIENCE or _state.spins_remaining <= 2):
		_move_to(Step.ANTE)
		return
	if step != Step.ANTE and step != Step.DRAFT:
		_move_to(Step.SECOND_PULL)


## The reels of the best pair standing on the payline, or none.
func _pair_on(board: SpinBoard) -> bool:
	_held_pair = PackedInt32Array()
	if board.pattern != Probability.Pattern.PAIR:
		return false
	var groups: Dictionary = {}
	for i: int in board.reel_count():
		var symbol: SymbolDef = board.line[i]
		if symbol == null or symbol.is_curse:
			continue
		var key: StringName = symbol.family if symbol.family != &"" else symbol.id
		var members: PackedInt32Array = groups.get(key, PackedInt32Array())
		members.append(i)
		groups[key] = members
	for key: StringName in groups:
		var members: PackedInt32Array = groups[key]
		if members.size() == 2:
			_held_pair = members
			return true
	return false


## The room tells the Clerk a hold was made, so the lesson can move to the spin.
func note_hold(reel: int) -> void:
	if step == Step.HOLD and _held_pair.has(reel):
		_move_to(Step.HOLD_SPIN)


func _move_to(next: Step) -> void:
	if next == step:
		return
	step = next
	_say(next)


## What the Clerk says at each step. The House's register: it informs.
func _say(at: Step) -> void:
	var hint: String = TouchBar.hint("ESC opens the door, where the lesson can be skipped",
			"the door, top right, skips the lesson")
	match at:
		Step.FIRST_PULL:
			spoke.emit("THE CLERK — Basement. Your account is open and the machine is yours. "
					+ "Pull the lever.", TouchBar.hint(Copy.filled("SPACE, or click the lever     %s", [hint]),
					Copy.filled("TAP to pull     %s", [hint])))
		Step.SECOND_PULL:
			spoke.emit("THE CLERK — Three reels, one line. The middle row is the one that pays; "
					+ "the rows above and below are what nearly landed, and they matter later. "
					+ "Pull again.", TouchBar.hint(Copy.filled("SPACE     %s", [hint]),
					Copy.filled("TAP     %s", [hint])))
		Step.NUDGE:
			spoke.emit("THE CLERK — A pair. The machine owes you nudges. A nudge drops the symbol "
					+ "above a reel onto the line, and each one costs a spin off the floor. "
					+ "The buttons say what each nudge would pay. Take one that pays, or "
					+ "TAKE IT and keep what is standing.", hint)
		Step.HOLD:
			spoke.emit("THE CLERK — A pair, and nothing owed. Hold it: lock the two matching "
					+ "reels and spin the third for the set. A lock costs a credit on the spin.",
					TouchBar.hint(Copy.filled("press the reel's number, or its button     %s", [hint]),
					Copy.filled("tap the reel's button     %s", [hint])))
		Step.HOLD_SPIN:
			spoke.emit("THE CLERK — Locked. Now spin the third.",
					TouchBar.hint(Copy.filled("SPACE     %s", [hint]), Copy.filled("TAP     %s", [hint])))
		Step.ANTE:
			spoke.emit("THE CLERK — The ante is due when the spins run out. Cover it or the House "
					+ "keeps the table — and the surety on the account is you. The column on "
					+ "the right is how much of you it holds; watch it. Cover the ante with "
					+ "spins to spare and you may SETTLE early: the House pays you in chips for "
					+ "every spin you leave — twice over, with half of them still on the clock. "
					+ "Chips buy hardware. Credits pay the ante. They never mix.", hint)
		Step.DRAFT:
			spoke.emit("THE CLERK — The draft. Chips buy hardware; hardware bolts on and stays. "
					+ "What you cannot afford, you may sign for — on the slate, against the "
					+ "debt, at the House's rate. Win loudly and the House notices: it sends "
					+ "one more of its people to the next floor, and says so. The doorman on "
					+ "this form takes chips to send nobody. From the next floor the draft "
					+ "may deal a chit — paper, spent once, at its moment. Everything else the House will "
					+ "explain when it charges you for it.",
					TouchBar.hint("SPACE leaves the draft", "Leave the draft"))
		_:
			spoke.emit("", "")
