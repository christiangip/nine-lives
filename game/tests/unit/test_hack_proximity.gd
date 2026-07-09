extends GutTest
## Spec: hacks need proximity + time — leaving range PAUSES (not resets) the hack, returning resumes,
## and a found code skips it entirely (FR-06-5, Phase 06.2). docs/tasks/06_heist_mechanics_obstacles.md, GDD §9.2.

class StubActor extends Node:
	var _items: Array
	func _init(items: Array = []) -> void:
		_items = items
	func has_item(id: StringName) -> bool:
		return id in _items

func _hack(clue: StringName = &"") -> HackTarget:
	var d := ObstacleDef.new()
	d.id = &"test_hack"
	d.category = ObstacleDef.Category.HACK_TARGET
	d.time_seconds = 3.0
	d.proximity_range = 3.0
	d.clue_id = clue
	d.params = {"device": "elock"}
	var h := HackTarget.new()
	h.def = d
	add_child_autofree(h)
	return h

func test_in_proximity() -> void:
	assert_true(HackTarget.in_proximity(2.0, 3.0), "inside range")
	assert_false(HackTarget.in_proximity(4.0, 3.0), "outside range")

func test_step_progress_pauses_out_of_range() -> void:
	assert_almost_eq(HackTarget.step_progress(0.0, 0.5, 3.0, true), 0.5, 0.0001, "advances in range")
	assert_almost_eq(HackTarget.step_progress(0.5, 0.5, 3.0, false), 0.5, 0.0001, "holds out of range")
	assert_almost_eq(HackTarget.step_progress(2.9, 0.5, 3.0, true), 3.0, 0.0001, "clamps to total")

func test_leaving_range_pauses_then_resumes_to_completion() -> void:
	var h := _hack()
	assert_false(h.begin_hack(null), "a timed hack starts (not an instant shortcut)")
	h.tick(1.0, 2.0)   # in range
	assert_false(h.solved, "one second in, not done")
	h.tick(5.0, 9.0)   # out of range: paused despite a big delta
	assert_false(h.solved, "leaving range does not complete the hack")
	assert_almost_eq(h.progress, 1.0, 0.0001, "progress held while out of range")
	h.tick(1.0, 2.0)   # back in range
	h.tick(1.0, 2.0)   # reaches the 3.0s total
	assert_true(h.solved, "returning resumes and completes the hack")

func test_found_code_skips_the_hack() -> void:
	var h := _hack(&"elock_code")
	var by := StubActor.new([&"elock_code"])
	autofree(by)
	assert_true(h.begin_hack(by), "holding the code resolves instantly")
	assert_true(h.solved, "no timed hack needed")

func test_interaction_progress_drives_the_hold_ring() -> void:
	var h := _hack()
	assert_almost_eq(h.interaction_progress(), 0.0, 0.0001, "no ring before the hack starts")
	h.begin_hack(null)
	h.tick(1.5, 2.0)   # halfway through the 3.0s in range
	assert_almost_eq(h.interaction_progress(), 0.5, 0.01, "the HUD ring reflects the proximity-hack fill")
	h.tick(1.5, 2.0)   # completes
	assert_almost_eq(h.interaction_progress(), 0.0, 0.0001, "no ring once solved")
