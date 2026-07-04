extends RefCounted
class_name EconomySimulator
## Monte-Carlo run simulator for balance passes (task 14, FR-14-6). Simulates many Streaks straight
## from EconomyConfigDef so a designer can sanity-check curves *before* a playtest: it reports the
## Streak-length distribution and Legacy-per-run, and compares a CLEAN playstyle cohort against a LOUD
## one. Because the game is stealth-focused, the tuning target is that clean *strictly dominates* loud
## on both axes (test_tuning_invariants asserts it). Pure/headless + seeded, so tests are deterministic.
##
## The catch model is a deliberate balancing abstraction: the real game ends a Streak when detection
## escalates to a Catch; here each contract rolls EconomyConfigDef.catch_chance (rising with tier and,
## for loud, with accumulated Heat). It reuses the real payout seams (RunManager.stack_multiplier /
## heat_multiplier_for / convert_to_legacy) so editing data/economy.json moves the sim too.
## See docs/tasks/14_economy_balancing.md.

enum Cohort { CLEAN, LOUD }

## Simulate `runs` Streaks for one cohort. Returns a report Dictionary (see _report). Deterministic
## for a given `seed`.
static func simulate(econ: EconomyConfigDef, cohort: int, runs: int, seed: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lengths: Array[int] = []
	var legacies: Array[int] = []
	var takes: Array[int] = []
	for _r in maxi(runs, 1):
		var res := _simulate_one(econ, cohort, rng)
		lengths.append(int(res["length"]))
		legacies.append(int(res["legacy"]))
		takes.append(int(res["take"]))
	var report := _report(lengths, legacies, takes)
	report["cohort"] = "clean" if cohort == Cohort.CLEAN else "loud"
	return report

## Run both cohorts under the same config and seed, for the greybox readout + the invariant test.
static func compare(econ: EconomyConfigDef, runs: int, seed: int = 0) -> Dictionary:
	return {
		"clean": simulate(econ, Cohort.CLEAN, runs, seed),
		"loud": simulate(econ, Cohort.LOUD, runs, seed + 1),
	}

# --- One Streak ------------------------------------------------------------
static func _simulate_one(econ: EconomyConfigDef, cohort: int, rng: RandomNumberGenerator) -> Dictionary:
	var notoriety := 0
	var take := 0
	var heat := 0.0
	var length := 0
	var perf := RunManager.stack_multiplier(_cohort_flags(cohort), econ)
	for contract_idx in maxi(econ.max_contracts_per_streak, 1):
		# The difficulty floor rises with Streak length (mirrors RunManager.refresh_board(1+len)); a
		# loud run also carries accumulated Heat into each contract.
		var tier := 1 + int(contract_idx / 2)
		if cohort == Cohort.LOUD:
			heat = clampf(heat + econ.sim_heat_per_loud_contract, 0.0, 1.0)
		var p := EconomyConfigDef.catch_chance(
			econ.base_catch_chance, econ.catch_per_tier, tier, econ.catch_per_heat, heat)
		if rng.randf() < p:
			break   # Caught mid-heist — this contract's haul is not banked.
		# Survived → complete the contract: objective NP × performance, plus flat secured-cash NP and
		# its take-fraction cut (the performance stack never touches loot cash — matches the real game).
		notoriety += int(round(econ.objective_notoriety * perf))
		notoriety += econ.sim_cash_per_contract
		take += EconomyConfigDef.take_cut(econ.sim_cash_per_contract, econ.take_fraction)
		length += 1
	var heat_mult := RunManager.heat_multiplier_for(heat, econ.heat_multiplier_base, econ.heat_multiplier_slope)
	var legacy := RunManager.convert_to_legacy(notoriety, heat_mult, econ.legacy_floor)
	return {"length": length, "legacy": legacy, "take": take}

## Performance flags a cohort earns. CLEAN stacks the stealth bonuses; LOUD forfeits them (still grabs
## the objective → full_clear only). Feeds RunManager.stack_multiplier, so the real bonus_* dials drive it.
static func _cohort_flags(cohort: int) -> Dictionary:
	if cohort == Cohort.CLEAN:
		return {"stealth": true, "no_alarm": true, "no_kill": true, "full_clear": true, "speed": false}
	return {"stealth": false, "no_alarm": false, "no_kill": false, "full_clear": true, "speed": false}

# --- Aggregation -----------------------------------------------------------
static func _report(lengths: Array, legacies: Array, takes: Array) -> Dictionary:
	var n := lengths.size()
	if n == 0:
		return {"runs": 0}
	var sorted_len := lengths.duplicate()
	sorted_len.sort()
	return {
		"runs": n,
		"mean_streak_len": _mean(lengths),
		"min_streak_len": sorted_len[0],
		"max_streak_len": sorted_len[n - 1],
		"p10_streak_len": sorted_len[int(n * 0.1)],
		"p50_streak_len": sorted_len[int(n * 0.5)],
		"p90_streak_len": sorted_len[mini(int(n * 0.9), n - 1)],
		"mean_legacy_per_run": _mean(legacies),
		"min_legacy_per_run": _min_int(legacies),
		"mean_take_per_run": _mean(takes),
		"lengths": lengths,
	}

## Count of runs at each Streak length 0..max_len (a histogram for the greybox readout).
static func histogram(lengths: Array, max_len: int) -> Array:
	var bins: Array = []
	bins.resize(max_len + 1)
	bins.fill(0)
	for l in lengths:
		var idx := clampi(int(l), 0, max_len)
		bins[idx] = int(bins[idx]) + 1
	return bins

## A multi-line human-readable summary of a compare() result — for print() runs + the greybox panel.
static func format_compare(cmp: Dictionary) -> String:
	var lines: Array = []
	lines.append("=== Economy balance harness ===")
	for key in ["clean", "loud"]:
		var r: Dictionary = cmp[key]
		lines.append("[%s]  runs=%d  streak len mean=%.2f (min %d / p50 %d / p90 %d / max %d)"
			% [key, int(r.get("runs", 0)), float(r.get("mean_streak_len", 0.0)),
				int(r.get("min_streak_len", 0)), int(r.get("p50_streak_len", 0)),
				int(r.get("p90_streak_len", 0)), int(r.get("max_streak_len", 0))])
		lines.append("        Legacy/run mean=%.0f (min %d)   Take/run mean=%.0f"
			% [float(r.get("mean_legacy_per_run", 0.0)), int(r.get("min_legacy_per_run", 0)),
				float(r.get("mean_take_per_run", 0.0))])
	var clean_leg := float(cmp["clean"].get("mean_legacy_per_run", 0.0))
	var loud_leg := float(cmp["loud"].get("mean_legacy_per_run", 0.0))
	var ratio := clean_leg / loud_leg if loud_leg > 0.0 else 0.0
	lines.append("clean/loud Legacy ratio = %.2fx  (stealth-favored target: > 1.0)" % ratio)
	return "\n".join(lines)

static func _mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var total := 0.0
	for v in arr:
		total += float(v)
	return total / float(arr.size())

static func _min_int(arr: Array) -> int:
	if arr.is_empty():
		return 0
	var m := int(arr[0])
	for v in arr:
		m = mini(m, int(v))
	return m
