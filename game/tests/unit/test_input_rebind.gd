extends GutTest
## Spec: rebinding an action then reloading from disk restores the new binding
## (rebinds persist to user://settings.cfg). FR-01-3.
## docs/tasks/01_project_setup.md.

const ACTION := &"jump"
var _saved_events: Array

func before_each() -> void:
	_saved_events = InputMap.action_get_events(ACTION).duplicate()

func after_each() -> void:
	# Restore the default binding both in memory and on disk so the rest of the
	# suite (and the next run) starts clean.
	InputMap.action_erase_events(ACTION)
	for ev in _saved_events:
		InputMap.action_add_event(ACTION, ev)
	InputManager.save_bindings()

func test_rebind_persists_through_reload() -> void:
	var new_event := InputEventKey.new()
	new_event.physical_keycode = KEY_K
	InputManager.rebind_action(ACTION, new_event)  # mutate InputMap + write file

	# Drop the in-memory binding, then rebuild it purely from disk.
	InputMap.action_erase_events(ACTION)
	InputManager.load_bindings()

	assert_true(_has_key(ACTION, KEY_K),
		"Rebound key (K) must survive a save -> reload cycle")

func test_rebind_replaces_prior_keyboard_binding() -> void:
	var new_event := InputEventKey.new()
	new_event.physical_keycode = KEY_K
	InputManager.rebind_action(ACTION, new_event)
	# The original Space binding should have been replaced, not stacked.
	assert_false(_has_key(ACTION, KEY_SPACE),
		"Rebinding should replace the prior keyboard event for the action")

## True if the action has any InputEventKey matching `keycode` by either the
## logical or physical keycode (defaults use keycode; rebinds use physical).
func _has_key(action: StringName, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev.keycode == keycode or ev.physical_keycode == keycode):
			return true
	return false
