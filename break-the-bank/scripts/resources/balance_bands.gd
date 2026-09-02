## The bands a balance batch has to land inside for a content merge to pass.
##
## Guardrails, not a balance spec. Each bound is the loosest value that still
## says "this is the game we shipped": the lab's numbers are the spec and they
## live in its reports, while these are the alarm thresholds around them — kept
## as a resource so a rebalance can move the alarm without touching the tool.
class_name BalanceBands
extends Resource

## Win rate of the whole batch, inclusive. The target is 15–20%; the band is
## wider than the target so a seed's worth of variance cannot trip it.
@export var win_rate_min: float = 0.12
@export var win_rate_max: float = 0.28
## Share of runs that die on the first floor. Past this the opening ante is the
## game rather than the run.
@export var floor_one_deaths_max: float = 0.15
## Share of the floor deaths any one floor may hold. A wall is one floor doing
## most of the killing, and a wall is what the floor 5 spike was.
@export var single_floor_share_max: float = 0.45
## Share of runs that clear every floor and lose to the debt. The debt has to
## be a live threat, and it must not be the only one.
@export var debt_loss_min: float = 0.05
@export var debt_loss_max: float = 0.40
## Share of runs that miss a vig payment at least once.
@export var default_rate_max: float = 0.20
## A run that spins this often has stopped ending.
@export var spins_per_run_max: int = 1000
## Entries the lab may flag as anomalies before the batch fails. Zero: every
## artifact the lab calls broken is a human's decision, never a nightly's.
@export var anomalies_max: int = 0
