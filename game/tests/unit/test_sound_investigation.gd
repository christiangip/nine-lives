extends GutTest
## Spec: a noise inside the hearing radius bumps suspicion toward the source and flips an
## Unaware sensor to Suspicious; a noise out of range does nothing; sound alone never fully
## spots (capped below Alerted) (FR-04-4). docs/tasks/04_stealth_detection.md.

const S := DetectionSensor.DetectionState

var _sensor: DetectionSensor

func before_each() -> void:
	_sensor = DetectionSensor.new()
	var cfg := DetectionConfigDef.new()
	cfg.sound_gain = 0.4
	cfg.sound_fill_cap = 0.6
	cfg.suspicious_threshold = 0.2
	cfg.searching_threshold = 0.5
	cfg.alerted_threshold = 0.85
	_sensor.config = cfg
	_sensor.hearing_radius = 8.0

func after_each() -> void:
	_sensor.free()

# --- Hearing falloff (pure) ------------------------------------------------
func test_noise_in_range_bumps_more_when_closer() -> void:
	var near := _sensor.hearing_bump(6.0, Vector3(1, 0, 0), Vector3.ZERO, 8.0, 0.4)
	var far := _sensor.hearing_bump(6.0, Vector3(7, 0, 0), Vector3.ZERO, 8.0, 0.4)
	assert_gt(near, 0.0, "a noise inside the reach produces a bump")
	assert_gt(near, far, "a closer noise bumps suspicion more")

func test_noise_out_of_range_no_bump() -> void:
	# Reach = max(noise radius 4, hearing 8) = 8; a source 12m away is out of range.
	var bump := _sensor.hearing_bump(4.0, Vector3(12, 0, 0), Vector3.ZERO, 8.0, 0.4)
	assert_eq(bump, 0.0, "a noise beyond reach produces no bump")

# --- Loudness (pure; misc-fixes-3 follow-up) --------------------------------
## The player's noise levers (stance / Silence / soft-soled gear / floor surface) all scale the emitted
## RADIUS. Before loudness_factor, that radius only ever widened the reach — and since a footstep's radius
## never exceeds a guard's hearing radius, a prone crawl filled a guard's meter exactly as fast as a
## standing walk. Quieter must mean slower-to-notice, or none of those levers buy anything.
func test_a_quieter_noise_registers_less() -> void:
	var walk := DetectionSensor.loudness_factor(6.6, 8.0)    # standing walk
	var crouch := DetectionSensor.loudness_factor(3.3, 8.0)  # crouch-walk
	var prone := DetectionSensor.loudness_factor(1.65, 8.0)  # prone crawl
	assert_gt(walk, crouch, "a crouch-step registers less than a standing step")
	assert_gt(crouch, prone, "a prone crawl registers less still")
	assert_almost_eq(crouch, 0.41, 0.01, "and it scales linearly with the noise radius")

func test_a_loud_noise_saturates() -> void:
	assert_eq(DetectionSensor.loudness_factor(11.2, 8.0), 1.0, "a sprint lands the full bump")
	assert_eq(DetectionSensor.loudness_factor(30.0, 8.0), 1.0, "a gunshot can't exceed it")

func test_quiet_movement_builds_the_meter_more_slowly() -> void:
	var sensor := _live_sensor()
	EventBus.noise_emitted.emit(Vector3(2, 0, 0), 6.6, "footstep")   # a standing step, 2 m away
	var loud_fill := sensor.fill
	sensor.fill = 0.0
	EventBus.noise_emitted.emit(Vector3(2, 0, 0), 3.3, "footstep")   # a crouch-step from the same spot
	assert_gt(loud_fill, sensor.fill,
		"the same step taken quietly takes longer to be noticed — the whole point of crouching")

# --- Signal-driven investigation (integration) -----------------------------
## A live sensor added to the tree (so _ready subscribes to EventBus.noise_emitted).
## Built locally + add_child_autofree so GUT owns its lifetime (member _sensor is for the
## pure tests and is freed in after_each — adding it here would double-free).
func _live_sensor() -> DetectionSensor:
	var sensor := DetectionSensor.new()
	var cfg := DetectionConfigDef.new()
	cfg.sound_gain = 0.4
	cfg.sound_fill_cap = 0.6
	cfg.suspicious_threshold = 0.2
	cfg.searching_threshold = 0.5
	cfg.alerted_threshold = 0.85
	sensor.config = cfg
	sensor.hearing_radius = 8.0
	add_child_autofree(sensor)
	sensor.global_position = Vector3.ZERO
	return sensor

func test_audible_noise_flips_unaware_to_suspicious() -> void:
	var sensor := _live_sensor()
	var src := Vector3(2, 0, 0)
	EventBus.noise_emitted.emit(src, 6.0, "footstep")
	assert_eq(sensor.state, S.SUSPICIOUS, "an audible noise flips the sensor to Suspicious")
	assert_eq(sensor.last_heard_position, src, "the sensor records the noise source to investigate")

func test_distant_noise_leaves_sensor_unaware() -> void:
	var sensor := _live_sensor()
	EventBus.noise_emitted.emit(Vector3(40, 0, 0), 6.0, "footstep")
	assert_eq(sensor.state, S.UNAWARE, "a distant noise leaves the sensor Unaware")

func test_sound_alone_never_fully_spots() -> void:
	var sensor := _live_sensor()
	# Hammer many point-blank noises; fill must cap below Alerted.
	for i in range(20):
		EventBus.noise_emitted.emit(Vector3.ZERO, 8.0, "drill")
	assert_lte(sensor.fill, sensor.config.sound_fill_cap + 0.0001,
		"sound alone is capped and cannot fully spot the player")
	assert_ne(sensor.state, S.ALERTED, "sound alone never reaches Alerted")
