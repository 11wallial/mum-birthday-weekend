## How the floor is running tonight.
##
## Seven floors in a fixed order are memorised by the tenth hour, and the
## roadmap's cheapest answer to that is variants: the same floor, found in
## a different state. A skin is not a new system and not one of the House's
## people — it is the room's own condition, drawn by the seed as the floor
## opens, announced with it, and torn up when it closes.
##
## Everything a skin can do is a number the engine already understood: the
## allowance, the ante, the stipend, what the reels carry, what the floor
## pays, and whether the House could spare anybody for it. No new
## vocabulary, so no new place for a rule to hide.
class_name FloorSkinDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## One line, in the House's register, for the floor's opening.
@export_multiline var line: String = ""
## Floor indices this can be found on. Empty means any floor with skins.
@export var floors: Array[int] = []

@export_group("What it does to the floor")
## Spins added to the allowance, or taken off it.
@export var spins_delta: int = 0
## Percent on the ante, either way.
@export var ante_percent: float = 0.0
## Chips added to the stipend at the close.
@export var chips_delta: int = 0
## Every payout on the floor, scaled.
@export var payout_scale: float = 1.0
## Draw weights the room itself puts on the reel, by symbol id or family.
@export var weight_shifts: Dictionary = {}
## The House had nobody to send: no boss on this floor.
@export var no_boss: bool = false
