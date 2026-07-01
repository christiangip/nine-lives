extends GutTest
## Spec: the Lockpicking attribute WIDENS the give arc and (via the Lock obstacle) LOWERS snap odds,
## while a higher difficulty tier narrows the arc — floored so it stays fair (FR-07-2/3, Phase 07.2).
## docs/tasks/07_minigames.md, GDD §9.8.

func test_higher_lockpicking_widens_the_arc() -> void:
	var lo := LockpickMinigame.sweet_spot_width(20.0, 0.0, 2.0)
	var hi := LockpickMinigame.sweet_spot_width(20.0, 5.0, 2.0)
	assert_gt(hi, lo, "more Lockpicking = a wider give")
	assert_almost_eq(hi, 30.0, 0.0001, "20 + 5*2")

func test_tier_narrows_but_floors() -> void:
	assert_almost_eq(LockpickMinigame.arc_base_for_tier(25.0, 1, 4.0, 6.0), 25.0, 0.0001, "tier 1 = base")
	assert_almost_eq(LockpickMinigame.arc_base_for_tier(25.0, 3, 4.0, 6.0), 17.0, 0.0001, "25 - 2*4")
	assert_almost_eq(LockpickMinigame.arc_base_for_tier(25.0, 20, 4.0, 6.0), 6.0, 0.0001, "floored, never impossible")

func test_in_sweet_spot_wraps_across_180() -> void:
	assert_true(LockpickMinigame.is_in_sweet_spot(170.0, -175.0, 20.0), "15° apart across the ±180 seam")
	assert_true(LockpickMinigame.is_in_sweet_spot(90.0, 90.0, 5.0), "dead centre")
	assert_false(LockpickMinigame.is_in_sweet_spot(0.0, 90.0, 20.0), "well outside")

func test_snap_odds_drop_with_lockpicking() -> void:
	# The snap half lives on the Lock obstacle (task 06); the overlay relies on this scaling.
	assert_gt(Lock.snap_chance(0.25, 0.0, 0.03), Lock.snap_chance(0.25, 5.0, 0.03),
		"more Lockpicking = fewer snaps")
