extends GutTest
## Spec: the detection fill rate is faster when the target is closer, lit, standing, and
## running than when it is far, in shadow, prone, and still (FR-04-2). All ordered, pure,
## deterministic. docs/tasks/04_stealth_detection.md.

var _sensor: DetectionSensor
var _player: PlayerController

func before_each() -> void:
	_sensor = DetectionSensor.new()
	var cfg := DetectionConfigDef.new()
	cfg.see_gain_rate = 1.0
	cfg.distance_falloff_exp = 1.0
	cfg.min_light_factor = 0.25
	cfg.walk_speed = 1.5
	cfg.run_speed = 4.0
	cfg.still_factor = 0.55
	cfg.walk_factor = 0.8
	cfg.run_factor = 1.0
	_sensor.config = cfg

	_player = PlayerController.new()
	var pcfg := PlayerConfigDef.new()
	pcfg.stand_visibility = 1.0
	pcfg.crouch_visibility = 0.6
	pcfg.prone_visibility = 0.35
	_player.config = pcfg

func after_each() -> void:
	_sensor.free()
	_player.free()

func test_closer_fills_faster_than_far() -> void:
	var near := _sensor.compute_fill_rate(_sensor.distance_factor(2.0, 14.0), 1.0, 1.0, 1.0, 1.0)
	var far := _sensor.compute_fill_rate(_sensor.distance_factor(12.0, 14.0), 1.0, 1.0, 1.0, 1.0)
	assert_gt(near, far, "a closer target fills the meter faster")

func test_lit_fills_faster_than_shadow() -> void:
	var lit := _sensor.compute_fill_rate(1.0, 1.0, 1.0, 1.0, 1.0)
	var shadow := _sensor.compute_fill_rate(1.0, _sensor.config.min_light_factor, 1.0, 1.0, 1.0)
	assert_gt(lit, shadow, "a lit target fills faster than one in shadow")

func test_stance_orders_stand_crouch_prone() -> void:
	var stand := _sensor.compute_fill_rate(1.0, 1.0, _player.detection_profile(PlayerController.Stance.STAND), 1.0, 1.0)
	var crouch := _sensor.compute_fill_rate(1.0, 1.0, _player.detection_profile(PlayerController.Stance.CROUCH), 1.0, 1.0)
	var prone := _sensor.compute_fill_rate(1.0, 1.0, _player.detection_profile(PlayerController.Stance.PRONE), 1.0, 1.0)
	assert_gt(stand, crouch, "standing fills faster than crouching")
	assert_gt(crouch, prone, "crouching fills faster than prone")

func test_movement_orders_run_walk_still() -> void:
	var run := _sensor.compute_fill_rate(1.0, 1.0, 1.0, _sensor.movement_factor(5.0), 1.0)
	var walk := _sensor.compute_fill_rate(1.0, 1.0, 1.0, _sensor.movement_factor(2.0), 1.0)
	var still := _sensor.compute_fill_rate(1.0, 1.0, 1.0, _sensor.movement_factor(0.5), 1.0)
	assert_gt(run, walk, "running fills faster than walking")
	assert_gt(walk, still, "walking fills faster than standing still")

func test_partial_cover_reduces_fill() -> void:
	var clear := _sensor.compute_fill_rate(1.0, 1.0, 1.0, 1.0, 1.0)
	var partial := _sensor.compute_fill_rate(1.0, 1.0, 1.0, 1.0, 0.5)
	assert_gt(clear, partial, "partial cover (lower visibility fraction) reduces the fill rate")

func test_full_cover_zero_visibility_no_fill() -> void:
	assert_eq(_sensor.compute_fill_rate(1.0, 1.0, 1.0, 1.0, 0.0), 0.0,
		"full cover (zero visibility) produces no fill")
