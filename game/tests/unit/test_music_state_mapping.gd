extends GutTest
## Task 17 (FR-17-1): detection/pursuit signals select the correct MusicState — the pure seam and the
## multi-actor aggregator. docs/tasks/17_audio.md.

func before_each() -> void:
	EventBus.game_state_changed.emit(0, 0)   # reset AudioManager's actor/phase/resolve state → CALM

func after_each() -> void:
	EventBus.game_state_changed.emit(0, 0)

func test_pure_mapping() -> void:
	assert_eq(AudioManager.music_state_for(AudioManager.DET_UNAWARE, 0), AudioManager.MusicState.CALM, "unaware → calm")
	assert_eq(AudioManager.music_state_for(AudioManager.DET_SUSPICIOUS, 0), AudioManager.MusicState.TENSE, "suspicious → tense")
	assert_eq(AudioManager.music_state_for(AudioManager.DET_SEARCHING, 0), AudioManager.MusicState.TENSE, "searching → tense")
	assert_eq(AudioManager.music_state_for(AudioManager.DET_ALERTED, 0), AudioManager.MusicState.COMBAT, "alerted → combat")
	assert_eq(AudioManager.music_state_for(AudioManager.DET_PURSUIT, 0), AudioManager.MusicState.COMBAT, "pursuit state → combat")

func test_pursuit_phase_forces_combat() -> void:
	assert_eq(AudioManager.music_state_for(AudioManager.DET_UNAWARE, 1), AudioManager.MusicState.COMBAT, "any pursuit phase → combat")

func test_aggregator_picks_most_alarming() -> void:
	var a: Node3D = add_child_autofree(Node3D.new())
	var b: Node3D = add_child_autofree(Node3D.new())
	EventBus.detection_changed.emit(a.get_instance_id(), AudioManager.DET_SUSPICIOUS, 0.3)
	EventBus.detection_changed.emit(b.get_instance_id(), AudioManager.DET_ALERTED, 0.9)
	assert_eq(AudioManager.music_state, AudioManager.MusicState.COMBAT, "worst actor drives combat")
	# b relaxes to unaware → only the suspicious actor remains → tense
	EventBus.detection_changed.emit(b.get_instance_id(), AudioManager.DET_UNAWARE, 0.0)
	assert_eq(AudioManager.music_state, AudioManager.MusicState.TENSE, "falls back to the remaining lead")
	EventBus.detection_changed.emit(a.get_instance_id(), AudioManager.DET_UNAWARE, 0.0)
	assert_eq(AudioManager.music_state, AudioManager.MusicState.CALM, "all clear → calm")

func test_mission_completed_resolves_and_latches() -> void:
	EventBus.mission_completed.emit({})
	assert_eq(AudioManager.music_state, AudioManager.MusicState.RESOLVE, "mission complete → resolve")
	# A stray detection while resolving must not pull us back out.
	var g: Node3D = add_child_autofree(Node3D.new())
	EventBus.detection_changed.emit(g.get_instance_id(), AudioManager.DET_ALERTED, 1.0)
	assert_eq(AudioManager.music_state, AudioManager.MusicState.RESOLVE, "resolve latches until the state resets")
