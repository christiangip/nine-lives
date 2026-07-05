extends GutTest
## Task 16 (FR-16-6): a rich permanent + Streak state survives save → reset → load exactly.
## docs/tasks/16_save_system.md.

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	GameManager.active_slot = 0
	_reset()

func after_each() -> void:
	TestHelper.rm_dir(SaveManager.SAVE_DIR)
	_reset()

func _reset() -> void:
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func test_roundtrip_preserves_all_state() -> void:
	# Permanent account
	ProgressionManager.legacy = 5000
	ProgressionManager.attributes[&"lockpicking"] = 4
	ProgressionManager.unlocked_gear = [&"lockpick", &"suppressed_pistol"]
	ProgressionManager.research_done = [&"suppressed_pistol"]
	ProgressionManager.stations_unlocked = [&"armory"]
	ProgressionManager.stash = [&"trophy_painting"]
	ProgressionManager.stats[&"streaks_caught"] = 3
	# Current Streak
	RunManager.notoriety = 2400
	RunManager.streak_level = 3
	RunManager.streak_length = 4
	RunManager.heat = 0.4
	RunManager.take = 1500
	RunManager.edges = [&"silent_hands"]
	RunManager.last_contract = "First National Bank"
	var c := Contract.new()
	c.archetype_id = &"bank"; c.objective_id = &"crack_vault"; c.mission_seed = 12345; c.tier = 2
	RunManager.job_board = [c]
	RunManager.intel_by_seed[12345] = ["modifiers"]

	assert_true(SaveManager.save_slot(0), "save_slot succeeds")
	# Snapshot AFTER save (save accumulates lifetime playtime into the permanent block).
	var perm_expected := ProgressionManager.to_dict()
	var streak_expected := RunManager.to_dict()

	_reset()
	assert_eq(ProgressionManager.legacy, 0, "reset cleared the account")
	assert_true(SaveManager.load_slot(0), "load_slot succeeds")

	# Permanent
	assert_eq(ProgressionManager.legacy, 5000, "legacy restored")
	assert_eq(ProgressionManager.attribute_level(&"lockpicking"), 4, "attribute restored")
	assert_true(&"suppressed_pistol" in ProgressionManager.unlocked_gear, "unlock restored")
	assert_true(&"armory" in ProgressionManager.stations_unlocked, "station restored")
	assert_true(&"trophy_painting" in ProgressionManager.stash, "stash restored")
	assert_eq(int(ProgressionManager.stats.get(&"streaks_caught", 0)), 3, "stats restored")
	assert_eq(ProgressionManager.to_dict(), perm_expected, "permanent block deep-equal")

	# Streak
	assert_eq(RunManager.notoriety, 2400, "notoriety restored")
	assert_eq(RunManager.streak_level, 3, "streak level restored")
	assert_eq(RunManager.take, 1500, "take restored")
	assert_true(&"silent_hands" in RunManager.edges, "edge restored")
	assert_eq(RunManager.last_contract, "First National Bank", "last_contract restored")
	assert_eq(RunManager.job_board.size(), 1, "job board restored")
	assert_eq((RunManager.job_board[0] as Contract).mission_seed, 12345, "contract seed restored")
	assert_eq(RunManager.intel_by_seed.get(12345, []), ["modifiers"], "intel restored")
	assert_eq(RunManager.to_dict(), streak_expected, "streak block deep-equal")
