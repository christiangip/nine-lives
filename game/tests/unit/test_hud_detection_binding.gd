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

# --- HUD survival/stamina/objective seams (Part B) -----------------------------
func test_survival_visible_adds_detected() -> void:
	# Pure stealth, full health, not committed, no pursuit, but a guard is onto you → the block shows (B1).
	assert_false(MissionHUD.survival_visible(false, 0, 1.0, false), "hidden while clean + unseen")
	assert_true(MissionHUD.survival_visible(false, 0, 1.0, true), "a guard onto you fades the survival block in")
	assert_true(MissionHUD.survival_visible(true, 0, 1.0, false), "committed keeps it up (persists once loud)")
	assert_true(MissionHUD.survival_visible(false, 0, 0.8, false), "having taken damage shows it")

func test_any_detected_threshold() -> void:
	assert_false(MissionHUD.any_detected([0, 0]), "all Unaware → not detected")
	assert_true(MissionHUD.any_detected([0, 1]), "a Suspicious detector counts as detected")
	assert_true(MissionHUD.any_detected([3]), "an Alerted detector counts as detected")

func test_stamina_visible_only_below_full() -> void:
	assert_false(MissionHUD.stamina_visible(100.0, 100.0), "full stamina hides the bar")
	assert_true(MissionHUD.stamina_visible(60.0, 100.0), "draining stamina shows the bar")
	assert_false(MissionHUD.stamina_visible(0.0, 0.0), "no max → hidden (avoids a divide-by-zero flash)")

func test_objective_fraction_clamps() -> void:
	assert_almost_eq(MissionHUD.objective_fraction(0, 1000), 0.0, 0.0001, "nothing secured → empty")
	assert_almost_eq(MissionHUD.objective_fraction(500, 1000), 0.5, 0.0001, "half secured → half bar")
	assert_almost_eq(MissionHUD.objective_fraction(1500, 1000), 1.0, 0.0001, "over-secured clamps to full")
	assert_almost_eq(MissionHUD.objective_fraction(50, 0), 0.0, 0.0001, "no loot total → empty (no divide-by-zero)")
