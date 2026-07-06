extends GutTest
## Task 20 (FR-20-2): a standalone Challenge run is ISOLATED from the endless Streak — it snapshots +
## restores the real Streak, and an alarm inside it never flips the on-disk strict-save commit flag. This
## is the riskiest slice, so it's regression-locked here. See docs/tasks/20_progression_milestones.md.

const RESULTS := "user://test_challenge_results.json"

func before_each() -> void:
	LiveChallenges.configure(RESULTS)
	GameManager.active_slot = -1
	RunManager.challenge_mode = false
	RunManager._streak_snapshot = {}
	ProgressionManager.legacy = 0
	# A clean real-Streak baseline.
	RunManager.notoriety = 0
	RunManager.heat = 0.0
	RunManager.take = 0
	RunManager.streak_length = 0
	RunManager.committed = false

func after_all() -> void:
	LiveChallenges.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULTS))
	GameManager.active_slot = -1

func test_challenge_restores_the_streak_exactly() -> void:
	RunManager.notoriety = 5000
	RunManager.heat = 0.4
	RunManager.take = 800
	RunManager.streak_length = 3
	RunManager.begin_challenge(12345, "daily", 100)
	assert_true(RunManager.challenge_mode, "entered challenge mode")
	assert_eq(RunManager.notoriety, 0, "the Challenge runs on a clean scratch streak")
	# Earn Notoriety + go loud inside the Challenge — all of this must be discarded on restore.
	RunManager.notoriety = 999
	RunManager.heat = 0.9
	RunManager.committed = true
	RunManager._on_mission_completed({"secured_value": 4000, "elapsed_seconds": 90.0})
	RunManager.end_challenge()   # what GameManager.goto_results does after a Challenge
	assert_false(RunManager.challenge_mode, "challenge mode cleared")
	assert_eq(RunManager.notoriety, 5000, "real Streak Notoriety restored")
	assert_almost_eq(RunManager.heat, 0.4, 0.001, "real Streak Heat restored")
	assert_eq(RunManager.take, 800, "real Streak Take restored")
	assert_eq(RunManager.streak_length, 3, "real Streak length restored")
	assert_false(RunManager.committed, "real Streak commit flag restored")
	assert_eq(ProgressionManager.legacy, 100, "the first-clear Legacy reward persists (Challenges do pay Legacy)")

func test_catch_in_a_challenge_does_not_convert_the_streak() -> void:
	RunManager.notoriety = 5000
	RunManager.streak_length = 2
	RunManager.begin_challenge(222, "daily", 0)
	var caught := RunManager.end_streak("caught")   # a Catch DURING the Challenge
	assert_eq(caught, 0, "no Notoriety→Legacy conversion for a Challenge Catch")
	RunManager.end_challenge()
	assert_eq(RunManager.notoriety, 5000, "the real Streak's Notoriety is untouched")
	assert_eq(RunManager.streak_length, 2, "the real Streak length is untouched")
	assert_eq(ProgressionManager.legacy, 0, "no Legacy banked from a Challenge Catch")

func test_alarm_in_a_challenge_never_commits_the_save() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")   # a prior save test may have removed it
	GameManager.active_slot = 0
	assert_true(SaveManager.save_slot(0), "seed a clean save at the active slot")
	assert_false(bool(SaveManager._read_slot(0).get("active_mission_committed", false)), "starts uncommitted")

	RunManager.begin_challenge(333, "daily", 0)
	RunManager._on_alarm_tripped("silent", Vector3.ZERO)   # would mark_committed in a normal run
	assert_false(bool(SaveManager._read_slot(0).get("active_mission_committed", false)),
		"an alarm during a Challenge must NOT flip the on-disk commit flag")
	RunManager.end_challenge()

	# Contrast: OUTSIDE a Challenge the very same alarm DOES commit on disk — proving the guard matters.
	RunManager.committed = false
	SaveManager.save_slot(0)
	RunManager._on_alarm_tripped("silent", Vector3.ZERO)
	assert_true(bool(SaveManager._read_slot(0).get("active_mission_committed", false)),
		"outside a Challenge the alarm commits on disk (strict saves)")

	SaveManager.delete_slot(0)
	GameManager.active_slot = -1
