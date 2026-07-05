extends GutTest
## Task 17 (FR-17-2): gameplay events drive AudioManager to the mapped SFX cue (observed via
## _last_sfx_id), and an unmapped id no-ops safely. docs/tasks/17_audio.md.

func before_each() -> void:
	EventBus.game_state_changed.emit(0, 0)

func after_each() -> void:
	EventBus.game_state_changed.emit(0, 0)
	# alarm_tripped commits the Streak / raises Heat as a side effect — reset it for later tests.
	RunManager.from_dict({})

func test_player_spotted_plays_sting() -> void:
	var g: Node3D = add_child_autofree(Node3D.new())
	EventBus.player_spotted.emit(g.get_instance_id())
	assert_eq(AudioManager._last_sfx_id, &"spotted")

func test_alarm_kind_selects_cue() -> void:
	EventBus.alarm_tripped.emit("loud", Vector3.ZERO)
	assert_eq(AudioManager._last_sfx_id, &"alarm_loud")
	EventBus.alarm_tripped.emit("silent", Vector3.ZERO)
	assert_eq(AudioManager._last_sfx_id, &"alarm_silent")

func test_loot_secured_plays_cue() -> void:
	EventBus.loot_secured.emit("cash_bundle", 500)
	assert_eq(AudioManager._last_sfx_id, &"loot_secured")

func test_unknown_cue_is_safe() -> void:
	AudioManager.play_sfx(&"no_such_cue")   # unmapped → no crash, no stream
	assert_eq(AudioManager._last_sfx_id, &"no_such_cue", "the call is recorded but nothing plays")
