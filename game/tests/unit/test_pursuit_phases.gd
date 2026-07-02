extends GutTest
## Task 10 (FR-10-1/FR-10-2): the Pursuit timeline arms on an alarm and escalates phases 0..5 on a
## response timer; silent alarms can skip ahead of loud's phase 1. Covers PursuitDirector's pure
## seams + one live signal-driven arm/emit.

func test_start_phase_loud_starts_local() -> void:
	assert_eq(PursuitDirector.start_phase("loud", 2), 1, "a loud alarm starts at phase 1 (local guards)")

func test_start_phase_silent_skips_ahead() -> void:
	assert_eq(PursuitDirector.start_phase("silent", 2), 2, "a silent alarm skips the timeline ahead")

func test_next_phase_advances_when_dwell_spent() -> void:
	var durs: Array = [0.0, 10.0, 10.0, 0.0]
	assert_eq(PursuitDirector.next_phase(1, 9.9, durs), 1, "still within the dwell time")
	assert_eq(PursuitDirector.next_phase(1, 10.0, durs), 2, "dwell spent -> escalate")

func test_terminal_phase_tops_out() -> void:
	var durs: Array = [0.0, 10.0, 0.0]   # phase 2 has duration 0 = terminal
	assert_eq(PursuitDirector.next_phase(2, 999.0, durs), 2, "the tactical phase tops out")

func test_spawn_budget_and_tier_ladder() -> void:
	assert_eq(PursuitDirector.spawn_budget_for(2, [0, 1, 2, 3]), 2)
	assert_eq(PursuitDirector.spawn_budget_for(9, [0, 1]), 0, "out-of-range phase -> 0")
	assert_eq(PursuitDirector.tier_for(1, [&"", &"guard", &"swat"]), &"guard")
	assert_eq(PursuitDirector.tier_for(9, [&"", &"guard"]), &"", "out-of-range phase -> empty")

func test_alarm_arms_the_director_and_emits_phase() -> void:
	var d := PursuitDirector.new()
	var cfg := PursuitConfigDef.new()
	cfg.phase_durations = [0.0, 0.05, 0.0]
	cfg.silent_skip_phase = 2
	d.config = cfg
	add_child_autofree(d)
	watch_signals(EventBus)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	assert_true(d.active, "the first alarm arms the timeline")
	assert_eq(d.phase, 1, "loud alarm -> phase 1")
	assert_signal_emitted(EventBus, "pursuit_phase_changed")

func test_silent_alarm_can_jump_the_active_timeline_ahead() -> void:
	var d := PursuitDirector.new()
	var cfg := PursuitConfigDef.new()
	cfg.phase_durations = [0.0, 30.0, 30.0, 0.0]
	cfg.silent_skip_phase = 2
	d.config = cfg
	add_child_autofree(d)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)     # -> phase 1
	EventBus.alarm_tripped.emit("silent", Vector3.ZERO)   # jumps ahead to phase 2
	assert_eq(d.phase, 2, "a silent alarm skips the active timeline ahead")
