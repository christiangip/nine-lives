extends Node
## GameManager — top-level application state and scene transitions.
## Autoload. Owns the high-level state machine (BOOT → MENU → HIDEOUT → MISSION).
## See docs/tasks/01_project_setup.md and docs/ARCHITECTURE.md.

enum State { BOOT, MAIN_MENU, HIDEOUT, MISSION, MISSION_RESULTS, PAUSED }

const MAIN_MENU_SCENE := "res://game/scenes/menu/MainMenu.tscn"

var state: int = State.BOOT
var active_slot: int = -1

func _ready() -> void:
	# Any system may request a scene swap by name through the EventBus rather
	# than reaching into GameManager directly.
	if not EventBus.scene_transition_requested.is_connected(_on_transition_requested):
		EventBus.scene_transition_requested.connect(_on_transition_requested)

func goto_main_menu() -> void:
	state = State.MAIN_MENU
	active_slot = -1
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_transition_requested(target: String, _payload: Dictionary) -> void:
	# Central routing point for EventBus-driven scene swaps. Extend as the other
	# task lists land their destinations.
	match target:
		"main_menu":
			goto_main_menu()
		_:
			pass # TODO[11/15/16]: route hideout / mission / results targets here

func start_new_game(slot: int) -> void:
	pass # TODO[16]: create fresh save, run tutorial, then hideout

func continue_game(slot: int) -> void:
	pass # TODO[16]: SaveManager.load_slot(slot) -> hideout

func enter_mission(contract: Resource) -> void:
	pass # TODO[11]: MissionGenerator.build(contract) -> swap scene

func return_to_hideout() -> void:
	pass # TODO[10]

func quit_game() -> void:
	get_tree().quit()
