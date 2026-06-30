extends GutTest
## Spec: after a takedown the guard's radio demands check-ins; a limited number are fakeable,
## then HQ escalates and the alarm trips (FR-05-3, Phase 05.2). docs/tasks/05_ai_actors.md, GDD §8.5.

func test_fakes_until_budget_then_escalates() -> void:
	var r := RadioCheckin.new(2, Vector3(1, 0, 2))
	watch_signals(EventBus)
	assert_true(r.try_fake(), "first 'all clear' holds")
	assert_true(r.try_fake(), "second holds")
	assert_false(r.try_fake(), "the third exceeds the fakeable budget")
	assert_signal_emitted(EventBus, "alarm_tripped", "exceeding the count escalates to alarm")

func test_no_escalation_while_budget_remains() -> void:
	var r := RadioCheckin.new(2)
	watch_signals(EventBus)
	r.try_fake()
	assert_signal_not_emitted(EventBus, "alarm_tripped", "a successful fake is silent")

func test_missed_checkin_escalates_immediately() -> void:
	var r := RadioCheckin.new(3)
	watch_signals(EventBus)
	r.missed()
	assert_signal_emitted(EventBus, "alarm_tripped", "an unanswered demand escalates at once")

func test_can_fake_reflects_remaining_budget() -> void:
	var r := RadioCheckin.new(1)
	assert_true(r.can_fake(), "budget available")
	r.try_fake()
	assert_false(r.can_fake(), "budget spent")
