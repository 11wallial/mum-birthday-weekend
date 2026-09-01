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
## The four lamps of the gamble ladder, bottom rung first.
var _ladder: Array[Node3D] = []
## The two dials on the crown: the wager, and the House's attention.
var _gauge_stake: Node3D
var _gauge_count: Node3D
## The pressure gauge on the gearbox flank: the run's HEAT, made physical.
var _heat_needle: Node3D
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
## How much a symbol has to be worth before it lights up at all, and the value
## at which its backlight is at full strength. Below the floor a symbol is just
## printed on the strip; a machine where everything glows says nothing about
## what landed.
const GLOW_FLOOR: float = 4.0
const GLOW_CEILING: float = 14.0
## Extra backlight per artifact the run has bought, as a fraction. A stacked
## machine is visibly hotter than a fresh one — the glow is the run's progress
## made physical, which is the same job the cash stacks and floor markers do.
const GLOW_PER_UPGRADE: float = 0.16
## Brightness of a top-value symbol on a fresh machine. Above the environment's
## 1.1 bloom threshold, so the best symbols flare rather than just tint.
const GLOW_GAIN: float = 2.3
const GLOW_MAX: float = 3.4

## How a spin's payout is judged, as a share of what one spin has to be worth
## to clear the floor: the ante divided by the spins allowed. Judging against a
## fixed number made a 60-credit win read as huge on floor 7 and as nothing on
## floor 1; judged against par, "good" means the same thing all the way down.
enum Result {
	## Paid less than a quarter of par. The reels ate the spin.
	DEAD,
	## Paid something, but you are still behind where you need to be.
	THIN,
	## Paid its own way and then some.
	GOOD,
	## Three times par or better.
	JACKPOT,
}

const THIN_SHARE: float = 0.25
const GOOD_SHARE: float = 1.0
const JACKPOT_SHARE: float = 3.0

## True from the first frame of a spin until the last reel has settled. The room
## refuses to advance the run while this holds, so the simulation can never get
## more than one spin ahead of what the player is looking at.
var _busy: bool = false

## How the spin was judged. The HUD listens so its readout agrees with the
## machine rather than restating the number in its own words.
##
## Emitted twice on a spin the machine owes a decision on: once when the drums
## stop, with [param settled] false and the board as it stands, and again when
## the credits actually move. A verdict on an unsettled board would call a line
## dead while the player was still holding a nudge worth forty credits.
signal result_judged(result: Result, payout: int, settled: bool)
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
	var gauges: Array = parts.get("gauges", [])
	_gauge_stake = (gauges[0] as Node3D) if gauges.size() > 0 else null
	_gauge_count = (gauges[1] as Node3D) if gauges.size() > 1 else null
	_odds = parts.get("odds", null) as Node3D
	var gearbox: Node3D = parts.get("gearbox", null) as Node3D
	if gearbox != null:
		_heat_needle = gearbox.get_node_or_null(^"Dial/HeatNeedle") as Node3D
	_readout = parts.get("readout", null) as Label
	_module_anchor = get_node_or_null(module_anchor_path) as Node3D
	_particles = get_node_or_null(payout_particles_path) as CPUParticles3D
	_light = get_node_or_null(machine_light_path) as OmniLight3D


## Optional: lets the reels click as they stop.
func set_audio(audio: AudioDirector) -> void:
	_audio = audio


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
			_fit_works(int(payload.get("reels", 3)), int(payload.get("rows", 1)))
		EffectBus.Event.PAYOUT_CALCULATED:
			_banked = int(payload.get("payout", 0))
			# The spin is over however it ended — nudges spent, declined, or
			# never offered — so the chevrons come down here rather than only
			# when the last one happens to be used.
			_offer_nudges(0)
			# Landed already: the decision was made after the drums stopped, so
			# the celebration is owed now rather than at the end of an animation
			# that has already finished.
			if not _busy:
				_celebrate(_banked, float(payload.get("multiplier", 1.0)))
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
func _play_spin(payout: int, multiplier: float) -> void:
	_busy = true
	_throw_lever()
	_turn_drives()
	if _audio != null:
		_audio.play_at(&"handle_pull")
		_audio.play_at(&"reel_start")
		_audio.start_loop(&"reel_spin_loop")
	var last: int = _reels.size() - 1
	for i: int in _reels.size():
		var reel: Node3D = _reels[i]
		var spin_time: float = SPIN_DURATION + REEL_STAGGER * float(i)
		var tween: Tween = create_tween()
		tween.tween_property(reel, "rotation:x", reel.rotation.x + TAU * 4.0, spin_time) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_settle_reel.bind(i))
		tween.tween_property(reel, "rotation:x", 0.0, SETTLE_DURATION) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == last:
			tween.tween_callback(_finish_spin.bind(payout, multiplier))


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
		_audio.play_at(&"reel_stop_final")
	else:
		const TICKS: Array = [&"reel_stop_tick_a", &"reel_stop_tick_b", &"reel_stop_tick_c"]
		_audio.play_at(TICKS[index % TICKS.size()])
	if index < _pending.size() \
			and StringName(_pending[index].get("symbol", &"")) == &"skull":
		_audio.play_at(&"curse_land")


## Puts one landed symbol on one reel, preferring the printed strip cell and
## falling back to the glyph token. Exactly one of the two is ever visible.
func _show_symbol(reel: Node3D, landed: Dictionary) -> void:
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


## Backlights the payline cell in proportion to what it is worth, scaled by how
## many upgrades the run is carrying. The plate itself is made emissive — a
## lamp behind printed paper lights the whole cell through the print, which is
## exactly how a fruit machine's win lamps read.
func _set_glow(reel: Node3D, tint: Color, value: float) -> void:
	var plate: MeshInstance3D = \
			reel.get_node_or_null(^"Payline") as MeshInstance3D
	if plate == null:
		return
	var material: StandardMaterial3D = \
			plate.material_override as StandardMaterial3D
	if material == null:
		return
	var importance: float = clampf(
			inverse_lerp(GLOW_FLOOR, GLOW_CEILING, value), 0.0, 1.0)
	if importance <= 0.0:
		material.emission_enabled = false
		return
	# Scaled past 1 deliberately: the environment blooms above 1.1, so a top
	# symbol on a stacked machine does not merely tint the cell, it flares.
	var energy: float = minf(
			importance * GLOW_GAIN * (1.0 + float(_upgrades) * GLOW_PER_UPGRADE),
			GLOW_MAX)
	material.emission_enabled = true
	# The lamp is behind the paper: enough to light the cell through the print,
	# not enough to bleach the ink out of it.
	material.emission = tint * 0.8
	material.emission_energy_multiplier = energy
	# A short flare as it lands, settling back to its resting brightness.
	material.emission_energy_multiplier = energy * 1.35
	var tween: Tween = create_tween()
	tween.tween_property(material, "emission_energy_multiplier", energy * 0.7,
			0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish_spin(payout: int, multiplier: float) -> void:
	_busy = false
	_set_odds(multiplier)
	if _banked >= 0:
		_celebrate(_banked, multiplier)
		return
	# The board is standing but not banked: the machine owes a decision. Say how
	# the line reads so the controls can open, and hold the coins and the bells
	# back until the player has actually taken the money.
	result_judged.emit(_judge(payout), payout, false)


## Snaps the arm down and lets it drift back up. The throw is deliberately
## faster than the return: a lever that falls slowly reads as weightless.
func _throw_lever() -> void:
	if _lever == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_lever, "rotation:x", 0.85, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_lever, "rotation:x", -0.5, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		if not arrow.visible:
			continue
		# A slow bob rather than a flash: the arrow has to read as an invitation
		# the player can take their time over, because taking it costs a spin.
		var bob: Tween = create_tween().set_loops(0)
		bob.tween_property(arrow, "position:y", 0.56, 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(arrow, "position:y", 0.5, 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
func _fit_works(reels: int, rows: int) -> void:
	if reels != _reels.size():
		_reels.assign(MachineFrame.new().rebuild_window(self, reels))
		# The drums were rebuilt, so whatever was standing on them is gone; the
		# next spin repaints them.
		for landed: Dictionary in _pending:
			var index: int = int(landed.get("reel", -1))
			if index >= 0 and index < _reels.size():
				_show_symbol(_reels[index], landed)
	if _audio != null:
		_audio.play(&"works_fitted")
	_light_rows(rows)


## Marks which of the three rows are paying, on the drums and on the window.
func _light_rows(rows: int) -> void:
	for reel: Node3D in _reels:
		for i: int in 3:
			var row: Sprite3D = reel.get_node_or_null(
					NodePath(["Above", "Payline", "Below"][i])) as Sprite3D
			if row == null:
				continue
			row.modulate = (Color(1, 1, 1, 1) if _row_pays(i, rows)
					else Color(0.62, 0.6, 0.58))
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
## would actually be showing.
func set_readout(debt: int, floor_name: String) -> void:
	if _readout != null:
		_readout.text = "LEDGER OF ACCOUNT\n--------------------\n%s\nPRINCIPAL  %d\n--------------------\n> _" \
				% [floor_name.to_upper(), debt]


## How this spin went, relative to what the floor needs per spin.
func _judge(payout: int) -> Result:
	var share: float = float(payout) / _par
	if share >= JACKPOT_SHARE:
		return Result.JACKPOT
	if share >= GOOD_SHARE:
		return Result.GOOD
	if share >= THIN_SHARE:
		return Result.THIN
	return Result.DEAD


## Everything that tells the player how the spin went, keyed to one judgement so
## the coins, the light, the shake and the sound can never disagree.
##
## Coins used to fall on any payout above zero, which is nearly every spin, and
## the flare scaled off the multiplier rather than the result. So a spin that
## lost you the floor looked and sounded like a spin that won it.
func _celebrate(payout: int, multiplier: float) -> void:
	var result: Result = _judge(payout)
	if _particles != null:
		match result:
			Result.JACKPOT:
				_particles.amount = 220
				_particles.restart()
			Result.GOOD:
				_particles.amount = 60
				_particles.restart()
			_:
				# A thin or dead spin throws nothing. Silence and stillness are
				# the feedback: you needed par and you did not get it.
				pass
	if _light != null:
		var flare: float = [0.35, 0.9, 2.6, 6.0][int(result)]
		var tween: Tween = create_tween()
		tween.tween_property(_light, "light_energy", flare, 0.08)
		tween.tween_property(_light, "light_energy", 1.0, 0.55)
	if _audio != null:
		match result:
			Result.JACKPOT:
				_audio.play(&"jackpot_bells")
				_audio.play_at(&"coin_cascade_large")
			Result.GOOD:
				_audio.play(&"payout_chime_big")
				_audio.play_at(&"coin_cascade_small")
			Result.THIN:
				_audio.play(&"payout_chime_small")
				_audio.play_at(&"coin_drop_single")
			_:
				pass
	result_judged.emit(result, payout, true)


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
	# Arrives oversized and settles, so a purchase is seen being fitted rather
	# than simply existing on the next frame.
	module.scale = Vector3.ONE * 1.7
	var tween: Tween = create_tween()
	tween.tween_property(module, "scale", Vector3.ONE, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
