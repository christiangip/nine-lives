extends GutTest
## Task 12 (FR-12-3/4): Heat raises the Legacy payout multiplier — a hotter Streak converts the same
## Notoriety into more Legacy (push-your-luck). Pure seams + the RunManager instance wrapper.

func test_heat_multiplier_curve() -> void:
	assert_almost_eq(RunManager.heat_multiplier_for(0.0, 1.0, 1.0), 1.0, 0.0001, "no Heat → ×1.0")
	assert_almost_eq(RunManager.heat_multiplier_for(0.5, 1.0, 1.0), 1.5, 0.0001, "half Heat → ×1.5")
	assert_almost_eq(RunManager.heat_multiplier_for(1.0, 1.0, 1.0), 2.0, 0.0001, "max Heat → ×2.0")

func test_heat_multiplier_clamps_heat() -> void:
	assert_almost_eq(RunManager.heat_multiplier_for(9.0, 1.0, 1.0), 2.0, 0.0001, "Heat is clamped to 1.0")

func test_higher_heat_pays_more_for_equal_notoriety() -> void:
	var cfg := ProgressionConfigDef.new()
	var cold := RunManager.convert_to_legacy(
		1000, RunManager.heat_multiplier_for(0.0, cfg.heat_multiplier_base, cfg.heat_multiplier_slope), cfg.legacy_floor)
	var hot := RunManager.convert_to_legacy(
		1000, RunManager.heat_multiplier_for(1.0, cfg.heat_multiplier_base, cfg.heat_multiplier_slope), cfg.legacy_floor)
	assert_gt(hot, cold, "the same Notoriety banks more Legacy at higher Heat")

func test_run_manager_instance_tracks_heat() -> void:
	var saved := RunManager.heat
	RunManager.heat = 0.0
	var m0 := RunManager.heat_multiplier()
	RunManager.heat = 1.0
	var m1 := RunManager.heat_multiplier()
	assert_gt(m1, m0, "RunManager.heat_multiplier() rises with Heat")
	RunManager.heat = saved
