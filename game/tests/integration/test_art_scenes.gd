extends GutTest
## Task 18 (FR-18-7): the art scenes + the dressed generated mission instantiate headlessly without error —
## the section `scene` seam actually fires (real SectionShell nodes end up in the mission), and the browse
## gallery hub + the standalone Bank showcase still build. Mirrors test_hideout_scenes.gd.
## See docs/tasks/18_art_asset_pipeline.md.

func _contract(seed_v: int, objective: StringName = &"crack_vault") -> Contract:
	var c := Contract.new()
	c.archetype_id = &"bank"
	c.objective_id = objective
	c.mission_seed = seed_v
	c.tier = 1
	c.difficulty = 1
	return c

func test_section_prefabs_build() -> void:
	for path in ["res://game/prefabs/sections/vault.tscn", "res://game/prefabs/sections/entry_lobby.tscn"]:
		var packed := load(path) as PackedScene
		assert_not_null(packed, "%s loads" % path)
		var shell = packed.instantiate()
		add_child_autofree(shell)
		assert_true(shell is SectionShell, "%s roots a SectionShell" % path)
		assert_gt(shell.get_child_count(), 0, "%s built its floor/walls/decor in _ready" % path)

func test_gallery_hub_instantiates() -> void:
	var packed := load("res://game/scenes/art/gallery_hub.tscn") as PackedScene
	assert_not_null(packed, "the gallery hub loads")
	var hub = packed.instantiate()
	add_child_autofree(hub)
	assert_true(is_instance_valid(hub), "the gallery hub built without error")

func test_bank_showcase_instantiates() -> void:
	var packed := load("res://game/scenes/art/bank_test.tscn") as PackedScene
	assert_not_null(packed, "the Bank showcase loads")
	var demo = packed.instantiate()
	add_child_autofree(demo)
	assert_true(is_instance_valid(demo), "the dressed Bank showcase built without error")

func test_generated_bank_dresses_with_real_sections() -> void:
	var controller := MissionGenerator.build(_contract(11))
	assert_not_null(controller, "the generator built a MissionController")
	add_child_autofree(controller)
	assert_true(is_instance_valid(controller), "the dressed mission realized without error")
	var shells := 0
	for n in controller.find_children("*", "Node3D", true, false):
		if n is SectionShell:
			shells += 1
	assert_gt(shells, 0, "the SectionDef.scene seam fired — real section shells are in the generated mission")
