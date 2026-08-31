## Cash, debt and ante settlement.
##
## The economy owns every credit in the run. Nothing else mutates cash directly:
## payouts, costs and interest all pass through here so the ledger stays the
## single source of truth for telemetry.
class_name CoreEconomy
extends RefCounted

var cash: int = 0
var debt: int = 0
## Total credits ever earned, including credits later spent. Telemetry only.
var lifetime_earned: int = 0
var lifetime_spent: int = 0
var interest_earned: int = 0
## Credits paid to service debt across the run. Telemetry only.
var debt_serviced: int = 0
## Times the player could not meet a service payment in full.
var defaults: int = 0

var _bus: EffectBus


func _init(config: BalanceConfig, bus: EffectBus) -> void:
	cash = config.starting_cash
	debt = config.starting_debt
	_bus = bus


## Adds credits. [param reason] is carried into telemetry.
func credit(amount: int, reason: StringName) -> void:
	if amount <= 0:
		return
	cash += amount
	lifetime_earned += amount
	_bus.emit_event(EffectBus.Event.CASH_CHANGED, {"delta": amount, "cash": cash, "reason": reason})


## Removes credits even when it takes the balance negative — callers decide
## whether a negative balance ends the run.
func debit(amount: int, reason: StringName) -> void:
	if amount <= 0:
		return
	cash -= amount
	lifetime_spent += amount
	_bus.emit_event(EffectBus.Event.CASH_CHANGED, {"delta": -amount, "cash": cash, "reason": reason})


func can_afford(amount: int) -> bool:
	return cash >= amount


## Settles a floor's ante. Returns true when the player survives.
func settle_ante(amount: int) -> bool:
	var paid: bool = cash >= amount
	if paid:
		debit(amount, &"ante")
	_bus.emit_event(EffectBus.Event.ANTE_SETTLED, {"ante": amount, "paid": paid, "cash": cash})
	return paid


## Charges the floor's debt service: interest only, so paying it never touches
## the principal. The principal comes down through DEBT_PAYDOWN artifacts or is
## settled in full at the end of the run — which is what makes buying down debt
## a real decision instead of a rounding error.
##
## A shortfall is added to the principal with a penalty on top, so a missed
## payment compounds into every floor that follows.
## Returns the credits actually paid.
func service_debt(service_percent: float, penalty_percent: float) -> int:
	if debt <= 0 or service_percent <= 0.0:
		return 0
	var due: int = int(ceil(float(debt) * service_percent / 100.0))
	var paid: int = mini(due, maxi(cash, 0))
	if paid > 0:
		debit(paid, &"debt_service")
		debt_serviced += paid
	var shortfall: int = due - paid
	if shortfall > 0:
		defaults += 1
		debt += shortfall + int(ceil(float(shortfall) * penalty_percent / 100.0))
	return paid


## Wipes [param percent] of the outstanding debt. Returns the credits cleared.
func forgive_debt(percent: float) -> int:
	if debt <= 0 or percent <= 0.0:
		return 0
	var wiped: int = mini(debt, int(ceil(float(debt) * percent / 100.0)))
	debt -= wiped
	return wiped


## Applies compounding interest to outstanding debt at the end of a floor.
func accrue_debt_interest(percent: float) -> int:
	if debt <= 0 or percent <= 0.0:
		return 0
	var charge: int = int(ceil(float(debt) * percent / 100.0))
	debt += charge
	return charge


## Pays interest on banked cash. [param cap] of zero or less means uncapped.
func pay_interest(percent: float, cap: float) -> int:
	if cash <= 0 or percent <= 0.0:
		return 0
	var amount: float = float(cash) * percent / 100.0
	if cap > 0.0:
		amount = minf(amount, cap)
	var payout: int = int(floor(amount))
	if payout <= 0:
		return 0
	credit(payout, &"interest")
	interest_earned += payout
	return payout


## Shop price for [param artifact] after inflation for cleared floors.
func price_of(artifact: ArtifactDef, config: BalanceConfig, floors_cleared: int) -> int:
	var inflation: float = 1.0 + (config.shop_inflation_percent / 100.0) * float(floors_cleared)
	return maxi(1, int(round(float(artifact.cost) * inflation)))


func snapshot() -> Dictionary:
	return {
		"cash": cash,
		"debt": debt,
		"lifetime_earned": lifetime_earned,
		"lifetime_spent": lifetime_spent,
		"interest_earned": interest_earned,
		"debt_serviced": debt_serviced,
		"defaults": defaults,
	}
