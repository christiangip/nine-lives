extends GutTest
## Spec: EventBus exposes the documented signal catalogue with the expected arg
## counts and stays logic-free (FR-02-1). docs/tasks/02_core_architecture.md.

const EXPECTED := {
	# stealth / detection
	"detection_changed": 3,
	"noise_emitted": 3,
	"player_spotted": 1,
	"body_discovered": 1,
	# alarms / pursuit
	"alarm_tripped": 2,
	"heat_changed": 1,
	"pursuit_phase_changed": 1,
	# loot / objectives
	"loot_picked_up": 1,
	"loot_secured": 2,
	"carry_changed": 2,
	"objective_updated": 2,
	# run / progression
	"notoriety_gained": 2,
	"streak_level_up": 2,
	"streak_ended": 2,
	"mission_completed": 1,
	# meta / flow
	"scene_transition_requested": 2,
	"game_state_changed": 2,
	"save_completed": 1,
	"settings_changed": 1,
}

func test_all_documented_signals_exist_with_arg_counts() -> void:
	for signal_name in EXPECTED:
		assert_true(EventBus.has_signal(signal_name),
			"EventBus must declare signal '%s'" % signal_name)
		assert_eq(_arg_count(signal_name), int(EXPECTED[signal_name]),
			"Signal '%s' should take %d args" % [signal_name, EXPECTED[signal_name]])

## EventBus is signals-only: its script declares no methods of its own (FR-02-1).
func test_event_bus_has_no_logic_methods() -> void:
	var own: Array = []
	for m in EventBus.get_script().get_script_method_list():
		own.append(m.name)
	assert_eq(own, [], "EventBus.gd should define no methods (signals only); found %s" % str(own))

func _arg_count(signal_name: String) -> int:
	for s in EventBus.get_signal_list():
		if s.name == signal_name:
			return (s.args as Array).size()
	return -1
