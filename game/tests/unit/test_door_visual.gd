extends GutTest
## Misc-fixes-2 door seams (issues 4–7), all pure/static and headless: DoorVisual's animation maths
## (which animation a solve method plays — with the unknown→slide default so a future method still opens
## the door — plus slide/swing/shatter geometry), MissionController.is_door_spawn (EVERY gate spawn is a
## door regardless of category — the `elock_basic` HACK_TARGET gate is the regression to lock in — plus
## BREACH_POINT hazards, and nothing else), and the cardinal yaw snap for freestanding hazard doors.
## No Tween, no physics — the node glue is F6-verified in MissionGreybox.tscn.

# --- DoorVisual.animation_for -----------------------------------------------

func test_animation_for_lockpick_swings() -> void:
	assert_eq(DoorVisual.animation_for(&"lockpick"), &"swing", "a picked lock swings open on its hinge")

func test_animation_for_slide_methods() -> void:
	for m in [&"keycard", &"clone", &"hack", &"found_code", &"power_cut"]:
		assert_eq(DoorVisual.animation_for(m), &"slide", "%s slides the leaf into the wall" % m)

func test_animation_for_breach_methods_shatter() -> void:
	for m in [&"drill", &"thermite", &"c4"]:
		assert_eq(DoorVisual.animation_for(m), &"shatter", "%s shatters the leaf" % m)

func test_animation_for_unknown_defaults_to_slide() -> void:
	assert_eq(DoorVisual.animation_for(&"some_future_method"), &"slide",
		"an unmapped method still OPENS the door (slide default) — doors are real barriers now")

# --- DoorVisual slide / swing / shatter geometry ------------------------------

func test_slide_offset_hides_leaf_by_its_width() -> void:
	assert_eq(DoorVisual.slide_offset(1.8), Vector3(1.8, 0.0, 0.0),
		"sliding by one leaf-width tucks the leaf fully behind the jamb")

func test_swing_angle_is_a_quarter_turn() -> void:
	assert_almost_eq(DoorVisual.swing_angle(), PI * 0.5, 0.0001, "the leaf swings 90° about its hinge")

func test_shatter_pieces_tile_the_leaf() -> void:
	var w := 2.0
	var h := 3.0
	var pieces := DoorVisual.shatter_pieces(w, h, 8)
	assert_eq(pieces.size(), 8, "one chunk per requested piece")
	for p in pieces:
		var pos: Vector3 = p["pos"]
		var size: Vector3 = p["size"]
		assert_between(pos.x, -w * 0.5, w * 0.5, "chunk centres stay within the leaf's width")
		assert_between(pos.y, 0.0, h, "chunk centres stay within the leaf's height")
		assert_almost_eq(size.x, w * 0.5, 0.0001, "2-column grid → each chunk is half the leaf width")
	# The tiling spans the full leaf: top of the highest chunk reaches the leaf height.
	var top := 0.0
	for p in pieces:
		top = maxf(top, float((p["pos"] as Vector3).y) + float((p["size"] as Vector3).y) * 0.5)
	assert_almost_eq(top, h, 0.0001, "the chunk grid tiles up to the leaf's full height")

func test_shatter_pieces_count_is_clamped() -> void:
	assert_eq(DoorVisual.shatter_pieces(2.0, 3.0, 0).size(), 1, "at least one chunk even for a bad count")

# --- MissionController.is_door_spawn ------------------------------------------

func test_every_gate_spawn_is_a_door_regardless_of_category() -> void:
	var elock := ObstacleDef.new()
	elock.category = ObstacleDef.Category.HACK_TARGET
	assert_true(MissionController.is_door_spawn(elock, true),
		"the elock_basic gate is HACK_TARGET — the DEFAULT vault gate must still be a door (regression)")
	var lock := ObstacleDef.new()
	lock.category = ObstacleDef.Category.LOCK
	assert_true(MissionController.is_door_spawn(lock, true), "a LOCK gate is a door")
	var keycard := ObstacleDef.new()
	keycard.category = ObstacleDef.Category.KEYCARD_DOOR
	assert_true(MissionController.is_door_spawn(keycard, true), "a KEYCARD_DOOR gate is a door")

func test_breach_point_hazard_is_a_door() -> void:
	var breach := ObstacleDef.new()
	breach.category = ObstacleDef.Category.BREACH_POINT
	assert_true(MissionController.is_door_spawn(breach, false),
		"an off-edge breach leaf is a door (freestanding frame + shatter)")

func test_non_gate_devices_are_not_doors() -> void:
	for cat in [ObstacleDef.Category.HACK_TARGET, ObstacleDef.Category.SAFE,
			ObstacleDef.Category.LASER_GRID, ObstacleDef.Category.MOTION_SENSOR]:
		var od := ObstacleDef.new()
		od.category = cat
		assert_false(MissionController.is_door_spawn(od, false),
			"a non-gate device (category %d) must not grow a leaf/frame" % cat)
	assert_false(MissionController.is_door_spawn(null, false), "a null def is never a door")

# --- Realize-path integration: doors grow a DoorVisual + frame ---------------

func test_realized_bank_doors_get_visual_and_frame() -> void:
	var c := Contract.new()
	c.archetype_id = &"bank"
	c.objective_id = &"grab_value"
	c.mission_seed = 20250702
	c.tier = 2
	c.difficulty = 2
	var controller := MissionGenerator.build(c)
	assert_not_null(controller, "bank mission built")
	if controller == null:
		return
	add_child_autofree(controller)   # _ready → realize → _spawn_obstacle → _wrap_door
	var visuals := controller.find_children("DoorVisual", "", true, false)
	assert_gt(visuals.size(), 0, "gate spawns grew a DoorVisual")
	assert_gt(controller.find_children("DoorFrame", "", true, false).size(), 0,
		"door spawns built a static jamb+lintel frame")
	for v in visuals:
		var dv := v as DoorVisual
		assert_gt(dv.leaf_height, 3.0,
			"leaf dims came from the prop's fitted Collider (both real leaves are ~3.54 m), not the fallback")
		assert_not_null(dv.leaf, "the DoorVisual adopted its leaf")

# --- MissionController._snap_yaw_to_wall (freestanding hazard doors) ----------

func test_snap_yaw_faces_the_guarded_room_on_a_cardinal() -> void:
	var o := Vector3.ZERO
	assert_almost_eq(MissionController._snap_yaw_to_wall(o, Vector3(0, 0, -5)), 0.0, 0.0001,
		"room toward -Z → the -Z-facing leaf needs no yaw")
	assert_almost_eq(absf(MissionController._snap_yaw_to_wall(o, Vector3(5, 0, 0))), PI * 0.5, 0.0001,
		"room toward +X → the leaf turns 90°")
	assert_almost_eq(absf(MissionController._snap_yaw_to_wall(o, Vector3(0, 0, 5))), PI, 0.0001,
		"room toward +Z → the leaf turns 180°")

func test_snap_yaw_snaps_diagonals_to_the_nearest_cardinal() -> void:
	var yaw := MissionController._snap_yaw_to_wall(Vector3.ZERO, Vector3(4, 0, 1))
	assert_almost_eq(absf(yaw), PI * 0.5, 0.0001, "an X-dominant diagonal snaps to the ±X cardinal")

func test_snap_yaw_degenerate_direction_defaults_to_zero() -> void:
	assert_almost_eq(MissionController._snap_yaw_to_wall(Vector3.ZERO, Vector3.ZERO), 0.0, 0.0001,
		"a zero direction (door on the watch centre) keeps the default facing")
