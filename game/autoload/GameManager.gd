extends Node
## GameManager — top-level application state and scene transitions.
## Autoload. Owns the high-level state machine and is the ONLY place scene swaps
## happen (everything else asks via EventBus.scene_transition_requested).
## See docs/tasks/02_core_architecture.md and docs/ARCHITECTURE.md.

enum State { BOOT, MAIN_MENU, HIDEOUT, MISSION, MISSION_RESULTS, PAUSED }

const MAIN_MENU_SCENE := "res://game/scenes/menu/MainMenu.tscn"
const HIDEOUT_SCENE := "res://game/scenes/hideout/Hideout.tscn"            ## the between-mission hub (task 13)
const MISSION_RESULTS_SCENE := "res://game/scenes/mission/MissionResults.tscn"  ## TODO[11/15]
const FADE_TIME := 0.25

## Legal state adjacency. Mirrors the boot/scene-flow diagram in ARCHITECTURE.md:
## BOOT → MAIN_MENU → HIDEOUT ⇄ MISSION → MISSION_RESULTS → HIDEOUT, plus PAUSED
## overlay during a mission and "quit to menu" from safe states. MISSION → HIDEOUT is the
## Q5 clean-abort path (PauseMenu._abort_clean): the in-mission pause overlay never routes
## through State.PAUSED (it pauses the SceneTree directly), so this edge must be direct.
const _TRANSITIONS := {
	State.BOOT: [State.MAIN_MENU],
	State.MAIN_MENU: [State.HIDEOUT],
	State.HIDEOUT: [State.MISSION, State.MAIN_MENU],
	State.MISSION: [State.MISSION_RESULTS, State.PAUSED, State.HIDEOUT],
	State.PAUSED: [State.MISSION, State.MAIN_MENU],
	State.MISSION_RESULTS: [State.HIDEOUT, State.MAIN_MENU],
}

var state: int = State.BOOT
var active_slot: int = -1
var pending_results: Dictionary = {}   ## last mission/Catch summary; read by MissionResults (task 15, FR-15-8)

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
	if not transition_to(State.MAIN_MENU):
		return   # illegal from the current state; state is untouched, so don't swap the scene under it
	active_slot = -1
	_change_scene(MAIN_MENU_SCENE)

func goto_hideout() -> void:
	if not transition_to(State.HIDEOUT):
		return
	# Between-mission autosave (FR-16-4): landing at the hub is a safe checkpoint, and it clears the
	# mid-mission commit flag so a subsequent quit doesn't re-resolve a Catch.
	if SaveManager != null:
		SaveManager.autosave()
	_change_scene(HIDEOUT_SCENE)

func goto_results(payload: Dictionary = {}) -> void:
	# A standalone Challenge (task 20) overrides the payload with its own results and restores the real
	# Streak snapshot, so both the escape path (MissionController) and the Catch path funnel through here.
	if RunManager != null and RunManager.challenge_mode:
		var cr := RunManager.consume_challenge_results()
		if not cr.is_empty():
			payload = cr
		RunManager.end_challenge()
	if not transition_to(State.MISSION_RESULTS):
		return
	pending_results = payload   # MissionResults reads this in _ready (task 15, FR-15-8)
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
			enter_mission(payload.get("contract"))
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
	# Fresh account/Streak, persisted to the slot before the hub swap so the file exists for autosave /
	# mark_committed (FR-16-1). goto_hideout autosaves again on arrival. TODO[22]: first-time hints.
	if RunManager != null:
		RunManager.start_new_streak()
	if SaveManager != null:
		SaveManager.save_slot(slot)
	goto_hideout()

func continue_game(slot: int) -> void:
	active_slot = slot
	# Rehydrate ProgressionManager/RunManager from disk BEFORE the hub swap; load_slot also resolves a
	# hot-quit-while-committed as the Catch (FR-16-5) so the hub shows the correct post-Catch state.
	if SaveManager != null:
		SaveManager.load_slot(slot)
	goto_hideout()

## Build a contract into a live mission and swap into it (task 11, FR-11-3). Validates the Streak
## loadout first (FR-09-8) and refuses to enter if the generator can't produce a solvable layout.
func enter_mission(contract) -> void:
	var c := contract as Contract
	if c == null:
		push_warning("GameManager.enter_mission: no contract supplied")
		return
	# Record the contract name for the save slot summary (task 16 meta.last_contract), and start this
	# mission's spotted/alarm tracking clean — a prior mission could have left it dirty via a path that
	# skips normal end-of-mission bookkeeping (e.g. PauseMenu's clean bug-out).
	if RunManager != null:
		RunManager.last_contract = _contract_name(c)
		RunManager.reset_mission_tracking()
	# FR-09-8: validate the Streak's equipped loadout before entering (the Armory fixes it, task 13).
	var run := Services.run()
	if run != null and run.has_method("loadout"):
		var lo = run.loadout()
		if lo != null and lo.has_method("validate") and not lo.validate():
			push_warning("GameManager.enter_mission: Streak loadout is invalid (over capacity / locked gear)")
	var root := MissionGenerator.build(c)
	if root == null:
		push_error("GameManager.enter_mission: mission build failed; staying put")
		return
	if not transition_to(State.MISSION):
		push_error("GameManager.enter_mission: illegal transition to MISSION from %s; discarding built scene" % State.keys()[state])
		root.queue_free()   # never adopted into the tree; free it ourselves
		return
	_swap_to_built_scene(root)

## Build + swap into a standalone daily/weekly Challenge (task 20, FR-20-2). Isolated from the endless
## Streak via RunManager.begin_challenge (snapshot/restore); results route back through goto_results.
func enter_challenge(contract, kind: String, reward: int) -> void:
	var c := contract as Contract
	if c == null:
		push_warning("GameManager.enter_challenge: no contract supplied")
		return
	if RunManager != null:
		RunManager.last_contract = _contract_name(c)
		RunManager.begin_challenge(c.mission_seed, kind, reward)
	var root := MissionGenerator.build(c)
	if root == null:
		push_error("GameManager.enter_challenge: mission build failed; aborting Challenge")
		if RunManager != null:
			RunManager.end_challenge()
		return
	if not transition_to(State.MISSION):
		push_error("GameManager.enter_challenge: illegal transition to MISSION from %s; aborting Challenge" % State.keys()[state])
		root.queue_free()
		if RunManager != null:
			RunManager.end_challenge()
		return
	_swap_to_built_scene(root)

## Swap an already-built Node (a MissionController) in as the current scene, sharing the fade seam.
func _swap_to_built_scene(root: Node) -> void:
	_ensure_fade_layer()
	var tree := get_tree()
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_TIME)
	tween.tween_callback(func() -> void:
		if tree.current_scene != null:
			tree.current_scene.queue_free()
		tree.root.add_child(root)
		tree.current_scene = root)
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_TIME)

## The archetype's display name for a contract, falling back to the raw id (save meta, task 16).
func _contract_name(c: Contract) -> String:
	if Content != null and Content.archetypes != null:
		var arch := Content.archetypes.get_def(c.archetype_id) as ArchetypeDef
		if arch != null and arch.display_name != "":
			return arch.display_name
	return String(c.archetype_id)

func return_to_hideout() -> void:
	goto_hideout()

func quit_game() -> void:
	get_tree().quit()
