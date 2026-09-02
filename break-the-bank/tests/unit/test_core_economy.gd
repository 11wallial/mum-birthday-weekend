extends GdUnitTestSuite

var _config: BalanceConfig
var _bus: EffectBus
var _economy: CoreEconomy


func before_test() -> void:
	_config = TestFixtures.config()
	_config.starting_cash = 100
	_config.starting_debt = 50
	_bus = EffectBus.new()
	_bus.recording = true
	_economy = CoreEconomy.new(_config, _bus)


func test_starts_from_the_config() -> void:
	assert_int(_economy.cash).is_equal(100)
	assert_int(_economy.debt).is_equal(50)


func test_credit_and_debit_track_lifetime_totals() -> void:
	_economy.credit(30, &"payout")
	_economy.debit(10, &"spin_cost")
	assert_int(_economy.cash).is_equal(120)
	assert_int(_economy.lifetime_earned).is_equal(30)
	assert_int(_economy.lifetime_spent).is_equal(10)


func test_non_positive_amounts_are_ignored() -> void:
	_economy.credit(0, &"payout")
	_economy.debit(-5, &"spin_cost")
	assert_int(_economy.cash).is_equal(100)
	assert_int(_bus.count_of(EffectBus.Event.CASH_CHANGED)).is_equal(0)


func test_an_unaffordable_ante_is_not_charged() -> void:
	assert_bool(_economy.settle_ante(500)).is_false()
	assert_int(_economy.cash).is_equal(100)


func test_a_settled_ante_leaves_the_ledger_balanced() -> void:
	assert_bool(_economy.settle_ante(40)).is_true()
	assert_int(_economy.cash).is_equal(60)


func test_debt_interest_rounds_up_and_compounds() -> void:
	assert_int(_economy.accrue_debt_interest(10.0)).is_equal(5)
	assert_int(_economy.debt).is_equal(55)
	assert_int(_economy.accrue_debt_interest(10.0)).is_equal(6)
	assert_int(_economy.debt).is_equal(61)


func test_interest_respects_its_cap() -> void:
	assert_int(_economy.pay_interest(50.0, 15.0)).is_equal(15)
	assert_int(_economy.cash).is_equal(115)


func test_interest_on_an_empty_purse_pays_nothing() -> void:
	_economy.debit(100, &"spin_cost")
	assert_int(_economy.pay_interest(10.0, 0.0)).is_equal(0)


func test_servicing_debt_is_interest_only() -> void:
	# The vig never touches the principal — that is what makes buying debt down
	# a decision rather than a formality.
	assert_int(_economy.service_debt(20.0, 50.0)).is_equal(10)
	assert_int(_economy.cash).is_equal(90)
	assert_int(_economy.debt).is_equal(50)
	assert_int(_economy.debt_serviced).is_equal(10)


func test_a_missed_payment_compounds_with_a_penalty() -> void:
	_economy.debit(96, &"spin_cost")
	# 20% of 50 is due, only 4 cash on hand: the 6 short returns as 9 of debt.
	assert_int(_economy.service_debt(20.0, 50.0)).is_equal(4)
	assert_int(_economy.cash).is_equal(0)
	assert_int(_economy.debt).is_equal(59)
	assert_int(_economy.defaults).is_equal(1)


func test_servicing_nothing_costs_nothing() -> void:
	_economy.debt = 0
	assert_int(_economy.service_debt(20.0, 50.0)).is_equal(0)
	assert_int(_economy.cash).is_equal(100)


func test_forgiving_debt_never_goes_below_zero() -> void:
	assert_int(_economy.forgive_debt(100.0)).is_equal(50)
	assert_int(_economy.debt).is_equal(0)
	assert_int(_economy.forgive_debt(50.0)).is_equal(0)


func test_chips_are_a_purse_of_their_own() -> void:
	# The House's scrip: earned, spent, never below zero, never cash.
	_economy.credit_chips(6, &"floor")
	_economy.credit_chips(2, &"settle")
	assert_int(_economy.chips).is_equal(8)
	assert_int(_economy.lifetime_chips).is_equal(8)
	assert_int(_economy.chips_from_settling).is_equal(2)
	assert_int(_economy.cash).is_equal(100)
	_economy.debit_chips(5, &"artifact")
	assert_int(_economy.chips).is_equal(3)
	assert_bool(_economy.can_afford_chips(4)).is_false()
	_economy.debit_chips(9, &"artifact")
	assert_int(_economy.chips).is_equal(0)
	assert_int(_bus.count_of(EffectBus.Event.CHIPS_CHANGED)).is_equal(4)


func test_chip_interest_pays_per_held_and_caps() -> void:
	_economy.credit_chips(12, &"floor")
	assert_int(_economy.accrue_chip_interest(5, 3)).is_equal(2)
	assert_int(_economy.chips).is_equal(14)
	_economy.credit_chips(30, &"floor")
	assert_int(_economy.accrue_chip_interest(5, 3)).is_equal(3)
	assert_int(_economy.chips_from_interest).is_equal(5)
	_economy.debit_chips(99, &"artifact")
	assert_int(_economy.accrue_chip_interest(5, 3)).is_equal(0)


func test_a_chip_is_priced_off_the_ante() -> void:
	_config.chip_credit_rate_percent = 3.0
	assert_int(CoreEconomy.chip_value(_config, 1000)).is_equal(30)
	assert_int(CoreEconomy.chip_value(_config, 10)).is_equal(1)
