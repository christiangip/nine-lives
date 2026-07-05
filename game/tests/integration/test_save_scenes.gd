extends GutTest
## Task 16: the SaveSandbox demo scene instantiates cleanly headlessly (mirrors test_ui_scenes.gd).
## docs/tasks/16_save_system.md.

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	GameManager.active_slot = 0

func after_each() -> void:
	TestHelper.rm_dir(SaveManager.SAVE_DIR)
	# SaveSandbox seeds demo state into the shared managers; reset so later tests start clean.
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func test_save_sandbox_instantiates() -> void:
	var packed := load("res://game/scenes/menu/SaveSandbox.tscn") as PackedScene
	assert_not_null(packed, "SaveSandbox.tscn loads")
	var node = packed.instantiate()
	add_child_autofree(node)
	assert_true(is_instance_valid(node), "the sandbox builds its readout without error")
