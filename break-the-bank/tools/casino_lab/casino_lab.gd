## Monte Carlo harness over the headless simulation.
##
## The lab is the reason the simulation has no engine dependencies: with the bus
## muted, a run is a few thousand integer operations, so 100k runs fit in a CI
## job rather than a weekend.
class_name CasinoLab
extends RefCounted

## Percentile boundaries reported for every distribution.
const PERCENTILES: Array = [50.0, 95.0, 99.0]
## Artifacts of one archetype a run has to own before it counts as having
## played that build. Two: one is a purchase, two is a plan.
const ARCHETYPE_THRESHOLD: int = 2
## Where the pick-rate scatter draws its lines: an offer taken this often is
## a habit, one taken this rarely is being passed over, and a win-rate delta
## past the lift is the difference between a habit and a trap.
const PICK_HIGH: float = 0.6
const PICK_LOW: float = 0.25
const PICK_LIFT: float = 0.05
## Runs a cohort needs before the lab will call it anything.
const MIN_COHORT: int = 30

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
	# The House's scrip: what a run earned of it, how much hardware that
	# bought, and how often the run left a floor early to get it. The
	# numbers the two-currency economy is tuned on.
	var chips: PackedInt32Array = PackedInt32Array()
	var hardware: PackedInt32Array = PackedInt32Array()
	var settled: PackedInt32Array = PackedInt32Array()
	# The balance guide's two tells for a loose economy: chips still in hand
	# when a draft is left (it wants near zero), and rerolls per draft (it
	# wants mitigation scarce enough to be a decision).
	var unspent: PackedInt32Array = PackedInt32Array()
	var rerolls: PackedInt32Array = PackedInt32Array()
	# How often the House noticed a run: the notice is tuned on this.
	var notices: PackedInt32Array = PackedInt32Array()
	var drafts_total: int = 0
	# Offers put in front of every run, against what was taken: the share of
	# the draft a run can afford is the number the chip supply is set by.
	var offers_total: int = 0
	var taken_total: int = 0
	var wins: int = 0
	var end_reasons: Dictionary = {}
	var floor_deaths: Dictionary = {}
	var artifact_runs: Dictionary = {}
	var artifact_wins: Dictionary = {}
	var synergy_runs: Dictionary = {}
	var synergy_wins: Dictionary = {}
	# The builds, as builds: a run that owned two or more of an archetype's
	# artifacts played it, whatever else it bought.
	var archetype_runs: Dictionary = {}
	var archetype_wins: Dictionary = {}
	# Where each artifact's, tag's and build's runs sat in the market buckets
	# below, so every cohort can be judged against runs of the same depth
	# rather than "everyone who got at least this far".
	var artifact_depths: Dictionary = {}
	var synergy_depths: Dictionary = {}
	var archetype_depths: Dictionary = {}
	# Drafts each artifact appeared on, so a pick rate can be put beside its
	# win rate: the thing people buy that loses is the trap the lab exists
	# to find before a person does.
	var offered_runs: Dictionary = {}
	# Who the House sent, and whether the run ended on their floor, so a boss
	# can be judged against the floor's ordinary death rate.
	var boss_faced: Dictionary = {}
	var boss_killed: Dictionary = {}
	var reached: PackedInt32Array = PackedInt32Array()
	reached.resize(content.floors.size() + 2)
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
		chips.append(state.economy.lifetime_chips)
		hardware.append(state.owned.size())
		settled.append(state.floors_settled_early)
		for left: int in state.chips_left_at_drafts:
			unspent.append(left)
		drafts_total += state.chips_left_at_drafts.size()
		rerolls.append(state.rerolls_total)
		notices.append(state.notices)
		for seen: StringName in state.offers_seen:
			offers_total += int(state.offers_seen[seen])
		taken_total += state.owned.size()
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
			_bump(artifact_depths, key, market, runs_by_market.size())
		for tag: StringName in state.active_synergies():
			var tag_key: String = String(tag)
			synergy_runs[tag_key] = int(synergy_runs.get(tag_key, 0)) + 1
			if won:
				synergy_wins[tag_key] = int(synergy_wins.get(tag_key, 0)) + 1
			_bump(synergy_depths, tag_key, market, runs_by_market.size())
		for floor_index: int in range(1, mini(state.floors_cleared + 1, content.floors.size()) + 1):
			reached[floor_index] += 1
		for faced_index: int in state.bosses_faced.size():
			var boss_id: String = String(state.bosses_faced[faced_index])
			if boss_id == "":
				continue
			boss_faced[boss_id] = int(boss_faced.get(boss_id, 0)) + 1
			if not won and state.floor_index == faced_index + 1 \
					and faced_index + 1 <= content.floors.size():
				boss_killed[boss_id] = int(boss_killed.get(boss_id, 0)) + 1
		for offered: StringName in state.offers_seen:
			var offered_key: String = String(offered)
			offered_runs[offered_key] = int(offered_runs.get(offered_key, 0)) + 1
		for archetype: ArchetypeDef in content.archetypes:
			var members: int = 0
			for artifact: ArtifactDef in state.owned:
				if artifact.archetype == archetype.id:
					members += 1
			if members < ARCHETYPE_THRESHOLD:
				continue
			var archetype_key: String = String(archetype.id)
			archetype_runs[archetype_key] = int(archetype_runs.get(archetype_key, 0)) + 1
			if won:
				archetype_wins[archetype_key] = int(archetype_wins.get(archetype_key, 0)) + 1
			_bump(archetype_depths, archetype_key, market, runs_by_market.size())

	var win_rate: float = float(wins) / float(maxi(count, 1))
	var artifact_rates: Dictionary = _stratified_rates(
			artifact_runs, artifact_wins, artifact_depths, runs_by_market, wins_by_market, win_rate)
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
		"chips": describe(chips),
		"hardware": describe(hardware),
		"settled_early": describe(settled),
		"draft_take_rate": _ratio(taken_total, offers_total),
		"chips_unspent_at_draft": describe(unspent),
		"rerolls_per_run": describe(rerolls),
		"rerolls_per_draft": _ratio(_sum(rerolls), drafts_total),
		"notices": describe(notices),
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
		"artifact_win_rates": artifact_rates,
		"synergy_win_rates": _stratified_rates(synergy_runs, synergy_wins, synergy_depths,
				runs_by_market, wins_by_market, _ratio(stocked_wins, stocked_runs)),
		"archetype_win_rates": _stratified_rates(archetype_runs, archetype_wins,
				archetype_depths, runs_by_market, wins_by_market, win_rate),
		"pick_rates": pick_rates(offered_runs, artifact_runs, artifact_rates),
		"boss_rates": _boss_rates(boss_faced, boss_killed, floor_deaths, reached, content),
		"anomalies": [],
	}


static func _sum(sample: PackedInt32Array) -> int:
	var total: int = 0
	for value: int in sample:
		total += value
	return total


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
	for group: String in ["artifact_win_rates", "synergy_win_rates", "archetype_win_rates"]:
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


## One cohort's win rate beside the win rate of runs that sat at the same
## market depth, in the same proportions.
##
## Owning an artifact that unlocks late already implies surviving that far,
## and — because prices track the ante — being rich when you got there. The
## first cure was to compare each artifact against every run that reached
## its floor and bought from its tier; that still lumped a floor-one trinket's
## owners in with the whole batch, and put every dear late item a dozen
## points above a cohort it was never really in. So each key's runs are
## counted by the market bucket they fell in, and the baseline is the batch's
## win rate at each of those depths, weighted by how many of the key's runs
## were there. What is left is the difference the thing itself made among
## runs of the same standing. [param fallback] covers a key that somehow has
## no depth on record.
static func _stratified_rates(runs: Dictionary, wins: Dictionary, depths: Dictionary,
		runs_by_market: PackedInt32Array, wins_by_market: PackedInt32Array,
		fallback: float) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = runs.keys()
	keys.sort()
	for key: String in keys:
		var seen: int = int(runs[key])
		var won: int = int(wins.get(key, 0))
		var baseline: float = fallback
		if depths.has(key):
			baseline = _stratified_baseline(depths[key], runs_by_market, wins_by_market, fallback)
		out[key] = {
			"runs": seen,
			"wins": won,
			"win_rate": _ratio(won, seen),
			"baseline": baseline,
			"baseline_note": "runs at the same market depth",
		}
	return out


## The batch's win rate across the market buckets in [param histogram]'s
## proportions.
static func _stratified_baseline(histogram: PackedInt32Array,
		runs_by_market: PackedInt32Array, wins_by_market: PackedInt32Array,
		fallback: float) -> float:
	var weighted: float = 0.0
	var total: int = 0
	for depth: int in histogram.size():
		var here: int = histogram[depth]
		if here <= 0 or depth >= runs_by_market.size():
			continue
		weighted += float(here) * _ratio(wins_by_market[depth], runs_by_market[depth])
		total += here
	if total <= 0:
		return fallback
	return weighted / float(total)


## Each boss's death rate — the share of runs that met them and ended on
## their floor — beside the floor's own death rate over every run that
## opened it, whoever was there. The lift is what the boss adds.
static func _boss_rates(faced: Dictionary, killed: Dictionary, floor_deaths: Dictionary,
		reached: PackedInt32Array, content: ContentDB) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = faced.keys()
	keys.sort()
	for key: String in keys:
		var met: int = int(faced[key])
		var died: int = int(killed.get(key, 0))
		var boss: BossDef = content.boss_by_id(StringName(key))
		var floor_index: int = boss.floor if boss != null else 0
		var floor_rate: float = 0.0
		if floor_index > 0 and floor_index < reached.size():
			floor_rate = _ratio(int(floor_deaths.get(floor_index, 0)), reached[floor_index])
		out[key] = {
			"floor": floor_index,
			"faced": met,
			"killed": died,
			"death_rate": _ratio(died, met),
			"floor_rate": floor_rate,
			"lift": _ratio(died, met) - floor_rate,
		}
	return out


## Counts one run at [param depth] under [param key].
static func _bump(histogram: Dictionary, key: String, depth: int, size: int) -> void:
	if not histogram.has(key):
		var fresh: PackedInt32Array = PackedInt32Array()
		fresh.resize(size)
		histogram[key] = fresh
	var counts: PackedInt32Array = histogram[key]
	counts[clampi(depth, 0, counts.size() - 1)] += 1
	histogram[key] = counts


## Every artifact's pick rate — the share of drafts it appeared on that ended
## with it owned — beside its win rate against its cohort, and a verdict.
##
## Four corners of the scatter are worth a name. A trap is bought often and
## loses; an auto-pick is bought often and wins, which is a decision the game
## has stopped asking; a sleeper is passed over and wins; dead stock is passed
## over and loses. Everything near the middle is fair.
##
## "Wins" and "loses" are measured against the pack, not against zero: what
## survivorship the stratified baseline leaves behind moves every lift the
## same way, and the median of the lifts is the honest zero. With the
## automated player buying by price, a pick rate is mostly a statement about
## what it could afford — the instrument is here for when the player is a
## person.
static func pick_rates(offered: Dictionary, taken: Dictionary,
		artifact_rates: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = offered.keys()
	keys.sort()
	var lifts: PackedFloat32Array = PackedFloat32Array()
	for key: String in keys:
		if int(taken.get(key, 0)) < MIN_COHORT:
			continue
		var rates: Dictionary = artifact_rates.get(key, {})
		lifts.append(float(rates.get("win_rate", 0.0)) - float(rates.get("baseline", 0.0)))
	var pack: float = _median(lifts)
	for key: String in keys:
		var drafts: int = int(offered[key])
		var owned: int = int(taken.get(key, 0))
		var pick: float = _ratio(owned, drafts)
		var rates: Dictionary = artifact_rates.get(key, {})
		var win_rate: float = float(rates.get("win_rate", 0.0))
		var baseline: float = float(rates.get("baseline", 0.0))
		var delta: float = win_rate - baseline - pack
		out[key] = {
			"offered": drafts,
			"taken": owned,
			"pick_rate": pick,
			"win_rate": win_rate,
			"baseline": baseline,
			"pack_lift": pack,
			"delta": delta,
			"verdict": pick_verdict(drafts, owned, pick, delta),
		}
	return out


static func pick_verdict(drafts: int, owned: int, pick: float, delta: float) -> String:
	if drafts < MIN_COHORT or owned < MIN_COHORT:
		return "unmeasured"
	if pick >= PICK_HIGH and delta <= -PICK_LIFT:
		return "trap"
	if pick >= PICK_HIGH and delta >= PICK_LIFT:
		return "auto"
	if pick <= PICK_LOW and delta >= PICK_LIFT:
		return "sleeper"
	if pick <= PICK_LOW and delta <= -PICK_LIFT:
		return "dead"
	return "fair"


static func _median(sample: PackedFloat32Array) -> float:
	if sample.is_empty():
		return 0.0
	var sorted: PackedFloat32Array = sample.duplicate()
	sorted.sort()
	var middle: int = sorted.size() / 2
	if sorted.size() % 2 == 1:
		return sorted[middle]
	return (sorted[middle - 1] + sorted[middle]) * 0.5


static func _ratio(part: int, whole: int) -> float:
	if whole <= 0:
		return 0.0
	return float(part) / float(whole)
