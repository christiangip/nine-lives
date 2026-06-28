extends GutTest
## Spec: Main Menu "Continue" is enabled IFF >=1 valid save exists.
## docs/tasks/16_save_system.md, GDD §15.1 / §16.3.

func test_scan_returns_ten_slots() -> void:
	var slots = SaveManager.scan_slots()
	assert_eq(slots.size(), SaveManager.SLOT_COUNT, "scan_slots() must return 10 entries")

func test_continue_disabled_when_empty() -> void:
	# With no saves, populated_count() == 0 -> Continue disabled.
	assert_eq(SaveManager.populated_count(), 0, "Fresh profile has zero populated slots")
