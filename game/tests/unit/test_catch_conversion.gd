extends GutTest
## Task 12 (FR-12-4): the Catch. end_streak() converts accrued Notoriety × Heat-multiplier into
## permanent Legacy, banks it via ProgressionManager, announces streak_ended, and resets the Streak
## to a fresh low-difficulty state (Notoriety/level/Heat/Edges all cleared).

func before_each() -> void:
	ProgressionManager.legacy = 0
	ProgressionManager.meta_perks.clear()   # end_streak now reads legacy-conversion Perks (task 14)
	RunManager.notoriety = 0
	RunManager.streak_level = 1
	RunManager.heat = 0.0
	RunManager.committed = false
	RunManager.edges.clear()

func test_catch_banks_notoriety_and_resets_streak() -> void:
	RunManager.notoriety = 5000
	RunManager.streak_level = 4
	RunManager.heat = 0.0            # multiplier ×1.0
	RunManager.choose_edge(&"mule")
	var awarded := RunManager.end_streak("caught")
	assert_eq(awarded, 5000, "5000 Notoriety × 1.0 → 5000 Legacy")
	assert_eq(ProgressionManager.legacy, 5000, "the payout banks into permanent Legacy")
	assert_eq(RunManager.notoriety, 0, "Notoriety resets on the Catch")
	assert_eq(RunManager.streak_level, 1, "Streak Level resets")
	assert_eq(RunManager.heat, 0.0, "Heat resets")
	assert_true(RunManager.edges.is_empty(), "Edges vanish on the Catch")

func test_catch_applies_the_heat_multiplier() -> void:
	# Task 14 owns the Heat→payout slope (data/economy.json), so derive the expectation from config
	# rather than pinning a number — the mechanic under test is "max Heat multiplies the payout".
	var econ := EconomyConfigDef.resolve()
	var expected := int(round(1000.0 * (econ.heat_multiplier_base + econ.heat_multiplier_slope)))
	RunManager.notoriety = 1000
	RunManager.heat = 1.0           # max Heat → base+slope multiplier
	var awarded := RunManager.end_streak("caught")
	assert_eq(awarded, expected, "1000 Notoriety × max-Heat multiplier → %d Legacy" % expected)
	assert_gt(awarded, 1000, "max Heat pays more than the flat Notoriety")

func test_catch_emits_streak_ended() -> void:
	watch_signals(EventBus)
	RunManager.notoriety = 3000
	RunManager.end_streak("caught")
	assert_signal_emitted(EventBus, "streak_ended", "the Catch announces streak_ended")

func test_catch_records_lifetime_stats() -> void:
	ProgressionManager.stats.clear()
	RunManager.notoriety = 2000
	var awarded := RunManager.end_streak("caught")
	assert_eq(int(ProgressionManager.stats.get(&"streaks_caught", 0)), 1, "the Catch is tallied")
	assert_eq(int(ProgressionManager.stats.get(&"legacy_earned", 0)), awarded, "lifetime Legacy is tallied")
