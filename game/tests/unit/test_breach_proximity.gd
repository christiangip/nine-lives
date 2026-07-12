extends GutTest
## Spec (misc-fixes-5): a running BREACH is the one timed interaction that DELIBERATELY keeps going while
## the player walks away — the drill screams for guards, so leaving it to fight them is the whole tension
## (GDD §9.6). It is therefore exempt from the "movement cancels the interaction" rule the timed HACK obeys.
## What DOES need you back at the door is clearing a JAM (misc-fixes-3 issue 2; see test_drill_proximity.gd).
##
## This locks the exemption in both halves: the breach runs unattended, and it reports is_channeling() ==
## false so PlayerController never roots or cancels on it.
## docs/tasks/06_heist_mechanics_obstacles.md (FR-06-9).

func _breach(total: float = 1.0) -> BreachPoint:
	var d := ObstacleDef.new()
	d.id = &"test_breach"
	d.category = ObstacleDef.Category.BREACH_POINT
	d.time_seconds = total
	d.valid_solutions = [&"drill"] as Array[StringName]
	var b: BreachPoint = add_child_autofree(BreachPoint.new())
	b.def = d
	return b

func test_the_drill_keeps_running_while_the_operator_walks_away() -> void:
	var b := _breach()
	var operator: Node3D = add_child_autofree(Node3D.new())
	b.begin_breach(&"drill", operator)
	b._process(0.4)
	operator.global_position = Vector3(50, 0, 0)   # off across the map to deal with the guards it drew
	b._process(0.4)
	b._process(0.4)
	assert_true(b.solved, "an unattended drill must finish — walking away is the intended play, not a cancel")

func test_a_breach_is_not_a_channelled_interaction() -> void:
	var b := _breach()
	b.begin_breach(&"drill")
	assert_true(b.running, "the breach is under way")
	assert_false(b.is_channeling(),
		"a running breach must NOT report as a channel, or the player would be rooted (or cancelled) by it")

func test_cancel_interaction_is_a_no_op_on_a_breach() -> void:
	var b := _breach()
	b.begin_breach(&"drill")
	b.cancel_interaction()   # the Interactable base's default
	assert_true(b.running, "nothing the movement rule does may stop a drill")
	b._process(0.6)
	b._process(0.6)
	assert_true(b.solved, "and it still completes")
