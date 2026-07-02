extends GutTest
## Task 09 (FR-09-3): the equipped breach tool's upgrade params are CONSUMED by the task-06 BreachPoint
## — a faster drill (speed_mult) and reduced jam chance (jam_mult). Closes the "gear/upgrades → 09" note.

func _breach(jam_per_sec: float = 0.0) -> BreachPoint:
	var d := ObstacleDef.new()
	d.category = ObstacleDef.Category.BREACH_POINT
	d.time_seconds = 4.0
	d.valid_solutions = [&"drill"] as Array[StringName]
	d.params = {"jam_chance_per_sec": jam_per_sec}
	var b := BreachPoint.new()
	b.def = d
	add_child_autofree(b)
	return b

func test_speed_upgrade_drills_faster() -> void:
	var base := _breach()
	base.begin_breach(&"drill")
	base._process(1.0)
	assert_almost_eq(base.progress, 1.0, 0.001, "no gear → 1s of progress per second")

	var upgraded := _breach()
	upgraded.equip_tool({"speed_mult": 2.0})
	upgraded.begin_breach(&"drill")
	upgraded._process(1.0)
	assert_almost_eq(upgraded.progress, 2.0, 0.001, "speed_mult 2 → double progress")

func test_jam_mult_zero_never_jams() -> void:
	var b := _breach(1000.0)   # absurd jam chance
	b.equip_tool({"jam_mult": 0.0})
	b.begin_breach(&"drill")
	for _i in 20:
		b._process(0.1)
	assert_false(b.is_jammed, "jam_mult 0 suppresses jams entirely")
