## Monte Carlo harness over the headless simulation.
##
## The lab is the reason the simulation has no engine dependencies: with the bus
## muted, a run is a few thousand integer operations, so 100k runs fit in a CI
## job rather than a weekend.
class_name CasinoLab
extends RefCounted

## Percentile boundaries reported for every distribution.
const PERCENTILES: Array = [50.0, 95.0, 99.0]

## Simulates [param count] runs from consecutive seeds and returns the report.
## [param options] is what every run starts with: the default measures the
## whole content set and the game that ends; one told to stay at the table
## measures the floors after hours.
static func run_batch(count: int, base_seed: int = 1, options: RunOptions = null) -> Dictionary:
	var content: ContentDB = ContentDB.shared()
	var bus: EffectBus = EffectBus.new()
	bus.muted = true
	var engine: SimEngine = SimEngine.new(content, bus)

	var earnings: PackedInt32Array = PackedInt32Array()
	var spins: PackedInt32Array = PackedInt32Array()
	var floors: PackedInt32Array = PackedInt32Array()
	var wins: int = 0
	var end_reasons: Dictionary = {}
	var floor_deaths: Dictionary = {}
	var artifact_runs: Dictionary = {}
	var artifact_wins: Dictionary = {}
	var synergy_runs: Dictionary = {}
	var synergy_wins: Dictionary = {}
	# Runs and wins bucketed by how many floors they cleared, so an artifact can
	# be compared against the cohort that got far enough to be offered it.
	var runs_by_depth: PackedInt32Array = PackedInt32Array()
	var wins_by_depth: PackedInt32Array = PackedInt32Array()
	runs_by_depth.resize(content.floors.size() + 1)
	wins_by_depth.resize(content.floors.size() + 1)
	# And bucketed again by how deep a tier the run actually bought from, which
	# is not the same thing. Reaching floor six says nothing about being able to
	# afford floor six's stock: prices track the ante, so the runs that own a
	# late artifact are the runs that were rich when they got there, and those
	# runs win more whatever they bought. Without this control every expensive
	# late item reads as overpowered, and nerfing one only promotes the next.
	var runs_by_market: PackedInt32Array = PackedInt32Array()
	var wins_by_market: PackedInt32Array = PackedInt32Array()
	runs_by_market.resize(content.floors.size() + 1)
	wins_by_market.resize(content.floors.size() + 1)
	# Same idea for tags: a synergy needs enough artifacts to exist at all.
	var stocked_runs: int = 0
	var stocked_wins: int = 0
	var serviced: PackedInt32Array = PackedInt32Array()
	var defaulted_runs: int = 0
	var paydown_runs: int = 0
	# The floors after hours, for a batch told to stay: how many runs took
	# the offer, how far each got, where each ended, and how many saw dawn.
	var stayed: int = 0
	var dawns: int = 0
	var after_hours: PackedInt32Array = PackedInt32Array()
	var after_hours_deaths: Dictionary = {}

	var started: int = Time.get_ticks_msec()
	for i: int in count:
		var state: RunState = engine.simulate_run(base_seed + i,
				options.duplicate_options() if options != null else null)
		# A run that stayed at the table had already won; how it ended after
		# hours is the after-hours figures' business, not the win rate's.
		var won: bool = state.phase == RunState.Phase.WON or state.endless
		earnings.append(state.economy.lifetime_earned)
		spins.append(state.spins_taken)
		floors.append(state.floors_cleared)
		if won:
			wins += 1
		else:
			floor_deaths[state.floor_index] = int(floor_deaths.get(state.floor_index, 0)) + 1
		if state.endless:
			stayed += 1
			var beyond: int = state.floors_cleared - content.floors.size()
			after_hours.append(beyond)
			if state.end_reason == &"dawn":
				dawns += 1
			else:
				after_hours_deaths[beyond + 1] = int(after_hours_deaths.get(beyond + 1, 0)) + 1
		var depth: int = clampi(state.floors_cleared, 0, runs_by_depth.size() - 1)
		runs_by_depth[depth] += 1
		if won:
			wins_by_depth[depth] += 1
		# A run counts as having been in the market for tier t when it both
		# cleared t floors and bought something from tier t or deeper.
		var bought_tier: int = 0
		for owned: ArtifactDef in state.owned:
			bought_tier = maxi(bought_tier, owned.min_floor)
		var market: int = clampi(mini(state.floors_cleared, bought_tier),
				0, runs_by_market.size() - 1)
		runs_by_market[market] += 1
		if won:
			wins_by_market[market] += 1
		if state.owned.size() >= content.balance.synergy_threshold:
			stocked_runs += 1
			if won:
				stocked_wins += 1
		serviced.append(state.economy.debt_serviced)
		if state.economy.defaults > 0:
			defaulted_runs += 1
		for artifact: ArtifactDef in state.owned:
			if artifact.effect == ArtifactDef.Effect.DEBT_PAYDOWN:
				paydown_runs += 1
				break
		var reason: String = String(state.end_reason)
		end_reasons[reason] = int(end_reasons.get(reason, 0)) + 1
		for artifact: ArtifactDef in state.owned:
			var key: String = String(artifact.id)
			artifact_runs[key] = int(artifact_runs.get(key, 0)) + 1
			if won:
				artifact_wins[key] = int(artifact_wins.get(key, 0)) + 1
		for tag: StringName in state.active_synergies():
			var tag_key: String = String(tag)
			synergy_runs[tag_key] = int(synergy_runs.get(tag_key, 0)) + 1
			if won:
				synergy_wins[tag_key] = int(synergy_wins.get(tag_key, 0)) + 1

	var win_rate: float = float(wins) / float(maxi(count, 1))
	return {
		"runs": count,
		"base_seed": base_seed,
		"stay_at_table": options != null and options.stay_at_table,
		"elapsed_ms": Time.get_ticks_msec() - started,
		"win_rate": win_rate,
		"death_rate": 1.0 - win_rate,
		"earnings": describe(earnings),
		"spins_per_run": describe(spins),
		"floors_cleared": describe(floors),
		"end_reasons": end_reasons,
		"debt": {
			"serviced": describe(serviced),
			"default_rate": _ratio(defaulted_runs, count),
			"paydown_owned_rate": _ratio(paydown_runs, count),
		},
		"deaths_by_floor": floor_deaths,
		"after_hours": {
			"stayed": stayed,
			"dawns": dawns,
			"floors": describe(after_hours),
			"deaths_by_floor": after_hours_deaths,
		},
		"artifact_win_rates": _artifact_rates(
				artifact_runs, artifact_wins, content, runs_by_market, wins_by_market),
		"synergy_win_rates": _synergy_rates(synergy_runs, synergy_wins, content,
				runs_by_market, wins_by_market, _ratio(stocked_wins, stocked_runs)),
		"anomalies": [],
	}


## Mean, median and tail percentiles of a sample.
static func describe(sample: PackedInt32Array) -> Dictionary:
	if sample.is_empty():
		return {"count": 0, "mean": 0.0, "min": 0, "max": 0}
	var sorted: PackedInt32Array = sample.duplicate()
	sorted.sort()
	var total: int = 0
	for value: int in sorted:
		total += value
	var out: Dictionary = {
		"count": sorted.size(),
		"mean": float(total) / float(sorted.size()),
		"min": sorted[0],
		"max": sorted[sorted.size() - 1],
	}
	for p: float in PERCENTILES:
		out["p%d" % int(p)] = percentile(sorted, p)
	return out


## Nearest-rank percentile of an already sorted sample.
static func percentile(sorted_sample: PackedInt32Array, p: float) -> int:
	if sorted_sample.is_empty():
		return 0
	var rank: int = int(ceil(p / 100.0 * float(sorted_sample.size())))
	return sorted_sample[clampi(rank - 1, 0, sorted_sample.size() - 1)]


## Flags win rates far from their comparison cohort — the artifacts and tag
## combos worth a human look. [param lift] is the win-rate delta counted as
## broken.
##
## Each entry is judged against its own baseline (see [method _artifact_rates]),
## falling back to the batch win rate for entries that carry none.
static func find_anomalies(report: Dictionary, lift: float = 0.25) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var batch_baseline: float = float(report.get("win_rate", 0.0))
	for group: String in ["artifact_win_rates", "synergy_win_rates"]:
		var rates: Dictionary = report.get(group, {})
		for key: String in rates:
			var entry: Dictionary = rates[key]
			var baseline: float = float(entry.get("baseline", batch_baseline))
			# A handful of runs cannot tell a broken combo from a lucky one.
			if int(entry.get("runs", 0)) < 30:
				continue
			var delta: float = float(entry.get("win_rate", 0.0)) - baseline
			if absf(delta) >= lift:
				out.append({
					"group": group,
					"id": key,
					"runs": entry.get("runs", 0),
					"win_rate": entry.get("win_rate", 0.0),
					"baseline": baseline,
					"delta": delta,
					"verdict": "overpowered" if delta > 0.0 else "underpowered",
				})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["delta"])) > absf(float(b["delta"])))
	return out


static func _rates(runs: Dictionary, wins: Dictionary, baseline: float) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = runs.keys()
	keys.sort()
	for key: String in keys:
		var seen: int = int(runs[key])
		var won: int = int(wins.get(key, 0))
		out[key] = {
			"runs": seen,
			"wins": won,
			"win_rate": _ratio(won, seen),
			"baseline": baseline,
		}
	return out


## Per-artifact rates, each against the cohort that reached the floor where the
## artifact first appears in a shop and bought from that tier.
##
## Comparing against the whole batch instead would flag every late artifact as
## overpowered: owning one that unlocks on floor 5 already means surviving to
## floor 5, so its win rate measures the player who got there, not the artifact.
## Controlling for depth alone is not enough either — see the market buckets in
## [method run_batch] for why.
static func _artifact_rates(runs: Dictionary, wins: Dictionary, content: ContentDB,
		runs_by_depth: PackedInt32Array, wins_by_depth: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = runs.keys()
	keys.sort()
	for key: String in keys:
		var seen: int = int(runs[key])
		var won: int = int(wins.get(key, 0))
		var artifact: ArtifactDef = content.artifact_by_id(StringName(key))
		# An artifact is first offered in the shop after its min_floor is cleared.
		var unlock_depth: int = artifact.min_floor if artifact != null else 0
		out[key] = {
			"runs": seen,
			"wins": won,
			"win_rate": _ratio(won, seen),
			"baseline": _depth_baseline(runs_by_depth, wins_by_depth, unlock_depth),
			"baseline_note": "runs clearing %d+ floors and buying from that tier" % unlock_depth,
		}
	return out


## Per-tag rates against the cohort that could actually light the synergy.
##
## A tag is only active once [member BalanceConfig.synergy_threshold] artifacts
## carrying it are owned, so the cohort is runs that cleared far enough to be
## offered that many — the threshold-th smallest min_floor among its members.
## Baselining tags against "owns 3+ artifacts" instead left late tags looking
## broken for the same survivorship reason artifacts once did.
static func _synergy_rates(runs: Dictionary, wins: Dictionary, content: ContentDB,
		runs_by_depth: PackedInt32Array, wins_by_depth: PackedInt32Array,
		fallback: float) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = runs.keys()
	keys.sort()
	for key: String in keys:
		var seen: int = int(runs[key])
		var won: int = int(wins.get(key, 0))
		var depth: int = _tag_unlock_depth(content, StringName(key))
		out[key] = {
			"runs": seen,
			"wins": won,
			"win_rate": _ratio(won, seen),
			"baseline": _depth_baseline(runs_by_depth, wins_by_depth, depth) if depth > 0 else fallback,
			"baseline_note": "runs clearing %d+ floors" % depth if depth > 0 else "runs owning 3+ artifacts",
		}
	return out


## Floors that must be cleared before enough artifacts carrying [param tag] can
## be owned for its synergy to light. Zero when the tag can never reach it.
static func _tag_unlock_depth(content: ContentDB, tag: StringName) -> int:
	var floors: Array[int] = []
	for artifact: ArtifactDef in content.artifacts:
		if artifact.has_tag(tag):
			floors.append(artifact.min_floor)
	if floors.size() < content.balance.synergy_threshold:
		return 0
	floors.sort()
	return floors[content.balance.synergy_threshold - 1]


## Win rate among runs that cleared at least [param from_depth] floors.
static func _depth_baseline(runs_by_depth: PackedInt32Array, wins_by_depth: PackedInt32Array,
		from_depth: int) -> float:
	var seen: int = 0
	var won: int = 0
	for depth: int in range(clampi(from_depth, 0, runs_by_depth.size()), runs_by_depth.size()):
		seen += runs_by_depth[depth]
		won += wins_by_depth[depth]
	return _ratio(won, seen)


static func _ratio(part: int, whole: int) -> float:
	if whole <= 0:
		return 0.0
	return float(part) / float(whole)
