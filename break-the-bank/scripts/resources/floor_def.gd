## Definition of one floor of the casino: its ante, its pacing and its flavour.
class_name FloorDef
extends Resource

@export var index: int = 1
@export var display_name: String = ""
@export_multiline var description: String = ""
## Credits that must be banked before the floor's spins run out.
@export var ante: int = 20
## Spins allowed on this floor before the ante is settled.
@export var spins: int = 8
## Interest charged on outstanding debt when the floor is cleared, as a percent.
@export var debt_interest_percent: float = 10.0
## Artifacts offered in the shop after the floor is cleared.
@export var shop_slots: int = 3
## Multiplier applied to every payout earned on this floor.
@export var payout_scale: float = 1.0
## Environment preset used by the 3D presentation layer.
@export var environment_id: StringName = &"basement"
## Systems this floor hands the player, by [Systems] name. Granted when the
## floor begins, and never taken back: a floor is a new verb, not a new number.
@export var grants: Array[StringName] = []
