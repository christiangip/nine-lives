extends Control
class_name MainMenu
## MainMenu — the game's front door (task 15, FR-15-1/2). Exactly four items: New Game, Continue (greyed
## out when no save exists — bound to SaveManager.populated_count()), Options, Exit (with a confirm). New
## Game / Continue open the shared 10-slot SlotPopup (NEW / LOAD); Options opens the full OptionsMenu
## overlay. The Continue-disabled rule is the pure seam continue_enabled(), so it's headless-testable.
## NOTE: real save data is task 16 — until it lands populated_count() is 0, so Continue is correctly greyed
## and the slot popup shows "Empty" (↩ From 15). Themed via UITheme. See docs/tasks/15_ui_hud_menus.md.

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	theme = UITheme.build()
	_add_background()
	_refresh_continue()
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_new_game_button.grab_focus()

## Pure seam (FR-15-2): Continue is available iff at least one save slot is populated.
static func continue_enabled(populated_count: int) -> bool:
	return populated_count > 0

func _refresh_continue() -> void:
	_continue_button.disabled = not continue_enabled(SaveManager.populated_count())

func _on_new_game_pressed() -> void:
	SlotPopup.open(self, SlotPopup.Mode.NEW).closed.connect(_refresh_continue)

func _on_continue_pressed() -> void:
	SlotPopup.open(self, SlotPopup.Mode.LOAD).closed.connect(_refresh_continue)

func _on_options_pressed() -> void:
	OptionsMenu.open(self)

func _on_quit_pressed() -> void:
	ConfirmPopup.open(self, "Exit Nine Lives?", "Exit").confirmed.connect(GameManager.quit_game)

## A dark backdrop behind the menu (the theme colours text/buttons; the root Control is otherwise bare).
func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
