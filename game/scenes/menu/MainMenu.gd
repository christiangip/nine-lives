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
	UITheme.style_title($Title, 48)      # the display face stays on the big headings (misc-fixes-2)
	UITheme.style_title($Subtitle, 20)
	_add_background()
	_add_version_stamp()
	# Localization scaffold (task 21, FR-21-1): button text is set to translation KEYS; Godot's Control
	# auto-translation renders the active locale and re-renders live when it changes in Options.
	Localization.ensure_registered()
	_new_game_button.text = "MENU_NEW_GAME"
	_continue_button.text = "MENU_CONTINUE"
	_options_button.text = "MENU_OPTIONS"
	_quit_button.text = "MENU_EXIT"
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
	ConfirmPopup.open(self, tr("MENU_EXIT_CONFIRM"), tr("MENU_EXIT")).confirmed.connect(GameManager.quit_game)

## The build/version stamp in the bottom-right corner (task 21, FR-21-7).
func _add_version_stamp() -> void:
	var v := Label.new()
	v.text = Version.string()
	v.add_theme_color_override("font_color", UITheme.MUTED)
	v.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_left = -220
	v.offset_top = -34
	v.offset_right = -14
	v.offset_bottom = -8
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)

## A dark backdrop behind the menu (the theme colours text/buttons; the root Control is otherwise bare).
func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
