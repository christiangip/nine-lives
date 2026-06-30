extends GutTest
## Spec: each stance yields the expected move speed and detection-profile value,
## ordered stand > crouch > prone; set_stance announces the change (FR-03-2).
## docs/tasks/03_player_controller_camera.md.

var _player: PlayerController

func before_each() -> void:
	_player = PlayerController.new()
	var cfg := PlayerConfigDef.new()
	cfg.stand_speed = 3.0
	cfg.crouch_speed = 1.5
	cfg.prone_speed = 0.8
	cfg.stand_visibility = 1.0
	cfg.crouch_visibility = 0.6
	cfg.prone_visibility = 0.3
	_player.config = cfg

func after_each() -> void:
	_player.free()

func test_speed_per_stance() -> void:
	assert_almost_eq(_player.stance_speed(PlayerController.Stance.STAND), 3.0, 0.001, "stand speed from config")
	assert_almost_eq(_player.stance_speed(PlayerController.Stance.CROUCH), 1.5, 0.001, "crouch speed from config")
	assert_almost_eq(_player.stance_speed(PlayerController.Stance.PRONE), 0.8, 0.001, "prone speed from config")

func test_speed_ordering() -> void:
	assert_gt(_player.stance_speed(PlayerController.Stance.STAND),
		_player.stance_speed(PlayerController.Stance.CROUCH), "standing is faster than crouching")
	assert_gt(_player.stance_speed(PlayerController.Stance.CROUCH),
		_player.stance_speed(PlayerController.Stance.PRONE), "crouching is faster than prone")

func test_detection_profile_ordering() -> void:
	assert_gt(_player.detection_profile(PlayerController.Stance.STAND),
		_player.detection_profile(PlayerController.Stance.CROUCH), "standing is more visible than crouching")
	assert_gt(_player.detection_profile(PlayerController.Stance.CROUCH),
		_player.detection_profile(PlayerController.Stance.PRONE), "crouching is more visible than prone")

func test_set_stance_updates_and_emits() -> void:
	watch_signals(_player)
	var ok := _player.set_stance(PlayerController.Stance.CROUCH)
	assert_true(ok, "crouching is always allowed (no ceiling check going down)")
	assert_eq(_player.stance, PlayerController.Stance.CROUCH, "stance updates to crouch")
	assert_signal_emitted(_player, "stance_changed", "set_stance announces stance_changed")
