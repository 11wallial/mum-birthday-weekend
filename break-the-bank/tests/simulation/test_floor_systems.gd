extends GdUnitTestSuite

## One suite per verb the floors hand over. Each of these is a floor's whole
## reason to exist, so each gets pinned down on its own rather than being
## inferred from a run that happens to pass through it.

var _engine: SimEngine
var _state: RunState
var _content: ContentDB


func before_test() -> void:
	_content = TestFixtures.content_with_shop()
	var everything: Array[StringName] = [
		Systems.HOLD, Systems.MARKET, Systems.STAKE, Systems.GAMBLE,
		Systems.VAULT, Systems.CONTRACTS, Systems.EXPANSION, Systems.HEAT,
	]
	_content.floors.assign([
		TestFixtures.floor_granting(1, 20, 6, everything),
		TestFixtures.floor_granting(2, 40, 6, []),
	])
	for floor_def: FloorDef in _content.floors:
		floor_def.shop_slots = 2
	var bus: EffectBus = EffectBus.new()
	bus.recording = true
	_engine = SimEngine.new(_content, bus)
	_engine.shop_policy = Callable()
	_engine.vault_policy = Callable()
	_engine.works_policy = Callable()
	_engine.launder_policy = Callable()
	_engine.contract_policy = Callable()
	_state = _engine.start_run(3)


func _reach_shop() -> void:
	var guard: int = 0
	while _state.phase != RunState.Phase.SHOPPING and not _state.is_over() and guard < 80:
		_engine.step(_state)
		guard += 1


# --- Floor 2: the market ----------------------------------------------------

func test_a_reroll_costs_more_every_time_it_is_bought() -> void:
	_reach_shop()
	_state.economy.cash = 5000
	var first: int = _state.reroll_price()
	assert_bool(_engine.reroll_shop(_state)).is_true()
	assert_int(_state.reroll_price()).is_greater(first)
	assert_int(_state.economy.cash).is_equal(5000 - first)


func test_selling_back_undoes_what_the_artifact_changed() -> void:
	_reach_shop()
	var reel_bender: ArtifactDef = TestFixtures.artifact(
			&"reel_bender", ArtifactDef.Effect.WEIGHT_SHIFT, 9.0)
	reel_bender.symbol_filter = &"seven"
	_state.acquire(reel_bender)
	var loaded: float = Probability.symbol_chance(_state.reel(), &"seven")

	assert_int(_engine.sell(_state, _state.owned.size() - 1)).is_greater(0)
	assert_bool(_state.owns(&"reel_bender")).is_false()
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_less(loaded)


func test_the_slate_takes_the_artifact_now_and_the_debt_later() -> void:
	_reach_shop()
	_state.economy.cash = 0
	var wanted: StringName = _state.shop_offers[0].id
	var price: int = _state.shop_prices[0]
	var debt: int = _state.economy.debt

	assert_bool(_engine.buy_on_slate(_state, 0)).is_true()
	assert_bool(_state.owns(wanted)).is_true()
	assert_int(_state.economy.cash).is_equal(0)
	# The markup is the whole point: the slate is never the cheap way to buy.
	assert_int(_state.economy.debt).is_greater(debt + price)


func test_the_market_is_shut_before_the_floor_that_opens_it() -> void:
	_reach_shop()
	_state.systems.erase(Systems.MARKET)
	_state.economy.cash = 5000
	assert_bool(_engine.reroll_shop(_state)).is_false()
	assert_bool(_engine.buy_on_slate(_state, 0)).is_false()
	assert_int(_engine.sell(_state, 0)).is_equal(0)


# --- Floor 4: the vault -----------------------------------------------------

func test_the_vault_holds_cash_that_cannot_settle_an_ante() -> void:
	_state.economy.cash = 100
	assert_int(_engine.deposit(_state, 90)).is_equal(90)
	assert_int(_state.economy.cash).is_equal(10)
	assert_int(_state.economy.vault).is_equal(90)
	# The ante is settled out of the purse, and the purse is nearly empty.
	assert_bool(_state.economy.settle_ante(50)).is_false()


func test_breaking_the_vault_mid_floor_costs_a_share_of_it() -> void:
	_state.economy.cash = 100
	_engine.deposit(_state, 100)
	var back: int = _engine.withdraw(_state, 100)
	assert_int(back).is_less(100)
	assert_int(_state.economy.vault).is_equal(0)


func test_the_vault_opens_whole_between_floors() -> void:
	_state.economy.cash = 100
	_engine.deposit(_state, 100)
	_state.phase = RunState.Phase.SHOPPING
	assert_int(_engine.withdraw(_state, 100)).is_equal(100)


func test_the_vault_pays_its_dividend_into_the_purse() -> void:
	_state.economy.vault = 200
	_state.economy.cash = 0
	assert_int(_state.economy.accrue_vault_interest(50.0)).is_equal(100)
	# The principal stays locked; only the income is spendable.
	assert_int(_state.economy.vault).is_equal(200)
	assert_int(_state.economy.cash).is_equal(100)


func test_a_reserve_is_collateral_the_machine_pays_more_on() -> void:
	var line: Array[SymbolDef] = [
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
	]
	var bare: int = ArtifactEngine.score_line(_state, line)
	_state.economy.vault = _content.floors[0].ante * 2
	assert_int(ArtifactEngine.score_line(_state, line)).is_greater(bare)
	# And never past the cap, however big the hoard gets.
	var capped: int = ArtifactEngine.score_line(_state, line)
	_state.economy.vault *= 50
	assert_int(ArtifactEngine.score_line(_state, line)).is_equal(capped)


# --- Floor 5: contracts -----------------------------------------------------

func _sign(boon: ContractDef.Clause, magnitude: float,
		toll: ContractDef.Clause = ContractDef.Clause.NONE,
		toll_magnitude: float = 0.0) -> void:
	var contract: ContractDef = ContractDef.new()
	contract.id = &"test_terms"
	contract.display_name = "Test Terms"
	contract.boon = boon
	contract.boon_magnitude = magnitude
	contract.toll = toll
	contract.toll_magnitude = toll_magnitude
	_state.set_contract(contract)


func test_a_contract_changes_the_floors_spin_allowance() -> void:
	_sign(ContractDef.Clause.SPINS, 4.0)
	_engine.begin_floor(_state)
	assert_int(_state.spins_remaining).is_equal(_content.floors[0].spins + 4)


func test_a_contract_takes_its_share_off_the_end_of_the_payout() -> void:
	var line: Array[SymbolDef] = [
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
	]
	var full: int = ArtifactEngine.score_line(_state, line)
	_sign(ContractDef.Clause.NONE, 0.0, ContractDef.Clause.PAYOUT_PERCENT, -50.0)
	assert_int(ArtifactEngine.score_line(_state, line)).is_equal(full / 2)


func test_a_contract_can_put_the_skulls_on_the_payroll() -> void:
	var line: Array[SymbolDef] = [
		_content.symbol_by_id(&"skull"),
		_content.symbol_by_id(&"cherry"),
		_content.symbol_by_id(&"seven"),
	]
	var bare: int = ArtifactEngine.score_line(_state, line)
	_sign(ContractDef.Clause.CURSE_PAYS, 8.0)
	assert_int(ArtifactEngine.score_line(_state, line)).is_greater(bare)


func test_a_contract_shifts_the_reel_and_tearing_it_up_puts_it_back() -> void:
	var bare: float = Probability.symbol_chance(_state.reel(), &"seven")
	var contract: ContractDef = ContractDef.new()
	contract.id = &"loose"
	contract.boon = ContractDef.Clause.WEIGHT
	contract.boon_magnitude = 20.0
	contract.boon_symbol = &"seven"
	_state.set_contract(contract)
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_greater(bare)

	_state.set_contract(null)
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_equal(bare)


func test_the_back_office_stands_between_the_draft_and_the_stairs() -> void:
	_content.contracts.assign([_stock_contract(&"a"), _stock_contract(&"b")])
	_reach_shop()
	_engine.leave_shop(_state)
	assert_int(_state.phase).is_equal(RunState.Phase.SIGNING)
	assert_array(_state.contract_offers).is_not_empty()

	assert_bool(_engine.sign_contract(_state, 0)).is_true()
	assert_int(_state.phase).is_equal(RunState.Phase.SPINNING)
	assert_object(_state.contract).is_not_null()


func _stock_contract(id: StringName) -> ContractDef:
	var contract: ContractDef = ContractDef.new()
	contract.id = id
	contract.display_name = String(id)
	contract.min_floor = 1
	contract.boon = ContractDef.Clause.SPINS
	contract.boon_magnitude = 1.0
	return contract


# --- Floor 6: the works -----------------------------------------------------

func test_a_bought_reel_widens_the_machine_for_good() -> void:
	_reach_shop()
	_state.economy.cash = 100000
	var reels: int = _state.machine_reels()
	assert_bool(_engine.buy_reel(_state)).is_true()
	assert_int(_state.machine_reels()).is_equal(reels + 1)

	_engine.leave_shop(_state)
	_engine.spin(_state)
	assert_int(_state.board.reel_count()).is_equal(reels + 1)


func test_a_bought_row_makes_the_band_pay() -> void:
	_state.extra_rows = 0
	var seven: SymbolDef = _content.symbol_by_id(&"seven")
	var cherry: SymbolDef = _content.symbol_by_id(&"cherry")
	for i: int in 3:
		_state.board.set_column(i, seven, cherry, cherry)
	_engine._resolve_board(_state, false)
	var payline_only: int = _state.board.payout

	_state.extra_rows = 1
	_engine._resolve_board(_state, false)
	assert_int(_state.board.payout).is_greater(payline_only)


func test_the_works_stop_where_the_machine_stops() -> void:
	_reach_shop()
	_state.economy.cash = 100000
	var guard: int = 0
	while _engine.buy_reel(_state) and guard < 10:
		guard += 1
	assert_int(_state.extra_reels).is_equal(_state.config.max_extra_reels)


# --- Floor 7: the count -----------------------------------------------------

func test_winning_loudly_raises_the_count_and_quiet_spins_lower_it() -> void:
	assert_float(_state.heat).is_equal(0.0)
	HeatEngine.observe(_state, 200, 5.0)
	var loud: float = _state.heat
	assert_float(loud).is_greater(0.0)
	HeatEngine.observe(_state, 0, 5.0)
	assert_float(_state.heat).is_less(loud)


func test_the_skim_comes_off_every_payout() -> void:
	var line: Array[SymbolDef] = [
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
		_content.symbol_by_id(&"seven"),
	]
	var calm: int = ArtifactEngine.score_line(_state, line)
	_state.heat = _state.config.heat_skim_at + 1.0
	assert_int(ArtifactEngine.score_line(_state, line)).is_less(calm)


func test_the_cold_deck_takes_the_good_symbols_off_the_reel() -> void:
	var warm: float = Probability.symbol_chance(_state.reel(), &"seven")
	_state.heat = _state.config.heat_cold_at + 1.0
	_state.mark_reel_dirty()
	assert_float(Probability.symbol_chance(_state.reel(), &"seven")).is_less(warm)


func test_the_pit_boss_raises_the_ante_and_leaves_the_count_short_of_itself() -> void:
	_state.heat = _state.config.heat_boss_at - 1.0
	HeatEngine.observe(_state, 10000, 5.0)
	assert_float(_state.heat_ante_percent).is_greater(0.0)
	assert_float(_state.heat).is_less(_state.config.heat_boss_at)


func test_a_word_with_someone_costs_cash_and_buys_the_count_down() -> void:
	_state.heat = 80.0
	_state.economy.cash = 10000
	var price: int = HeatEngine.launder_price(_state)
	assert_bool(_engine.launder(_state)).is_true()
	assert_float(_state.heat).is_equal(80.0 - _state.config.launder_relief)
	assert_int(_state.economy.cash).is_equal(10000 - price)


func test_the_house_is_not_counting_before_the_floor_that_starts_it() -> void:
	_state.systems.erase(Systems.HEAT)
	_state.heat = 90.0
	assert_float(HeatEngine.heat_of(_state)).is_equal(0.0)
	assert_int(HeatEngine.current(_state)).is_equal(HeatEngine.Measure.NONE)
	assert_bool(_engine.launder(_state)).is_false()
