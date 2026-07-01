extends GutTest
## Spec: the safe adds wheels at higher tiers and tightens the click cue, while the stethoscope gadget
## and the Hacking attribute both WIDEN that cue — floored so a maxed tier is still fair (FR-07-2/4,
## Phase 07.3). docs/tasks/07_minigames.md, GDD §9.1.

func test_wheels_scale_with_tier() -> void:
	assert_eq(SafeCrackMinigame.wheel_count(3, 1, 1), 3, "tier 1 = base wheels")
	assert_eq(SafeCrackMinigame.wheel_count(3, 3, 1), 5, "two more wheels at tier 3")

func test_stethoscope_and_hacking_widen_the_cue() -> void:
	var base := SafeCrackMinigame.tolerance(6.0, 0.0, 0.0, 0.5)
	var steth := SafeCrackMinigame.tolerance(6.0, 4.0, 0.0, 0.5)
	var skilled := SafeCrackMinigame.tolerance(6.0, 0.0, 4.0, 0.5)
	assert_almost_eq(base, 6.0, 0.0001, "no gear/skill = base cue")
	assert_gt(steth, base, "the stethoscope widens the cue")
	assert_gt(skilled, base, "Hacking widens the cue")
	assert_almost_eq(skilled, 8.0, 0.0001, "6 + 4*0.5")

func test_tier_tightens_but_floors() -> void:
	assert_almost_eq(SafeCrackMinigame.tolerance_base_for_tier(6.0, 1, 1.0, 1.5), 6.0, 0.0001, "tier 1 = base")
	assert_almost_eq(SafeCrackMinigame.tolerance_base_for_tier(6.0, 3, 1.0, 1.5), 4.0, 0.0001, "6 - 2*1")
	assert_almost_eq(SafeCrackMinigame.tolerance_base_for_tier(6.0, 20, 1.0, 1.5), 1.5, 0.0001, "floored")

func test_is_on_number_wraps() -> void:
	assert_true(SafeCrackMinigame.is_on_number(178.0, -179.0, 5.0), "3° apart across the ±180 seam")
	assert_false(SafeCrackMinigame.is_on_number(0.0, 45.0, 5.0), "way off the number")
