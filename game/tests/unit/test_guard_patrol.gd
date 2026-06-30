extends GutTest
## Spec: a guard walks its waypoint route and loops back to the start; "reached" gates arrival
## at each waypoint (FR-05-1, Phase 05.1). docs/tasks/05_ai_actors.md.

var _g: GuardAI

func before_each() -> void:
	_g = GuardAI.new()

func after_each() -> void:
	_g.free()

func test_waypoint_index_loops() -> void:
	assert_eq(_g.next_waypoint_index(0, 3), 1, "advances to the next waypoint")
	assert_eq(_g.next_waypoint_index(1, 3), 2, "...and the next")
	assert_eq(_g.next_waypoint_index(2, 3), 0, "wraps back to the first — the route loops")

func test_waypoint_index_safe_on_empty_route() -> void:
	assert_eq(_g.next_waypoint_index(0, 0), 0, "no waypoints never indexes out of range")

func test_reached_within_arrival_radius() -> void:
	assert_true(_g.reached(Vector3.ZERO, Vector3(0.5, 0, 0), 0.6), "inside the arrival radius counts as reached")
	assert_false(_g.reached(Vector3.ZERO, Vector3(2, 0, 0), 0.6), "still far away is not reached")
