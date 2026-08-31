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


func test_shop_prices_inflate_per_cleared_floor() -> void:
	var artifact: ArtifactDef = TestFixtures.artifact(&"x", ArtifactDef.Effect.FLAT_BONUS, 1.0)
	artifact.cost = 10
	_config.shop_inflation_percent = 20.0
	assert_int(_economy.price_of(artifact, _config, 0)).is_equal(10)
	assert_int(_economy.price_of(artifact, _config, 2)).is_equal(14)
