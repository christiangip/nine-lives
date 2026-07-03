extends GutTest
## Task 10 (FR-10-8): value already secured/banked (task 08) is safe even when the Streak ends in a
## loud Catch — going loud and the Catch handoff must not roll back accrued Notoriety/Take.

func before_each() -> void:
	RunManager.notoriety = 0
	RunManager.take = 0
	RunManager.heat = 0.0
	RunManager.committed = false
	RunManager.edges.clear()
	ProgressionManager.legacy = 0

func test_secured_value_survives_a_loud_catch() -> void:
	RunManager.add_notoriety(500)   # a secured haul banked its Notoriety (task 08)
	RunManager.add_take(300)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)   # going loud
	assert_true(RunManager.committed, "the Streak is committed")
	assert_gt(RunManager.heat, 0.0, "Heat rose")
	# The Catch converts the *full* accrued Notoriety into Legacy (task 12) — going loud must not
	# roll back already-secured value. With Heat > 0 the multiplier is > 1, so the payout ≥ 500.
	var legacy := RunManager.end_streak("caught")
	assert_true(legacy >= 500, "the full secured 500 Notoriety converted to Legacy (%d), not rolled back" % legacy)
	assert_eq(ProgressionManager.legacy, legacy, "the payout banked into permanent Legacy")
	assert_eq(RunManager.notoriety, 0, "the Streak reset after the Catch")
	assert_eq(RunManager.take, 0, "The Take resets on the Catch (it doesn't convert — GDD §5.3)")
