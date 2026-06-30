extends GutTest
## Spec: difficulty tiers scale an EnemyDef on its senses/health/speed axes via a pure copy —
## a higher tier sees wider/farther, hears better, is tougher and faster (FR-05-9).
## docs/tasks/05_ai_actors.md.

func test_scaled_enlarges_senses_and_stats() -> void:
	var base := EnemyDef.new()
	base.vision_angle = 90.0
	base.vision_range = 14.0
	base.hearing_radius = 8.0
	base.health = 100
	base.move_speed = 2.5
	var elite := base.scaled(1.5)
	assert_gt(elite.vision_angle, base.vision_angle, "higher tier sees wider")
	assert_gt(elite.vision_range, base.vision_range, "...and farther")
	assert_gt(elite.hearing_radius, base.hearing_radius, "...and hears better")
	assert_gt(elite.health, base.health, "...and is tougher")
	assert_gt(elite.move_speed, base.move_speed, "...and is faster")

func test_scaled_values_are_exact() -> void:
	var base := EnemyDef.new()
	base.vision_range = 10.0
	base.health = 100
	var s := base.scaled(1.5)
	assert_almost_eq(s.vision_range, 15.0, 0.001, "vision range scales by the multiplier")
	assert_eq(s.health, 150, "health scales and rounds to an int")

func test_scaled_does_not_mutate_base() -> void:
	var base := EnemyDef.new()
	base.vision_range = 14.0
	base.scaled(2.0)
	assert_eq(base.vision_range, 14.0, "scaling returns a copy; the base def is untouched")
