extends GutTest
## Task 16 (FR-16-5, Q5 strict integrity): a slot flagged mid-mission-committed (a hot-quit while the
## alarm was up) loads as the Catch — Legacy banked, Streak reset — not a free continue.
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

func test_committed_hot_quit_resolves_as_catch() -> void:
	RunManager.notoriety = 2000
	RunManager.streak_length = 3
	SaveManager.save_slot(0)          # written with active_mission_committed = false
	SaveManager.mark_committed()      # an alarm mid-mission flips the on-disk flag true

	var legacy_before := ProgressionManager.legacy
	assert_true(SaveManager.load_slot(0), "load succeeds")
	assert_gt(ProgressionManager.legacy, legacy_before, "the Catch converted Notoriety → Legacy")
	assert_eq(RunManager.streak_length, 0, "the Streak was reset by the Catch")
	assert_eq(RunManager.notoriety, 0, "Notoriety cleared after conversion")

func test_reload_after_resolution_is_not_a_second_catch() -> void:
	# load_slot re-persists the cleared, fresh Streak; a subsequent load must be a plain continue.
	RunManager.notoriety = 1500
	SaveManager.save_slot(0)
	SaveManager.mark_committed()
	SaveManager.load_slot(0)                 # first load → Catch (+ re-save with flag cleared)
	var legacy_after_catch := ProgressionManager.legacy
	assert_true(SaveManager.load_slot(0), "second load succeeds")
	assert_eq(ProgressionManager.legacy, legacy_after_catch, "no double Catch on the next load")
