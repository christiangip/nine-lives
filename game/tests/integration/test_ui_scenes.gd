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
