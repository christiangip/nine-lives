extends GutTest
## Task 14: smoke test that the Economy Sandbox greybox instantiates and builds its room, props (real
## heist + Quaternius furniture models), and HUD in _ready() without error. Mirrors test_hideout_scenes.

const ECONOMY_GREYBOX := "res://game/scenes/economy/EconomyGreybox.tscn"

func before_each() -> void:
	RunManager.start_new_streak()   # a fresh Streak so the seeded currencies + board exist

func test_economy_greybox_instantiates() -> void:
	var packed := load(ECONOMY_GREYBOX) as PackedScene
	assert_not_null(packed, "the economy greybox scene loads")
	var demo = packed.instantiate()
	add_child_autofree(demo)
	assert_true(is_instance_valid(demo), "the sandbox builds its room/props/HUD without error")

func test_harness_runs_from_config() -> void:
	# The [B] balance readout drives EconomySimulator.compare — prove it produces a sane report.
	var econ := EconomyConfigDef.resolve()
	var cmp := EconomySimulator.compare(econ, 200, 1)
	assert_true(cmp.has("clean") and cmp.has("loud"), "compare reports both cohorts")
	assert_gt(float(cmp["clean"]["mean_streak_len"]), 0.0, "clean cohort completes contracts")
	var text := EconomySimulator.format_compare(cmp)
	assert_true(text.find("Legacy ratio") != -1, "the readout summarises the clean/loud ratio")
