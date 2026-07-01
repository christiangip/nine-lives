extends GutTest
## Spec: possessing the found combo clue BYPASSES the safe minigame entirely (FR-06-2, Phase 06.5).
## docs/tasks/06_heist_mechanics_obstacles.md, GDD §9.1.

class StubActor extends Node:
	var _items: Array
	func _init(items: Array = []) -> void:
		_items = items
	func has_item(id: StringName) -> bool:
		return id in _items

func _safe() -> Safe:
	var d := ObstacleDef.new()
	d.id = &"test_safe"
	d.category = ObstacleDef.Category.SAFE
	d.clue_id = &"safe_combo_clue"
	var s := Safe.new()
	s.def = d
	add_child_autofree(s)
	return s

func test_can_skip_requires_the_clue() -> void:
	assert_true(Safe.can_skip([&"safe_combo_clue"], &"safe_combo_clue"), "holding the clue skips")
	assert_false(Safe.can_skip([], &"safe_combo_clue"), "no clue, no skip")
	assert_false(Safe.can_skip([&"safe_combo_clue"], &""), "no required clue id, no skip")

func test_clue_holder_opens_without_a_minigame() -> void:
	var s := _safe()
	watch_signals(s)
	var by := StubActor.new([&"safe_combo_clue"])
	autofree(by)
	s.interact(by)
	assert_true(s.solved, "the clue trivialises the safe")
	assert_signal_not_emitted(s, "minigame_requested", "no minigame when the clue is held")

func test_without_clue_requests_the_minigame() -> void:
	var s := _safe()
	watch_signals(s)
	var by := StubActor.new([])
	autofree(by)
	s.interact(by)
	assert_false(s.solved, "no clue: the safe stays shut pending the minigame")
	assert_signal_emitted(s, "minigame_requested", "falls back to the dial minigame (task 07)")
