extends GutTest
## Task 14 (FR-14-5/6): the balancing harness hits the tuning targets straight from data. A clean
## Streak averages "several missions," every Catch affords the cheapest first buy, and — because the
## game is stealth-focused — a clean cohort STRICTLY beats a loud one on Legacy/run and Streak length.

const RUNS := 4000
const SEED := 20260704

func test_clean_streak_length_in_target_band() -> void:
	var econ := EconomyConfigDef.resolve()
	var r := EconomySimulator.simulate(econ, EconomySimulator.Cohort.CLEAN, RUNS, SEED)
	var mean := float(r["mean_streak_len"])
	assert_true(mean >= econ.target_streak_len_min and mean <= econ.target_streak_len_max,
		"clean mean Streak length %.2f in target band [%.1f, %.1f]"
			% [mean, econ.target_streak_len_min, econ.target_streak_len_max])

func test_every_catch_affords_something() -> void:
	var econ := EconomyConfigDef.resolve()
	var r := EconomySimulator.simulate(econ, EconomySimulator.Cohort.CLEAN, RUNS, SEED)
	var min_payout := int(r["min_legacy_per_run"])
	assert_true(min_payout >= econ.legacy_floor, "min payout %d ≥ floor %d" % [min_payout, econ.legacy_floor])
	assert_true(min_payout >= _cheapest_first_buy(),
		"every Catch affords the cheapest first Training buy (%d)" % _cheapest_first_buy())

func test_clean_strictly_beats_loud() -> void:
	var econ := EconomyConfigDef.resolve()
	var cmp := EconomySimulator.compare(econ, RUNS, SEED)
	var clean: Dictionary = cmp["clean"]
	var loud: Dictionary = cmp["loud"]
	assert_gt(float(clean["mean_legacy_per_run"]), float(loud["mean_legacy_per_run"]),
		"stealth-focused: clean banks more Legacy/run than loud")
	assert_gt(float(clean["mean_streak_len"]), float(loud["mean_streak_len"]),
		"clean Streaks last longer than loud (loud gets you caught)")

func _cheapest_first_buy() -> int:
	var cheapest := 1 << 30
	for res in Content.attributes.all():
		var def := res as AttributeDef
		if def != null and not def.cost_curve.is_empty():
			cheapest = mini(cheapest, def.cost_curve[0])
	return cheapest
