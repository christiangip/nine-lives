extends GutTest
## Spec: hacks need proximity + time — leaving range ABANDONS the hack (progress resets; you start over),
## and a found code skips it entirely (FR-06-5, Phase 06.2). docs/tasks/06_heist_mechanics_obstacles.md, GDD §9.2.
## The cancel rule supersedes the original pause-and-resume one (misc-fixes-4 issue 2): a paused hack
## silently ran to completion behind the player's back the moment they drifted back into range.

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

func test_step_progress_cancels_out_of_range() -> void:
	assert_almost_eq(HackTarget.step_progress(0.0, 0.5, 3.0, true), 0.5, 0.0001, "advances in range")
	assert_almost_eq(HackTarget.step_progress(0.5, 0.5, 3.0, false), 0.0, 0.0001, "out of range = abandoned, back to 0")
	assert_almost_eq(HackTarget.step_progress(2.9, 0.5, 3.0, true), 3.0, 0.0001, "clamps to total")

func test_leaving_range_cancels_the_hack() -> void:
	var h := _hack()
	assert_false(h.begin_hack(null), "a timed hack starts (not an instant shortcut)")
	h.tick(1.0, 2.0)   # in range
	assert_false(h.solved, "one second in, not done")
	h.tick(0.1, 9.0)   # walked away
	assert_false(h.solved, "leaving range does not complete the hack")
	assert_false(h.hacking, "leaving range abandons the hack outright")
	assert_almost_eq(h.progress, 0.0, 0.0001, "progress is LOST, not parked")

func test_returning_does_not_silently_resume() -> void:
	var h := _hack()
	h.begin_hack(null)
	h.tick(2.5, 2.0)   # almost through the 3.0s
	h.tick(0.1, 9.0)   # walked away → abandoned
	h.tick(1.0, 2.0)   # wandered back into range
	h.tick(1.0, 2.0)
	assert_false(h.solved, "a cancelled hack does not finish itself when the player drifts back")
	assert_almost_eq(h.progress, 0.0, 0.0001, "ticking a cancelled hack does nothing until it's restarted")

func test_restarting_after_a_cancel_works() -> void:
	var h := _hack()
	h.begin_hack(null)
	h.tick(2.5, 2.0)
	h.tick(0.1, 9.0)               # abandoned
	assert_false(h.begin_hack(null), "the hack can be started again from scratch")
	h.tick(1.0, 2.0)
	assert_false(h.solved, "and it really is from scratch — 1s of a 3s hack")
	h.tick(2.0, 2.0)
	assert_true(h.solved, "the full timer in range completes it")

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
