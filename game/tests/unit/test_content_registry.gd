extends GutTest
## Spec: a ContentRegistry scans a folder of *Def `.tres` (and bulk JSON) and indexes
## by id, so dropping in new content makes it queryable with zero code changes
## (FR-02-3..5). docs/tasks/02_core_architecture.md.

const TMP_DIR := "user://test_registry_loot"
const TMP_EDGES := "user://test_registry_edges"
const TMP_JSON := "user://test_registry_loot.json"

func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)

func after_all() -> void:
	TestHelper.rm_dir(TMP_DIR)
	TestHelper.rm_dir(TMP_EDGES)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_JSON))

func test_dropped_tres_is_indexed_by_id() -> void:
	var loot := LootDef.new()
	loot.id = &"test_emerald"
	loot.display_name = "Emerald"
	loot.value = 4200
	ResourceSaver.save(loot, TMP_DIR.path_join("emerald.tres"))

	var reg := ContentRegistry.new(LootDef, [TMP_DIR])
	reg.scan()

	assert_true(reg.has(&"test_emerald"), "registry indexes the dropped def by id")
	var got := reg.get_def(&"test_emerald") as LootDef
	assert_not_null(got, "get_def returns the indexed def")
	assert_eq(got.value, 4200, "indexed def keeps its data")
	assert_eq(reg.size(), 1, "exactly one def indexed")
	assert_true(&"test_emerald" in reg.ids(), "ids() lists the def")

func test_json_hydration_resolves_enum_names() -> void:
	var f := FileAccess.open(TMP_JSON, FileAccess.WRITE)
	f.store_string('[{ "id": "test_ingot", "tier": "BULKY", "value": 900, "weight": 8.0 }]')
	f.close()

	var reg := ContentRegistry.new(LootDef, [], [TMP_JSON])
	reg.scan()

	var got := reg.get_def(&"test_ingot") as LootDef
	assert_not_null(got, "JSON object is hydrated and indexed by id")
	assert_eq(got.tier, LootDef.Tier.BULKY, "enum-name string coerces to the enum int")
	assert_eq(got.value, 900, "scalar fields hydrate")

func test_filter_is_property_based() -> void:
	var ghost := EdgeDef.new()
	ghost.id = &"test_ghost"
	var ghost_tags: Array[StringName] = [&"ghost", &"stealth"]
	ghost.tags = ghost_tags
	var mule := EdgeDef.new()
	mule.id = &"test_mule"
	var mule_tags: Array[StringName] = [&"mule"]
	mule.tags = mule_tags

	DirAccess.make_dir_recursive_absolute(TMP_EDGES)
	ResourceSaver.save(ghost, TMP_EDGES.path_join("ghost.tres"))
	ResourceSaver.save(mule, TMP_EDGES.path_join("mule.tres"))

	var reg := ContentRegistry.new(EdgeDef, [TMP_EDGES])
	reg.scan()

	var stealthy := reg.filter(&"ghost")
	assert_eq(stealthy.size(), 1, "filter returns only defs tagged 'ghost'")
	assert_eq((stealthy[0] as EdgeDef).id, &"test_ghost", "the right def is returned")
	assert_eq(reg.filter(&"nonexistent").size(), 0, "an unknown tag yields empty")

func test_missing_dir_is_safe() -> void:
	var reg := ContentRegistry.new(LootDef, ["user://does_not_exist_xyz"])
	reg.scan()
	assert_eq(reg.size(), 0, "scanning a missing folder yields an empty, non-crashing registry")
