## The scoring performance, planned.
##
## A spin is not an event that produces a number. A spin is a performance with
## a beginning, a rising middle, a held pause and a payoff, and the art
## handover is right that this is most of why people cannot put the reference
## down. The simulation resolves a spin in one frame and hands over a receipt
## of steps; this turns that receipt into a timetable — every contributing
## symbol and device as its own beat, the tempo running away as the chain
## grows, a pitch ladder climbing a semitone a beat, a rhythm break wherever
## a device fires, then the count-up, then the pause, then the total — and
## [SlotView3D] plays it.
##
## Pure: nothing here draws, waits or plays. A plan can be asserted on, which
## is how the tempo curve, the ladder's cap and the pause's floor are held.
class_name ScoreDirector
extends RefCounted

## What the spin was worth, felt before it is read. The five tiers of the
## handover plus the loss, judged against par — the ante divided by the spins
## allowed — so a tier means the same thing on every floor.
enum Tier {
	## Paid less than a quarter of par: the reels ate the spin.
	DEAD,
	## Paid something, apologetically.
	SCRAPING,
	## Paid its own way: the full chain, a light shake.
	PAID,
	## Something is working: the camera leans in, the tubes brighten.
	STRONG,
	## The machine is straining: an ante in one spin.
	HEAVY,
	## The House is in trouble: three antes in one spin. Rare enough to be
	## remembered individually.
	OVERLOAD,
}

## The share of par each tier starts at, from SCRAPING up.
const TIER_SHARES: Array[float] = [0.25, 1.0, 3.0, 10.0, 30.0]

## Seconds between beats at the start of a chain, and the floor the gap
## decays to as the chain extends. A long chain should feel like it is
## running away from you.
const FIRST_GAP: float = 0.18
const GAP_FLOOR: float = 0.06
const GAP_DECAY: float = 0.86
## A device firing breaks the tempo: a longer gap, a heavier hit. Rhythm then
## broken rhythm is where the surprise lives.
const BREAK_GAP: float = 1.8
## Semitones the ladder climbs before it caps. The cap is its own signal.
const LADDER_CAP: int = 12
## The count-up's length, scaled by the number's magnitude and capped.
const COUNT_MIN: float = 0.3
const COUNT_MAX: float = 1.5
const COUNT_PER_DECADE: float = 0.3
## The pause before the total lands: everything stops for slightly longer
## than is comfortable. Scaled by pace, but never below the floor — a veteran
## on max speed still gets the pause.
const PAUSE: float = 0.45
const PAUSE_FLOOR: float = 0.2
## How much of the total the count-up reaches before the pause: the final
## digits land after it, slower than the ones before.
const COUNT_SHORT: float = 0.92

## The step kinds that break the rhythm rather than climbing the ladder.
const BREAK_KINDS: Array[String] = ["artifact", "synergy", "house", "stake", "row"]


## The tier a payout falls in against [param par].
static func tier_of(payout: int, par: float) -> Tier:
	var share: float = float(payout) / maxf(par, 1.0)
	var tier: int = int(Tier.DEAD)
	for threshold: float in TIER_SHARES:
		if share >= threshold:
			tier += 1
	return tier as Tier


## The timetable for a spin that paid [param payout] from [param steps] — a
## [member SpinBoard.breakdown]'s steps — at [param pace] (1.0 is the
## authored timing; smaller is quicker).
##
## Returns [code]tier[/code], [code]beats[/code] (each with [code]at[/code] in
## seconds, its step's [code]kind[/code], [code]label[/code], [code]text[/code],
## [code]reel[/code] and [code]id[/code], the [code]running[/code] total so
## far, its [code]pitch[/code] on the ladder in semitones, and whether it is a
## [code]break[/code] or at the [code]cap[/code]), then [code]chain_end[/code],
## [code]count_seconds[/code], [code]pause_at[/code], [code]pause[/code],
## [code]total_at[/code] and [code]end[/code], all in seconds from the start.
static func plan(steps: Array, payout: int, par: float, pace: float = 1.0) -> Dictionary:
	var tier: Tier = tier_of(payout, par)
	var scale: float = maxf(pace, 0.05)
	var beats: Array[Dictionary] = []
	var t: float = 0.0
	if tier == Tier.SCRAPING:
		# Almost apologetic: one soft hit, no chain.
		beats.append({"at": 0.0, "kind": "soft", "label": "", "text": "",
				"reel": -1, "id": "", "running": payout, "pitch": 0,
				"break": false, "cap": false})
		t = FIRST_GAP * scale
	elif tier > Tier.SCRAPING:
		var gap: float = FIRST_GAP
		var ladder: int = 0
		var base: int = 0
		var flat: float = 0.0
		var mult: float = 1.0
		var stake: int = 1
		var rows: int = 0
		for entry: Variant in steps:
			var step: Dictionary = entry as Dictionary
			var kind: String = String(step.get("kind", ""))
			var text: String = String(step.get("text", ""))
			var breaks: bool = BREAK_KINDS.has(kind)
			match kind:
				"symbol":
					base += int(text)
				"pattern":
					if text == "x0":
						mult = 0.0
					elif text.begins_with("+"):
						mult += float(text.trim_prefix("+").trim_suffix("x"))
				"stake":
					stake = maxi(1, int(text.trim_prefix("x")))
				"row":
					rows += int(text)
				_:
					for token: String in text.split(" ", false):
						if token.ends_with("x"):
							var value: float = float(token.trim_suffix("x"))
							if token.begins_with("+") or token.begins_with("-"):
								mult += value
							elif token.begins_with("x"):
								mult *= float(token.trim_prefix("x").trim_suffix("x"))
						elif token.begins_with("x"):
							mult *= float(token.trim_prefix("x"))
						else:
							flat += float(token)
			var running: int = int(round((float(base) + flat) * mult)) * stake + rows
			var cap: bool = false
			var pitch: int = ladder
			if not breaks:
				if ladder < LADDER_CAP:
					ladder += 1
				else:
					cap = true
				pitch = ladder
			beats.append({"at": t, "kind": kind, "label": String(step.get("label", "")),
					"text": text, "reel": int(step.get("reel", -1)),
					"id": String(step.get("id", "")), "running": running,
					"pitch": pitch, "break": breaks, "cap": cap})
			t += gap * (BREAK_GAP if breaks else 1.0) * scale
			gap = maxf(GAP_FLOOR, gap * GAP_DECAY)
	var chain_end: float = t
	var count_seconds: float = 0.0
	var pause: float = 0.0
	if tier > Tier.DEAD:
		var decades: float = log(maxf(float(payout), 1.0)) / log(10.0)
		count_seconds = clampf(COUNT_MIN + decades * COUNT_PER_DECADE,
				COUNT_MIN, COUNT_MAX) * scale
		pause = maxf(PAUSE * scale * (0.5 if tier == Tier.SCRAPING else 1.0),
				PAUSE_FLOOR)
	var pause_at: float = chain_end + count_seconds
	var total_at: float = pause_at + pause
	return {
		"tier": tier,
		"beats": beats,
		"chain_end": chain_end,
		"count_seconds": count_seconds,
		"pause_at": pause_at,
		"pause": pause,
		"total_at": total_at,
		"end": total_at,
	}


## The pitch multiplier for a rung of the ladder.
static func pitch_scale(semitones: int) -> float:
	return pow(2.0, float(clampi(semitones, 0, LADDER_CAP)) / 12.0)
