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
