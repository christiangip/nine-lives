extends GutTest
## Spec: the hack overlay runs a SOFT TIMER that fails when it expires and PAUSES while the hacker is
## out of proximity; the Hacking attribute adds fault tolerance and a higher tier tightens the timer
## (FR-07-2/5, Phase 07.2). docs/tasks/07_minigames.md, GDD §9.2.

func test_soft_timer_expiry_fails() -> void:
	assert_false(HackMinigame.is_expired(3.0, 8.0), "time left, still going")
	assert_true(HackMinigame.is_expired(8.0, 8.0), "hit the limit = fail")
	assert_true(HackMinigame.is_expired(9.5, 8.0), "past the limit = fail")

func test_out_of_range_pauses_the_timer() -> void:
	assert_almost_eq(HackMinigame.tick_timer(2.0, 0.5, true), 2.5, 0.0001, "advances in range")
	assert_almost_eq(HackMinigame.tick_timer(2.0, 0.5, false), 2.0, 0.0001, "holds out of range (pause, not reset)")

func test_proximity_gate() -> void:
	assert_true(HackMinigame.in_proximity(2.0, 3.0), "inside range")
	assert_false(HackMinigame.in_proximity(4.0, 3.0), "outside range")

func test_hacking_adds_fault_tolerance() -> void:
	assert_eq(HackMinigame.fault_budget(0.0, 0.0, 0.34), 0, "no skill = no mistakes allowed")
	assert_eq(HackMinigame.fault_budget(0.0, 3.0, 0.34), 1, "~1 fault per 3 levels")
	assert_eq(HackMinigame.fault_budget(0.0, 9.0, 0.34), 3, "scales up")

func test_time_limit_tightens_with_tier_but_floors() -> void:
	assert_almost_eq(HackMinigame.time_limit_for_tier(8.0, 1, 1.5, 2.5), 8.0, 0.0001, "tier 1 = base")
	assert_almost_eq(HackMinigame.time_limit_for_tier(8.0, 3, 1.5, 2.5), 5.0, 0.0001, "8 - 2*1.5")
	assert_almost_eq(HackMinigame.time_limit_for_tier(8.0, 20, 1.5, 2.5), 2.5, 0.0001, "floored")

func test_node_count_grows_with_tier() -> void:
	assert_eq(HackMinigame.node_count_for_tier(4, 1, 1), 4)
	assert_eq(HackMinigame.node_count_for_tier(4, 3, 1), 6)
