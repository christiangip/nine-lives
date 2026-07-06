extends GutTest
## Pure-seam checks for PackManager (task 19): manifest discovery, default-enabled state, and the category
## scan-hooks (tres_dirs_for / json_files_for) that Content._make appends. Read side only — no Content
## reload side effects. See docs/tasks/19_expansion_framework.md.

const ROOT := "user://test_packmgr"
const PACK := "user://test_packmgr/demo_pack"
const STATE := "user://test_packmgr_state.json"

func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(PACK.path_join("loot"))
	var mf := FileAccess.open(PACK.path_join("pack.json"), FileAccess.WRITE)
	mf.store_string('{ "id": "demo_pack", "name": "Demo", "version": "2.1", "default_enabled": true }')
	mf.close()
	var jf := FileAccess.open(PACK.path_join("loot.json"), FileAccess.WRITE)
	jf.store_string('[]')
	jf.close()

func after_all() -> void:
	PackManager.reset()
	TestHelper.rm_tree(ROOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))

func before_each() -> void:
	# Fresh: no state file → default_enabled from the manifest.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))
	PackManager.configure([ROOT], STATE)

func test_discovers_manifest() -> void:
	var packs := PackManager.installed()
	assert_eq(packs.size(), 1, "discovers exactly the one fixture pack")
	assert_eq(String(packs[0]["id"]), "demo_pack", "reads the manifest id")
	assert_eq(String(packs[0]["name"]), "Demo", "reads the manifest name")

func test_default_enabled_from_manifest() -> void:
	assert_true(PackManager.is_enabled(&"demo_pack"), "default_enabled=true starts the pack enabled")

func test_tres_dirs_for_returns_existing_subfolder_only() -> void:
	var loot_dirs := PackManager.tres_dirs_for(&"loot")
	assert_eq(loot_dirs.size(), 1, "the loot/ subfolder is offered to the loot registry")
	assert_true(String(loot_dirs[0]).ends_with("demo_pack/loot"), "…with the right path")
	assert_eq(PackManager.tres_dirs_for(&"gear").size(), 0, "no gear/ subfolder → nothing offered")

func test_json_files_for_returns_bulk_file() -> void:
	var jsons := PackManager.json_files_for(&"loot")
	assert_eq(jsons.size(), 1, "the loot.json bulk file is offered")
	assert_true(String(jsons[0]).ends_with("demo_pack/loot.json"), "…with the right path")

func test_disabled_pack_offers_nothing() -> void:
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	f.store_string('{ "enabled": { "demo_pack": false } }')
	f.close()
	PackManager.configure([ROOT], STATE)   # re-read the disabling state
	assert_false(PackManager.is_enabled(&"demo_pack"), "the state file disables the pack")
	assert_eq(PackManager.tres_dirs_for(&"loot").size(), 0, "a disabled pack offers no folders")
