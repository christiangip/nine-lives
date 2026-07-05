extends GutTest
## Task 15 FR-15-5: the EventBus.detection_changed signal drives the HUD's compass-eye indicator. Locks the
## pure visual + bearing seams (CompassEye.detection_visual / bearing_tick) and the signal→indicator update.
## docs/tasks/15_ui_hud_menus.md.

func test_detection_visual_state_bands() -> void:
	var unaware := CompassEye.detection_visual(0, 0.0)
	assert_almost_eq(float(unaware["fill"]), 0.0, 0.0001, "Unaware → empty fill")
	assert_eq(unaware["color"], UITheme.detection_color(0), "Unaware → grey band")
	assert_eq(String(unaware["symbol"]), "", "Unaware shows no alert symbol")
	var alerted := CompassEye.detection_visual(3, 1.0)
	assert_almost_eq(float(alerted["fill"]), 1.0, 0.0001, "Alerted → full fill")
	assert_eq(alerted["color"], UITheme.detection_color(3), "Alerted → red band")
	assert_ne(String(alerted["symbol"]), "", "Alerted shows a non-colour symbol cue")

func test_fill_tracks_and_clamps() -> void:
	assert_almost_eq(float(CompassEye.detection_visual(2, 0.5)["fill"]), 0.5, 0.0001, "fill tracks the meter")
	assert_almost_eq(float(CompassEye.detection_visual(2, 9.0)["fill"]), 1.0, 0.0001, "fill clamps to 1.0")

func test_bearing_tick_points_at_target() -> void:
	var o := Vector3.ZERO
	var b := Basis.IDENTITY   # forward = -Z, right = +X
	assert_eq(CompassEye.bearing_tick(o, b, Vector3(0, 0, -10), 12), 0, "dead ahead → tick 0")
	assert_eq(CompassEye.bearing_tick(o, b, Vector3(10, 0, 0), 12), 3, "to the right → tick 3")
	assert_eq(CompassEye.bearing_tick(o, b, Vector3(0, 0, 10), 12), 6, "behind → tick 6")
	assert_eq(CompassEye.bearing_tick(o, b, Vector3(-10, 0, 0), 12), 9, "to the left → tick 9")

func test_signal_updates_indicator() -> void:
	var eye: CompassEye = add_child_autofree(CompassEye.new())
	# A real Node3D so the id resolves like a live DetectionSensor would (a fabricated id trips ObjectDB).
	var threat: Node3D = add_child_autofree(Node3D.new())
	var id := threat.get_instance_id()
	EventBus.detection_changed.emit(id, 3, 0.8)
	assert_true(eye._actors.has(id), "detection_changed registers the detector")
	eye._recompute_primary()
	assert_eq(eye._primary_state, 3, "the indicator reflects the strongest state")
	assert_almost_eq(eye._primary_fill, 0.8, 0.0001, "the indicator reflects the fill")
	EventBus.detection_changed.emit(id, 0, 0.0)   # fully recovered
	assert_false(eye._actors.has(id), "a fully-recovered detector is dropped")
