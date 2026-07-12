extends GutTest
## Spec (misc-fixes-3 issue 8): footfalls accumulate DISTANCE, not time. The old time-based version reset
## its accumulator whenever the player was nearly still, so tapping a move key crossed a room in silence
## while a held key could spam the interval. Now every metre travelled counts toward the next step.
## docs/tasks/03_player_controller_camera.md (FR-03-6).

const STRIDE := 1.6

func test_a_full_stride_emits_one_step_and_carries_the_remainder() -> void:
	var r := PlayerController.accumulate_step(0.0, 2.0, STRIDE)
	assert_true(bool(r[0]), "crossing the stride emits a footstep")
	assert_almost_eq(float(r[1]), 0.4, 0.0001, "the overshoot carries into the next step (cadence never drifts)")

func test_travel_below_the_stride_stays_silent() -> void:
	var r := PlayerController.accumulate_step(0.0, 0.5, STRIDE)
	assert_false(bool(r[0]), "half a stride makes no noise yet")
	assert_almost_eq(float(r[1]), 0.5, 0.0001, "but the ground covered is remembered")

func test_tapping_eventually_makes_noise_exactly_once() -> void:
	# Eight taps of 0.25 m: the old time-based accumulator reset on every stop → total silence.
	var accum := 0.0
	var emits := 0
	for _i in 8:
		var r := PlayerController.accumulate_step(accum, 0.25, STRIDE)
		accum = float(r[1])
		if bool(r[0]):
			emits += 1
	assert_eq(emits, 1, "2.0 m covered in taps is one footstep — you can't stutter-step in silence")

func test_zero_distance_adds_nothing() -> void:
	var r := PlayerController.accumulate_step(1.2, 0.0, STRIDE)
	assert_false(bool(r[0]), "standing still never emits")
	assert_almost_eq(float(r[1]), 1.2, 0.0001, "and the accumulator is HELD, not reset — taps carry over")

## Issue 3, corrected: the ASK was "a footstep should generate less noise so guards take longer to notice",
## NOT "shrink the noise ring". The ring (base_step_radius) is the audibility/readability read and stays as
## authored; how fast a guard's meter fills is DetectionSensor.loudness_factor's job (test_sound_investigation).
func test_the_noise_ring_is_not_shrunk() -> void:
	var cfg := PlayerConfigDef.new()
	assert_almost_eq(cfg.base_step_radius, 6.0, 0.0001,
		"the on-world noise ring keeps its authored size — detection strength is tuned on the sensor, not here")
