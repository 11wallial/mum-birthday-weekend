## Turning seeds into something people can type, say and share.
##
## The simulation already replays a run exactly from its seed, so a shared seed
## is a shared run. What was missing was a form a person can pass on: 64-bit
## integers are not that. Codes here are five syllables from a fixed alphabet —
## SOLAR-MIRTH-CANDLE-OX-DRIFT — which survive being read aloud.
class_name SeedBook
extends RefCounted

## Deliberately unambiguous when spoken: no rhymes, no homophones, no plurals.
## Typed as Array rather than PackedStringArray because a packed array
## constructor is not a constant expression and would fail to parse.
const WORDS: Array = [
	"SOLAR", "MIRTH", "CANDLE", "OX", "DRIFT", "VELVET", "PLUM", "GRAVEL",
	"NEON", "HUSK", "TALON", "MARBLE", "CINDER", "OTTER", "PRISM", "LEDGER",
	"VAULT", "TILT", "COBALT", "RUIN", "SPARROW", "GILT", "MOTH", "QUARRY",
	"HOLLOW", "BRASS", "SALT", "WREN", "ORBIT", "FABLE", "CHALK", "IVORY",
]
## Total seed space addressed by a five-word code: 32^5.
const SEED_SPACE: int = 33554432
const CODE_WORDS: int = 5


## Encodes a seed as a shareable code. Seeds outside [constant SEED_SPACE] wrap,
## so decoding a code always yields a seed inside it.
static func to_code(seed_value: int) -> String:
	var value: int = posmod(seed_value, SEED_SPACE)
	var parts: PackedStringArray = PackedStringArray()
	for i: int in CODE_WORDS:
		parts.append(String(WORDS[value % WORDS.size()]))
		value /= WORDS.size()
	return "-".join(parts)


## Decodes a code back to its seed. Returns -1 when the code is not one of ours.
static func from_code(code: String) -> int:
	var parts: PackedStringArray = code.strip_edges().to_upper().split("-", false)
	if parts.size() != CODE_WORDS:
		return -1
	var value: int = 0
	for i: int in range(parts.size() - 1, -1, -1):
		var index: int = WORDS.find(parts[i].strip_edges())
		if index < 0:
			return -1
		value = value * WORDS.size() + index
	return value


## Reads whatever the player typed: a code, a plain number, or free text used as
## a phrase seed. Returns -1 only for empty input.
static func parse(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return -1
	var decoded: int = from_code(trimmed)
	if decoded >= 0:
		return decoded
	if trimmed.is_valid_int():
		return absi(trimmed.to_int())
	# Anything else is a phrase: hash it, so "mum's birthday" is a run you can
	# tell someone about without knowing what a seed is.
	return RngStream.derive_seed(0, StringName(trimmed.to_lower()))


## The seed for a given UTC date, as YYYY-MM-DD. Everyone gets the same run.
static func daily_seed(date: String) -> int:
	return RngStream.derive_seed(0, StringName("daily/" + date)) % SEED_SPACE


## Today's challenge seed, in UTC so the day turns over at the same instant
## everywhere rather than at each player's local midnight.
static func today_seed() -> int:
	return daily_seed(today_key())


static func today_key() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [int(now["year"]), int(now["month"]), int(now["day"])]
