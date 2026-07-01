extends GutTest
## Spec: every authored obstacle exposes a valid solution set for the generator/Intel, and no obstacle
## is solvable ONLY by a minigame except where the GDD allows it — the pin-tumbler lock (FR-06-10).
## docs/tasks/06_heist_mechanics_obstacles.md, GDD §9.1.

# Categories exempt from the ">=2 solutions" rule: LOCK is the documented minigame-only exception, and
# FUSE_BOX / LIGHT are single-operation tools the player uses, not gates that must offer alternates.
const EXEMPT_FROM_MULTI := [
	ObstacleDef.Category.LOCK,
	ObstacleDef.Category.FUSE_BOX,
	ObstacleDef.Category.LIGHT,
]

func test_registry_has_a_catalogue() -> void:
	assert_not_null(Content.obstacles, "Content.obstacles registry exists")
	assert_gt(Content.obstacles.all().size(), 0, "the obstacle .tres catalogue scanned")

func test_no_obstacle_is_minigame_only_except_locks() -> void:
	for d in Content.obstacles.all():
		if d.category == ObstacleDef.Category.LOCK:
			continue   # pin-tumbler is the one documented minigame-only obstacle (GDD §9.1)
		assert_false(d.is_minigame_only(),
			"%s must offer a non-minigame alternate (clue/gadget/power/route)" % d.id)

func test_gated_obstacles_expose_at_least_two_solutions() -> void:
	for d in Content.obstacles.all():
		assert_gt(d.valid_solutions.size(), 0, "%s must list at least one solution" % d.id)
		if d.category in EXEMPT_FROM_MULTI:
			continue
		assert_gt(d.valid_solutions.size(), 1,
			"%s must expose >=2 counter-play solutions for the generator/Intel" % d.id)
