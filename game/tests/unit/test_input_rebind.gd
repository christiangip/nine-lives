extends GutTest
## Spec: rebinding an action then reloading from disk restores the new binding
## (rebinds persist to user://settings.cfg). FR-01-3.
## docs/tasks/01_project_setup.md.

const ACTION := &"jump"
const TEST_PATH := "user://test_controls.cfg"
var _saved_events: Array
var _orig_path: String

func before_all() -> void:
	# Redirect persistence at a throwaway file so the suite never touches the
	# developer's real user://settings.cfg [controls].
	_orig_path = InputManager.config_path
	InputManager.config_path = TEST_PATH

func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	InputManager.config_path = _orig_path

func before_each() -> void:
	_saved_events = InputMap.action_get_events(ACTION).duplicate()

func after_each() -> void:
	# Restore the default binding in memory so the rest of the suite starts clean;
	# the on-disk temp file is discarded in after_all().
	InputMap.action_erase_events(ACTION)
	for ev in _saved_events:
		InputMap.action_add_event(ACTION, ev)

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

## InputManager.ACTIONS is a hand-maintained mirror of project.godot [input]; guard
## against the two silently drifting. Compares against the non-ui_* actions the engine
## actually loaded from project settings.
func test_actions_match_input_map() -> void:
	var declared := {}
	for action in InputManager.ACTIONS:
		declared[action] = true
	var loaded := {}
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			loaded[action] = true
	var missing_in_map := declared.keys().filter(func(a): return not loaded.has(a))
	var missing_in_actions := loaded.keys().filter(func(a): return not declared.has(a))
	assert_eq(missing_in_map, [],
		"Actions in InputManager.ACTIONS but absent from the loaded InputMap")
	assert_eq(missing_in_actions, [],
		"Game actions in the InputMap but absent from InputManager.ACTIONS")

## True if the action has any InputEventKey matching `keycode` by either the
## logical or physical keycode (defaults use keycode; rebinds use physical).
func _has_key(action: StringName, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev.keycode == keycode or ev.physical_keycode == keycode):
			return true
	return false
