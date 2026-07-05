extends GutTest
## Task 16 (FR-16-7): an old (v1) save upgrades to the current schema via migrate(), both as a raw
## dict and when loaded from disk. docs/tasks/16_save_system.md.

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	GameManager.active_slot = 0
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func after_each() -> void:
	TestHelper.rm_dir(SaveManager.SAVE_DIR)
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func _v1_save() -> Dictionary:
	# A pre-task-16 save: no active_mission_committed flag, no permanent.playtime_seconds.
	return {
		"schema_version": 1,
		"meta": {"streak_len": 1, "legacy": 777, "playtime": 0, "last_played": "2026-01-01", "last_contract": "Old Save"},
		"permanent": {"legacy": 777, "attributes": {}, "unlocked_gear": [], "research_done": [],
			"meta_perks": [], "stations_unlocked": [], "stash": [], "stats": {}},
		"streak": {"notoriety": 0, "streak_level": 1, "streak_length": 1, "heat": 0.0, "take": 0,
			"edges": [], "committed": false, "loadout": {}, "job_board": [], "intel_by_seed": {}},
	}

func test_migrate_dict_upgrades_and_stamps() -> void:
	var up := SaveManager.migrate(_v1_save())
	assert_eq(int(up["schema_version"]), SaveManager.SCHEMA_VERSION, "stamped to current version")
	assert_true(up.has("active_mission_committed"), "checkpoint flag added")
	assert_true((up["permanent"] as Dictionary).has("playtime_seconds"), "playtime field added")

func test_v1_file_loads_and_applies() -> void:
	var f := FileAccess.open("%s/slot_0.json" % SaveManager.SAVE_DIR, FileAccess.WRITE)
	f.store_string(JSON.stringify(_v1_save()))
	f.close()
	assert_true(SaveManager.load_slot(0), "a v1 save on disk loads")
	assert_eq(ProgressionManager.legacy, 777, "v1 permanent state applied")
	assert_eq(ProgressionManager.playtime_seconds, 0.0, "migration defaulted the new field")
