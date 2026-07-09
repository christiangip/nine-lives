extends GutTest
## Regression: taking down / killing a guard must clear its detection from the HUD/compass. A freed
## DetectionSensor emits a final UNAWARE on _exit_tree so the CompassEye drops it — otherwise the last
## detection state lingers forever (no more ticks to decay it), leaving the compass "suspicious" with no
## guard actually aware of the player. See bug-fixes-ui-overhaul follow-up (2026-07-08).

func test_freeing_a_sensor_clears_the_compass() -> void:
	var eye: CompassEye = add_child_autofree(CompassEye.new())
	var host: Node3D = add_child_autofree(Node3D.new())
	var sensor := DetectionSensor.new()
	host.add_child(sensor)   # in-tree so _exit_tree fires on free
	await get_tree().process_frame
	var id := sensor.get_instance_id()
	EventBus.detection_changed.emit(id, 3, 0.9)   # pretend this sensor spotted the player (ALERTED)
	assert_true(eye._actors.has(id), "the alerted sensor is on the compass")
	sensor.free()   # a takedown frees the guard + its sensor child
	await get_tree().process_frame
	assert_false(eye._actors.has(id), "freeing the sensor drops it from the compass — suspicion clears")

func test_compass_prunes_a_stale_freed_actor() -> void:
	# Belt-and-suspenders: even if a freed sensor never emitted, _recompute_primary drops invalid ids.
	var eye: CompassEye = add_child_autofree(CompassEye.new())
	var ghost: Node3D = Node3D.new()   # never added to the tree; freed immediately below
	var id := ghost.get_instance_id()
	eye._actors[id] = [3, 0.9]
	ghost.free()
	eye._recompute_primary()
	assert_false(eye._actors.has(id), "a detector whose object was freed is pruned from the compass")
	assert_eq(eye._primary_state, 0, "with no live detectors the compass reads Unaware")
