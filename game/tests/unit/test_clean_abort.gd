extends GutTest
## Task 16 (FR-16-5, Q5): a save taken while undetected (no mid-mission commit flag) loads with the
## Streak + secured Take/Notoriety intact — a clean bug-out keeps everything.
## docs/tasks/16_save_system.md.

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	GameManager.active_slot = 0
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func after_each() -> void:
	TestHelper.rm_dir(SaveManager.SAVE_DIR)
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func test_undetected_save_keeps_streak_and_secured_loot() -> void:
	RunManager.notoriety = 1500
	RunManager.take = 800
	RunManager.streak_length = 2
	RunManager.committed = false
	SaveManager.save_slot(0)          # active_mission_committed = false (safe checkpoint)

	var legacy_before := ProgressionManager.legacy
	ProgressionManager.from_dict({})
	RunManager.from_dict({})
	assert_true(SaveManager.load_slot(0), "load succeeds")

	assert_eq(RunManager.streak_length, 2, "Streak intact (no Catch)")
	assert_eq(RunManager.take, 800, "secured Take preserved")
	assert_eq(RunManager.notoriety, 1500, "Notoriety preserved")
	assert_eq(ProgressionManager.legacy, legacy_before, "no Legacy conversion on a clean load")
