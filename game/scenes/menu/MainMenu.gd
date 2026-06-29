extends Control
## MainMenu — placeholder boot menu (the full version is task 15).
## Four actions: Continue (enabled iff a save exists), New Game, Options, Quit.
## See docs/tasks/01_project_setup.md (FR-01-2) and 15_ui_hud_menus.md.

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	# Continue is only available when at least one save slot is populated.
	_continue_button.disabled = SaveManager.populated_count() == 0
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_new_game_button.grab_focus()

func _on_continue_pressed() -> void:
	GameManager.continue_game(_latest_populated_slot())  # TODO[16]: real slot-select UI

func _on_new_game_pressed() -> void:
	GameManager.start_new_game(0)  # TODO[16]: slot-pick popup before starting

func _on_options_pressed() -> void:
	pass  # TODO[15]: open the Options menu

func _on_quit_pressed() -> void:
	GameManager.quit_game()

func _latest_populated_slot() -> int:
	var slots: Array = SaveManager.scan_slots()
	for i in range(slots.size()):
		if slots[i]:
			return i
	return -1
