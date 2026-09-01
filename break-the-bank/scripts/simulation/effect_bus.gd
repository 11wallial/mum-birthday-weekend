## The one-way channel from the simulation to everything watching it.
##
## The simulation never calls into the presentation layer; it emits events here
## and keeps going. In a Monte Carlo batch the bus is muted, which reduces every
## emission to a boolean check so 100k runs never pay for signal dispatch.
class_name EffectBus
extends RefCounted

enum Event {
	RUN_STARTED,
	FLOOR_STARTED,
	SPIN_STARTED,
	SYMBOL_LANDED,
	PATTERN_MATCHED,
	## The board's value is known but not yet banked. This is what the machine
	## animates to; PAYOUT_CALCULATED means the credits actually moved.
	SPIN_RESOLVED,
	NUDGES_AWARDED,
	REEL_NUDGED,
	GAMBLE_OFFERED,
	GAMBLE_RESOLVED,
	PAYOUT_CALCULATED,
	ARTIFACT_TRIGGERED,
	CASH_CHANGED,
	ANTE_SETTLED,
	FLOOR_CLEARED,
	SHOP_OPENED,
	ARTIFACT_ACQUIRED,
	ARTIFACT_SOLD,
	SHOP_REROLLED,
	SLATE_SIGNED,
	SYSTEM_GRANTED,
	RUN_ENDED,
}

## Emitted for every simulation event. [param payload] is read-only for listeners.
signal event_emitted(kind: Event, payload: Dictionary)

## When true, nothing is dispatched or recorded. Set for batch simulation.
var muted: bool = false
## When true, events are appended to [member event_log] for assertions in tests.
var recording: bool = false
var event_log: Array[Dictionary] = []


## True when nothing is listening. Hot emitters check this before building a
## payload: a muted bus still costs a Dictionary allocation per call otherwise,
## and the spin path emits several per spin across millions of batch spins.
func is_live() -> bool:
	return not muted


func emit_event(kind: Event, payload: Dictionary = {}) -> void:
	if muted:
		return
	if recording:
		event_log.append({"kind": kind, "payload": payload})
	event_emitted.emit(kind, payload)


func clear_log() -> void:
	event_log.clear()


## Every recorded payload for one event kind, in order.
func events_of(kind: Event) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in event_log:
		if entry["kind"] == kind:
			out.append(entry["payload"])
	return out


func count_of(kind: Event) -> int:
	return events_of(kind).size()


static func event_name(kind: Event) -> String:
	return String(Event.keys()[kind])
