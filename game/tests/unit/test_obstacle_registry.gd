extends GutTest
## Spec: the obstacle catalogue is data-driven — Content.obstacles scans game/resources/obstacles/*.tres
## and indexes each by id, so new obstacles appear with zero code edits (FR-06-10, Phase 06.x).
## docs/tasks/06_heist_mechanics_obstacles.md, docs/tasks/02_core_architecture.md.

func test_registry_indexes_obstacle_defs_by_id() -> void:
	assert_not_null(Content.obstacles, "Content gained a 14th registry for obstacles")
	assert_true(Content.obstacles.has(&"lock_basic"), "the pin-tumbler lock scanned in")
	var lock := Content.obstacles.get_def(&"lock_basic") as ObstacleDef
	assert_not_null(lock, "get_def returns an ObstacleDef")
	assert_eq(lock.category, ObstacleDef.Category.LOCK, "category hydrated from the .tres")

func test_core_catalogue_present() -> void:
	for id in [&"keycard_door", &"elock_basic", &"camera_ptz", &"laser_grid", &"fuse_box", &"safe_basic"]:
		assert_true(Content.obstacles.has(id), "obstacle '%s' is authored + indexed" % id)
