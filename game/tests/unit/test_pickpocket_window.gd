extends GutTest
## Spec: the Pickpocketing attribute WIDENS the safe-zone window and a warier mark (higher tier)
## narrows it — floored so it stays catchable; a stop inside the window succeeds (FR-07-2/7, Phase
## 07.4). docs/tasks/07_minigames.md, GDD §9.7.

func test_pickpocketing_widens_the_window() -> void:
	var lo := PickpocketMinigame.window_width(0.18, 0.0, 0.02)
	var hi := PickpocketMinigame.window_width(0.18, 5.0, 0.02)
	assert_gt(hi, lo, "more Pickpocketing = a bigger safe zone")
	assert_almost_eq(hi, 0.28, 0.0001, "0.18 + 5*0.02")

func test_tier_narrows_but_floors() -> void:
	assert_almost_eq(PickpocketMinigame.window_base_for_tier(0.18, 1, 0.02, 0.04), 0.18, 0.0001, "tier 1 = base")
	assert_almost_eq(PickpocketMinigame.window_base_for_tier(0.18, 3, 0.02, 0.04), 0.14, 0.0001, "0.18 - 2*0.02")
	assert_almost_eq(PickpocketMinigame.window_base_for_tier(0.18, 20, 0.02, 0.04), 0.04, 0.0001, "floored")

func test_stop_inside_the_window_succeeds() -> void:
	assert_true(PickpocketMinigame.is_in_window(0.5, 0.5, 0.1), "dead centre")
	assert_true(PickpocketMinigame.is_in_window(0.58, 0.5, 0.1), "just inside the edge")
	assert_false(PickpocketMinigame.is_in_window(0.7, 0.5, 0.1), "outside = caught")
