extends GutTest
## Spec: the MinigameHost maps each kind to its overlay and routes a finished overlay's outcome back to
## the requesting obstacle via apply_minigame_result — opening the Lock/Safe/DisplayCase/HackTarget on a
## solve, leaving them shut on a fail (FR-07-1, Phase 07.1). docs/tasks/07_minigames.md.

func _lock() -> Lock:
	var d := ObstacleDef.new()
	d.id = &"t_lock"; d.category = ObstacleDef.Category.LOCK
	var n := Lock.new(); n.def = d
	add_child_autofree(n)
	return n

func _safe() -> Safe:
	var d := ObstacleDef.new()
	d.id = &"t_safe"; d.category = ObstacleDef.Category.SAFE
	var n := Safe.new(); n.def = d
	add_child_autofree(n)
	return n

func _case() -> DisplayCase:
	var d := ObstacleDef.new()
	d.id = &"t_case"; d.category = ObstacleDef.Category.DISPLAY_CASE
	var n := DisplayCase.new(); n.def = d
	add_child_autofree(n)
	return n

func _keypad() -> HackTarget:
	var d := ObstacleDef.new()
	d.id = &"t_kp"; d.category = ObstacleDef.Category.HACK_TARGET
	d.params = {"device": "keypad"}
	var n := HackTarget.new(); n.def = d
	add_child_autofree(n)
	return n

func test_builder_maps_each_kind() -> void:
	assert_eq(MinigameHost.builder_for(&"lockpick").resource_path, "res://game/systems/minigames/LockpickMinigame.gd")
	assert_eq(MinigameHost.builder_for(&"safe_dial").resource_path, "res://game/systems/minigames/SafeCrackMinigame.gd")
	assert_eq(MinigameHost.builder_for(&"hack").resource_path, "res://game/systems/minigames/HackMinigame.gd")
	assert_eq(MinigameHost.builder_for(&"keypad").resource_path, "res://game/systems/minigames/KeypadMinigame.gd")
	assert_eq(MinigameHost.builder_for(&"pickpocket").resource_path, "res://game/systems/minigames/PickpocketMinigame.gd")
	assert_eq(MinigameHost.builder_for(&"drill").resource_path, "res://game/systems/minigames/DrillMinigame.gd")
	assert_null(MinigameHost.builder_for(&"unknown"), "unknown kind has no overlay")

func test_apply_result_opens_each_obstacle() -> void:
	var lock := _lock(); lock.apply_minigame_result(&"lockpick", true); assert_true(lock.solved, "lockpick opens the lock")
	var safe := _safe(); safe.apply_minigame_result(&"safe_dial", true); assert_true(safe.solved, "dial opens the safe")
	var case := _case(); case.apply_minigame_result(&"hack", true); assert_true(case.solved, "hack opens the case")
	var kp := _keypad(); kp.apply_minigame_result(&"keypad", true); assert_true(kp.solved, "deduction opens the keypad")

func test_failed_result_leaves_obstacle_shut() -> void:
	var lock := _lock(); lock.apply_minigame_result(&"lockpick", false); assert_false(lock.solved, "a fluffed pick doesn't open it")
	var safe := _safe(); safe.apply_minigame_result(&"safe_dial", false); assert_false(safe.solved)

func test_attach_request_solve_routes_end_to_end() -> void:
	var host := MinigameHost.new()
	add_child_autofree(host)
	var case := _case()
	host.attach(case)
	case.interact(null)   # DisplayCase falls through to hack → minigame_requested(&"hack")
	assert_true(host.is_busy(), "the request mounted an overlay")
	var mg := host.active()
	assert_not_null(mg, "an overlay is active")
	mg._finish_solved()
	assert_true(case.solved, "solving the overlay opened the case via apply_minigame_result")
	assert_false(host.is_busy(), "the host closed after the outcome")

func test_open_unknown_kind_is_a_noop() -> void:
	var host := MinigameHost.new()
	add_child_autofree(host)
	assert_null(host.open(&"nope", null), "unknown kind mounts nothing")
	assert_false(host.is_busy())
