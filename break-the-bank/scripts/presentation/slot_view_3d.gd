## The 3D face of one slot machine.
##
## Strictly a listener: it reads [EffectBus] events and [RunState], and never
## calls back into the simulation. Deleting this node leaves a fully playable
## headless game, which is what keeps the balance lab honest.
class_name SlotView3D
extends Node3D

## The simulation resolves a spin instantly: SPIN_STARTED and PAYOUT_CALCULATED
## arrive in the same frame. The pacing of a spin is therefore entirely the
## view's business, which is why these live here and not in BalanceConfig.
## Tightened once the spin became a decision. A run is eighty-odd spins and
## every one of them now ends in a choice, so a second of drum before the player
## can act is a minute of waiting per run.
const SPIN_DURATION: float = 0.34
const REEL_STAGGER: float = 0.1
const SETTLE_DURATION: float = 0.16
## Multiplies every one of those, and the scoring performance after them. A
## setting: a long session wants the reels quicker, a first one wants them
## slower, and the view is the only place that knows how long a spin takes.
static var pace: float = 1.0
## The three steps the setting offers, slow to quick, and their names.
const PACES: Array[float] = [1.45, 1.0, 0.62]
const PACE_NAMES: Array[String] = ["SLOW", "NORMAL", "QUICK"]
## A steady picture: no flicker, no flash past the tubes' running heat, no
## tearing in the render, no shake, no swinging lamp. A setting, kept on
## the profile, for anyone the machine's overload would hurt — the display
## hygiene the roadmap lists — and the performance's timing is untouched by
## it, so nothing is skipped, only the light held still.
static var steady: bool = false
## Holding the lever — or Space — through a performance runs the clock this
## much faster. The whole sequence scales; nothing is cut out of it, and the
## pause before the total still stands, shorter.
const FAST_FORWARD: float = 2.2

@export var module_anchor_path: NodePath = ^"ModuleAnchor"
@export var payout_particles_path: NodePath = ^"PayoutParticles"
@export var machine_light_path: NodePath = ^"MachineLight"

var _reels: Array[Node3D] = []
var _module_anchor: Node3D
## Places on the frame where bought hardware bolts on, in fill order.
var _mounts: Array[Node3D] = []
## Every "Drive" node across the fitted modules, turned while the reels spin.
var _drives: Array[Node3D] = []
var _lever: Node3D
## The Nixie counters across the chassis face, digit labels per bank.
var _counters: Dictionary = {}
## Values the counters are waiting to show: a payout is credited the frame
## the reels are told to turn, and a counter that jumped then would spoil
## the spin. Held until the drums land.
var _counter_pending: Dictionary = {}
var _counter_shown: Dictionary = {}
## The console keys under the reel buttons, in slot order.
var _console: Array[Node3D] = []
## The payline bar, flashed on a win.
var _payline: MeshInstance3D
## Extra spin time on the last drum when the ones before it already match:
## the anticipation every real machine sells.
const TENSION_EXTRA: float = 0.85
## The four lamps of the gamble ladder, bottom rung first.
var _ladder: Array[Node3D] = []
## The two dials on the crown: the wager, and the House's attention.
var _gauge_stake: Node3D
var _gauge_count: Node3D
## The pressure gauge on the gearbox flank: the run's HEAT, made physical.
var _heat_needle: Node3D
## The surety column on the right flank: its fluid's pivot and its lamp.
var _surety_fluid: Node3D
var _surety_lamp: MeshInstance3D
## The level the column is waiting to show, or -1. Held through a spin like
## the cash counter, so the surety moves on the spin's own beat.
var _surety_pending: float = -1.0
var _surety_shown: float = 0.0
## The charge cable's arc and the light it throws while it rides.
var _arc_material: ShaderMaterial
var _arc_light: OmniLight3D
var _odds: Node3D
var _readout: Label
var _particles: CPUParticles3D
var _light: OmniLight3D
var _audio: AudioDirector
var _bus: EffectBus
var _pending: Array[Dictionary] = []
## The payout actually banked for the spin in progress, or -1 while the machine
## still owes the player a decision about it.
var _banked: int = -1
## Reels the player has locked, and how many nudges the board is owed. Held so
## the lamps can be redrawn without asking the simulation anything.
var _held: Array[bool] = []
## The most a plate may ever be lit, when it flares on a beat of the chain.
## Held under the environment's 1.1 bloom threshold: past it the cell bloomed
## white and the symbol on it vanished. A plate at rest is not lit at all.
const GLOW_MAX: float = 1.02

## How a spin's payout is judged, as a share of what one spin has to be worth
## to clear the floor: the ante divided by the spins allowed. Judging against a
## fixed number made a 60-credit win read as huge on floor 7 and as nothing on
## floor 1; judged against par, "good" means the same thing all the way down.
## The six values are [enum ScoreDirector.Tier], one to one: the director
## judges, the machine performs.
enum Result {
	## Paid less than a quarter of par. The reels ate the spin.
	DEAD,
	## Paid something, apologetically.
	SCRAPING,
	## Paid its own way: the full chain, a light shake.
	PAID,
	## Something is working: the camera leans in, the tubes brighten.
	STRONG,
	## The machine is straining: an ante in one spin.
	HEAVY,
	## The House is in trouble: three antes in one spin.
	OVERLOAD,
}

## True from the first frame of a spin until the last reel has settled. The room
## refuses to advance the run while this holds, so the simulation can never get
## more than one spin ahead of what the player is looking at.
var _busy: bool = false
## True while a redraw is waiting on the strip bake.
var _redraw_booked: bool = false
## The last memo the ledger printed, so a beep marks a new one only.
var _last_memo: String = ""
## The receipt of the spin being performed: the breakdown's steps, from
## PAYOUT_CALCULATED, which is what the scoring chain is made of.
var _steps: Array = []
## True from a spin's start until its total has landed. The cash counter is
## held for the whole of it — a payout that appeared on the tubes before the
## chain had counted it up would spoil the count.
var _awaiting: bool = false
## Whether this spin's last drum ran on: the near-miss hold on a loss.
var _tense: bool = false
## The last values put on each counter, by bank.
var _counter_value: Dictionary = {}
## When the count-up last tinked, so a rolling counter does not fire a tink
## every frame.
var _last_tink: float = 0.0
## Where the machine's lamp rests between flares.
const LAMP_REST: float = 1.0

## How the spin was judged. The HUD listens so its readout agrees with the
## machine rather than restating the number in its own words.
##
## Emitted twice on a spin the machine owes a decision on: once when the drums
## stop, with [param settled] false and the board as it stands, and again when
## the credits actually move. A verdict on an unsettled board would call a line
## dead while the player was still holding a nudge worth forty credits.
signal result_judged(result: Result, payout: int, settled: bool)
## The scoring performance is about to play: [param plan] is
## [method ScoreDirector.plan]'s timetable, so the receipt can print in time
## with it and the room can brace for its tier.
signal scoring_started(plan: Dictionary)
## The pause before the total lands: everything stops for [param seconds].
signal pause_started(seconds: float)
## A physical reel button was clicked. Same shape as the deck's
## action_requested, and the room routes both through one handler.
signal control_pressed(action: StringName, index: int)
## Artifacts acquired this run. Drives how hard the reels are backlit.
var _upgrades: int = 0
## What one spin needs to be worth on this floor. Set from FLOOR_STARTED.
var _par: float = 1.0


func _ready() -> void:
	# The machine is generated rather than authored, so it has to exist before
	# anything below can be resolved against it.
	var parts: Dictionary = MachineFrame.new().build(self)
	_reels.assign(parts.get("reels", []))
	_lever = parts.get("lever", null) as Node3D
	_mounts.assign(parts.get("mounts", []))
	# The machine's own gearing turns on a spin alongside any bought hardware:
	# a train of cogs sitting dead above turning reels is scenery, not works.
	_drives.assign(parts.get("crown", []))
	_ladder.assign(parts.get("ladder", []))
	_counters = parts.get("counters", {})
	_console.assign(parts.get("console", []))
	_payline = parts.get("payline", null) as MeshInstance3D
	var lever_pick: Area3D = parts.get("lever_pick", null) as Area3D
	if lever_pick != null:
		lever_pick.input_event.connect(_on_lever_input)
	for key: Node3D in _console:
		var pick: Area3D = key.get_node_or_null(^"Pick") as Area3D
		if pick != null:
			pick.input_event.connect(_on_key_input.bind(key))
	var gauges: Array = parts.get("gauges", [])
	_gauge_stake = (gauges[0] as Node3D) if gauges.size() > 0 else null
	_gauge_count = (gauges[1] as Node3D) if gauges.size() > 1 else null
	_odds = parts.get("odds", null) as Node3D
	var gearbox: Node3D = parts.get("gearbox", null) as Node3D
	if gearbox != null:
		_heat_needle = gearbox.get_node_or_null(^"Dial/HeatNeedle") as Node3D
	var surety: Dictionary = parts.get("surety", {})
	_surety_fluid = surety.get("fluid", null) as Node3D
	_surety_lamp = surety.get("lamp", null) as MeshInstance3D
	var arc: Dictionary = parts.get("arc", {})
	_arc_material = arc.get("material", null) as ShaderMaterial
	_arc_light = arc.get("light", null) as OmniLight3D
	_readout = parts.get("readout", null) as Label
	_module_anchor = get_node_or_null(module_anchor_path) as Node3D
	_particles = get_node_or_null(payout_particles_path) as CPUParticles3D
	_light = get_node_or_null(machine_light_path) as OmniLight3D


## Optional: lets the reels click as they stop.
func set_audio(audio: AudioDirector) -> void:
	_audio = audio


## Hold to fast-forward. The clock itself runs faster while the lever is held
## through a spin, so every beat, the count and the pause all shorten
## together and nothing is skipped. Released, the clock returns.
func _process(_delta: float) -> void:
	var wanted: float = FAST_FORWARD if _busy and Input.is_action_pressed(&"bb_advance") else 1.0
	if not is_equal_approx(Engine.time_scale, wanted):
		Engine.time_scale = wanted


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## The step of the pace setting nearest [param value].
static func pace_index(value: float) -> int:
	var best: int = 1
	for i: int in PACES.size():
		if absf(PACES[i] - value) < absf(PACES[best] - value):
			best = i
	return best


## Subscribes to a simulation. Call once, after the engine is built.
func bind(bus: EffectBus) -> void:
	if _bus != null and _bus.event_emitted.is_connected(_on_event):
		_bus.event_emitted.disconnect(_on_event)
	_bus = bus
	_bus.event_emitted.connect(_on_event)


func _on_event(kind: EffectBus.Event, payload: Dictionary) -> void:
	match kind:
		EffectBus.Event.SPIN_STARTED:
			_pending.clear()
			_banked = -1
			_busy = true
			_awaiting = true
			_steps = []
			_clear_lamps()
		EffectBus.Event.SYMBOL_LANDED:
			_pending.append(payload)
		EffectBus.Event.SPIN_RESOLVED:
			# The reels turn on this, not on the payout. A board that owes the
			# player nudges is never banked, so waiting for the credits to move
			# would leave the drums standing still for the whole decision.
			_play_spin(int(payload.get("payout", 0)), float(payload.get("multiplier", 1.0)))
		EffectBus.Event.NUDGES_AWARDED:
			_offer_nudges(int(payload.get("nudges", 0)))
		EffectBus.Event.REEL_NUDGED:
			_drop_reel(int(payload.get("reel", 0)),
					payload.get("column", {}) as Dictionary,
					int(payload.get("nudges", 0)))
		EffectBus.Event.WORKS_FITTED:
			_fit_works(int(payload.get("reels", 3)), int(payload.get("rows", 1)),
					not bool(payload.get("resumed", false)))
		EffectBus.Event.PAYOUT_CALCULATED:
			_banked = int(payload.get("payout", 0))
			_steps = payload.get("steps", [])
			# The spin is over however it ended — nudges spent, declined, or
			# never offered — so the chevrons come down here rather than only
			# when the last one happens to be used.
			_offer_nudges(0)
			# Landed already: the decision was made after the drums stopped, so
			# the performance is owed now rather than at the end of an animation
			# that has already finished.
			if not _busy:
				_perform(_banked, float(payload.get("multiplier", 1.0)))
		EffectBus.Event.FLOOR_STARTED:
			var spins: int = maxi(1, int(payload.get("spins", 1)))
			_par = maxf(1.0, float(payload.get("ante", 0)) / float(spins))
		EffectBus.Event.ARTIFACT_ACQUIRED:
			_upgrades += 1
			_attach_module(StringName(payload.get("artifact", &"")))
		EffectBus.Event.HEAT_CHANGED:
			# Boss territory is 100; the red zone starts where the sim's
			# thresholds say it should.
			_set_gauge(_heat_needle,
					clampf(float(payload.get("heat", 0.0)) / 100.0, 0.0, 1.0),
					Color(1.0, 0.3, 0.2))
		EffectBus.Event.RUN_STARTED:
			_upgrades = 0
			_clear_modules()
		_:
			pass


## True while reels are still turning. The run must not advance until this
## clears, or the readout describes a spin the reels have not shown yet.
func is_busy() -> bool:
	return _busy


## Spins every reel, then stops them left to right.
##
## When every drum but the last has landed a match, the last one runs on: the
## anticipation is the single most valuable feeling a slot machine has, and
## the view is the only thing that knows the answer before the player does.
func _play_spin(payout: int, multiplier: float) -> void:
	_busy = true
	_throw_lever()
	_charge_arc()
	_turn_drives()
	if _audio != null:
		_audio.play_at(&"handle_pull")
		_audio.play_at(&"reel_start")
		_audio.play_at(&"gear_grind")
		_audio.start_loop(&"reel_spin_loop")
		_audio.start_loop(&"axle_whir_loop")
	var last: int = _reels.size() - 1
	var tense: bool = _tension_builds()
	_tense = tense
	if tense:
		_tells((SPIN_DURATION + REEL_STAGGER * float(last - 1)) * pace, TENSION_EXTRA * pace)
	for i: int in _reels.size():
		var reel: Node3D = _reels[i]
		var spin_time: float = (SPIN_DURATION + REEL_STAGGER * float(i)) * pace
		if tense and i == last:
			spin_time += TENSION_EXTRA * pace
		var tween: Tween = create_tween()
		tween.tween_property(reel, "rotation:x", reel.rotation.x + TAU * 4.0, spin_time) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_settle_reel.bind(i))
		# Lands past the stop and springs back: a drum with weight in it.
		tween.tween_property(reel, "rotation:x", -MachineFrame.BAND_ANGLE * 0.14,
				SETTLE_DURATION * 0.6 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(reel, "rotation:x", 0.0, SETTLE_DURATION * pace) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if tense and i == last - 1:
			tween.tween_callback(func() -> void:
				if _audio != null:
					_audio.play(&"reel_tension"))
		if i == last:
			tween.tween_callback(_finish_spin.bind(payout, multiplier))


## True when the drums before the last one already agree — a pair, or more,
## standing before the last stop — which is when a real machine slows down.
func _tension_builds() -> bool:
	if _pending.size() < 3:
		return false
	var line: Array[SymbolDef] = []
	var content: ContentDB = ContentDB.shared()
	for i: int in _pending.size() - 1:
		var symbol: SymbolDef = content.symbol_by_id(StringName(_pending[i].get("symbol", &"")))
		if symbol == null or symbol.is_curse:
			return false
		line.append(symbol)
	return Probability.detect_pattern(line) >= Probability.Pattern.PAIR


## Reveals the landed symbol as its reel comes to rest.
func _settle_reel(index: int) -> void:
	if index < _pending.size():
		_show_symbol(_reels[index], _pending[index])
	# Land on a whole turn so the drum never settles crooked after many spins.
	_reels[index].rotation.x = fmod(_reels[index].rotation.x, TAU)
	if _audio == null:
		return
	# The last reel gets the heavier stop. Three identical clicks is a machine
	# ticking over; a lighter, lighter, then a solid one is a machine landing.
	var is_last: bool = index >= _reels.size() - 1
	if is_last:
		_audio.stop_loop(&"reel_spin_loop")
		_audio.stop_loop(&"axle_whir_loop")
		_audio.play_at(&"reel_stop_final")
	else:
		const TICKS: Array = [&"reel_stop_tick_a", &"reel_stop_tick_b", &"reel_stop_tick_c"]
		_audio.play_at(TICKS[index % TICKS.size()])
	if index < _pending.size() \
			and StringName(_pending[index].get("symbol", &"")) == &"skull":
		_audio.play_at(&"curse_land")


## Puts one landed symbol on one reel, preferring the printed strip cell and
## falling back to the glyph token. Exactly one of the two is ever visible.
##
## The strip bakes a frame after the machine is built. A board shown before
## it lands — every resumed run — fell back to the glyph tokens, and nothing
## put the plates on once the print existed, so the tokens sat over the
## drum's own printing for the rest of the floor. The redraw is booked here.
func _show_symbol(reel: Node3D, landed: Dictionary) -> void:
	if ReelPrint.strip() == null and not _redraw_booked:
		_redraw_booked = true
		ReelPrint.bake(self, func() -> void:
			# Headless has no strip to bake and answers at once; redrawing
			# then would book the same redraw again, without end.
			if ReelPrint.strip() != null:
				show_standing()
			_redraw_booked = false)
	var printed: bool = _face(reel, ^"Payline",
			StringName(landed.get("symbol", &"")))
	# The band above and below scores nothing. It is there so the player can see
	# what nearly landed, which is most of what makes a spin worth watching.
	_face(reel, ^"Above", StringName(landed.get("above", &"")))
	_face(reel, ^"Below", StringName(landed.get("below", &"")))
	# The glyph text remains the fallback for a symbol with no strip cell, on
	# the payline only: an unreadable near miss is worse than none.
	var label: Label3D = reel.get_node_or_null(^"Symbol") as Label3D
	if label != null:
		label.text = String(landed.get("glyph", "?"))
		label.modulate = landed.get("color", Color.WHITE)
		label.visible = not printed
	_set_glow(reel, landed.get("color", Color.WHITE), float(landed.get("value", 0)))


## Turns one window plate to the strip cell printed with [param symbol_id].
## Returns false when the symbol has no cell — the strip is not baked yet, or
## the symbol is new content with no art — so the caller can fall back.
func _face(reel: Node3D, row: NodePath, symbol_id: StringName) -> bool:
	var plate: MeshInstance3D = reel.get_node_or_null(row) as MeshInstance3D
	if plate == null:
		return false
	var material: StandardMaterial3D = \
			plate.material_override as StandardMaterial3D
	var cell: int = ReelPrint.cell_of(symbol_id)
	if material == null or material.albedo_texture == null or cell < 0:
		plate.visible = false
		return false
	material.uv1_offset.y = float(cell) / float(ReelPrint.CELLS)
	plate.visible = true
	return true


## A landed plate rests unlit. It used to be backlit in proportion to its
## value — a lamp behind the paper — and the art handover named that as the
## thing that made the symbols read as UI rather than as print on a drum:
## light that did not come from the room. The plate is lit by the room now,
## and lights up only as a beat of the scoring chain, in the accent, because
## it paid.
func _set_glow(reel: Node3D, _tint: Color, _value: float) -> void:
	var plate: MeshInstance3D = \
			reel.get_node_or_null(^"Payline") as MeshInstance3D
	if plate == null:
		return
	var material: StandardMaterial3D = \
			plate.material_override as StandardMaterial3D
	if material != null:
		material.emission_enabled = false


func _finish_spin(payout: int, multiplier: float) -> void:
	if _banked >= 0:
		# Banked already: the performance starts the moment the last drum
		# lands, and the machine stays busy until the total has.
		_perform(_banked, multiplier)
		return
	_busy = false
	_set_odds(multiplier)
	_flush_counters()
	# The board is standing but not banked: the machine owes a decision. Say how
	# the line reads so the controls can open, and hold the coins and the bells
	# back until the player has actually taken the money.
	result_judged.emit(_judge(payout), payout, false)


## The machine knows before you do. While the last drum runs on, the tubes
## flicker, the lamp dims a shade and the count's needle twitches — tells
## that only ever play on a genuinely live line, because a tell that lies
## is a tell this audience will stop believing.
func _tells(after: float, seconds: float) -> void:
	if steady:
		return
	var tells: Tween = create_tween()
	tells.tween_interval(after)
	if _light != null:
		tells.tween_property(_light, "light_energy", LAMP_REST * 0.7, 0.12)
	var ticks: int = maxi(1, int(seconds / 0.07))
	for i: int in ticks:
		tells.tween_callback(_tell_tick).set_delay(0.07)
	if _light != null:
		tells.tween_property(_light, "light_energy", LAMP_REST, 0.2)
	tells.tween_callback(func() -> void:
		for digit: Label3D in _counters.get("cash", []):
			digit.modulate = Color(1.0, 0.6, 0.18) * 2.6)


func _tell_tick() -> void:
	for digit: Label3D in _counters.get("cash", []):
		digit.modulate = Color(1.0, 0.6, 0.18) * randf_range(1.2, 3.2)
	if _gauge_count != null:
		var twitch: Tween = create_tween()
		twitch.tween_property(_gauge_count, "rotation:z",
				_gauge_count.rotation.z + randf_range(-0.08, 0.08), 0.05)


## Snaps the arm down and lets it drift back up. The throw is deliberately
## faster than the return: a lever that falls slowly reads as weightless.
func _throw_lever() -> void:
	if _lever == null:
		return
	if _audio != null:
		_audio.play_at(&"leather_squeak")
	var tween: Tween = create_tween()
	tween.tween_property(_lever, "rotation:x", 0.9, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The machine exhales at the bottom of the stroke, and the arm springs
	# home slower than it fell: a lever that falls slowly reads as weightless,
	# and one that snaps back instantly reads as plastic.
	tween.tween_callback(func() -> void:
		if _audio != null:
			_audio.play_at(&"lever_steam_release"))
	tween.tween_interval(0.1)
	tween.tween_callback(func() -> void:
		if _audio != null:
			_audio.play_at(&"handle_return"))
	tween.tween_property(_lever, "rotation:x", -0.5, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fires the charge down the cable from the coil to the drivetrain: the blue
## arc is the power the lever just asked for, arriving. Timed to land as the
## drums come up to speed.
func _charge_arc() -> void:
	if _arc_material == null:
		return
	if _audio != null:
		_audio.play_at(&"arc_charge")
	_arc_material.set_shader_parameter(&"charge", 0.0)
	var tween: Tween = create_tween()
	tween.tween_method(func(head: float) -> void:
		_arc_material.set_shader_parameter(&"charge", head),
		0.0, 1.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_arc_material.set_shader_parameter(&"charge", -1.0))
	if _arc_light != null:
		var flare: Tween = create_tween()
		flare.tween_property(_arc_light, "light_energy", 2.4, 0.1) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flare.tween_property(_arc_light, "light_energy", 0.22, 0.45) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## Turns every fitted module's moving parts for the length of a spin. A machine
## whose bought hardware sits dead while the reels turn reads as decoration
## bolted to a machine, rather than as part of one.
func _turn_drives() -> void:
	for i: int in _drives.size():
		var drive: Node3D = _drives[i]
		if not is_instance_valid(drive):
			continue
		# Alternating direction, and never quite the same speed: meshing gears
		# turn against each other, and a rack of identical spinners reads as a
		# single texture scrolling.
		var turns: float = TAU * (1.5 + float(i % 3) * 0.4)
		var direction: float = -1.0 if i % 2 == 1 else 1.0
		var tween: Tween = create_tween()
		tween.tween_property(drive, "rotation:z",
				drive.rotation.z + turns * direction, SPIN_DURATION + 0.35) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Writes the spin's multiplier onto the readout above the reels. The value is
## already on the HUD; putting it on the machine is what makes the machine the
## thing being read rather than a backdrop to a text overlay.
func _set_odds(multiplier: float) -> void:
	if _odds == null:
		return
	var text: String = "%.0fx" % maxf(multiplier, 1.0) if multiplier < 100.0 \
			else "%dx" % int(multiplier)
	# Right-aligned into the four tubes, the way a counter fills from its low
	# digit. A tube with nothing to show goes dark rather than showing a zero —
	# that is the difference between a Nixie bank and a number.
	var padded: String = text.lpad(4)
	for i: int in 4:
		var digit: Label3D = _odds.get_node_or_null("Digit%d" % i) as Label3D
		if digit == null:
			continue
		var glyph: String = padded[i]
		var lit: bool = glyph != " "
		digit.text = glyph
		digit.visible = lit
		var halo: MeshInstance3D = \
				_odds.get_node_or_null("Halo%d" % i) as MeshInstance3D
		if halo != null:
			halo.visible = lit
		if lit:
			# The strike flash of a tube changing state, settling to running heat.
			var flash: Tween = create_tween()
			digit.modulate = Color(1.0, 0.72, 0.32) * 2.0
			flash.tween_property(digit, "modulate",
					Color(1.0, 0.55, 0.14) * 1.5, 0.4)


## Relights the physical button row from ControlDeck's per-reel model. The
## deck computes what each reel offers; these lamps only say it in hardware.
func set_reel_controls(models: Array) -> void:
	var row: Node3D = get_node_or_null(^"Buttons") as Node3D
	if row == null:
		return
	var shelf: Node3D = row.get_child(0) as Node3D if row.get_child_count() > 0 \
			else null
	if shelf == null:
		return
	for child: Node in shelf.get_children():
		var button: Node3D = child as Node3D
		if button == null or not String(button.name).begins_with("ReelButton"):
			continue
		var index: int = int(String(button.name).trim_prefix("ReelButton"))
		var model: Dictionary = {}
		for candidate: Dictionary in models:
			if int(candidate.get("index", -1)) == index:
				model = candidate
				break
		_dress_button(button, model)


func _dress_button(button: Node3D, model: Dictionary) -> void:
	var lamp: MeshInstance3D = button.get_node_or_null(^"Lamp") as MeshInstance3D
	var caption: Label3D = button.get_node_or_null(^"Caption") as Label3D
	var material: StandardMaterial3D = \
			(lamp.material_override as StandardMaterial3D) if lamp != null else null
	button.set_meta(&"action", model.get("action", &""))
	button.set_meta(&"enabled", bool(model.get("enabled", false)))
	if not button.has_meta(&"wired"):
		button.set_meta(&"wired", true)
		var pick: Area3D = button.get_node_or_null(^"Pick") as Area3D
		if pick != null:
			pick.input_event.connect(_on_button_input.bind(button))
	if caption != null:
		caption.text = String(model.get("label", ""))
		caption.visible = not model.is_empty()
	if material == null:
		return
	if model.is_empty() or not bool(model.get("enabled", false)):
		# Dark: the machine is not offering this button right now.
		material.albedo_color = Color(0.16, 0.14, 0.12)
		material.emission_enabled = false
		return
	var nudging: bool = StringName(model.get("action", &"")) == &"nudge"
	var lamp_tint: Color = Color(0.5, 0.75, 1.0) if nudging \
			else Color(1.0, 0.72, 0.3)
	material.albedo_color = lamp_tint * 0.7
	material.emission_enabled = true
	material.emission = lamp_tint
	# Offered reads as lit even under the key light; taken reads as ON.
	material.emission_energy_multiplier = 3.2 if bool(model.get("lit", false)) \
			else 1.6


func _on_button_input(_camera: Node, event: InputEvent, _at: Vector3,
		_normal: Vector3, _shape: int, button: Node3D) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed \
			or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not bool(button.get_meta(&"enabled", false)):
		return
	var action: StringName = button.get_meta(&"action", &"") as StringName
	if action == &"":
		return
	var index: int = int(String(button.name).trim_prefix("ReelButton"))
	control_pressed.emit(action, index)


## Lights the ladder up to [param rung], and leaves the one above it waiting.
func _light_ladder(rung: int) -> void:
	for i: int in _ladder.size():
		var lit: bool = i < rung
		var pending: bool = i == rung
		_lamp_energy(_ladder[i], 3.2 if lit else (0.9 if pending else 0.0))


## Flares the rung just won, or drops the whole ladder at once.
func _resolve_ladder(won: bool, rung: int) -> void:
	if not won:
		for lamp: Node3D in _ladder:
			_lamp_energy(lamp, 0.0)
		return
	_light_ladder(rung)
	if rung <= 0 or rung > _ladder.size():
		return
	var lamp: MeshInstance3D = _ladder[rung - 1] as MeshInstance3D
	var flare: Tween = create_tween()
	flare.tween_method(func(energy: float) -> void: _lamp_energy(lamp, energy),
			9.0, 3.2, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Turns a dial to [param value] in 0..1, and tints it as it climbs.
func _set_gauge(pivot: Node3D, value: float, hot: Color) -> void:
	if pivot == null:
		return
	var turned: float = MachineFrame.GAUGE_SWEEP * (1.0 - 2.0 * clampf(value, 0.0, 1.0))
	var sweep: Tween = create_tween()
	sweep.tween_property(pivot, "rotation:z", turned, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var needle: MeshInstance3D = pivot.get_child(0) as MeshInstance3D
	if needle == null:
		return
	var material: StandardMaterial3D = needle.material_override as StandardMaterial3D
	if material != null:
		material.emission = Materials.SIGN.lerp(hot, clampf(value, 0.0, 1.0))


func _lamp_energy(lamp: Node3D, energy: float) -> void:
	var mesh: MeshInstance3D = lamp as MeshInstance3D
	if mesh == null:
		return
	var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = energy > 0.0
	material.emission_energy_multiplier = energy


## Puts whatever the simulation says is standing onto the drums, without a
## spin. A resumed run has already had its spin; what it needs is its board.
func show_standing() -> void:
	for i: int in mini(_pending.size(), _reels.size()):
		_show_symbol(_reels[i], _pending[i])
	_busy = false


## Lights the hold lamp under every locked reel.
func set_holds(held: Array) -> void:
	_held = []
	for value: Variant in held:
		_held.append(bool(value))
	for i: int in _reels.size():
		_set_lamp(_reels[i], ^"HoldLamp", Color(1.0, 0.66, 0.22),
				2.4 if i < _held.size() and _held[i] else 0.0)


## Raises the chevron over every reel the trail can still move.
func _offer_nudges(nudges: int) -> void:
	for i: int in _reels.size():
		var arrow: MeshInstance3D = _reels[i].get_node_or_null(^"NudgeArrow") as MeshInstance3D
		if arrow == null:
			continue
		arrow.visible = nudges > 0
		# The last bob stops here either way: a looping tween left on an arrow
		# that was hidden, or freed with its drum, spun forever and errored.
		if arrow.has_meta(&"bob"):
			var old: Tween = arrow.get_meta(&"bob") as Tween
			if old != null and old.is_valid():
				old.kill()
			arrow.remove_meta(&"bob")
		if not arrow.visible:
			continue
		# A slow bob rather than a flash: the arrow has to read as an invitation
		# the player can take their time over, because taking it costs a spin.
		# Bound to the arrow, so it dies with the drum on a window rebuild.
		var bob: Tween = arrow.create_tween().set_loops(0)
		bob.tween_property(arrow, "position:y", 0.56, 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(arrow, "position:y", 0.5, 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		arrow.set_meta(&"bob", bob)


## Rolls one drum down a stop, then repaints it with what now stands on it.
func _drop_reel(index: int, column: Dictionary, nudges_left: int) -> void:
	if index < 0 or index >= _reels.size():
		return
	var reel: Node3D = _reels[index]
	if _audio != null:
		_audio.play_at(&"reel_nudge")
	var roll: Tween = create_tween()
	roll.tween_property(reel, "rotation:x",
			reel.rotation.x + MachineFrame.BAND_ANGLE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	roll.tween_callback(func() -> void:
		reel.rotation.x = 0.0
		if not column.is_empty():
			_show_symbol(reel, column))
	if nudges_left <= 0:
		roll.tween_callback(_offer_nudges.bind(0))


## Widens the window when the works are fitted, and dims the rows that still do
## not pay so the ones the player has bought are the ones that read as live.
func _fit_works(reels: int, rows: int, aloud: bool = true) -> void:
	if reels != _reels.size():
		_reels.assign(MachineFrame.new().rebuild_window(self, reels))
		# The drums were rebuilt, so whatever was standing on them is gone; the
		# next spin repaints them.
		for landed: Dictionary in _pending:
			var index: int = int(landed.get("reel", -1))
			if index >= 0 and index < _reels.size():
				_show_symbol(_reels[index], landed)
	# Hardware refitted to a resumed run was fitted long ago; it makes no noise.
	if _audio != null and aloud:
		_audio.play(&"works_fitted")
	_light_rows(rows)


## Marks which of the three rows are paying, on the drums and on the window.
func _light_rows(rows: int) -> void:
	for reel: Node3D in _reels:
		for i: int in 3:
			var row: MeshInstance3D = reel.get_node_or_null(
					NodePath(["Above", "Payline", "Below"][i])) as MeshInstance3D
			if row == null:
				continue
			var material: StandardMaterial3D = \
					row.material_override as StandardMaterial3D
			if material == null:
				continue
			material.albedo_color = (Color(0.93, 0.91, 0.87) if _row_pays(i, rows)
					else Color(0.76, 0.74, 0.71))
	for i: int in 3:
		var marks: Node3D = get_node_or_null(
				NodePath("Bezel/Paylines/Row%d" % i)) as Node3D
		if marks == null:
			continue
		for mark: Node in marks.get_children():
			_lamp_energy(mark as Node3D,
					MachineFrame.PAYLINE_ENERGY if _row_pays(i, rows) else 0.0)


## Rows are bought from the middle outward: the payline, then the band above it,
## then the band below.
static func _row_pays(row: int, rows: int) -> bool:
	return row == 1 or (row == 0 and rows >= 2) or (row == 2 and rows >= 3)


func _clear_lamps() -> void:
	for reel: Node3D in _reels:
		_set_lamp(reel, ^"HoldLamp", Color(1.0, 0.66, 0.22), 0.0)
		var arrow: Node3D = reel.get_node_or_null(^"NudgeArrow") as Node3D
		if arrow != null:
			arrow.visible = false


func _set_lamp(reel: Node3D, path: NodePath, tint: Color, energy: float) -> void:
	var lamp: MeshInstance3D = reel.get_node_or_null(path) as MeshInstance3D
	if lamp == null:
		return
	var material: StandardMaterial3D = lamp.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = energy > 0.0
	material.emission = tint
	material.emission_energy_multiplier = energy


## Puts the run's debt on the machine's own monitor, as the ledger a terminal
## would actually be showing, with whatever the House has to say underneath.
## The screen holds six short lines; a memo is two of them.
func set_readout(debt: int, floor_name: String, memo: String = "",
		log: PackedStringArray = PackedStringArray()) -> void:
	if _readout == null:
		return
	var lines: PackedStringArray = PackedStringArray([
		"LEDGER OF ACCOUNT", "--------------------", floor_name.to_upper(),
		"PRINCIPAL  %d" % debt,
	])
	if memo.is_empty():
		lines.append("--------------------")
		lines.append("> _")
	else:
		var said: PackedStringArray = memo.split("\n", false)
		for i: int in mini(said.size(), 2):
			lines.append(("> " if i == 0 else "  ") + said[i].strip_edges())
	# The run's last entries, printed under the memo: the event log lives on
	# the ledger now, not in the corner of the screen.
	if not log.is_empty():
		lines.append("--------------------")
		for entry: String in log:
			lines.append("· " + entry.left(26))
	var text: String = "\n".join(lines)
	if text != _readout.text and _audio != null and not _readout.text.is_empty():
		# The tube rewrites: a click, and a beep when the House has something
		# new to say.
		_audio.play(&"crt_click")
		if memo != _last_memo:
			_audio.play(&"crt_beep")
	_last_memo = memo
	_readout.text = text


## How this spin went, relative to what the floor needs per spin.
func _judge(payout: int) -> Result:
	return int(ScoreDirector.tier_of(payout, _par)) as Result


## Writes [param value] onto the [param bank] counter — cash, ante, spins or
## chips. While the drums are turning the value is held and shown as they
## land, so a payout never appears on the machine before the reels have.
func set_counter(bank: String, value: int) -> void:
	if _busy or (_awaiting and bank == "cash"):
		_counter_pending[bank] = value
		return
	_show_counter(bank, value)


func _flush_counters() -> void:
	for bank: String in _counter_pending:
		_show_counter(bank, int(_counter_pending[bank]))
	_counter_pending.clear()


func _show_counter(bank: String, value: int) -> void:
	var digits: Array = _counters.get(bank, [])
	if digits.is_empty():
		return
	var text: String = str(maxi(0, value))
	if text.length() > digits.size():
		# In thousands, with a K on the last tube: a run that has outgrown
		# five tubes has not outgrown reading.
		text = "%dK" % (maxi(0, value) / 1000)
		if text.length() > digits.size():
			text = "%dM" % (maxi(0, value) / 1000000)
	text = text.lpad(digits.size())
	var before: String = String(_counter_shown.get(bank, ""))
	_counter_shown[bank] = text
	_counter_value[bank] = value
	var tinked: bool = false
	for i: int in digits.size():
		var digit: Label3D = digits[i] as Label3D
		var glyph: String = text[i]
		var lit: bool = glyph != " "
		digit.text = glyph
		digit.visible = lit
		var halo: MeshInstance3D = digit.get_parent().get_node_or_null(
				"Halo_%s_%d" % [bank, i]) as MeshInstance3D
		if halo != null:
			halo.visible = lit
		# A tube that changed strikes brighter for a moment, the way a Nixie
		# does when its cathode swaps, and tinks once for the bank.
		if lit and (before.length() != text.length() or before[i] != glyph):
			var flash: Tween = create_tween()
			digit.modulate = Color(1.0, 0.8, 0.42) * 2.8
			flash.tween_property(digit, "modulate", Color(1.0, 0.6, 0.18) * 2.6, 0.35)
			var now: float = float(Time.get_ticks_msec()) / 1000.0
			if not tinked and _audio != null and not before.is_empty() \
					and now - _last_tink > 0.07:
				_audio.play_at(&"nixie_tink")
				_last_tink = now
				tinked = true


## Relights the console keys from ControlDeck's action model: the moves the
## machine offers beyond the reels, up to six at a time. A key with nothing
## to offer goes dark and out of the way.
func set_action_controls(models: Array) -> void:
	for i: int in _console.size():
		var key: Node3D = _console[i]
		var model: Dictionary = models[i] if i < models.size() else {}
		key.visible = not model.is_empty()
		key.set_meta(&"action", model.get("action", &""))
		key.set_meta(&"enabled", bool(model.get("enabled", false)))
		var caption: Label3D = key.get_node_or_null(^"Caption") as Label3D
		if caption != null:
			var note: String = String(model.get("note", ""))
			caption.text = String(model.get("label", "")) \
					+ ("\n" + note if not note.is_empty() else "")
		var lamp: MeshInstance3D = key.get_node_or_null(^"Lamp") as MeshInstance3D
		var material: StandardMaterial3D = \
				(lamp.material_override as StandardMaterial3D) if lamp != null else null
		if material == null:
			continue
		if model.is_empty() or not bool(model.get("enabled", false)):
			material.albedo_color = Color(0.3, 0.28, 0.25)
			material.emission_enabled = false
			continue
		var primary: bool = bool(model.get("lit", false))
		var tint: Color = Color(0.95, 0.8, 0.5) if primary else Color(0.92, 0.86, 0.72)
		material.albedo_color = tint * 0.8
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.4 if primary else 0.7


func _on_key_input(_camera: Node, event: InputEvent, _at: Vector3,
		_normal: Vector3, _shape: int, key: Node3D) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not bool(key.get_meta(&"enabled", false)):
		return
	var action: StringName = key.get_meta(&"action", &"") as StringName
	if action != &"":
		control_pressed.emit(action, 0)


## The lever is the spin. A click anywhere along the arm pulls it.
func _on_lever_input(_camera: Node, event: InputEvent, _at: Vector3,
		_normal: Vector3, _shape: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	control_pressed.emit(&"spin", 0)


## The win, on the window: every payline plate flares in turn and the payline
## bar flashes, so the eye is told which symbols paid before the number is.
func _ripple(result: Result) -> void:
	var strength: float = 1.0 if result >= Result.HEAVY else 0.6
	for i: int in _reels.size():
		var plate: MeshInstance3D = _reels[i].get_node_or_null(^"Payline") as MeshInstance3D
		if plate == null:
			continue
		var material: StandardMaterial3D = plate.material_override as StandardMaterial3D
		if material == null:
			continue
		var resting: float = material.emission_energy_multiplier if material.emission_enabled else 0.0
		var resting_tint: Color = material.emission
		var pulse: Tween = create_tween()
		pulse.tween_interval(0.07 * float(i) * pace)
		pulse.tween_callback(func() -> void:
			material.emission_enabled = true
			material.emission = Materials.SCORE
			material.emission_energy_multiplier = GLOW_MAX * strength)
		pulse.tween_property(material, "emission_energy_multiplier", resting, 0.5 * pace) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pulse.tween_callback(func() -> void:
			material.emission = resting_tint
			material.emission_enabled = resting > 0.0)
	if _payline != null:
		var bar: StandardMaterial3D = _payline.material_override as StandardMaterial3D
		if bar != null:
			var flash: Tween = create_tween()
			bar.emission_energy_multiplier = 6.0 * strength
			flash.tween_property(bar, "emission_energy_multiplier", 1.8, 0.7 * pace) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The scoring performance. A spin is not an event that produces a number;
## it is a beginning, a rising middle, a held pause and a payoff, and this is
## where the machine plays it: every symbol and device on the receipt as its
## own beat, the total rolling up on the tubes, everything stopping, then the
## number. [ScoreDirector] writes the timetable; the machine keeps to it and
## stays busy until the total has landed, so the run cannot advance through
## its own payoff.
##
## Keyed to one judgement so the coins, the light, the shake and the sound
## can never disagree. Coins used to fall on any payout above zero, which is
## nearly every spin, and a spin that lost you the floor looked and sounded
## like a spin that won it.
func _perform(payout: int, multiplier: float) -> void:
	var plan: Dictionary = ScoreDirector.plan(_steps, payout, _par, pace)
	var result: Result = int(plan["tier"]) as Result
	_busy = true
	scoring_started.emit(plan)
	var seq: Tween = create_tween()
	var clock: float = 0.0
	for beat: Dictionary in plan["beats"]:
		seq.tween_interval(maxf(float(beat["at"]) - clock, 0.001))
		clock = float(beat["at"])
		seq.tween_callback(_beat.bind(beat))
	if result == Result.DEAD:
		seq.tween_callback(_fail.bind(payout))
		# On a near miss, the failed reel sits there for a moment before the
		# machine moves on. Let it sit.
		seq.tween_interval((0.6 if _tense else 0.14) * pace)
		seq.tween_callback(_land.bind(result, payout, multiplier))
		return
	seq.tween_interval(maxf(float(plan["chain_end"]) - clock, 0.001))
	seq.tween_callback(_count_up.bind(float(plan["count_seconds"])))
	seq.tween_interval(float(plan["count_seconds"]))
	seq.tween_callback(_hold.bind(float(plan["pause"])))
	seq.tween_interval(float(plan["pause"]))
	seq.tween_callback(_land.bind(result, payout, multiplier))


## One beat of the chain: the thing that scored lights on the machine, the
## drum jolts, one hit on the ladder, the running total steps up on the tubes.
func _beat(beat: Dictionary) -> void:
	var kind: String = String(beat["kind"])
	var reel: int = int(beat["reel"])
	var breaks: bool = bool(beat["break"])
	match kind:
		"symbol":
			if reel >= 0 and reel < _reels.size():
				_flare_plate(reel, Materials.SCORE, 1.0)
				_jolt(reel)
		"pattern":
			_flash_payline(0.25 if String(beat["text"]) == "x0" else 0.7)
		"soft":
			pass
		_:
			_flash_odds()
	_show_running(int(beat["running"]))
	if _audio == null:
		return
	if kind == "soft":
		_audio.play(&"payout_chime_small")
	elif kind == "artifact" and not String(beat["id"]).is_empty():
		# A device keeps its own voice: the rhythm break is a different
		# instrument, and this is the instrument.
		_audio.play(_audio.tier_cue(StringName(beat["id"])))
	elif breaks:
		_audio.play_at(&"score_break")
	elif bool(beat["cap"]):
		_audio.play(&"score_cap")
	else:
		_audio.play(&"score_beat", ScoreDirector.pitch_scale(int(beat["pitch"])))


## The count-up: the cash tubes roll through the intermediate values rather
## than swapping, most of the way to the total, and stop just short of it.
func _count_up(seconds: float) -> void:
	var from: int = int(_counter_value.get("cash", 0))
	var target: int = int(_counter_pending.get("cash", from))
	if target <= from or seconds <= 0.0:
		return
	var short: int = from + int(floor(float(target - from) * ScoreDirector.COUNT_SHORT))
	var roll: Tween = create_tween()
	roll.tween_method(func(value: float) -> void:
		_show_counter("cash", int(value)), float(from), float(short), seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The pause. Everything stops: the lamp dims, the room drops to its own
## tone, the reels are still. Held for slightly longer than is comfortable.
func _hold(seconds: float) -> void:
	pause_started.emit(seconds)
	if _light != null:
		var dim: Tween = create_tween()
		dim.tween_property(_light, "light_energy", LAMP_REST * 0.3, 0.05)


## Then the total. The final digits land, the tubes flare in the accent, and
## the tier's package plays — the coins, the sparks, the sound, the light —
## before the room is told how the spin went.
func _land(result: Result, payout: int, multiplier: float) -> void:
	_awaiting = false
	_flush_counters()
	_set_odds(multiplier)
	if result > Result.DEAD:
		_flare_bank("cash", 1.0 if result >= Result.STRONG else 0.6)
	_package(result, multiplier)
	_busy = false
	_flush_surety()
	result_judged.emit(result, payout, true)


## The machine goes dark: the counters' tubes out one by one, the odds
## tubes with them, the console's keys, the lamp behind the window, the
## column draining. The ending the win earns; nothing here is undone,
## because a new run rebuilds every counter from the run it starts.
func blackout(seconds: float) -> void:
	var order: Array = ["chips", "spins", "ante", "cash"]
	var step: float = seconds * 0.55 / 4.0
	for i: int in order.size():
		for digit: Label3D in _counters.get(order[i], []):
			var out: Tween = create_tween()
			out.tween_property(digit, "modulate", Color(0.2, 0.08, 0.02, 1.0), 0.25) \
					.set_delay(step * float(i) + randf_range(0.0, 0.2))
	if _odds != null:
		for i: int in 4:
			var digit: Label3D = _odds.get_node_or_null("Digit%d" % i) as Label3D
			if digit != null:
				var out: Tween = create_tween()
				out.tween_property(digit, "modulate", Color(0.2, 0.08, 0.02, 1.0), 0.3) \
						.set_delay(seconds * 0.5)
	for key: Node3D in _console:
		var lamp: MeshInstance3D = key.get_node_or_null(^"Lamp") as MeshInstance3D
		var material: StandardMaterial3D = \
				(lamp.material_override as StandardMaterial3D) if lamp != null else null
		if material != null:
			var out: Tween = create_tween()
			out.tween_property(material, "emission_energy_multiplier", 0.0, 0.4) \
					.set_delay(seconds * 0.6)
	if _light != null:
		var out: Tween = create_tween()
		out.tween_property(_light, "light_energy", 0.0, seconds * 0.7)
	if _surety_fluid != null:
		var drain: Tween = create_tween()
		drain.tween_property(_surety_fluid, "scale:y", 0.02, seconds * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _audio != null:
		_audio.play_at(&"switch_click")
		var thud: Tween = create_tween()
		thud.tween_callback(func() -> void: _audio.play_at(&"cash_thud")).set_delay(seconds * 0.6)


## Writes the House's hold on the player onto the surety column, in 0..1.
## Held through a spin and released as the total lands, so the level moves
## on the spin's beat: up on a dead one, down on a paying one.
func set_surety(value: float) -> void:
	if _busy or _awaiting:
		_surety_pending = value
		return
	_show_surety(value)


func _flush_surety() -> void:
	if _surety_pending >= 0.0:
		_show_surety(_surety_pending)
		_surety_pending = -1.0


func _show_surety(value: float) -> void:
	var level: float = clampf(value, 0.0, 1.0)
	var rising: bool = level > _surety_shown + 0.001
	_surety_shown = level
	if _surety_fluid != null:
		var rise: Tween = create_tween()
		rise.tween_property(_surety_fluid, "scale:y", maxf(0.02, level), 0.5 * pace) \
				.set_trans(Tween.TRANS_BACK if rising else Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_OUT)
	if _surety_lamp != null:
		var material: StandardMaterial3D = _surety_lamp.material_override as StandardMaterial3D
		if material != null:
			var lit: bool = level >= 0.85
			material.emission_energy_multiplier = 1.0 if lit else 0.0
			material.albedo_color = Color(0.75, 0.12, 0.1) if lit else Color(0.25, 0.06, 0.05)


## A losing spin, given weight: the lamp flickers once and settles, one dry
## mechanical sound with no musical content, and on a near miss the failed
## reel held in the red for a moment.
func _fail(_payout: int) -> void:
	if _light != null and not steady:
		var flicker: Tween = create_tween()
		flicker.tween_property(_light, "light_energy", LAMP_REST * 0.15, 0.05)
		flicker.tween_property(_light, "light_energy", LAMP_REST * 0.8, 0.06)
		flicker.tween_property(_light, "light_energy", LAMP_REST * 0.3, 0.05)
		flicker.tween_property(_light, "light_energy", LAMP_REST, 0.25)
	if _audio != null:
		_audio.play_at(&"score_dead")
	if _tense and not _reels.is_empty():
		_flare_plate(_reels.size() - 1, Materials.JACKPOT, 0.5, 0.6)


## The tier's package: what a spin of this size does to the machine.
func _package(result: Result, multiplier: float) -> void:
	if _particles != null and result >= Result.PAID:
		_particles.amount = [0, 0, 40, 90, 180, 300][int(result)]
		_particles.restart()
	var sparks: CPUParticles3D = get_node_or_null(^"Sparks") as CPUParticles3D
	var smoke: CPUParticles3D = get_node_or_null(^"Smoke") as CPUParticles3D
	if result >= Result.PAID:
		_ripple(result)
	if sparks != null and result >= Result.HEAVY:
		sparks.amount = 160 if result == Result.OVERLOAD else 90
		sparks.restart()
	if smoke != null and result == Result.OVERLOAD:
		smoke.restart()
	if _light != null:
		var flare: float = [0.35, 0.9, 1.6, 2.6, 4.5, 7.0][int(result)]
		var tween: Tween = create_tween()
		tween.tween_property(_light, "light_energy", flare, 0.08)
		tween.tween_property(_light, "light_energy", LAMP_REST, 0.55)
	if result == Result.OVERLOAD and not steady:
		_overbright(0.9)
	if _audio == null:
		return
	match result:
		Result.OVERLOAD:
			_audio.play(&"score_land")
			_audio.play(&"jackpot_bells")
			_audio.play_at(&"tube_overload")
			_audio.play_at(&"coin_cascade_large")
			_audio.play_at(&"coin_clatter_concrete", Vector3(0.6, -1.0, 0.8))
			_audio.play(&"mult_swell", clampf(multiplier / 3.0, 0.9, 1.7))
		Result.HEAVY:
			_audio.play(&"score_land")
			_audio.play_at(&"coin_cascade_large")
			_audio.play_at(&"coin_clatter_concrete", Vector3(0.6, -1.0, 0.8))
			_audio.play(&"mult_swell", clampf(multiplier / 3.0, 0.9, 1.5))
		Result.STRONG:
			_audio.play(&"score_land")
			_audio.play_at(&"coin_cascade_small")
			if multiplier >= 2.0:
				_audio.play(&"mult_swell", clampf(multiplier / 3.0, 0.8, 1.4))
		Result.PAID:
			_audio.play(&"score_land", 1.12)
			_audio.play_at(&"coin_cascade_small")
		Result.SCRAPING:
			_audio.play_at(&"coin_drop_single")
		_:
			pass


## Lights one reel's payline plate in [param tint] and lets it fade back.
func _flare_plate(reel: int, tint: Color, strength: float, seconds: float = 0.35) -> void:
	var plate: MeshInstance3D = _reels[reel].get_node_or_null(^"Payline") as MeshInstance3D
	if plate == null:
		return
	var material: StandardMaterial3D = plate.material_override as StandardMaterial3D
	if material == null:
		return
	var resting: float = material.emission_energy_multiplier if material.emission_enabled else 0.0
	var resting_tint: Color = material.emission
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = GLOW_MAX * strength
	var fade: Tween = create_tween()
	fade.tween_property(material, "emission_energy_multiplier", resting, seconds * pace) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade.tween_callback(func() -> void:
		material.emission = resting_tint
		material.emission_enabled = resting > 0.0)


## The drum bay jolts a few millimetres: a symbol scoring is a thing that
## happens to the machine, not to a number.
func _jolt(reel: int) -> void:
	var drum: Node3D = _reels[reel]
	var rest: float = drum.position.y
	var jolt: Tween = create_tween()
	jolt.tween_property(drum, "position:y", rest + 0.007, 0.03)
	jolt.tween_property(drum, "position:y", rest, 0.11) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_payline(strength: float) -> void:
	if _payline == null:
		return
	var bar: StandardMaterial3D = _payline.material_override as StandardMaterial3D
	if bar == null:
		return
	var flash: Tween = create_tween()
	bar.emission_energy_multiplier = 6.0 * strength
	flash.tween_property(bar, "emission_energy_multiplier", 1.8, 0.45 * pace) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The odds tubes strike on a device's beat.
func _flash_odds() -> void:
	if _odds == null:
		return
	for i: int in 4:
		var digit: Label3D = _odds.get_node_or_null("Digit%d" % i) as Label3D
		if digit == null or not digit.visible:
			continue
		var flash: Tween = create_tween()
		digit.modulate = Materials.SCORE * 2.6
		flash.tween_property(digit, "modulate", Color(1.0, 0.55, 0.14) * 1.5, 0.3)


## The running total, on the odds tubes while the chain plays. They go back
## to the multiplier when the total lands.
func _show_running(value: int) -> void:
	if _odds == null:
		return
	var text: String = str(maxi(0, value))
	if text.length() > 4:
		text = "%dK" % (maxi(0, value) / 1000)
	text = text.lpad(4)
	for i: int in 4:
		var digit: Label3D = _odds.get_node_or_null("Digit%d" % i) as Label3D
		if digit == null:
			continue
		var glyph: String = text[i]
		var lit: bool = glyph != " "
		digit.text = glyph
		digit.visible = lit
		var halo: MeshInstance3D = _odds.get_node_or_null("Halo%d" % i) as MeshInstance3D
		if halo != null:
			halo.visible = lit


## The bank's tubes flare in the accent as the total lands on them.
func _flare_bank(bank: String, strength: float) -> void:
	for digit: Label3D in _counters.get(bank, []):
		if not digit.visible:
			continue
		var flash: Tween = create_tween()
		digit.modulate = Materials.SCORE * (2.4 + 2.0 * strength)
		flash.tween_property(digit, "modulate", Color(1.0, 0.6, 0.18) * 2.6, 0.6 * pace) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Tier five: the tubes overbright and buzzing for [param seconds], past what
## they were built for.
func _overbright(seconds: float) -> void:
	for bank: String in _counters:
		for digit: Label3D in _counters[bank]:
			if not digit.visible:
				continue
			var burn: Tween = create_tween()
			var ticks: int = int(seconds / 0.06)
			for i: int in ticks:
				burn.tween_callback(func() -> void:
					digit.modulate = Color(1.0, 0.75, 0.4) * randf_range(3.5, 6.0)).set_delay(0.06)
			burn.tween_property(digit, "modulate", Color(1.0, 0.6, 0.18) * 2.6, 0.4)


## Fits hardware without buying it. For visual QA only: a real run reaches a
## well-stocked machine rarely and slowly, which is exactly the state that most
## needs looking at.
func debug_fit(artifact_id: StringName) -> void:
	_upgrades += 1
	_attach_module(artifact_id)


## Bolts the artifact's hardware onto the next free place on the frame.
##
## Every artifact gets hardware, built by [ModuleFactory] from its effect and
## its tag. An artifact may still name a [member ArtifactDef.module_scene_path]
## to override that with an authored scene, which is how a one-off centrepiece
## would be done — but nothing has to, and the default is never "nothing", which
## is what left twenty-four of twenty-six purchases invisible.
func _attach_module(artifact_id: StringName) -> void:
	var artifact: ArtifactDef = ContentDB.shared().artifact_by_id(artifact_id)
	if artifact == null:
		return
	var module: Node3D = _module_for(artifact)
	if module == null:
		return
	var mount: Node3D = _next_mount()
	if mount == null:
		# Out of places to put it. The frame is full at a dozen, which is well
		# past what a run buys; dropping the model is better than stacking two
		# in the same hole.
		module.queue_free()
		return
	mount.add_child(module)
	_collect_drives(module)
	_tag_module(mount, module, artifact)
	# Arrives oversized and settles, so a purchase is seen being fitted rather
	# than simply existing on the next frame.
	module.scale = Vector3.ONE * 1.7
	var tween: Tween = create_tween()
	tween.tween_property(module, "scale", Vector3.ONE, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The tag on a fitted piece of hardware: its name and what it does, on a
## paper label that shows while the pointer is over it (or on a tap), and
## for a moment as it is fitted. The first playtest had no way to read what
## a bought artifact did once it was on the machine; the machine now says.
func _tag_module(mount: Node3D, module: Node3D, artifact: ArtifactDef) -> void:
	var tag: Label3D = Label3D.new()
	tag.name = "Tag"
	tag.text = "%s\n%s" % [artifact.display_name.to_upper(), artifact.description]
	tag.font_size = 30
	tag.pixel_size = 0.0011
	tag.width = 520.0
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tag.modulate = Color(0.12, 0.1, 0.08)
	tag.outline_size = 14
	tag.outline_modulate = Color(0.9, 0.87, 0.8)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.render_priority = 10
	tag.position = Vector3(0.0, 0.22, 0.12)
	tag.visible = false
	mount.add_child(tag)
	var pick: Area3D = Area3D.new()
	pick.name = "TagPick"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.16
	shape.shape = sphere
	pick.add_child(shape)
	mount.add_child(pick)
	pick.mouse_entered.connect(func() -> void: _show_tag(tag, true))
	pick.mouse_exited.connect(func() -> void: _show_tag(tag, false))
	pick.input_event.connect(func(_camera: Node, event: InputEvent, _at: Vector3,
			_normal: Vector3, _shape: int) -> void:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			_show_tag(tag, true, 3.0))
	# Read as it is fitted, then put away.
	_show_tag(tag, true, 3.0)


## Shows or hides a hardware tag; with [param seconds], hides it again after.
func _show_tag(tag: Label3D, shown: bool, seconds: float = 0.0) -> void:
	if not is_instance_valid(tag):
		return
	tag.visible = shown
	if shown and seconds > 0.0:
		var later: Tween = tag.create_tween()
		later.tween_callback(func() -> void:
			if is_instance_valid(tag):
				tag.visible = false).set_delay(seconds)


## Strips the frame back to bare metal for a new run.
func _clear_modules() -> void:
	_drives.clear()
	for mount: Node3D in _mounts:
		for child: Node in mount.get_children():
			# Removed as well as freed: queue_free defers, and a new run that
			# starts in the same frame would find every mount still occupied.
			mount.remove_child(child)
			child.queue_free()


func _module_for(artifact: ArtifactDef) -> Node3D:
	if not artifact.module_scene_path.is_empty() \
			and ResourceLoader.exists(artifact.module_scene_path):
		var packed: PackedScene = load(artifact.module_scene_path) as PackedScene
		if packed != null:
			return packed.instantiate() as Node3D
	return ModuleFactory.build(artifact)


func _next_mount() -> Node3D:
	for mount: Node3D in _mounts:
		if mount.get_child_count() == 0:
			return mount
	return null


## Finds the turning parts of a fitted module, by the name its builder gives
## them. A module with no moving parts simply contributes none.
func _collect_drives(module: Node3D) -> void:
	var pending: Array[Node] = [module]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Node3D and String(node.name).begins_with("Drive"):
			_drives.append(node as Node3D)
		pending.append_array(node.get_children())
