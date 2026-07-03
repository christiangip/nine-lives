extends GutTest
## Task 12 (FR-12-1): the performance-multiplier stack. Bonuses (stealth/no-alarm/no-kill/speed/
## full-clear) are additive on a ×1.0 base; a flawless run out-scores an unbonused one. Pure seam,
## so no autoload/tree state is touched.

func _cfg() -> ProgressionConfigDef:
	return ProgressionConfigDef.new()   # schema defaults

func test_unbonused_is_base_one() -> void:
	assert_almost_eq(RunManager.stack_multiplier({}, _cfg()), 1.0, 0.0001, "no bonuses → ×1.0")

func test_stealth_and_full_clear_beat_unbonused() -> void:
	var cfg := _cfg()
	var flawless := RunManager.stack_multiplier({"stealth": true, "full_clear": true}, cfg)
	var plain := RunManager.stack_multiplier({}, cfg)
	assert_gt(flawless, plain, "a stealthy full-clear scores more than a plain finish")
	assert_almost_eq(flawless, 1.0 + cfg.bonus_stealth + cfg.bonus_full_clear, 0.0001, "bonuses add")

func test_all_bonuses_stack_additively() -> void:
	var cfg := _cfg()
	var m := RunManager.stack_multiplier(
		{"stealth": true, "no_alarm": true, "no_kill": true, "speed": true, "full_clear": true}, cfg)
	var expected := 1.0 + cfg.bonus_stealth + cfg.bonus_no_alarm + cfg.bonus_no_kill \
		+ cfg.bonus_speed + cfg.bonus_full_clear
	assert_almost_eq(m, expected, 0.0001, "every enabled bonus stacks on the base")

func test_partial_flags_only_count_enabled() -> void:
	var cfg := _cfg()
	var m := RunManager.stack_multiplier({"no_alarm": true, "speed": false}, cfg)
	assert_almost_eq(m, 1.0 + cfg.bonus_no_alarm, 0.0001, "a false flag contributes nothing")
