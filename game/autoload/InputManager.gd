extends Node
## InputManager — remappable actions for KB+M and gamepad.
## Autoload. Adds gamepad default events at boot; persists rebinds to the
## [controls] section of user://settings.cfg.
## See docs/tasks/01_project_setup.md (input) and 15_ui_hud_menus.md (Options).

## Default config path; a plain var (not const) so tests can redirect I/O at a
## throwaway user://test_*.cfg instead of clobbering the player's real rebinds.
var config_path := "user://settings.cfg"
const CONTROLS_SECTION := "controls"

## The full action set (GDD §15 — Options → Controls). KB+M defaults live in project.godot [input];
## gamepad defaults are added here at boot. Keep this list in sync with [input].
const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint", &"crouch", &"prone", &"jump",
	&"lean_left", &"lean_right", &"interact", &"takedown",
	&"casing_vision", &"drop_loot", &"throw",
	&"aim", &"fire", &"reload", &"weapon_next", &"gadget_use",
	&"pause",
]

## Gamepad button defaults, applied additively at boot if not already bound.
## `prone` and `throw` are intentionally left without a pad default here — a 21-action
## set exceeds the clean buttons available, so those two get context/chord bindings in
## the loadout/Options work (tasks 09/15). Every other action has a sensible default.
const _GAMEPAD_BUTTONS := {
	&"jump": JOY_BUTTON_A,
	&"interact": JOY_BUTTON_X,
	&"takedown": JOY_BUTTON_B,
	&"casing_vision": JOY_BUTTON_Y,
	&"sprint": JOY_BUTTON_LEFT_STICK,
	&"crouch": JOY_BUTTON_RIGHT_STICK,
	&"lean_left": JOY_BUTTON_LEFT_SHOULDER,
	&"lean_right": JOY_BUTTON_RIGHT_SHOULDER,
	&"reload": JOY_BUTTON_DPAD_LEFT,
	&"weapon_next": JOY_BUTTON_DPAD_UP,
	&"gadget_use": JOY_BUTTON_DPAD_RIGHT,
	&"drop_loot": JOY_BUTTON_DPAD_DOWN,
	&"pause": JOY_BUTTON_START,
}

## Gamepad axis defaults: action -> [axis, direction] where direction is +1 / -1
## for the positive / negative half of the axis (sticks) or +1 for triggers.
const _GAMEPAD_AXES := {
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"aim": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	&"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

func _ready() -> void:
	_apply_gamepad_defaults()
	load_bindings()

## Add a sensible gamepad event to each action at boot, skipping any that already
## have an equivalent binding (idempotent — safe to call more than once).
func _apply_gamepad_defaults() -> void:
	for action in _GAMEPAD_BUTTONS:
		if not InputMap.has_action(action):
			continue
		var ev := InputEventJoypadButton.new()
		ev.button_index = _GAMEPAD_BUTTONS[action]
		if not _action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
	for action in _GAMEPAD_AXES:
		if not InputMap.has_action(action):
			continue
		var spec: Array = _GAMEPAD_AXES[action]
		var ev := InputEventJoypadMotion.new()
		ev.axis = spec[0]
		ev.axis_value = spec[1]
		if not _action_has_event(action, ev):
			InputMap.action_add_event(action, ev)

## Rebind an action for the device class of `event` (keyboard/mouse vs joypad),
## replacing any prior binding of that class, then persist to disk.
func rebind_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var is_pad := _is_pad_event(event)
	for existing in InputMap.action_get_events(action):
		if _is_pad_event(existing) == is_pad:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)
	save_bindings()

## Human-readable label for the primary keyboard/mouse binding of `action` (e.g. "F", "LMB"), so HUD
## prompts show the live bound key and stay correct after a rebind. Falls back to the action name.
func primary_key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			return OS.get_keycode_string(code)
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
	return String(action)

## Read saved bindings from disk and overwrite the in-memory InputMap for any
## action present in the file. Actions absent from the file keep their defaults.
func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	for action in ACTIONS:
		if not cfg.has_section_key(CONTROLS_SECTION, action):
			continue
		var encoded: Array = cfg.get_value(CONTROLS_SECTION, action, [])
		if encoded.is_empty():
			continue
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for data in encoded:
			var ev := _decode_event(data)
			if ev != null:
				InputMap.action_add_event(action, ev)

## Write every action's current events to the [controls] section, preserving the
## other sections (video/audio/gameplay) that SettingsManager owns.
## TODO[01]: persist a controls schema version (mirroring the save system) so a future
## default-binding change or new pad default can reach returning players — today the
## full saved keymap always wins, masking later default edits.
func save_bindings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(config_path)  # ignore error: a missing file just means a fresh write
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		var encoded: Array = []
		for ev in InputMap.action_get_events(action):
			var data := _encode_event(ev)
			if not data.is_empty():
				encoded.append(data)
		cfg.set_value(CONTROLS_SECTION, action, encoded)
	cfg.save(config_path)

# --- helpers ---------------------------------------------------------------

func _is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func _action_has_event(action: StringName, event: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event):
			return true
	return false

## InputEvent <-> plain Dictionary, so bindings survive in a ConfigFile.
func _encode_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.keycode, "physical": event.physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "pad_button", "button": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "pad_axis", "axis": event.axis, "value": event.axis_value}
	return {}

func _decode_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.keycode = int(data.get("keycode", 0))
			k.physical_keycode = int(data.get("physical", 0))
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(data.get("button", 0))
			return m
		"pad_button":
			var b := InputEventJoypadButton.new()
			b.button_index = int(data.get("button", 0))
			return b
		"pad_axis":
			var a := InputEventJoypadMotion.new()
			a.axis = int(data.get("axis", 0))
			a.axis_value = float(data.get("value", 0.0))
			return a
	return null
