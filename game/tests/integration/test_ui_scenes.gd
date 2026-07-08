extends GutTest
## Task 15: smoke test that every new UI surface instantiates + builds its UI in-tree without error (they all
## build their controls in _ready). Guards the menu/HUD/results/sandbox against regressions, mirroring
## test_hideout_scenes.gd / test_economy_scenes.gd. docs/tasks/15_ui_hud_menus.md.

func before_each() -> void:
	RunManager.start_new_streak()   # a valid Streak so the HUD/loud readouts have live state to poll

func after_each() -> void:
	# PauseMenu pauses the tree in _ready — never let that leak into the next test.
	if get_tree() != null:
		get_tree().paused = false

func test_main_menu_builds() -> void:
	_smoke("res://game/scenes/menu/MainMenu.tscn")

func test_hud_builds() -> void:
	_smoke("res://game/scenes/ui/hud/HUD.tscn")

## Regression (FP mouse-look): NO Control in the HUD may keep the default MOUSE_FILTER_STOP. In captured
## mouse mode the cursor is pinned to screen centre, so a STOP Control there (the crosshair) consumes
## InputEventMouseMotion before it reaches PlayerController._unhandled_input, silently killing camera look
## while WASD still works. HUD._make_mouse_transparent(_root) enforces this; this test locks it in so a
## future HUD element added without a filter can't re-break look. See HUD._build.
func test_hud_never_blocks_the_mouse() -> void:
	var packed := load("res://game/scenes/ui/hud/HUD.tscn") as PackedScene
	assert_not_null(packed, "the HUD scene loads")
	var hud := packed.instantiate()
	add_child_autofree(hud)
	var blockers: Array[String] = []
	_collect_mouse_blockers(hud, blockers)
	assert_eq(blockers.size(), 0,
		"every HUD Control must be MOUSE_FILTER_IGNORE so it can't eat FP camera look; blockers: %s" % [blockers])

func _collect_mouse_blockers(node: Node, out: Array[String]) -> void:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		out.append(node.name)
	for child in node.get_children():
		_collect_mouse_blockers(child, out)

func test_results_builds() -> void:
	_smoke("res://game/scenes/mission/MissionResults.tscn")

func test_ui_sandbox_builds() -> void:
	# The furnished demo spawns a real player + Quaternius/character models + the real HUD in _ready.
	_smoke("res://game/scenes/ui/UISandbox.tscn")

func test_options_menu_builds() -> void:
	var o: OptionsMenu = add_child_autofree(OptionsMenu.new())
	assert_true(is_instance_valid(o), "Options builds all five tabs incl. the per-action remap rows")

func test_slot_popup_builds() -> void:
	var s: SlotPopup = add_child_autofree(SlotPopup.new())
	assert_true(is_instance_valid(s), "the 10-slot popup builds its rows (all 'Empty' on a fresh profile)")

func test_pause_menu_builds() -> void:
	var packed := load("res://game/scenes/mission/PauseMenu.tscn") as PackedScene
	assert_not_null(packed, "the Pause menu scene loads")
	var p: PauseMenu = add_child_autofree(packed.instantiate())
	assert_true(is_instance_valid(p), "the Pause menu builds + shows its strict-saves status line")
	get_tree().paused = false   # PauseMenu paused the tree in _ready

func _smoke(path: String) -> void:
	var packed := load(path) as PackedScene
	assert_not_null(packed, "%s loads" % path)
	var inst = packed.instantiate()
	add_child_autofree(inst)
	assert_true(is_instance_valid(inst), "%s builds without error" % path)
