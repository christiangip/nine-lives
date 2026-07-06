extends GutTest
## FR-19-3: ContentValidator validates the base game clean AND rejects malformed content — a missing
## required field, a duplicate id, a dangling cross-reference, and a bad id format — each with a clear,
## specific message. Proves the validator is not a rubber stamp (mirrors test_data_tables_valid). The
## malformed content is delivered as an enabled fixture pack, exercising the real scan+validate path.
## See docs/tasks/19_expansion_framework.md.

const ROOT := "user://test_packs_validator"
const PACK := "user://test_packs_validator/broken_pack"
const STATE := "user://test_packs_validator_state.json"

func before_all() -> void:
	_build_broken_pack()

func after_all() -> void:
	PackManager.reset()
	Content.reload()
	TestHelper.rm_tree(ROOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))

func before_each() -> void:
	PackManager.reset()
	Content.reload()   # guarantee base-only content regardless of test order

func test_base_game_validates_clean() -> void:
	var errors := ContentValidator.validate()
	assert_eq(errors.size(), 0, "base game content is valid — violations: %s" % str(errors))

func test_rejects_malformed_pack() -> void:
	PackManager.configure([ROOT], STATE)
	PackManager.set_enabled(&"broken_pack", true)   # reload now includes the broken content

	var errors := ContentValidator.validate()
	assert_gt(errors.size(), 0, "malformed content produces violations")
	assert_true(_has(errors, "scene_path"), "flags the station's empty required scene_path: %s" % str(errors))
	assert_true(_has(errors, "duplicate id"), "flags the duplicate cash_bundle id: %s" % str(errors))
	assert_true(_has(errors, "unknown sections"), "flags the archetype's dangling section reference: %s" % str(errors))
	assert_true(_has(errors, "lowercase_snake"), "flags the bad id format: %s" % str(errors))

func _has(errors: Array, needle: String) -> bool:
	for e in errors:
		if String(e).findn(needle) != -1:
			return true
	return false

# --- Fixture: a pack that violates every check ------------------------------
func _build_broken_pack() -> void:
	DirAccess.make_dir_recursive_absolute(PACK.path_join("loot"))
	DirAccess.make_dir_recursive_absolute(PACK.path_join("stations"))
	DirAccess.make_dir_recursive_absolute(PACK.path_join("archetypes"))
	var mf := FileAccess.open(PACK.path_join("pack.json"), FileAccess.WRITE)
	mf.store_string('{ "id": "broken_pack", "name": "Broken", "version": "1.0", "default_enabled": false }')
	mf.close()

	# Duplicate id (collides with the base game's cash_bundle).
	var dup := LootDef.new()
	dup.id = &"cash_bundle"
	dup.display_name = "Dup Cash"
	dup.value = 1
	ResourceSaver.save(dup, PACK.path_join("loot/dup_cash.tres"))

	# Bad id format (uppercase — not lowercase_snake).
	var bad := LootDef.new()
	bad.id = &"Bad_Id"
	bad.display_name = "Bad Id"
	bad.value = 10
	ResourceSaver.save(bad, PACK.path_join("loot/bad_id.tres"))

	# Missing required field (StationDef with empty scene_path).
	var station := StationDef.new()
	station.id = &"broken_station"
	station.display_name = "Broken Station"
	ResourceSaver.save(station, PACK.path_join("stations/broken_station.tres"))

	# Dangling reference (archetype points at a section id that doesn't exist).
	var arch := ArchetypeDef.new()
	arch.id = &"broken_arch"
	arch.display_name = "Broken Arch"
	var secs: Array[StringName] = [&"ghost_section"]
	arch.section_ids = secs
	var objs: Array[StringName] = [&"grab_value"]
	arch.objective_ids = objs
	ResourceSaver.save(arch, PACK.path_join("archetypes/broken_arch.tres"))
