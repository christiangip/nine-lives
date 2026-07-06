extends GutTest
## Task 20 (FR-20-5): a packaged NEW archetype appears on the board with no code change — enabling the
## shipped live_season pack registers its Casino archetype and makes it generatable; disabling removes
## it. Exercises the real PackManager discover→enable→Content.reload path (a temp state file keeps CI off
## the player's user://packs.json). See docs/tasks/20_progression_milestones.md and docs/CONTENT_PACKS.md.

const STATE := "user://test_live_pack_state.json"

func before_each() -> void:
	PackManager.reset()
	Content.reload()   # base-only content regardless of prior test order

func after_all() -> void:
	PackManager.reset()
	Content.reload()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))

func test_pack_archetype_absent_until_enabled() -> void:
	assert_false(Content.archetypes.has(&"casino"), "casino is not in base content")
	assert_false(_generatable_has(&"casino"), "and not on the board with the pack disabled")

func test_enabling_pack_lands_archetype_on_board() -> void:
	PackManager.configure(["res://game/packs"], STATE)   # real packs, temp enable-state
	PackManager.set_enabled(&"live_season", true)         # persists + Content.reload()

	assert_true(Content.archetypes.has(&"casino"), "the pack's archetype registered by id, no code change")
	assert_true(_generatable_has(&"casino"), "and is generatable — it appears on the board live (FR-20-5)")
	# The pack also drops in a milestone + a modifier purely as data.
	assert_true(Content.milestones.has(&"vip_list"), "the pack's milestone arc registered too")
	assert_true(Content.modifiers.has(&"vip_security"), "the pack's event modifier registered too")

func test_disabling_pack_removes_archetype() -> void:
	PackManager.configure(["res://game/packs"], STATE)
	PackManager.set_enabled(&"live_season", true)
	assert_true(_generatable_has(&"casino"), "present while enabled")
	PackManager.set_enabled(&"live_season", false)
	assert_false(_generatable_has(&"casino"), "gone again when disabled — pure data toggle")

func _generatable_has(id: StringName) -> bool:
	for a in MissionBoard.generatable_archetypes():
		if (a as ArchetypeDef).id == id:
			return true
	return false
