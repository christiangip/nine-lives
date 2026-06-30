extends GutTest
## Spec: an un-concealed body seen in a guard's cone with clear LoS raises the alarm (and
## announces the discovery so nearby guards converge); a concealed/out-of-cone/blocked body
## does not (FR-05-2, Phase 05.1). docs/tasks/05_ai_actors.md, GDD §8.5.

var _body: Body

func before_each() -> void:
	_body = Body.new()
	add_child_autofree(_body)   # _ready joins group &"body"; tree gives it a global_position

func test_discoverable_only_when_visible_and_unhidden() -> void:
	assert_true(Body.raises_alarm(false, true, true), "unhidden + in cone + LoS is discoverable")
	assert_false(Body.raises_alarm(true, true, true), "a concealed body is not discoverable")
	assert_false(Body.raises_alarm(false, false, true), "out of cone is not discoverable")
	assert_false(Body.raises_alarm(false, true, false), "blocked line of sight is not discoverable")

func test_discover_raises_alarm_and_announces() -> void:
	watch_signals(EventBus)
	_body.discover()
	assert_signal_emitted(EventBus, "body_discovered", "the discovery is announced for nearby guards")
	assert_signal_emitted(EventBus, "alarm_tripped", "and the alarm trips")
	assert_true(_body.discovered, "the body latches as discovered")

func test_discover_is_idempotent() -> void:
	_body.discover()
	watch_signals(EventBus)
	_body.discover()
	assert_signal_not_emitted(EventBus, "alarm_tripped", "an already-found body doesn't re-trip the alarm")

func test_concealed_body_never_discovers() -> void:
	_body.set_concealed(true)
	watch_signals(EventBus)
	_body.discover()
	assert_signal_not_emitted(EventBus, "body_discovered", "hiding the body suppresses discovery")
	assert_false(_body.discovered, "a concealed body stays undiscovered")
