extends Node
## GameManager — top-level application state and scene transitions.
## Autoload. Owns the high-level state machine and is the ONLY place scene swaps
## happen (everything else asks via EventBus.scene_transition_requested).
## See docs/tasks/02_core_architecture.md and docs/ARCHITECTURE.md.

enum State { BOOT, MAIN_MENU, HIDEOUT, MISSION, MISSION_RESULTS, PAUSED }

const MAIN_MENU_SCENE := "res://game/scenes/menu/MainMenu.tscn"
const HIDEOUT_SCENE := "res://game/scenes/hideout/Hideout.tscn"            ## TODO[13]: built by Hideout list
const MISSION_RESULTS_SCENE := "res://game/scenes/mission/MissionResults.tscn"  ## TODO[11/15]
const FADE_TIME := 0.25

## Legal state adjacency. Mirrors the boot/scene-flow diagram in ARCHITECTURE.md:
## BOOT → MAIN_MENU → HIDEOUT ⇄ MISSION → MISSION_RESULTS → HIDEOUT, plus PAUSED
## overlay during a mission and "quit to menu" from safe states.
const _TRANSITIONS := {
	State.BOOT: [State.MAIN_MENU],
	State.MAIN_MENU: [State.HIDEOUT],
	State.HIDEOUT: [State.MISSION, State.MAIN_MENU],
	State.MISSION: [State.MISSION_RESULTS, State.PAUSED],
	State.PAUSED: [State.MISSION, State.MAIN_MENU],
	State.MISSION_RESULTS: [State.HIDEOUT, State.MAIN_MENU],
}

var state: int = State.BOOT
var active_slot: int = -1

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	# Any system may request a scene swap by name through the EventBus rather
	# than reaching into GameManager directly.
	if not EventBus.scene_transition_requested.is_connected(_on_transition_requested):
		EventBus.scene_transition_requested.connect(_on_transition_requested)

## True if `next_state` is reachable from the current state.
func can_transition(next_state: int) -> bool:
	return next_state in _TRANSITIONS.get(state, [])

## Validate + apply a state change. Pure: updates `state` and announces it on the
## EventBus, but performs NO scene swap (callers pair this with `_change_scene`).
## Returns false (and warns) on an illegal transition, leaving `state` untouched.
func transition_to(next_state: int) -> bool:
	if not can_transition(next_state):
		push_warning("GameManager: illegal transition %s -> %s" % [
			State.keys()[state], State.keys()[next_state]])
		return false
	var previous := state
	state = next_state
	EventBus.game_state_changed.emit(previous, next_state)
	return true

func goto_main_menu() -> void:
	transition_to(State.MAIN_MENU)
	active_slot = -1
	_change_scene(MAIN_MENU_SCENE)

func goto_hideout() -> void:
	transition_to(State.HIDEOUT)
	_change_scene(HIDEOUT_SCENE)

func goto_results(_payload: Dictionary = {}) -> void:
	transition_to(State.MISSION_RESULTS)
	_change_scene(MISSION_RESULTS_SCENE)

func _on_transition_requested(target: String, payload: Dictionary) -> void:
	# Central routing point for EventBus-driven scene swaps. Extend as the other
	# task lists land their destinations.
	match target:
		"main_menu":
			goto_main_menu()
		"hideout":
			goto_hideout()
		"results":
			goto_results(payload)
		"mission":
			pass # TODO[11]: enter_mission() once a built contract is supplied via payload
		_:
			push_warning("GameManager: unknown transition target '%s'" % target)

## Fade/loading hook: fade to black, swap, fade back in. A real loading screen
## (progress, art) lands in 15; the seam lives here so all swaps share it. The
## overlay is parented to this autoload so it survives the scene change.
func _change_scene(path: String) -> void:
	_ensure_fade_layer()
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_TIME)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(path))
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_TIME)

func _ensure_fade_layer() -> void:
	if is_instance_valid(_fade_layer):
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128 # above gameplay/UI
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	add_child(_fade_layer)

func start_new_game(slot: int) -> void:
	active_slot = slot
	# TODO[16]: SaveManager.save_slot(slot) fresh, run tutorial, then goto_hideout()

func continue_game(slot: int) -> void:
	active_slot = slot
	# TODO[16]: SaveManager.load_slot(slot) -> goto_hideout()

func enter_mission(_contract: Resource) -> void:
	pass # TODO[11]: MissionGenerator.build(contract) -> transition_to(MISSION) -> swap

func return_to_hideout() -> void:
	goto_hideout()

func quit_game() -> void:
	get_tree().quit()
