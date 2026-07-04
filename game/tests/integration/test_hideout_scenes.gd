extends GutTest
## Task 13: smoke test that the Hideout hub + every station panel actually instantiate and build their
## UI in-tree without error (the panels build their controls in _ready/_populate). Guards the 2D hub
## against panel regressions and proves every StationDef.scene_path resolves to a real StationPanel.

const HIDEOUT := "res://game/scenes/hideout/Hideout.tscn"

func before_each() -> void:
	# A fresh Streak gives the Job Map / Planning panels a board to render.
	RunManager.start_new_streak()
	ProgressionManager.legacy = 1000
	RunManager.take = 5000

func test_hideout_hub_instantiates() -> void:
	var packed := load(HIDEOUT) as PackedScene
	assert_not_null(packed, "the Hideout hub scene loads")
	var hub = packed.instantiate()
	add_child_autofree(hub)
	assert_true(is_instance_valid(hub), "the hub builds its station grid without error")

func test_every_station_panel_builds() -> void:
	# Unlock everything so every panel is reachable + renders its populated body.
	for res in Content.stations.all():
		var def := res as StationDef
		if def != null and def.id not in ProgressionManager.stations_unlocked:
			ProgressionManager.stations_unlocked.append(def.id)
	assert_gt(Content.stations.size(), 0, "stations are registered")
	for res in Content.stations.all():
		var def := res as StationDef
		var packed := load(def.scene_path) as PackedScene
		assert_not_null(packed, "station '%s' scene_path resolves" % def.id)
		var panel = packed.instantiate()
		assert_true(panel is StationPanel, "station '%s' root is a StationPanel" % def.id)
		add_child_autofree(panel)
		assert_true(is_instance_valid(panel), "station '%s' panel built its UI" % def.id)

func test_greybox_demo_instantiates() -> void:
	# The 3D furnished demo builds its room/props/mannequin from the Phase-1 art in _ready().
	var packed := load("res://game/scenes/hideout/HideoutGreybox.tscn") as PackedScene
	assert_not_null(packed, "the greybox scene loads")
	var demo = packed.instantiate()
	add_child_autofree(demo)
	assert_true(is_instance_valid(demo), "the furnished demo builds without error")
