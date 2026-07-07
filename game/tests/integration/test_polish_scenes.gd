extends GutTest
## Task 21: smoke-test that the Polish & Performance Sandbox instantiates without error — it mounts the REAL
## PlayerController + HUD and builds its room/props from imported art, so this catches wiring regressions in
## the accessibility / juice / perf demo. Resets the Streak/loadout state the sandbox touches afterwards so it
## can't perturb other scene-smoke tests. Mirrors test_ui_scenes / test_live_scenes.

const SANDBOX := "res://game/scenes/polish/PolishSandbox.tscn"

func before_each() -> void:
	RunManager.start_new_streak()   # a fresh Streak so loadout() exists for the dev-equip

func after_each() -> void:
	# The sandbox appends dev gear + equips a loadout; reset the run/account state it touched.
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func test_polish_sandbox_instantiates() -> void:
	var packed := load(SANDBOX) as PackedScene
	assert_not_null(packed, "the polish sandbox scene loads")
	var demo = packed.instantiate()
	add_child_autofree(demo)
	assert_true(is_instance_valid(demo), "the sandbox builds its room / player / HUD / readouts without error")
