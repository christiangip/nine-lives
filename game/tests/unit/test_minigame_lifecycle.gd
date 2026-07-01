extends GutTest
## Spec: the Minigame base runs a clean lifecycle — begin → (solved | failed | aborted) fires the right
## signal EXACTLY ONCE and latches, so a double-call or a second outcome can't re-fire (FR-07-1, Phase
## 07.1). docs/tasks/07_minigames.md, GDD §9.8.

func _mg() -> Minigame:
	var mg := Minigame.new()
	mg.pauses_world = false   # never pause the GUT tree
	add_child_autofree(mg)
	return mg

func test_solved_emits_once() -> void:
	var mg := _mg()
	watch_signals(mg)
	mg.begin({})
	mg._finish_solved()
	mg._finish_solved()   # latched — no re-fire
	assert_signal_emit_count(mg, "solved", 1)

func test_failed_emits_once_with_reason() -> void:
	var mg := _mg()
	watch_signals(mg)
	mg._finish_failed("miss")
	mg._finish_failed("miss")
	assert_signal_emit_count(mg, "failed", 1)
	assert_signal_emitted_with_parameters(mg, "failed", ["miss"])

func test_aborted_emits_once() -> void:
	var mg := _mg()
	watch_signals(mg)
	mg.abort()
	mg.abort()
	assert_signal_emit_count(mg, "aborted", 1)

func test_only_the_first_outcome_wins() -> void:
	var mg := _mg()
	watch_signals(mg)
	mg._finish_solved()
	mg._finish_failed("late")
	mg.abort()
	assert_signal_emit_count(mg, "solved", 1)
	assert_signal_emit_count(mg, "failed", 0)
	assert_signal_emit_count(mg, "aborted", 0)

func test_scaled_widens_linearly() -> void:
	assert_almost_eq(Minigame.scaled(10.0, 0.0, 2.0), 10.0, 0.0001, "no level = base")
	assert_almost_eq(Minigame.scaled(10.0, 3.0, 2.0), 16.0, 0.0001, "base + level*per_level")

func test_configure_clamps() -> void:
	var mg := _mg()
	mg.configure(0, -5, {"stethoscope": true})
	assert_eq(mg.difficulty, 1, "difficulty floored at 1")
	assert_eq(mg.attribute_level, 0, "attribute floored at 0")
	assert_true(mg.has_gear(&"stethoscope"), "gear flag readable")
	assert_false(mg.has_gear(&"emp"), "absent gear reads false")
