extends GutTest
## Task 17: the AudioSandbox demo scene instantiates cleanly headlessly (mirrors test_ui_scenes.gd).
## docs/tasks/17_audio.md.

func after_each() -> void:
	EventBus.game_state_changed.emit(0, 0)   # the sandbox drives audio state; reset for later tests

func test_audio_sandbox_instantiates() -> void:
	var packed := load("res://game/scenes/audio/AudioSandbox.tscn") as PackedScene
	assert_not_null(packed, "AudioSandbox.tscn loads")
	var node = packed.instantiate()
	add_child_autofree(node)
	assert_true(is_instance_valid(node), "the sandbox builds its room + readout without error")
