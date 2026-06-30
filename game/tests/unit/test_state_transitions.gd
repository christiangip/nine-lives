extends GutTest
## Spec: fill thresholds drive Unaware↔Suspicious↔Searching↔Alerted; Suspicious/Searching
## recover as fill decays; Alerted latches (full detection commits to alert); detection_changed
## fires on a state change (FR-04-3). docs/tasks/04_stealth_detection.md.

const S := DetectionSensor.DetectionState

var _sensor: DetectionSensor

func before_each() -> void:
	_sensor = DetectionSensor.new()
	var cfg := DetectionConfigDef.new()
	cfg.suspicious_threshold = 0.2
	cfg.searching_threshold = 0.5
	cfg.alerted_threshold = 0.85
	_sensor.config = cfg

func after_each() -> void:
	_sensor.free()

func test_state_for_fill_bands() -> void:
	assert_eq(_sensor.state_for_fill(0.0), S.UNAWARE, "empty meter is Unaware")
	assert_eq(_sensor.state_for_fill(0.3), S.SUSPICIOUS, "past the suspicious threshold is Suspicious")
	assert_eq(_sensor.state_for_fill(0.6), S.SEARCHING, "past the searching threshold is Searching")
	assert_eq(_sensor.state_for_fill(0.9), S.ALERTED, "past the alerted threshold is Alerted")

func test_rising_through_bands() -> void:
	assert_eq(_sensor.step_state(S.UNAWARE, 0.25), S.SUSPICIOUS, "rising fill escalates Unaware→Suspicious")
	assert_eq(_sensor.step_state(S.SUSPICIOUS, 0.6), S.SEARCHING, "rising fill escalates Suspicious→Searching")
	assert_eq(_sensor.step_state(S.SEARCHING, 0.9), S.ALERTED, "rising fill escalates Searching→Alerted")

func test_suspicious_and_searching_recover() -> void:
	assert_eq(_sensor.step_state(S.SUSPICIOUS, 0.0), S.UNAWARE, "Suspicious recovers to Unaware as fill decays")
	assert_eq(_sensor.step_state(S.SEARCHING, 0.3), S.SUSPICIOUS, "Searching steps back to Suspicious as fill decays")

func test_alerted_latches() -> void:
	assert_eq(_sensor.step_state(S.ALERTED, 0.0), S.ALERTED, "Alerted does not auto-recover even at empty fill")
	assert_eq(_sensor.step_state(S.PURSUIT, 0.0), S.PURSUIT, "Pursuit also latches")

func test_detection_changed_fires_on_change() -> void:
	watch_signals(EventBus)
	_sensor.fill = 0.3
	_sensor._update_state()
	assert_signal_emitted(EventBus, "detection_changed",
		"a state change emits detection_changed")
	assert_eq(_sensor.state, S.SUSPICIOUS, "the sensor advanced to Suspicious")

func test_player_spotted_fires_on_alerted() -> void:
	watch_signals(EventBus)
	_sensor.fill = 0.9
	_sensor._update_state()
	assert_signal_emitted(EventBus, "player_spotted",
		"entering Alerted emits player_spotted")
