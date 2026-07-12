extends GutTest
## Spec (misc-fixes-3 issue 1): an alarm turns the whole floor and the level runs a mission-scoped alert
## lifecycle CALM → PURSUIT → ALERTED. Losing all detection contact for pursuit_lost_timeout seconds ends
## the pursuit (phase 0), which de-latches every sensor, stands guards down to patrol, and leaves the level
## permanently ALERTED (sharper senses); a fresh alarm re-escalates. Covers the pure seams + the live
## signal wiring. docs/tasks/10_going_loud_pursuit.md, docs/tasks/05_ai_actors.md.

const AI := GuardAI.AIState
const S := DetectionSensor.DetectionState

var _phase_probe := Callable()

func after_each() -> void:
	# These exercise the real RunManager autoload — reset it so suites stay order-independent.
	RunManager.alert_state = RunManager.AlertState.CALM
	RunManager.committed = false
	RunManager.heat = 0.0
	# …and never leave a probe connected to the frozen EventBus behind us.
	if not _phase_probe.is_null() and EventBus.pursuit_phase_changed.is_connected(_phase_probe):
		EventBus.pursuit_phase_changed.disconnect(_phase_probe)
	_phase_probe = Callable()

# --- Pure seams ------------------------------------------------------------
func test_has_contact_counts_any_nonzero_fill() -> void:
	assert_false(PursuitDirector.has_contact([]), "no sensors at all → no contact")
	assert_false(PursuitDirector.has_contact([0.0, 0.0]), "empty meters → no contact")
	assert_true(PursuitDirector.has_contact([0.0, 0.01]), "even a partial sighting counts as contact")

func test_lost_timer_resets_on_contact_and_accumulates_without() -> void:
	assert_eq(PursuitDirector.step_lost_timer(9.0, 0.5, true), 0.0, "contact re-arms the timer")
	assert_almost_eq(PursuitDirector.step_lost_timer(9.0, 0.5, false), 9.5, 0.0001, "no contact accumulates")

func test_guards_ignore_silent_alarms_only() -> void:
	assert_true(GuardAI.responds_to_alarm("loud"), "a loud alarm turns the floor")
	assert_true(GuardAI.responds_to_alarm("camera"), "a camera spot turns the floor")
	assert_false(GuardAI.responds_to_alarm("silent"),
		"a silent alarm is a police-only response — guards must not visibly converge")

# --- RunManager lifecycle --------------------------------------------------
func test_alarm_enters_pursuit_and_timeout_enters_alerted() -> void:
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	assert_eq(RunManager.alert_state, RunManager.AlertState.PURSUIT, "an alarm starts an active hunt")
	RunManager.enter_alerted()
	assert_eq(RunManager.alert_state, RunManager.AlertState.ALERTED, "losing contact leaves the level on edge")
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	assert_eq(RunManager.alert_state, RunManager.AlertState.PURSUIT, "a fresh alarm re-escalates to a full pursuit")

func test_mission_entry_resets_the_alert_state() -> void:
	RunManager.alert_state = RunManager.AlertState.ALERTED
	RunManager.reset_mission_tracking()
	assert_eq(RunManager.alert_state, RunManager.AlertState.CALM, "every mission starts calm")

# --- PursuitDirector: the lost-contact timer -------------------------------
func _director(timeout: float) -> PursuitDirector:
	var d := PursuitDirector.new()
	var cfg := PursuitConfigDef.new()
	cfg.phase_durations = [0.0, 30.0, 30.0, 0.0]
	cfg.pursuit_lost_timeout = timeout
	d.config = cfg
	add_child_autofree(d)
	return d

func test_no_contact_for_the_timeout_ends_the_pursuit() -> void:
	var d := _director(1.0)
	var phases: Array[int] = []
	_phase_probe = func(p: int) -> void: phases.append(p)
	EventBus.pursuit_phase_changed.connect(_phase_probe)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	assert_true(d.active, "the alarm armed the timeline")
	d._process(0.6)
	assert_true(d.active, "still hunting inside the window")
	d._process(0.6)
	assert_false(d.active, "no contact for pursuit_lost_timeout ends the pursuit")
	assert_eq(d.phase, 0, "the level drops to phase 0")
	assert_eq(RunManager.alert_state, RunManager.AlertState.ALERTED, "and stays ALERTED for the rest of the mission")
	assert_eq(phases, [1, 0] as Array[int],
		"phase 0 is the mission-wide 'pursuit ended' broadcast sensors + guards key off")

func test_a_sensor_holding_contact_pins_the_lost_timer() -> void:
	var d := _director(1.0)
	var sensor: DetectionSensor = add_child_autofree(DetectionSensor.new())
	sensor.fill = 1.0   # staring right at the player: throttled + latched, so it emits NOTHING (discovery.md #4)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	for _i in 5:
		d._process(0.5)
	assert_true(d.active, "steady contact must keep the pursuit alive — this is the mid-firefight case")

func test_ending_the_pursuit_requests_no_reinforcements() -> void:
	var d := _director(1.0)
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	watch_signals(d)
	d._process(1.5)
	assert_signal_not_emitted(d, "reinforcements_requested", "phase 0 has a zero spawn budget")

# --- DetectionSensor / CameraEye de-latch ----------------------------------
func test_sensor_delatches_on_the_phase_zero_broadcast() -> void:
	var sensor: DetectionSensor = add_child_autofree(DetectionSensor.new())
	sensor.config = DetectionConfigDef.new()
	sensor.fill = 0.9
	sensor.has_target = true
	sensor._update_state()
	assert_eq(sensor.state, S.ALERTED, "the sensor committed to Alerted")
	EventBus.pursuit_phase_changed.emit(0)
	assert_eq(sensor.state, S.UNAWARE, "the pursuit ending drops the latch")
	assert_eq(sensor.fill, 0.0, "and empties the meter")

func test_camera_can_raise_a_fresh_alarm_after_a_pursuit_ends() -> void:
	var eye: CameraEye = add_child_autofree(CameraEye.new())
	eye.config = DetectionConfigDef.new()
	eye._alarm_raised = true            # it already alarmed once this mission
	EventBus.pursuit_phase_changed.emit(0)
	assert_false(eye._alarm_raised, "the camera re-arms once the pursuit is called off (discovery.md #1)")

func test_alerted_sharpens_the_senses() -> void:
	var sensor: DetectionSensor = add_child_autofree(DetectionSensor.new())
	var cfg := DetectionConfigDef.new()
	cfg.alerted_gain_mult = 2.0
	cfg.alerted_range_mult = 1.5
	sensor.config = cfg
	assert_eq(sensor._gain_mult(), 1.0, "a calm level senses normally")
	assert_eq(sensor._range_mult(), 1.0, "a calm level sees its normal distance")
	RunManager.alert_state = RunManager.AlertState.PURSUIT
	assert_eq(sensor._gain_mult(), 1.0, "an ACTIVE pursuit must not tip its hand (a silent alarm armed it)")
	RunManager.alert_state = RunManager.AlertState.ALERTED
	assert_eq(sensor._gain_mult(), 2.0, "a shaken-off pursuit leaves guards filling faster")
	assert_eq(sensor._range_mult(), 1.5, "and seeing further")

# --- GuardAI: converge, keep hunting, stand down ---------------------------
func _guard() -> GuardAI:
	var g: GuardAI = add_child_autofree(GuardAI.new())
	var sensor: DetectionSensor = DetectionSensor.new()
	sensor.config = DetectionConfigDef.new()
	g.add_child(sensor)
	g._resolve_sensor()
	return g

func test_guard_converges_on_a_loud_alarm_and_ignores_a_silent_one() -> void:
	var g := _guard()
	g._on_alarm_tripped("silent", Vector3(9, 0, 9))
	assert_eq(g.ai_state, AI.PATROL, "a silent alarm leaves the guard on its route")
	g._on_alarm_tripped("camera", Vector3(9, 0, 9))
	assert_eq(g.ai_state, AI.INVESTIGATE, "a camera alarm sends the guard to the alarm spot")
	assert_eq(g._investigate_target, Vector3(9, 0, 9), "it knows the ALARM location, not the player's")

func test_guard_stands_down_when_the_pursuit_ends() -> void:
	var g := _guard()
	g._set_ai_state(AI.COMBAT)
	g._on_pursuit_phase_changed(0)
	assert_eq(g.ai_state, AI.PATROL, "phase 0 is the COMBAT exit the state machine never had")

func test_guard_with_live_contact_does_not_stand_down() -> void:
	var g := _guard()
	g._set_ai_state(AI.COMBAT)
	g._sensor.fill = 0.4   # still seeing something
	g._on_pursuit_phase_changed(0)
	assert_eq(g.ai_state, AI.COMBAT, "a guard that still has eyes on you keeps fighting")
