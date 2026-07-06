extends GutTest
## FR-19-1/4: dropping a content-pack folder (a pack.json manifest + category subfolders of .tres) and
## enabling it surfaces the pack's content through the EXISTING registries with ZERO code change — the
## "expansions ship as data" platform promise, proven at the pack level. Mirrors test_content_registry's
## drop-in-a-folder proof, one layer up. See docs/tasks/19_expansion_framework.md and docs/CONTENT_PACKS.md.

const ROOT := "user://test_packs_addcontent"
const PACK := "user://test_packs_addcontent/aurora_pack"
const STATE := "user://test_packs_addcontent_state.json"

func before_all() -> void:
	_build_fixture_pack()

func after_all() -> void:
	# Restore the base registries + real pack root for the rest of the suite.
	PackManager.reset()
	Content.reload()
	TestHelper.rm_tree(ROOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))

func before_each() -> void:
	PackManager.configure([ROOT], STATE)
	Content.reload()   # base + (disabled-by-default) fixture pack → aurora absent

func test_pack_absent_until_enabled() -> void:
	assert_false(Content.loot.has(&"aurora_gem"), "pack content is absent before the pack is enabled")

func test_enabled_pack_surfaces_content_via_registries() -> void:
	PackManager.set_enabled(&"aurora_pack", true)   # persists + Content.reload()
	assert_true(Content.loot.has(&"aurora_gem"), "enabling the pack surfaces its loot with no code change")
	assert_true(Content.edges.has(&"aurora_edge"), "…and its edges")
	var got := Content.loot.get_def(&"aurora_gem") as LootDef
	assert_not_null(got, "the pack def is a real, queryable def")
	assert_eq(got.value, 5000, "the pack def keeps its authored data")

func test_disabling_removes_pack_content() -> void:
	PackManager.set_enabled(&"aurora_pack", true)
	assert_true(Content.loot.has(&"aurora_gem"), "sanity: enabled")
	PackManager.set_enabled(&"aurora_pack", false)
	assert_false(Content.loot.has(&"aurora_gem"), "disabling the pack cleanly removes its content")

# --- Fixture ---------------------------------------------------------------
func _build_fixture_pack() -> void:
	DirAccess.make_dir_recursive_absolute(PACK.path_join("loot"))
	DirAccess.make_dir_recursive_absolute(PACK.path_join("edges"))
	var mf := FileAccess.open(PACK.path_join("pack.json"), FileAccess.WRITE)
	mf.store_string('{ "id": "aurora_pack", "name": "Aurora", "version": "1.0", "default_enabled": false }')
	mf.close()
	var loot := LootDef.new()
	loot.id = &"aurora_gem"
	loot.display_name = "Aurora Gem"
	loot.value = 5000
	ResourceSaver.save(loot, PACK.path_join("loot/aurora_gem.tres"))
	var edge := EdgeDef.new()
	edge.id = &"aurora_edge"
	edge.display_name = "Aurora Edge"
	var tags: Array[StringName] = [&"ghost"]
	edge.tags = tags
	ResourceSaver.save(edge, PACK.path_join("edges/aurora_edge.tres"))
