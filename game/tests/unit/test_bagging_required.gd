extends GutTest
## Spec: loose loot (needs_bagging) can't be carried until bagged; pocketable loot bypasses
## bagging entirely; a carried bag occupies one hand slot (GDD §10.1 lists "gold bag" as a
## hand-slot example). docs/tasks/08_loot_inventory.md (FR-08-3).

func test_loose_loot_cannot_be_picked_up_direct() -> void:
	var inv := Inventory.new()
	var cash := TestHelper.make_loot(0.5, 0.4)
	cash.needs_bagging = true
	assert_false(inv.pick_up_direct(cash), "Loose loot must reject direct pickup")
	assert_eq(inv.current_weight(), 0.0, "Rejected direct pickup must not add weight")

func test_loose_loot_can_be_bagged() -> void:
	var inv := Inventory.new()
	var cash := TestHelper.make_loot(0.5, 0.4, 2500)
	cash.needs_bagging = true
	assert_true(inv.bag_loot(cash), "Loose loot must be acceptable once routed through bag_loot")
	assert_almost_eq(inv.current_weight(), 0.5, 0.001)
	assert_eq(inv.in_hand_value(), 2500)

func test_pocketable_loot_bypasses_bagging() -> void:
	var inv := Inventory.new()
	var jewelry := TestHelper.make_loot(0.3, 0.2, 4200)
	jewelry.needs_bagging = false
	assert_true(inv.pick_up_direct(jewelry))
	assert_false(inv.bag_loot(jewelry), "Pocketable loot must reject the bagging route")

func test_bag_occupies_one_hand_slot() -> void:
	var inv := Inventory.new()
	var cash := TestHelper.make_loot(0.5, 0.4, 2500)
	cash.needs_bagging = true
	inv.bag_loot(cash)
	assert_eq(inv.hand_slots_used(), 1, "A carried bag occupies exactly one hand slot (GDD §10.1)")

func test_a_second_loose_item_joins_the_same_bag() -> void:
	var inv := Inventory.new()
	var cash := TestHelper.make_loot(0.5, 0.4, 2500)
	cash.needs_bagging = true
	var gold := TestHelper.make_loot(1.0, 0.2, 1000)
	gold.needs_bagging = true
	inv.bag_loot(cash)
	inv.bag_loot(gold)
	assert_eq(inv.hand_slots_used(), 1, "Adding more loose loot to an already-open bag costs no extra hand slot")
	assert_eq(inv.in_hand_value(), 3500)
