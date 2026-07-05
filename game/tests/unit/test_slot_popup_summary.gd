extends GutTest
## Task 15 FR-15-3: an occupied slot renders the five summary fields (Streak length · total Legacy ·
## playtime · last-played date · last contract); an empty slot reads "Empty." Locks the pure rendering seam
## SlotPopup.format_slot(). The real SaveManager.slot_summary() that feeds it is task 16 (↩ From 15).
## docs/tasks/15_ui_hud_menus.md.

func test_empty_slot_reads_empty() -> void:
	assert_eq(SlotPopup.format_slot({}), "Empty.", "an empty summary dict renders 'Empty.'")

func test_occupied_slot_shows_all_five_fields() -> void:
	var summary := {
		"streak_len": 4,
		"legacy": 12300,
		"playtime": 4800,               # seconds → 1h 20m
		"last_played": "2026-07-04",
		"last_contract": "First National Bank",
	}
	var line := SlotPopup.format_slot(summary)
	assert_string_contains(line, "4")                     # Streak length
	assert_string_contains(line, "12300")                 # total Legacy
	assert_string_contains(line, "1h 20m")                # playtime
	assert_string_contains(line, "2026-07-04")            # last-played date
	assert_string_contains(line, "First National Bank")   # last contract

func test_playtime_formats_hours_minutes() -> void:
	var line := SlotPopup.format_slot({"streak_len": 1, "legacy": 0, "playtime": 3661,
		"last_played": "x", "last_contract": "y"})
	assert_string_contains(line, "1h 01m", "playtime renders as Hh MMm")
