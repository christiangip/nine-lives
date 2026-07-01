extends GutTest
## Spec: dragging a Body is a heavy two-handed haul (both hand slots), mutually exclusive with
## carrying a Bag, grants its carried_item on pickup (the Inspector keycard), and backs
## BiometricLock's is_carrying_keyholder() duck-type. docs/tasks/08_loot_inventory.md
## (↩ from 05, ↩ from 06).

func test_picking_up_a_body_occupies_both_hand_slots() -> void:
	var inv := Inventory.new()
	var body: Body = autofree(Body.new())
	assert_true(inv.pick_up_body(body))
	assert_eq(inv.hand_slots_used(), 2)
	assert_true(inv.is_carrying_body())

func test_cannot_carry_two_bodies_at_once() -> void:
	var inv := Inventory.new()
	var first: Body = autofree(Body.new())
	var second: Body = autofree(Body.new())
	inv.pick_up_body(first)
	assert_false(inv.pick_up_body(second), "A second body must be rejected while one is carried")

func test_put_down_body_frees_hand_slots() -> void:
	var inv := Inventory.new()
	var body: Body = autofree(Body.new())
	inv.pick_up_body(body)
	var returned := inv.put_down_body()
	assert_eq(returned, body)
	assert_eq(inv.hand_slots_used(), 0)
	assert_false(inv.is_carrying_body())

func test_is_carrying_keyholder_matches_carried_item() -> void:
	var inv := Inventory.new()
	var body: Body = autofree(Body.new())
	body.carried_item = &"cfo_biometrics"
	inv.pick_up_body(body)
	assert_true(inv.is_carrying_keyholder(&"cfo_biometrics"))
	assert_false(inv.is_carrying_keyholder(&"vault_keycard"))

func test_pickup_grants_carried_item_into_held_items() -> void:
	var inv := Inventory.new()
	var body: Body = autofree(Body.new())
	body.carried_item = &"vault_keycard"
	inv.pick_up_body(body)
	assert_true(inv.has_item(&"vault_keycard"), "Dragging a body grants its carried_item (the Inspector keycard pickup)")

func test_bag_blocks_picking_up_a_body() -> void:
	var inv := Inventory.new()
	var cash := TestHelper.make_loot(0.5, 0.4, 2500)
	cash.needs_bagging = true
	assert_true(inv.bag_loot(cash))
	var body: Body = autofree(Body.new())
	assert_false(inv.pick_up_body(body), "Both hands full of a carried bag must block dragging a body")

func test_body_blocks_starting_a_new_bag() -> void:
	var inv := Inventory.new()
	var body: Body = autofree(Body.new())
	assert_true(inv.pick_up_body(body))
	var cash := TestHelper.make_loot(0.5, 0.4, 2500)
	cash.needs_bagging = true
	assert_false(inv.bag_loot(cash), "Both hands full of a dragged body must block starting a bag")
