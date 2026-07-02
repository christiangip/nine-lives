extends GutTest
## Spec: releasing a carried bag for a throw removes it from carry; a thrown bag landing in a
## Drop Point banks its value through the exact seam a real ThrownBag physics collision calls —
## no physics simulation needed here. Throw distance scales with Strength. A bag that misses a
## Drop Point and settles (DroppedBag) can be reclaimed via Inventory.adopt_bag() — the reverse
## of release_bag_for_throw(). docs/tasks/08_loot_inventory.md (FR-08-4).

func test_thrown_bag_landing_in_drop_point_banks_value() -> void:
	var inv := Inventory.new()
	var gold := TestHelper.make_loot(12.4, 0.6, 18000)
	gold.needs_bagging = true
	inv.bag_loot(gold)
	assert_true(inv.can_throw_bag())

	var bag := inv.release_bag_for_throw()
	assert_not_null(bag)
	assert_eq(inv.in_hand_value(), 0, "Releasing the bag for a throw removes it from carry")
	assert_false(inv.can_throw_bag(), "No bag remains after release")

	var drop: DropPoint = autofree(DropPoint.new())
	var amount := drop.receive_bag(bag, inv)
	assert_eq(amount, 18000)
	assert_eq(inv.secured_value(), 18000, "The throwing Inventory's secured tally must include the landed bag")

func test_throw_distance_scales_with_strength() -> void:
	var base := Inventory.throw_distance(6.0, 0.0, 4.0)
	var boosted := Inventory.throw_distance(6.0, 0.5, 4.0)
	assert_almost_eq(base, 6.0, 0.001)
	assert_almost_eq(boosted, 8.0, 0.001)
	assert_gt(boosted, base, "Strength must increase throw distance")

func test_cannot_throw_without_a_bag() -> void:
	var inv := Inventory.new()
	assert_false(inv.can_throw_bag())
	assert_null(inv.release_bag_for_throw())

func test_a_thrown_bag_that_settles_can_be_reclaimed() -> void:
	var inv := Inventory.new()
	var gold := TestHelper.make_loot(12.4, 0.6, 18000)
	gold.needs_bagging = true
	inv.bag_loot(gold)
	var bag := inv.release_bag_for_throw()

	# The bag misses a Drop Point and settles (ThrownBag._settle() spawns a DroppedBag holding
	# it); reclaiming restores it as the active carried bag with its value intact.
	assert_true(inv.adopt_bag(bag), "A settled bag must be reclaimable")
	assert_eq(inv.in_hand_value(), 18000, "Reclaiming restores the bag's value to carry")
	assert_true(inv.can_throw_bag(), "The reclaimed bag is a normal active bag again — throwable")

func test_cannot_adopt_a_bag_while_already_holding_one() -> void:
	var inv := Inventory.new()
	var held := TestHelper.make_loot(0.5, 0.4, 100)
	held.needs_bagging = true
	assert_true(inv.bag_loot(held))
	var other := Bag.new()
	other.add(TestHelper.make_loot(1.0, 1.0, 500))
	assert_false(inv.adopt_bag(other), "Can't reclaim a second bag while one is already held")

func test_cannot_adopt_a_bag_while_dragging_a_body() -> void:
	var inv := Inventory.new()
	var body: Body = autofree(Body.new())
	inv.pick_up_body(body)
	var bag := Bag.new()
	bag.add(TestHelper.make_loot(1.0, 1.0, 500))
	assert_false(inv.adopt_bag(bag), "Both hands full of a dragged body must block reclaiming a bag")
