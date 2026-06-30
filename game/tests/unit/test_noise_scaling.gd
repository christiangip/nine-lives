extends GutTest
## Spec: footstep radius scales with stance/speed/surface and shrinks with Silence;
## running on metal is louder than crouch-walking on carpet; emit_noise broadcasts on
## EventBus.noise_emitted (FR-03-6). docs/tasks/03_player_controller_camera.md.

var _player: PlayerController

func before_each() -> void:
	_player = PlayerController.new()
	var cfg := PlayerConfigDef.new()
	cfg.base_step_radius = 10.0
	cfg.run_noise_mult = 2.0
	cfg.stand_noise_mult = 1.0
	cfg.crouch_noise_mult = 0.5
	cfg.prone_noise_mult = 0.25
	cfg.max_silence_reduction = 0.85
	cfg.surface_noise = {"metal": 1.5, "carpet": 0.5}
	cfg.surface_noise_default = 1.0
	_player.config = cfg

func after_each() -> void:
	_player.free()

func test_run_metal_louder_than_crouch_carpet() -> void:
	var loud := _player.compute_noise_radius(PlayerController.Stance.STAND, true, "metal", 0.0)
	var quiet := _player.compute_noise_radius(PlayerController.Stance.CROUCH, false, "carpet", 0.0)
	assert_gt(loud, quiet, "running on metal emits a larger radius than crouch-walking on carpet")

func test_silence_shrinks_radius() -> void:
	var full := _player.compute_noise_radius(PlayerController.Stance.STAND, true, "metal", 0.0)
	var hushed := _player.compute_noise_radius(PlayerController.Stance.STAND, true, "metal", 0.5)
	assert_lt(hushed, full, "a Silence reduction shrinks the radius")
	assert_almost_eq(hushed, full * 0.5, 0.001, "a 0.5 reduction halves the radius")

func test_silence_reduction_is_capped() -> void:
	# A reduction beyond max_silence_reduction is clamped, never producing a 0 radius.
	var clamped := _player.compute_noise_radius(PlayerController.Stance.STAND, false, "metal", 1.0)
	assert_gt(clamped, 0.0, "Silence is capped so footsteps never go fully silent")

func test_unknown_surface_uses_default() -> void:
	assert_almost_eq(_player.surface_mult("unobtanium"), 1.0, 0.001, "unknown surface tags fall back to the default")
	assert_almost_eq(_player.surface_mult(""), 1.0, 0.001, "an empty tag falls back to the default")

func test_emit_noise_broadcasts_on_event_bus() -> void:
	# Use the full scene so global_position is valid and the @onready nodes resolve
	# (emit_noise reports the player's world position on EventBus.noise_emitted).
	var scene := load("res://game/scenes/player/PlayerController.tscn")
	if scene == null:
		pending("PlayerController.tscn not importable in this context")
		return
	var p: PlayerController = scene.instantiate()
	add_child_autofree(p)
	watch_signals(EventBus)
	p.emit_noise(4.2, "footstep")
	assert_signal_emitted_with_parameters(EventBus, "noise_emitted",
		[p.global_position, 4.2, "footstep"])
