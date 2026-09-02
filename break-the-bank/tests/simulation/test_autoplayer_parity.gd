extends GdUnitTestSuite

## Every verb the engine gives a player's hands, the automated player has to
## have an opinion about — or the lab measures a game with that verb switched
## off, which is exactly how the vault and the works went unplayed for every
## batch before Milestone 2, and how the market went unplayed for every batch
## after it. This suite is that checklist, enforced.

## Enough runs to reach the late floors often enough for every verb to be
## seen, and few enough to stay quick.
const RUNS: int = 150

var _log: Array[Dictionary] = []


func before() -> void:
	_log.clear()
	for run: int in RUNS:
		var engine: SimEngine = SimEngine.new()
		var bus: EffectBus = engine.get_bus()
		bus.recording = true
		engine.simulate_run(51000 + run)
		_log.append_array(bus.event_log)


## True when some recorded event of [param kind] satisfies [param test].
func _seen(kind: EffectBus.Event, test: Callable = Callable()) -> bool:
	for entry: Dictionary in _log:
		if entry["kind"] != kind:
			continue
		if not test.is_valid() or bool(test.call(entry["payload"] as Dictionary)):
			return true
	return false


## What in the telemetry proves a verb was used. An event alone is not always
## enough — every spin announces its holds, so the proof of a hold is a held
## reel in that announcement, not the announcement.
func _proof(verb: StringName) -> bool:
	match verb:
		&"toggle_hold":
			return _seen(EffectBus.Event.SPIN_STARTED, func(p: Dictionary) -> bool:
				return (p.get("held", []) as Array).has(true))
		&"nudge":
			return _seen(EffectBus.Event.REEL_NUDGED)
		&"gamble":
			return _seen(EffectBus.Event.GAMBLE_RESOLVED)
		&"set_stake":
			return _seen(EffectBus.Event.SPIN_STARTED, func(p: Dictionary) -> bool:
				return int(p.get("stake", 1)) > 1)
		&"deposit":
			return _seen(EffectBus.Event.VAULT_CHANGED, func(p: Dictionary) -> bool:
				return int(p.get("delta", 0)) > 0)
		&"withdraw":
			return _seen(EffectBus.Event.VAULT_CHANGED, func(p: Dictionary) -> bool:
				return int(p.get("delta", 0)) < 0)
		&"buy_reel":
			return _seen(EffectBus.Event.WORKS_FITTED, func(p: Dictionary) -> bool:
				return String(p.get("kind", "")) == "reel")
		&"buy_row":
			return _seen(EffectBus.Event.WORKS_FITTED, func(p: Dictionary) -> bool:
				return String(p.get("kind", "")) == "row")
		&"launder":
			return _seen(EffectBus.Event.HEAT_CHANGED, func(p: Dictionary) -> bool:
				return p.has("paid"))
		&"buy_offer":
			return _seen(EffectBus.Event.CASH_CHANGED, func(p: Dictionary) -> bool:
				return StringName(p.get("reason", &"")) == &"artifact")
		&"reroll_shop":
			return _seen(EffectBus.Event.SHOP_REROLLED)
		&"sell":
			return _seen(EffectBus.Event.ARTIFACT_SOLD)
		&"buy_on_slate":
			return _seen(EffectBus.Event.SLATE_SIGNED)
		&"sign_contract":
			return _seen(EffectBus.Event.CONTRACT_SIGNED)
		_:
			return false


func test_every_player_verb_is_a_real_engine_method() -> void:
	var engine: SimEngine = SimEngine.new()
	for verb: StringName in SimEngine.PLAYER_VERBS:
		assert_bool(engine.has_method(verb)).override_failure_message(
				"SimEngine.PLAYER_VERBS names %s, which is not a method on the engine" % verb).is_true()


func test_every_player_verb_has_an_opinion_behind_it() -> void:
	for verb: StringName in SimEngine.PLAYER_VERBS:
		assert_bool(AutoPlayer.COVERAGE.has(verb)).override_failure_message(
				"%s has no row in AutoPlayer.COVERAGE: the lab is measuring a game with it switched off" % verb).is_true()
		var opinion: StringName = AutoPlayer.COVERAGE.get(verb, &"")
		assert_bool(Callable(AutoPlayer, opinion).is_valid()).override_failure_message(
				"AutoPlayer.COVERAGE says %s is covered by %s, which does not exist" % [verb, opinion]).is_true()


func test_no_opinion_claims_a_verb_the_engine_does_not_have() -> void:
	for verb: StringName in AutoPlayer.COVERAGE:
		assert_bool(SimEngine.PLAYER_VERBS.has(verb)).override_failure_message(
				"AutoPlayer.COVERAGE covers %s, which SimEngine.PLAYER_VERBS does not list" % verb).is_true()


func test_this_suite_knows_how_to_prove_every_verb() -> void:
	# A verb the engine grew that this file cannot recognise would pass the
	# checklist above and never be looked for below.
	for verb: StringName in SimEngine.PLAYER_VERBS:
		var known: bool = verb in [
			&"toggle_hold", &"nudge", &"gamble", &"set_stake", &"deposit", &"withdraw",
			&"buy_reel", &"buy_row", &"launder", &"buy_offer", &"reroll_shop", &"sell",
			&"buy_on_slate", &"sign_contract",
		]
		assert_bool(known).override_failure_message(
				"add a proof for %s to test_autoplayer_parity.gd" % verb).is_true()


func test_a_batch_is_seen_using_every_verb() -> void:
	for verb: StringName in SimEngine.PLAYER_VERBS:
		assert_bool(_proof(verb)).override_failure_message(
				"%d runs never used %s: the opinion exists but nothing it does ever fires" % [RUNS, verb]).is_true()
