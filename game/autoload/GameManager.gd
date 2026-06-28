extends Node
## GameManager — top-level application state and scene transitions.
## Autoload. Owns the high-level state machine (BOOT → MENU → HIDEOUT → MISSION).
## See docs/tasks/01_project_setup.md and docs/ARCHITECTURE.md.

enum State { BOOT, MAIN_MENU, HIDEOUT, MISSION, MISSION_RESULTS, PAUSED }

var state: int = State.BOOT
var active_slot: int = -1

func _ready() -> void:
	# TODO[01]: connect EventBus.scene_transition_requested -> _on_transition
	pass

func goto_main_menu() -> void:
	pass # TODO[15]

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
