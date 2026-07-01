extends GutTest
## Spec: releasing a carried bag for a throw removes it from carry; a thrown bag landing in a
## Drop Point banks its value through the exact seam a real ThrownBag physics collision calls —
## no physics simulation needed here. Throw distance scales with Strength.
## docs/tasks/08_loot_inventory.md (FR-08-4).

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
