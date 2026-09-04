## One cue in the audio manifest.
##
## The manifest is the contract between design and sourcing: it names the file a
## sourced asset must land at, the length and tone it has to hit, and how the
## engine is allowed to vary it. A cue with no file on disk still plays — the
## director synthesises a placeholder from the fallback fields — so the manifest
## can be fully populated long before the assets are.
class_name SoundDef
extends Resource

enum Category {
	UI,
	MECHANICAL,
	LOGIC,
	AMBIENCE,
	## The score. Appended, because the value is written into the manifest:
	## a cue on the Music bus that is neither a sting nor a room.
	MUSIC,
}

## Shape used when synthesising a placeholder for a missing file.
enum Fallback {
	## Filtered noise burst: clicks, ticks, chip and card handling.
	CLICK,
	## Decaying tone with harmonics: chimes, stingers, confirmations.
	TONE,
	## Rising pair of tones: fanfares and positive resolutions.
	RISE,
	## Falling pair of tones: failures, denials, deductions.
	FALL,
	## Low sustained drone: room hum and machine idle loops.
	DRONE,
	## Slow amplitude-modulated tone: sirens and alarms.
	SIREN,
	## Pressurised air: a hiss that opens, falls in pitch and shuts with a thud.
	## The handle, and anything else driven by a cylinder.
	PNEUMATIC,
	## Two hits a beat apart — a bright strike, then a low damped body. The
	## cha-chunk of a reel locking, which one click can never be.
	CLACK,
	## Inharmonic partials with staggered decays, the way a struck bell rings.
	## A plain harmonic tone reads as a test signal; a bell reads as a payout.
	BELL,
	## A scatter of short metallic pings at irregular times: coins arriving.
	COINS,
	## Machinery turning: pseudo-periodic rumble with a tick every stroke.
	RATCHET,
	## A sustained vent of steam: noise through a filter that opens, holds,
	## and closes, distinct from PNEUMATIC's single stroke.
	STEAM,
	## An electric arc: gated buzz with snap transients, for the charge cable.
	ZAP,
	## A motor under load: a low hum whose whir rises as it comes up to speed.
	## The drive turning the drums; loops.
	MOTOR,
	## Gears meshing badly: broadband grind chopped at tooth rate over a buzz.
	GRIND,
	## A dot-matrix head: bursts of pin clicks at line rate, paper feed under.
	PRINTER,
	## Paper torn off a spool: a noise burst that rises and frays.
	TEAR,
	## Coins on concrete: a scatter of pings over a floor's dead thud.
	CLATTER,
	## A stack of paper landing: low, damped, no ring.
	THUD,
	## Leather on a grip: a short, wobbling squeak.
	SQUEAK,
	## A live tube: mains hum, its harmonics, and the flyback whine over it.
	HUM,
	## A Nixie cathode swapping: one metallic tink with a glassy ring.
	TINK,
	## A gas-discharge transformer: hundred-hertz buzz with flicker pops.
	BUZZ,
	## One drop into a puddle: a falling blip and a splash.
	DRIP,
	## A structure shifting: a low, resonant metallic groan.
	GROAN,
	## A rising analogue swell: detuned saws climbing with vibrato.
	SWELL,
	## A sub-bass drop: a sine falling an octave and a half.
	DROP,
	## An alarm: a hard tone gated four times a second.
	ALARM,
	## A tactile switch with a copper contact zap behind it.
	SWITCH,
	## A tannoy keying on: static, a hum, and the mumble of a voice.
	CRACKLE,
	## Wind through an iron vent: slow, filtered noise breathing.
	WIND,
}

@export var id: StringName = &""
## Path under assets/audio/, e.g. "ui/ui_hover.wav". Sourced assets land here.
@export var file_name: String = ""
@export var category: Category = Category.UI
## Bus to route to: UI, SFX, Ambience or Music.
@export var bus: StringName = &"SFX"
## Target length in milliseconds, as (min, max). Sourcing brief, not enforced —
## a cue outside it is flagged by the manifest test, not rejected at runtime.
@export var duration_ms: Vector2i = Vector2i(80, 200)
## What the cue should sound like, for whoever sources or edits it.
@export_multiline var frequency_notes: String = ""

## Playback pitch range. Applied per trigger to kill repetition fatigue.
@export var pitch_jitter: Vector2 = Vector2(0.95, 1.05)
## Playback gain range in dB, added to [member base_volume_db] per trigger.
@export var volume_jitter_db: Vector2 = Vector2(-1.5, 1.5)
@export_range(-40.0, 12.0) var base_volume_db: float = 0.0

## Play through an AudioStreamPlayer3D anchored in the room rather than flat.
@export var positional: bool = false
@export var loops: bool = false
## Simultaneous voices this cue may hold. Beyond it, the oldest is stolen.
@export_range(1, 16) var max_voices: int = 3
## Higher priority steals a voice from lower when the global pool is full.
@export_range(0, 10) var priority: int = 5
## Duck the music bus by this many dB while the cue plays. Zero disables.
@export_range(0.0, 24.0) var duck_music_db: float = 0.0

@export var fallback: Fallback = Fallback.CLICK
## Base frequency for the synthesised placeholder, in Hz.
@export var fallback_hz: float = 440.0


## Midpoint of the target duration, in seconds. Used to size placeholders.
func nominal_seconds() -> float:
	return float(duration_ms.x + duration_ms.y) * 0.5 / 1000.0


func absolute_path() -> String:
	return "res://assets/audio/%s" % file_name


## True when a sourced asset exists; false means the placeholder is in use.
func is_sourced() -> bool:
	return ResourceLoader.exists(absolute_path())
