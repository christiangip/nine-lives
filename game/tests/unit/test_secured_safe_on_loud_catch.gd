extends GutTest
## Task 10 (FR-10-8): value already secured/banked (task 08) is safe even when the Streak ends in a
## loud Catch — going loud and the Catch handoff must not roll back accrued Notoriety/Take.

func before_each() -> void:
	RunManager.notoriety = 0
	RunManager.take = 0
	RunManager.heat = 0.0
	RunManager.committed = false

func test_secured_value_survives_a_loud_catch() -> void:
	RunManager.add_notoriety(500)   # a secured haul banked its Notoriety (task 08)
	RunManager.add_take(300)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)   # going loud
	assert_true(RunManager.committed, "the Streak is committed")
	assert_gt(RunManager.heat, 0.0, "Heat rose")
	var _legacy := RunManager.end_streak("caught")      # the Catch (task 12 owns the conversion)
	assert_eq(RunManager.notoriety, 500, "already-secured Notoriety is intact at the Catch")
	assert_eq(RunManager.take, 300, "and secured Take too")
