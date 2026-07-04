extends GutTest
## Task 14 (FR-14-3/4): the Notoriety performance multipliers are data — changing one in the
## EconomyConfigDef changes the payout — and the central balance table hydrates from data/economy.json.

func test_stack_multiplier_reads_config() -> void:
	var econ := EconomyConfigDef.new()
	var flags := {"stealth": true}
	econ.bonus_stealth = 0.5
	var m1 := RunManager.stack_multiplier(flags, econ)
	econ.bonus_stealth = 1.5
	var m2 := RunManager.stack_multiplier(flags, econ)
	assert_almost_eq(m1, 1.5, 0.0001, "×1.0 base + 0.5 stealth")
	assert_almost_eq(m2, 2.5, 0.0001, "×1.0 base + 1.5 stealth")
	assert_gt(m2, m1, "raising the stealth multiplier in data raises the Notoriety result")

func test_all_bonuses_stack_additively() -> void:
	var econ := EconomyConfigDef.new()
	var flags := {"stealth": true, "no_alarm": true, "no_kill": true, "speed": true, "full_clear": true}
	var expected := 1.0 + econ.bonus_stealth + econ.bonus_no_alarm + econ.bonus_no_kill \
		+ econ.bonus_speed + econ.bonus_full_clear
	assert_almost_eq(RunManager.stack_multiplier(flags, econ), expected, 0.0001, "every enabled bonus stacks")

func test_economy_config_hydrates_from_json() -> void:
	# The registry loaded data/economy.json into an EconomyConfigDef indexed as &"default" (FR-14-4).
	assert_true(Content.economy != null, "economy registry exists")
	assert_true(Content.economy.has(&"default"), "data/economy.json hydrated the &default balance table")
	var econ := EconomyConfigDef.resolve()
	assert_not_null(econ, "the economy config resolves")
	assert_gt(econ.take_fraction, 0.0, "take_fraction loaded from JSON")
	assert_lt(econ.take_fraction, 1.0, "take_fraction is a fraction")

func test_stealth_favored_relationship_holds_in_config() -> void:
	# Stealth-focused tuning: the clean stealth bonuses dwarf what a modest Heat payout can add.
	var econ := EconomyConfigDef.resolve()
	var clean_stack := econ.bonus_stealth + econ.bonus_no_alarm + econ.bonus_no_kill + econ.bonus_full_clear
	assert_gt(clean_stack, econ.heat_multiplier_slope,
		"a clean run's stacked bonuses (%.2f) exceed the max Heat payout bump (%.2f)" % [clean_stack, econ.heat_multiplier_slope])
