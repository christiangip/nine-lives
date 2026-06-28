extends Node
## InputManager — remappable actions for KB+M and gamepad.
## Autoload. Adds gamepad default events at boot; persists rebinds to config.
## See docs/tasks/01_project_setup.md (input) and 15_ui_hud_menus.md (Options).

const CONFIG_PATH := "user://settings.cfg"

func _ready() -> void:
	_apply_gamepad_defaults()
	load_bindings()

func _apply_gamepad_defaults() -> void:
	pass # TODO[01]: add JoyButton/JoyAxis events for each action

func rebind_action(action: StringName, event: InputEvent) -> void:
	pass # TODO[15]

func load_bindings() -> void:
	pass # TODO[16]

func save_bindings() -> void:
	pass # TODO[16]
