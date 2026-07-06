extends GutTest
## Task 20: smoke-test that the live UI instantiates without error — the Live Board station panel ("The
## Wire": milestones / event / challenges / season) and the Live Sandbox greybox (real art + dev
## controls). Restores base pack/registry/challenge/season state afterwards so it can't perturb other
## scene-smoke tests. Mirrors test_expansion_scenes / test_hideout_scenes.

const STATION := "res://game/scenes/hideout/stations/LiveBoardStation.tscn"
const SANDBOX := "res://game/scenes/live/LiveSandbox.tscn"

func before_each() -> void:
	RunManager.start_new_streak()   # a fresh Streak so job_board / loadout exist
	LiveChallenges.configure("user://test_live_scenes_results.json")

func after_each() -> void:
	# The panel/sandbox touch shared state (Content packs, challenge results, season baseline) — reset it.
	PackManager.reset()
	Content.reload()
	LiveChallenges.reset()
	if ProgressionManager != null:
		ProgressionManager.season_progress = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://packs_sandbox_live.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://challenge_results_sandbox.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_live_scenes_results.json"))

func test_live_board_station_instantiates() -> void:
	var packed := load(STATION) as PackedScene
	assert_not_null(packed, "the Live Board station scene loads")
	var panel = packed.instantiate()
	add_child_autofree(panel)
	assert_true(is_instance_valid(panel), "The Wire builds its milestone/event/challenge/season UI without error")

func test_live_sandbox_instantiates() -> void:
	var packed := load(SANDBOX) as PackedScene
	assert_not_null(packed, "the live sandbox scene loads")
	var demo = packed.instantiate()
	add_child_autofree(demo)
	assert_true(is_instance_valid(demo), "the sandbox builds its room/props/HUD without error")
