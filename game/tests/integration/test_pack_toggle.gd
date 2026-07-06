extends GutTest
## FR-19-4/6: toggling the shipped "The Estate Job" pack surfaces/removes its content live, and a save
## that references pack content still LOADS after the pack is disabled — the preserve-but-dormant policy:
## SaveReconcile reports the dormant ids, nothing is stripped or crashes, and re-enabling revives it with
## no data loss. Uses the real res://game/packs pack via a temp state file (never the real user://packs.json).
## See docs/tasks/19_expansion_framework.md and docs/CONTENT_PACKS.md.

const STATE := "user://test_pack_toggle_state.json"
var _prog_snapshot: Dictionary

func before_all() -> void:
	_prog_snapshot = ProgressionManager.to_dict()
	PackManager.configure([PackManager.DEFAULT_PACK_ROOT], STATE)

func after_all() -> void:
	PackManager.reset()
	Content.reload()
	ProgressionManager.from_dict(_prog_snapshot)   # undo the granted unlock
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))

func test_toggle_surfaces_and_removes_pack_content() -> void:
	PackManager.set_enabled(&"estate_job", true)
	assert_true(Content.archetypes.has(&"estate"), "enabled pack adds its archetype")
	assert_true(Content.gear.has(&"estate_snips"), "…its gear")
	assert_true(Content.stations.has(&"locksmith"), "…its station")
	assert_true(Content.sections.has(&"estate_gallery"), "…its sections")

	PackManager.set_enabled(&"estate_job", false)
	assert_false(Content.archetypes.has(&"estate"), "disabling removes its archetype")
	assert_false(Content.gear.has(&"estate_snips"), "…and its gear")

func test_save_referencing_disabled_pack_still_loads() -> void:
	PackManager.set_enabled(&"estate_job", true)
	# A save would hold these as earned permanent unlocks.
	if not (&"estate_snips" in ProgressionManager.unlocked_gear):
		ProgressionManager.unlocked_gear.append(&"estate_snips")

	PackManager.set_enabled(&"estate_job", false)   # pack gone, save data stays

	assert_true(&"estate_snips" in ProgressionManager.unlocked_gear,
		"a disabled-pack unlock is preserved (dormant), never stripped")
	var unknown := SaveReconcile.unknown_ids()
	assert_true(unknown.has(&"gear") and &"estate_snips" in unknown[&"gear"],
		"SaveReconcile reports the dormant gear id (nothing crashed)")

	PackManager.set_enabled(&"estate_job", true)   # re-enable → revive
	assert_true(Content.gear.has(&"estate_snips"), "re-enabling the pack revives the content")
	var revived := SaveReconcile.unknown_ids()
	assert_false(revived.has(&"gear") and &"estate_snips" in revived.get(&"gear", []),
		"no longer dormant once the pack is back")
