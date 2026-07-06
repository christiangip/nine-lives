extends GutTest
## Task 18: the master material set (Palette) + the art `scene`/`mesh`/`model` def seams resolve — the
## pure, headless half of FR-18-1/2/7. See docs/tasks/18_art_asset_pipeline.md.

func test_every_master_material_resolves() -> void:
	assert_gt(Palette.names().size(), 0, "the master material set is registered")
	for name in Palette.names():
		var m := Palette.material(name)
		assert_not_null(m, "master material '%s' resolves" % name)
		assert_true(m is StandardMaterial3D, "'%s' is a StandardMaterial3D" % name)

func test_material_is_cached_and_shared() -> void:
	assert_true(Palette.material(&"floor") == Palette.material(&"floor"), "named materials are cached/shared")

func test_tinted_is_fresh_and_coloured() -> void:
	var a := Palette.tinted(Palette.TINT_GUARD)
	assert_eq(a.albedo_color, Palette.TINT_GUARD, "tinted() carries the requested colour")
	assert_false(a == Palette.tinted(Palette.TINT_GUARD), "tinted() returns a fresh material each call")

func test_missing_material_falls_back_not_null() -> void:
	assert_not_null(Palette.material(&"does_not_exist"), "an unknown name still returns a flat fallback (never hard-fails)")

func test_def_art_seams_exist() -> void:
	assert_true("scene" in ObstacleDef.new(), "ObstacleDef exposes a scene field")
	assert_true("mesh" in LootDef.new(), "LootDef exposes a mesh field")
	assert_true("model" in EnemyDef.new(), "EnemyDef exposes a model field")

func test_bank_vault_and_lobby_point_at_real_section_scenes() -> void:
	for id in [&"bank_vault", &"bank_entry_lobby"]:
		var def := Content.sections.get_def(id) as SectionDef
		assert_not_null(def, "%s section def is registered" % id)
		assert_not_null(def.scene, "%s.scene points at a real section prefab" % id)
		assert_true(def.scene is PackedScene, "%s.scene is a PackedScene" % id)

func test_actor_and_loot_defs_carry_art() -> void:
	var g := Content.enemies.get_def(&"guard") as EnemyDef
	assert_not_null(g.model, "the guard def carries a character model")
	var cash := Content.loot.get_def(&"cash_bundle") as LootDef
	assert_not_null(cash.mesh, "cash loot carries a mesh")
	var door := Content.obstacles.get_def(&"keycard_door") as ObstacleDef
	assert_not_null(door.scene, "the keycard door carries a prop scene")

func test_scaled_enemy_keeps_its_model() -> void:
	# EnemyDef.scaled() duplicates the def for difficulty tiers; the art reference must survive so scaled
	# reinforcements still render (MissionController spawns them via scaled()).
	var g := Content.enemies.get_def(&"guard") as EnemyDef
	assert_not_null(g.scaled(1.4).model, "a scaled enemy keeps its model reference")
