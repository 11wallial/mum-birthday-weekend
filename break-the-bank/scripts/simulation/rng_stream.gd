## A named, deterministic random stream derived from a run's master seed.
##
## Every consumer (reels, shop rolls, event rolls) draws from its own stream, so
## adding a die roll in one system can never shift the numbers another system
## sees. That is what makes a recorded seed replay identically after a balance
## change touches an unrelated subsystem.
class_name RngStream
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _name: StringName = &""
var _master_seed: int = 0
## Number of draws taken. Recorded in telemetry to spot desynced replays.
var draws: int = 0


func _init(master_seed: int, stream_name: StringName) -> void:
	_master_seed = master_seed
	_name = stream_name
	_rng.seed = derive_seed(master_seed, stream_name)


## FNV-1a over the stream name, mixed with the master seed. Platform independent:
## it touches only integer arithmetic, never [method String.hash].
static func derive_seed(master_seed: int, stream_name: StringName) -> int:
	var h: int = 0x100000001B3
	var text: String = String(stream_name)
	for i: int in text.length():
		h = (h ^ text.unicode_at(i)) * 0x100000001B3
		h = h & 0x7FFFFFFFFFFFFFFF
	h = h ^ master_seed
	return h & 0x7FFFFFFFFFFFFFFF


## Returns an integer in [param from]..[param to] inclusive.
##
## Deliberately not named [code]randi_range[/code]: an unqualified call to a
## method sharing a @GlobalScope utility's name binds to the global, so an
## internal caller would silently draw from Godot's unseeded global RNG instead
## of this stream. Every draw here must go through one seeded generator.
func next_int(from: int, to: int) -> int:
	draws += 1
	return _rng.randi_range(from, to)


## Runs [param draw] against this stream and puts the stream back exactly
## where it was: a look at what is coming that moves nothing. The peek chit.
func peek(draw: Callable) -> Variant:
	var saved_state: int = _rng.state
	var saved_draws: int = draws
	var out: Variant = draw.call()
	_rng.state = saved_state
	draws = saved_draws
	return out


## Returns a float in 0.0..1.0. Named to avoid the @GlobalScope [code]randf[/code],
## for the same reason as [method next_int].
func next_float() -> float:
	draws += 1
	return _rng.randf()


## Picks an index from [param weights]. Returns -1 when every weight is zero.
func weighted_index(weights: PackedInt32Array) -> int:
	var total: int = 0
	for w: int in weights:
		total += maxi(w, 0)
	if total <= 0:
		return -1
	var roll: int = next_int(1, total)
	var running: int = 0
	for i: int in weights.size():
		running += maxi(weights[i], 0)
		if roll <= running:
			return i
	return weights.size() - 1


## A fresh stream with the same master seed, for replaying one subsystem.
func fork(suffix: StringName) -> RngStream:
	return RngStream.new(_master_seed, StringName(String(_name) + "/" + String(suffix)))


func get_stream_name() -> StringName:
	return _name
