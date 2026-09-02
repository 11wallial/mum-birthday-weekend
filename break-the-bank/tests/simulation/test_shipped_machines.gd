## The House's machines, held to their shape: every one loads, every one is
## opened by something or is the standard, and every one is a game — neither
## unwinnable nor free — when the lab plays it.
extends GdUnitTestSuite

const RUNS: int = 120

var _catalogue: MetaCatalogue


func before() -> void:
	_catalogue = MetaCatalogue.new()
	_catalogue.load_all()


func test_the_standard_machine_exists_and_changes_nothing() -> void:
	var standard: MachineDef = _catalogue.machine_by_id(&"standard")
	assert_object(standard).is_not_null()
	var options: RunOptions = standard.apply_to(RunOptions.new())
	assert_str(options.ruleset_key()).is_equal(RunOptions.new().ruleset_key())


func test_every_machine_has_a_name_a_line_and_a_way_in() -> void:
	assert_int(_catalogue.machines.size()).is_greater_equal(5)
	var seen: Dictionary = {}
	for machine: MachineDef in _catalogue.machines:
		assert_bool(seen.has(machine.id)).override_failure_message(
				"%s is defined twice" % machine.id).is_false()
		seen[machine.id] = true
		assert_str(machine.display_name).is_not_empty()
		assert_str(machine.brief).is_not_empty()
		if machine.id == &"standard":
			continue
		var opened: bool = false
		for unlock: UnlockDef in _catalogue.unlocks:
			if unlock.kind == UnlockDef.Kind.STARTER and unlock.target_id == machine.id:
				opened = true
		assert_bool(opened).override_failure_message(
				"nothing opens %s" % machine.id).is_true()


func test_every_machine_names_real_hardware_and_real_symbols() -> void:
	var content: ContentDB = ContentDB.shared()
	var families: Dictionary = {}
	for symbol: SymbolDef in content.symbols:
		if symbol.family != &"":
			families[symbol.family] = true
	for machine: MachineDef in _catalogue.machines:
		for artifact: StringName in machine.starting_artifacts:
			assert_object(content.artifact_by_id(artifact)).override_failure_message(
					"%s ships with %s, which does not exist" % [machine.id, artifact]).is_not_null()
		for key: Variant in machine.weight_shifts:
			var symbol: StringName = StringName(String(key))
			assert_bool(content.symbol_by_id(symbol) != null or families.has(symbol)) \
					.override_failure_message("%s leans on %s, which is neither symbol nor family"
					% [machine.id, symbol]).is_true()
		for system: StringName in machine.early_systems:
			assert_bool(Systems.ORDER.has(system)).is_true()


func test_a_machine_ships_fitted_and_leaned() -> void:
	var high_roller: MachineDef = _catalogue.machine_by_id(&"high_roller")
	assert_object(high_roller).is_not_null()
	var engine: SimEngine = SimEngine.new()
	engine.clear_policies()
	var state: RunState = engine.start_run(3, high_roller.apply_to(RunOptions.new()))
	assert_bool(state.has_system(Systems.STAKE)).is_true()
	var orchard: MachineDef = _catalogue.machine_by_id(&"orchard")
	var leaned: RunState = SimEngine.new().start_run(3, orchard.apply_to(RunOptions.new()))
	assert_bool(leaned.owns(&"fruit_ledger")).is_true()
	var plain: RunState = SimEngine.new().start_run(3)
	assert_float(Probability.symbol_chance(leaned.reel(), &"cherry")).is_greater(
			Probability.symbol_chance(plain.reel(), &"cherry"))


func test_every_machine_is_a_game() -> void:
	for machine: MachineDef in _catalogue.machines:
		var report: Dictionary = CasinoLab.run_batch(RUNS, 7,
				machine.apply_to(RunOptions.new()))
		var win_rate: float = float(report["win_rate"])
		assert_float(win_rate).override_failure_message(
				"%s never wins" % machine.id).is_greater(0.0)
		assert_float(win_rate).override_failure_message(
				"%s is free at %.0f%%" % [machine.id, win_rate * 100.0]).is_less(0.6)


func test_a_machines_options_survive_the_journal() -> void:
	var press: MachineDef = _catalogue.machine_by_id(&"bone_press")
	var options: RunOptions = press.apply_to(RunOptions.new())
	var back: RunOptions = RunOptions.from_dict(JSON.parse_string(JSON.stringify(options.to_dict())))
	assert_str(back.ruleset_key()).is_equal(options.ruleset_key())
	assert_int(int(back.weight_shifts.get(&"skull", 0))).is_equal(6)
