extends GutTest
## Spec: sprinting drains stamina; depletion locks sprint; regen past the unlock
## fraction restores it; the Stamina attribute raises max stamina (FR-03-1).
## docs/tasks/03_player_controller_camera.md.

var _player: PlayerController
var _saved_attrs: Dictionary

func before_all() -> void:
	_saved_attrs = ProgressionManager.attributes.duplicate(true)

func after_all() -> void:
	ProgressionManager.attributes = _saved_attrs

func before_each() -> void:
	ProgressionManager.attributes = {}
	_player = PlayerController.new()
	var cfg := PlayerConfigDef.new()
	cfg.stamina_max = 100.0
	cfg.stamina_drain_per_sec = 50.0
	cfg.stamina_regen_per_sec = 50.0
	cfg.stamina_regen_delay = 0.0
	cfg.sprint_unlock_fraction = 0.25
	cfg.sprint_min_to_start = 5.0
	_player.config = cfg
	_player.stamina = cfg.stamina_max

func after_each() -> void:
	_player.free()
	ProgressionManager.attributes = {}

func test_sprinting_drains_stamina() -> void:
	var before := _player.stamina
	_player.update_stamina(0.1, true)
	assert_lt(_player.stamina, before, "sprinting reduces stamina")

func test_depletion_locks_sprint() -> void:
	for i in 30:
		_player.update_stamina(0.1, true)
	assert_almost_eq(_player.stamina, 0.0, 0.001, "stamina bottoms out at 0 under sustained sprint")
	assert_false(_player.can_sprint(), "an emptied bar locks sprint")

func test_regen_restores_sprint() -> void:
	for i in 30:
		_player.update_stamina(0.1, true)   # drain to empty -> lock
	assert_false(_player.can_sprint(), "sprint is locked right after depletion")
	for i in 30:
		_player.update_stamina(0.1, false)  # regen (delay 0)
	assert_gt(_player.stamina, 25.0, "stamina regenerates past the unlock fraction")
	assert_true(_player.can_sprint(), "sprint unlocks once regen passes the fraction")

func test_stamina_attribute_raises_max() -> void:
	var base_max := _player._stamina_max()
	ProgressionManager.attributes[&"stamina"] = 5
	if Content.attributes.get_def(&"stamina") == null:
		pending("stamina.tres not scanned by Content; attribute scaling unverified")
		return
	assert_gt(_player._stamina_max(), base_max, "training Stamina increases max stamina")
