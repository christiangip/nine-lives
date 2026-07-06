extends GutTest
## Task 19: smoke test that the Expansion Sandbox greybox instantiates and builds its room, props (real
## Quaternius furniture + heist props + an NPC), and HUD in _ready() without error. Restores the base
## pack/registry state afterwards so it doesn't perturb other scene-smoke tests. Mirrors test_economy_scenes.

const SANDBOX := "res://game/scenes/expansion/ExpansionSandbox.tscn"

func before_each() -> void:
	RunManager.start_new_streak()   # a fresh Streak so RunManager.loadout()/edges exist

func after_each() -> void:
	# The sandbox's _ready reconfigures PackManager + reloads Content; restore the base state.
	PackManager.reset()
	Content.reload()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://packs_sandbox.json"))

func test_expansion_sandbox_instantiates() -> void:
	var packed := load(SANDBOX) as PackedScene
	assert_not_null(packed, "the expansion sandbox scene loads")
	var demo = packed.instantiate()
	add_child_autofree(demo)
	assert_true(is_instance_valid(demo), "the sandbox builds its room/props/HUD without error")
