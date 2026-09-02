## Chooses what the House prints on the ledger for a run as it stands.
##
## Reads [RunState] and the memo resources, and nothing else. The choice is
## deterministic for a run — the same seed on the same floor in the same
## trouble reads the same memo — so a memo is part of the run the way the
## reels are, and a storyboard of it is repeatable.
class_name MemoBook
extends RefCounted

const MEMO_DIR: String = "res://resources/narrative/memos"

var memos: Array[MemoDef] = []


func load_all() -> void:
	memos.clear()
	var dir: DirAccess = DirAccess.open(MEMO_DIR)
	if dir == null:
		push_warning("MemoBook: missing %s" % MEMO_DIR)
		return
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres") and not clean.ends_with(".res"):
			continue
		var memo: MemoDef = load("%s/%s" % [MEMO_DIR, clean]) as MemoDef
		if memo != null:
			memos.append(memo)


## The memo for [param state], or an empty string when none fits.
##
## The most specific memo that fits is printed; among equals, the run's seed
## and floor pick one, so two memos written for the same moment both get read
## across runs without either being random within one.
func memo_for(state: RunState) -> String:
	var chosen: MemoDef = choose(state)
	return chosen.text if chosen != null else ""


func choose(state: RunState) -> MemoDef:
	if state == null:
		return null
	var floor_def: FloorDef = state.current_floor()
	var ante: int = floor_def.ante if floor_def != null else 0
	var ratio: float = float(state.economy.debt) / float(maxi(ante, 1))
	var measure: int = int(HeatEngine.current(state))
	var on_last: bool = (floor_def != null and not state.endless
			and state.floor_at(state.floor_index + 1) == null)
	var fitting: Array[MemoDef] = []
	var best: int = -1
	for memo: MemoDef in memos:
		if not _fits(memo, state.floor_index, ratio, measure, state.endless, on_last):
			continue
		var score: int = memo.specificity()
		if score > best:
			best = score
			fitting.clear()
		if score == best:
			fitting.append(memo)
	if fitting.is_empty():
		return null
	var pick: int = RngStream.derive_seed(state.seed_value,
			StringName("memo/%d" % state.floor_index)) % fitting.size()
	return fitting[pick]


static func _fits(memo: MemoDef, floor_index: int, ratio: float, measure: int,
		endless: bool, on_last: bool) -> bool:
	if memo.floor_min > 0 and floor_index < memo.floor_min:
		return false
	if memo.floor_max > 0 and floor_index > memo.floor_max:
		return false
	if memo.debt_ratio_min > 0.0 and ratio < memo.debt_ratio_min:
		return false
	if memo.debt_ratio_max > 0.0 and ratio > memo.debt_ratio_max:
		return false
	if memo.heat_min > 0 and measure < memo.heat_min:
		return false
	if memo.after_hours != endless:
		return false
	if memo.last_floor and not on_last:
		return false
	return true
