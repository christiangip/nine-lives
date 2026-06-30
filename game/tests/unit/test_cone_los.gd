extends GutTest
## Spec: a target inside the vision cone with a clear ray is seen; out-of-cone, beyond
## range, or behind cover is not. Cone test is pure; LoS is a physics integration check
## (FR-04-1/2). docs/tasks/04_stealth_detection.md.

const FORWARD := Vector3(0, 0, -1)   # Node3D faces -Z

var _sensor: DetectionSensor

func before_each() -> void:
	_sensor = DetectionSensor.new()

func after_each() -> void:
	_sensor.free()

func _half(angle_deg: float) -> float:
	return deg_to_rad(angle_deg * 0.5)

# --- Cone geometry (pure) --------------------------------------------------
func test_target_ahead_in_range_is_in_cone() -> void:
	assert_true(_sensor.is_in_cone(Vector3.ZERO, FORWARD, Vector3(0, 0, -5), _half(90.0), 14.0),
		"a target straight ahead within range is inside the cone")

func test_target_behind_is_out_of_cone() -> void:
	assert_false(_sensor.is_in_cone(Vector3.ZERO, FORWARD, Vector3(0, 0, 5), _half(90.0), 14.0),
		"a target behind the sensor is outside the cone")

func test_target_beyond_range_is_excluded() -> void:
	assert_false(_sensor.is_in_cone(Vector3.ZERO, FORWARD, Vector3(0, 0, -20), _half(90.0), 14.0),
		"a target past the vision range is excluded even if straight ahead")

func test_target_outside_angle_is_excluded() -> void:
	# 90deg cone => 45deg half. A target ~63deg off-axis is outside.
	assert_false(_sensor.is_in_cone(Vector3.ZERO, FORWARD, Vector3(10, 0, -5), _half(90.0), 14.0),
		"a target beyond the cone half-angle is excluded")

# --- Line of sight / cover (physics integration) ---------------------------
func test_clear_los_is_fully_visible() -> void:
	var ctx := _build_los_scene(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var vis: float = ctx.sensor._visibility_fraction(ctx.sensor.global_position, ctx.player)
	assert_eq(vis, 1.0, "an unobstructed target exposes every LoS sample point")

func test_wall_blocks_los() -> void:
	var ctx := _build_los_scene(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var vis: float = ctx.sensor._visibility_fraction(ctx.sensor.global_position, ctx.player)
	assert_eq(vis, 0.0, "a full wall between sensor and target blocks all LoS rays")

func _build_los_scene(with_wall: bool) -> Dictionary:
	var root := Node3D.new()
	add_child_autofree(root)

	var sensor := DetectionSensor.new()
	sensor.config = DetectionConfigDef.new()
	root.add_child(sensor)
	sensor.global_position = Vector3(0, 1, 0)

	var player := CharacterBody3D.new()
	var pcs := CollisionShape3D.new()
	pcs.shape = CapsuleShape3D.new()
	player.add_child(pcs)
	root.add_child(player)
	player.global_position = Vector3(0, 1, 4)

	if with_wall:
		var wall := StaticBody3D.new()
		var wcs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3, 3, 0.4)
		wcs.shape = box
		wall.add_child(wcs)
		root.add_child(wall)
		wall.global_position = Vector3(0, 1, 2)

	return {"sensor": sensor, "player": player}
