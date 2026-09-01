## Cash, debt and ante settlement.
##
## The economy owns every credit in the run. Nothing else mutates cash directly:
## payouts, costs and interest all pass through here so the ledger stays the
## single source of truth for telemetry.
class_name CoreEconomy
extends RefCounted

var cash: int = 0
var debt: int = 0
## Credits locked in the vault. Earns interest and cannot settle an ante: this
## is the only money in the game that is not the same as the rest of the money.
var vault: int = 0
## Interest the vault has paid across the run. Telemetry only.
var vault_interest: int = 0
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


## Locks [param amount] away. Returns the credits actually moved.
func deposit(amount: int) -> int:
	var moved: int = clampi(amount, 0, maxi(cash, 0))
	if moved <= 0:
		return 0
	debit(moved, &"deposit")
	vault += moved
	return moved


## Releases [param amount] from the vault, keeping [param fee_percent] of it if
## the vault is being broken into rather than opened. Returns what reached the
## purse, which is what the player actually cares about.
func withdraw(amount: int, fee_percent: float = 0.0) -> int:
	var moved: int = clampi(amount, 0, maxi(vault, 0))
	if moved <= 0:
		return 0
	vault -= moved
	var fee: int = int(floor(float(moved) * maxf(fee_percent, 0.0) / 100.0))
	var reaching: int = maxi(0, moved - fee)
	credit(reaching, &"withdrawal")
	return reaching


## Pays the vault's dividend into the purse, leaving the principal where it is.
## Returns the credits paid.
##
## A vault that compounded into itself was a number that grew where the player
## could not reach it, on a floor where they were usually broke. Paying out
## instead makes a deposit what it should be: cash now, traded for income on
## every floor that follows, which is a decision whose answer changes as the
## floors run out.
func accrue_vault_interest(percent: float) -> int:
	if vault <= 0 or percent <= 0.0:
		return 0
	var earned: int = int(floor(float(vault) * percent / 100.0))
	if earned <= 0:
		return 0
	credit(earned, &"vault_interest")
	vault_interest += earned
	return earned


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


## Shop price for [param artifact] on a floor whose ante is [param ante].
##
## The authored cost, inflated for the floors already cleared, is the floor the
## price never drops below; past that the price tracks the ante, so a draft on
## floor six costs a share of floor six's problem rather than a share of floor
## one's.
func price_of(artifact: ArtifactDef, config: BalanceConfig, floors_cleared: int,
		ante: int = 0) -> int:
	var inflation: float = 1.0 + (config.shop_inflation_percent / 100.0) * float(floors_cleared)
	var authored: int = maxi(1, int(round(float(artifact.cost) * inflation)))
	if ante <= 0 or config.shop_ante_divisor <= 0.0:
		return authored
	var against_ante: int = int(round(float(ante) * float(artifact.cost)
			/ config.shop_ante_divisor))
	return maxi(authored, against_ante)


func snapshot() -> Dictionary:
	return {
		"cash": cash,
		"debt": debt,
		"vault": vault,
		"vault_interest": vault_interest,
		"lifetime_earned": lifetime_earned,
		"lifetime_spent": lifetime_spent,
		"interest_earned": interest_earned,
		"debt_serviced": debt_serviced,
		"defaults": defaults,
	}
