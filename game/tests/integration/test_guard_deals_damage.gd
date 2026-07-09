extends GutTest
## Regression: an ALERTED guard with a clear line of sight to the player actually deals damage.
## Guards were never firing because GuardAI._has_los cast its ray to the player's own origin without
## excluding the player's collider, so the ray always terminated inside the player and read "no LoS" —
## should_fire() was never true. This locks the "alerted guard + LoS → player Health drops" invariant
## and the underlying _has_los target-exclusion fix. See bug-fixes-ui-overhaul.md Part A.

const AI := GuardAI.AIState

## Minimal player stand-in: a real collider (so it WOULD block the LoS ray if not excluded) in group
## "player", tallying the damage a guard deals it. Avoids pulling in the full PlayerController rig.
class PlayerDouble extends CharacterBody3D:
	var damage_taken: float = 0.0
	func _init() -> void:
		add_to_group(&"player")
		var col := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		col.shape = shape
		add_child(col)
	func apply_damage(d: float) -> void:
		damage_taken += d

var _guard: GuardAI
var _sensor: DetectionSensor
var _player: PlayerDouble

func before_each() -> void:
	_guard = GuardAI.new()
	_sensor = DetectionSensor.new()
	_guard.add_child(_sensor)
	_guard.ai_config = AIConfigDef.new()
	_player = PlayerDouble.new()
	add_child_autofree(_guard)          # _ready resolves sensor + fetches the &"guard" EnemyDef (loadout weapon)
	add_child_autofree(_player)
	_guard.global_position = Vector3.ZERO
	_player.global_position = Vector3(10, 0, 0)   # inside engage range (18 m), clear line between

func _raised_player_point() -> Vector3:
	return _player.global_position + Vector3.UP * _guard.ai_config.combat_aim_height

# --- The precise bug: the ray to the target must exclude the target's own collider ---------
func test_los_clears_when_only_the_excluded_target_is_on_the_ray() -> void:
	await get_tree().physics_frame          # let the physics space register the player's collider
	await get_tree().physics_frame
	assert_true(
		_guard._has_los(_sensor.global_position, _raised_player_point(), _guard._collider_rid(_player)),
		"a clear line to the player reads as LoS once the player's own collider is excluded")

func test_los_blocked_by_a_wall_between() -> void:
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 3, 6)
	col.shape = box
	wall.add_child(col)
	add_child_autofree(wall)
	wall.global_position = Vector3(5, 0, 0)   # squarely between guard and player
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(
		_guard._has_los(_sensor.global_position, _raised_player_point(), _guard._collider_rid(_player)),
		"a wall between the guard and player blocks LoS even with the target excluded")

# --- End to end: a committed guard with LoS actually damages the player --------------------
func test_alerted_guard_with_los_damages_player() -> void:
	_guard._set_ai_state(AI.COMBAT)         # skip straight to the firing state (detection→COMBAT is covered elsewhere)
	# Run the real physics loop: the guard's _physics_process ticks _tick_combat, which faces the player,
	# clears LoS (now that the fix excludes the player), and fires the loadout weapon at it.
	for i in range(120):                    # ~2 s at 60 Hz — several shots past the fire interval
		await get_tree().physics_frame
		if _player.damage_taken > 0.0:
			break
	assert_gt(_player.damage_taken, 0.0, "an ALERTED guard with a clear LoS must land damage on the player")
