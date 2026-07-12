extends GutTest
## Spec (misc-fixes-3 issue 2): a jammed drill can only be cleared from AT the breach point. The overlay
## polls a global action, so without a proximity gate the jam cleared from anywhere on the map.
## docs/tasks/07_minigames.md (FR-07-8).

func _breach() -> BreachPoint:
	var d := ObstacleDef.new()
	d.id = &"test_breach"
	d.time_seconds = 4.0
	d.valid_solutions = [&"drill"] as Array[StringName]
	var b: BreachPoint = add_child_autofree(BreachPoint.new())
	b.def = d
	return b

func _drill(breach: BreachPoint, driller: Node3D) -> DrillMinigame:
	var mg: DrillMinigame = add_child_autofree(DrillMinigame.new())
	mg.begin({"breach": breach, "hacker": driller})
	return mg

func test_in_range_can_clear_the_jam() -> void:
	var b := _breach()
	var p: Node3D = add_child_autofree(Node3D.new())
	p.global_position = Vector3(1.5, 0, 0)   # inside the default 3 m reach
	var mg := _drill(b, p)
	assert_true(mg._can_reach_drill(), "standing at the drill, the repair prompt is live")

func test_out_of_range_cannot_clear_the_jam() -> void:
	var b := _breach()
	var p: Node3D = add_child_autofree(Node3D.new())
	p.global_position = Vector3(25, 0, 0)   # walked off down the corridor
	var mg := _drill(b, p)
	b.begin_breach(&"drill")
	b.is_jammed = true
	assert_false(mg._can_reach_drill(), "the jam can't be cleared from across the map")
	mg._process(0.016)
	assert_true(b.is_jammed, "an out-of-range press never reaches repair()")

func test_no_spatial_context_stays_operable() -> void:
	var b := _breach()
	var mg: DrillMinigame = add_child_autofree(DrillMinigame.new())
	mg.begin({"breach": b})   # no player in the scene (headless / greybox)
	assert_true(mg._can_reach_drill(), "with no player to measure against, the drill stays usable")
