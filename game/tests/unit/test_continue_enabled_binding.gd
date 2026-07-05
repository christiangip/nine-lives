extends GutTest
## Task 15 FR-15-2: the Main Menu "Continue" is enabled IFF at least one save slot is populated. This locks
## the pure binding seam MainMenu.continue_enabled(populated_count). The save-backed integration half (a real
## temp save flips populated_count to 1) is deferred to task 16 — see the ↩ From 15 banner in
## 16_save_system.md. docs/tasks/15_ui_hud_menus.md.

func test_disabled_with_no_saves() -> void:
	assert_false(MainMenu.continue_enabled(0), "Continue is disabled when zero slots are populated")

func test_enabled_with_one_or_more() -> void:
	assert_true(MainMenu.continue_enabled(1), "Continue is enabled with one populated slot")
	assert_true(MainMenu.continue_enabled(5), "Continue stays enabled with several populated slots")

func test_matches_savemanager_on_fresh_profile() -> void:
	# A fresh profile has no saves, so the live binding must resolve disabled (task 16 fills the seams).
	assert_eq(MainMenu.continue_enabled(SaveManager.populated_count()), false,
		"On a fresh profile the live binding is disabled")
