extends GutTest
## Spec: duplicate ids in a scanned folder are detected and reported, and lookups
## stay deterministic (one stable entry; first writer wins).
## docs/tasks/02_core_architecture.md.

const TMP_DIR := "user://test_registry_dupes"

func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)

func after_all() -> void:
	TestHelper.rm_dir(TMP_DIR)

func test_duplicate_ids_are_detected_and_lookup_is_deterministic() -> void:
	var a := LootDef.new()
	a.id = &"twin"
	a.value = 100
	var b := LootDef.new()
	b.id = &"twin"
	b.value = 999
	ResourceSaver.save(a, TMP_DIR.path_join("aaa_twin.tres"))
	ResourceSaver.save(b, TMP_DIR.path_join("bbb_twin.tres"))

	var reg := ContentRegistry.new(LootDef, [TMP_DIR])
	reg.scan()

	assert_true(&"twin" in reg.duplicate_ids, "the duplicated id is reported")
	assert_eq(reg.size(), 1, "only one entry is kept for the duplicated id")
	assert_not_null(reg.get_def(&"twin"), "the id is still queryable after a collision")
