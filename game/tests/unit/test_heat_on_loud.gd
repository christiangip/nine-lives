extends GutTest
## Task 10 (FR-10-3): going loud raises Heat for the remainder of the Streak and commits it (strict
## saves). RunManager listens for EventBus.alarm_tripped and raises Heat by the PursuitConfigDef amount.

func before_each() -> void:
	RunManager.heat = 0.0
	RunManager.committed = false

func test_loud_alarm_raises_heat_and_commits() -> void:
	watch_signals(EventBus)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	assert_gt(RunManager.heat, 0.0, "going loud raises Heat")
	assert_true(RunManager.committed, "an alarm commits the Streak (no mid-mission save-scum)")
	assert_signal_emitted(EventBus, "heat_changed")

func test_raise_heat_clamps_to_one() -> void:
	RunManager.raise_heat(2.0)
	assert_almost_eq(RunManager.heat, 1.0, 0.001, "Heat ceilings at 1.0")

func test_raise_heat_ignores_non_positive() -> void:
	RunManager.raise_heat(0.0)
	assert_eq(RunManager.heat, 0.0, "a zero raise is a no-op")

func test_silent_alarm_raises_less_than_loud() -> void:
	RunManager.heat = 0.0
	EventBus.alarm_tripped.emit("silent", Vector3.ZERO)
	var silent := RunManager.heat
	RunManager.heat = 0.0
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	var loud := RunManager.heat
	assert_lt(silent, loud, "a silent alarm raises Heat less than a loud one")
