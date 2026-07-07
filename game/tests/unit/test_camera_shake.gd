extends GutTest
## Task 21 pure seams (FR-21-3 juice + FR-21-1 aim-assist): CameraShake trauma math and PlayerCombat's
## aim-assist geometry. Both are deterministic and headless — the node glue that applies them lives on
## PlayerController / PlayerCombat. See docs/tasks/21_release_polish.md.

# --- CameraShake -----------------------------------------------------------
func test_shake_magnitude_is_quadratic() -> void:
	assert_almost_eq(CameraShake.shake_magnitude(0.0), 0.0, 0.0001, "no trauma → no shake")
	assert_almost_eq(CameraShake.shake_magnitude(0.5), 0.25, 0.0001, "shake is trauma² (quadratic falloff)")
	assert_almost_eq(CameraShake.shake_magnitude(1.0), 1.0, 0.0001, "full trauma → full shake")
	assert_almost_eq(CameraShake.shake_magnitude(2.0), 1.0, 0.0001, "trauma clamps at 1")

func test_decay_reduces_and_floors_at_zero() -> void:
	assert_almost_eq(CameraShake.decay(1.0, 2.0, 0.5), 0.0, 0.0001, "decays linearly at rate·dt")
	assert_almost_eq(CameraShake.decay(0.5, 2.0, 0.1), 0.3, 0.0001, "partial decay")
	assert_almost_eq(CameraShake.decay(0.1, 2.0, 1.0), 0.0, 0.0001, "never dips below 0")

func test_tick_is_zero_without_trauma() -> void:
	var cs := CameraShake.new()
	var out := cs.tick(0.016)
	assert_eq(out["rot"], Vector3.ZERO, "no trauma → zero additive rotation")
	assert_eq(out["ofs"], Vector2.ZERO, "no trauma → zero additive offset")

func test_add_trauma_accumulates_and_clamps() -> void:
	var cs := CameraShake.new()
	cs.add_trauma(0.4)
	assert_almost_eq(cs.trauma, 0.4, 0.0001, "trauma accumulates")
	cs.add_trauma(1.0)
	assert_almost_eq(cs.trauma, 1.0, 0.0001, "trauma clamps to max_trauma")

func test_tick_decays_trauma_over_time() -> void:
	var cs := CameraShake.new()
	cs.decay_per_sec = 2.0
	cs.add_trauma(1.0)
	cs.tick(0.25)
	assert_almost_eq(cs.trauma, 0.5, 0.0001, "tick bleeds trauma off at decay_per_sec")

# --- PlayerCombat.assist_aim (loud aim-assist) -----------------------------
func test_assist_aim_snaps_when_within_cap() -> void:
	var aim := Vector3(0, 0, -1)
	var target := Vector3(0.05, 0, -1)   # a few degrees off the aim
	var out := PlayerCombat.assist_aim(aim, target, 10.0)
	assert_almost_eq(out.angle_to(target.normalized()), 0.0, 0.001,
		"a target within the cap is snapped onto")

func test_assist_aim_caps_the_nudge_for_far_targets() -> void:
	var aim := Vector3(0, 0, -1)
	var target := Vector3(1, 0, 0)   # 90° away
	var out := PlayerCombat.assist_aim(aim, target, 6.0)
	assert_almost_eq(rad_to_deg(aim.angle_to(out)), 6.0, 0.1, "a far target moves the aim by at most the cap")
	assert_lt(out.angle_to(target), aim.angle_to(target), "…and the nudge is toward the target")

func test_assist_aim_ignores_degenerate_input() -> void:
	var aim := Vector3(0, 0, -1)
	assert_eq(PlayerCombat.assist_aim(aim, Vector3.ZERO, 6.0), aim,
		"a zero-length target direction leaves the aim unchanged")
