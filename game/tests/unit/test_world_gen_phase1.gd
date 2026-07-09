extends GutTest
## World-gen Phase 1 seams: edge-aware door-side resolution, camera defeat gating, and the fixture-driven
## light model (a point is lit only inside a fixture pool; shadowed otherwise; back-compat with no fixtures).
## See world-gen-fixes.md (Phase 1).

# --- 1B: which wall faces a neighbour (pure) --------------------------------
func test_dominant_side_cardinals() -> void:
	assert_eq(MissionController.dominant_side(Vector3.ZERO, Vector3(10, 0, 0)), &"east", "+X neighbour opens east")
	assert_eq(MissionController.dominant_side(Vector3.ZERO, Vector3(-10, 0, 0)), &"west", "-X neighbour opens west")
	assert_eq(MissionController.dominant_side(Vector3.ZERO, Vector3(0, 0, 10)), &"north", "+Z neighbour opens north")
	assert_eq(MissionController.dominant_side(Vector3.ZERO, Vector3(0, 0, -10)), &"south", "-Z neighbour opens south")

func test_dominant_side_picks_larger_axis() -> void:
	assert_eq(MissionController.dominant_side(Vector3.ZERO, Vector3(10, 0, 3)), &"east", "a mostly-east diagonal opens east")
	assert_eq(MissionController.dominant_side(Vector3.ZERO, Vector3(2, 0, -9)), &"south", "a mostly-south diagonal opens south")

# --- 1D: a defeated camera is blind (pure) ---------------------------------
func test_camera_defeated_states() -> void:
	assert_false(CameraEye.is_defeated(false, false, true, false), "a live, powered, unhacked camera sees")
	assert_true(CameraEye.is_defeated(true, false, true, false), "a disabled camera is blind")
	assert_true(CameraEye.is_defeated(false, true, true, false), "a looped camera is blind")
	assert_true(CameraEye.is_defeated(false, false, false, false), "an unpowered camera is blind")
	assert_true(CameraEye.is_defeated(false, false, true, true), "a solved/hacked camera is blind")

# --- 1C: light-fixture pool (pure geometry) --------------------------------
func test_light_fixture_pool() -> void:
	var f := LightFixture.new()
	f.radius = 4.0
	add_child_autofree(f)
	f.global_position = Vector3.ZERO
	assert_true(f.lights_point(Vector3(2, 0, 0)), "inside the pool radius is lit")
	assert_true(f.lights_point(Vector3(0, 3, 3.5)), "height is ignored; horizontal distance < radius is lit")
	assert_false(f.lights_point(Vector3(5, 0, 0)), "outside the pool radius is dark")
	f.set_on(false)
	assert_false(f.lights_point(Vector3(2, 0, 0)), "an off fixture lights nothing")

# --- 1C: detection reads fixtures (shadowed by default, back-compat) --------
func test_sensor_light_sampling_with_fixtures() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var sensor := DetectionSensor.new()
	sensor.config = DetectionConfigDef.new()
	root.add_child(sensor)
	# No fixtures at all → legacy fully-lit (existing scenes/tests unchanged).
	assert_almost_eq(sensor._sample_light_level(Vector3.ZERO), 1.0, 0.001, "no fixtures => fully lit (back-compat)")
	# A fixture that does NOT cover the point → the scene is now fixture-lit, so the point is shadowed.
	var f := LightFixture.new()
	f.radius = 3.0
	root.add_child(f)
	f.global_position = Vector3(20, 0, 0)
	assert_almost_eq(sensor._sample_light_level(Vector3.ZERO), sensor.config.min_light_factor, 0.001,
		"a scene with fixtures but no local coverage => shadow")
	# Move the fixture over the point → lit.
	f.global_position = Vector3(0.5, 0, 0)
	assert_almost_eq(sensor._sample_light_level(Vector3.ZERO), 1.0, 0.001, "inside a fixture pool => lit")
	# Turn it off → dark again (the shoot/switch/power-cut coupling).
	f.set_on(false)
	assert_almost_eq(sensor._sample_light_level(Vector3.ZERO), sensor.config.min_light_factor, 0.001,
		"switching the fixture off drops the pool => shadow")

# --- realization smoke: the new geometry actually lands in a built mission --
func test_realized_mission_is_enclosed_lit_and_watched() -> void:
	var c := Contract.new()
	c.archetype_id = &"bank"
	c.objective_id = &"crack_vault"
	c.mission_seed = 20250702
	c.tier = 2
	c.difficulty = 2
	var controller := MissionGenerator.build(c)
	assert_not_null(controller, "the generator built a MissionController")
	add_child_autofree(controller)
	assert_gt(get_tree().get_nodes_in_group(&"lit").size(), 0, "1C: the realized mission scattered light fixtures")
	assert_gt(controller.find_children("Bound*", "StaticBody3D", true, false).size(), 0,
		"1A: the realized mission built boundary colliders")
	# 1D (conditional): any placed camera got a CameraEye detection cone.
	for cam in controller.find_children("*", "HackTarget", true, false):
		if String(cam.get(&"def_id")) == "camera_ptz":
			assert_gt(cam.find_children("*", "CameraEye", true, false).size(), 0,
				"a placed camera got a CameraEye detection cone")
			break
