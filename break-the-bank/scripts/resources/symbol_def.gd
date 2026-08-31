## Definition of a single reel symbol.
##
## Pure data. Loaded once at run start and never mutated by the simulation —
## per-run modifications live on [RunState] so that a batch of Monte Carlo runs
## can share one immutable content set.
class_name SymbolDef
extends Resource

## Stable identifier used by artifacts, telemetry and save data.
@export var id: StringName = &""
@export var display_name: String = ""
## Base credits paid when this symbol lands in any slot.
@export var base_value: int = 0
## Relative draw weight on a stock reel. Higher is more common.
@export var base_weight: int = 10
## Symbols with the same non-empty family count as a match for patterns.
@export var family: StringName = &""
## Matches every family when evaluating patterns.
@export var is_wild: bool = false
## Pays nothing and suppresses the line multiplier when it lands.
@export var is_curse: bool = false
## Short token painted on the reel face. Two or three characters: a reel is
## ~0.3m wide, and an id like "double_bar" is metres long at readable sizes.
@export var glyph: String = "?"
## Tint for the glyph and for this symbol's effects in the 3D layer.
@export var color: Color = Color.WHITE


func matches(other: SymbolDef) -> bool:
	if other == null:
		return false
	if is_wild or other.is_wild:
		return true
	if family == &"" or other.family == &"":
		return id == other.id
	return family == other.family
