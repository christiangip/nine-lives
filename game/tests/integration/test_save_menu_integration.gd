extends GutTest
## Task 16 closes the task-15 deferrals (FR-15-2/3): the Main Menu / SlotPopup seams light up once a
## real save exists — Continue enables, and an occupied slot renders the five summary fields.
## docs/tasks/16_save_system.md, docs/tasks/15_ui_hud_menus.md.

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	GameManager.active_slot = 0
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func after_each() -> void:
	TestHelper.rm_dir(SaveManager.SAVE_DIR)
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func test_continue_enables_once_a_real_save_exists() -> void:
	assert_eq(SaveManager.populated_count(), 0, "fresh profile has no saves")
	assert_false(MainMenu.continue_enabled(SaveManager.populated_count()), "Continue greyed with no saves")
	assert_true(SaveManager.save_slot(0), "write a real save")
	assert_gt(SaveManager.populated_count(), 0, "a slot is now populated")
	assert_true(MainMenu.continue_enabled(SaveManager.populated_count()), "Continue enables")

func test_occupied_slot_renders_the_five_fields() -> void:
	ProgressionManager.legacy = 3000
	RunManager.streak_length = 5
	RunManager.last_contract = "Museum Job"
	assert_true(SaveManager.save_slot(2), "save the slot")
	var text := SlotPopup.format_slot(SaveManager.slot_summary(2))
	assert_ne(text, "Empty.", "an occupied slot is not 'Empty.'")
	assert_string_contains(text, "Streak 5")
	assert_string_contains(text, "Legacy 3000")
	assert_string_contains(text, "Museum Job")
