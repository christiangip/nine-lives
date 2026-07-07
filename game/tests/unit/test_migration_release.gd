extends GutTest
## Task 21 FR-21-5 (extends task 16): a previous-version (v1) save migrates to the current schema with ZERO
## data loss — every permanent + Streak field survives, the v2 fields and the task-19/20 additive fields
## default safely, and a subsequent save→load round-trips identically (the "update, then keep playing" cycle
## must not drift any field). This is the release-QA migration gate. See docs/QA_MATRIX.md.

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	GameManager.active_slot = 0
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func after_each() -> void:
	TestHelper.rm_dir(SaveManager.SAVE_DIR)
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

## A RICH pre-task-16 (v1) save: populated permanent + Streak, missing the v2 fields
## (active_mission_committed, permanent.playtime_seconds) and the task-19/20 additive fields.
func _rich_v1_save() -> Dictionary:
	return {
		"schema_version": 1,
		"meta": {"streak_len": 4, "legacy": 8200, "playtime": 0, "last_played": "2026-02-02", "last_contract": "Old Bank"},
		"permanent": {
			"legacy": 8200,
			"attributes": {"lockpicking": 5, "stamina": 2},
			"unlocked_gear": ["lockpick", "suppressed_pistol", "keycard_cloner"],
			"research_done": ["suppressed_pistol"],
			"meta_perks": ["nimble", "ghost_protocol"],
			"stations_unlocked": ["armory", "workshop"],
			"stash": ["trophy_painting"],
			"stats": {"streaks_caught": 6, "contracts_completed": 19},
		},
		"streak": {
			"notoriety": 3300, "streak_level": 4, "streak_length": 4, "heat": 0.35, "take": 2100,
			"edges": ["silent_hands", "mule"], "committed": false,
			"loadout": {}, "job_board": [], "intel_by_seed": {},
		},
	}

func _write_v1_to_slot0() -> void:
	var f := FileAccess.open("%s/slot_0.json" % SaveManager.SAVE_DIR, FileAccess.WRITE)
	f.store_string(JSON.stringify(_rich_v1_save()))
	f.close()

func test_v1_migrates_with_zero_data_loss() -> void:
	_write_v1_to_slot0()
	assert_true(SaveManager.load_slot(0), "a rich v1 save on disk loads")

	# Permanent — every v1 field survived.
	assert_eq(ProgressionManager.legacy, 8200, "legacy preserved")
	assert_eq(ProgressionManager.attribute_level(&"lockpicking"), 5, "attribute preserved")
	assert_eq(ProgressionManager.attribute_level(&"stamina"), 2, "second attribute preserved")
	assert_true(&"keycard_cloner" in ProgressionManager.unlocked_gear, "gear unlock preserved")
	assert_true(&"suppressed_pistol" in ProgressionManager.research_done, "research preserved")
	assert_true(&"ghost_protocol" in ProgressionManager.meta_perks, "Legacy Perk preserved")
	assert_true(&"workshop" in ProgressionManager.stations_unlocked, "station preserved")
	assert_true(&"trophy_painting" in ProgressionManager.stash, "stash preserved")
	assert_eq(int(ProgressionManager.stats.get(&"streaks_caught", 0)), 6, "lifetime stats preserved")

	# Streak — every v1 field survived.
	assert_eq(RunManager.notoriety, 3300, "notoriety preserved")
	assert_eq(RunManager.streak_level, 4, "streak level preserved")
	assert_almost_eq(RunManager.heat, 0.35, 0.0001, "heat preserved")
	assert_eq(RunManager.take, 2100, "take preserved")
	assert_true(&"mule" in RunManager.edges, "edge preserved")

	# New fields default safely (no crash, no garbage) — v2 + the task-19/20 additive fields.
	assert_eq(ProgressionManager.playtime_seconds, 0.0, "the v2 playtime field defaulted")
	assert_eq(ProgressionManager.unlocked_archetypes.size(), 0, "task-20 unlocked_archetypes defaults empty")
	assert_eq(ProgressionManager.milestones_reached.size(), 0, "task-20 milestones_reached defaults empty")
	assert_eq(ProgressionManager.titles_earned.size(), 0, "task-20 titles_earned defaults empty")

func test_migrate_stamps_current_version() -> void:
	var up := SaveManager.migrate(_rich_v1_save())
	assert_eq(int(up["schema_version"]), SaveManager.SCHEMA_VERSION, "migrate stamps the current schema version")
	assert_true(up.has("active_mission_committed"), "the v2 checkpoint flag was added")
	assert_true((up["permanent"] as Dictionary).has("playtime_seconds"), "the v2 playtime field was added")

func test_migrated_save_round_trips_identically() -> void:
	# Load a v1 save, then re-save under the current schema and reload — the "update then keep playing"
	# cycle must not drift any field.
	_write_v1_to_slot0()
	assert_true(SaveManager.load_slot(0), "v1 loads")
	assert_true(SaveManager.save_slot(0), "re-saves under the current schema")
	var perm_expected := ProgressionManager.to_dict()
	var streak_expected := RunManager.to_dict()
	ProgressionManager.from_dict({})
	RunManager.from_dict({})
	assert_true(SaveManager.load_slot(0), "reloads the migrated slot")
	assert_eq(ProgressionManager.to_dict(), perm_expected, "permanent block identical after the update round-trip")
	assert_eq(RunManager.to_dict(), streak_expected, "streak block identical after the update round-trip")
