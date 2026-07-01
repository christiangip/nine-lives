extends GutTest
## Spec: hand-slot loot applies the FR-08-2 movement/agility penalty and blocks vents/climb;
## Strength reduces the penalty magnitude. docs/tasks/08_loot_inventory.md.

func test_hand_slot_speed_penalty() -> void:
	var mult := Inventory.hand_speed_mult(2, 0.25, 0.0)
	assert_almost_eq(mult, 0.5, 0.001, "2 occupied slots at 0.25/slot, no Strength -> 0.5x speed")

func test_strength_reduces_hand_penalty() -> void:
	var mult := Inventory.hand_speed_mult(2, 0.25, 0.5)
	assert_almost_eq(mult, 0.75, 0.001, "Strength effect 0.5 halves the penalty magnitude")

func test_penalty_floors_at_min_speed() -> void:
	var mult := Inventory.hand_speed_mult(2, 5.0, 0.0)
	assert_almost_eq(mult, Inventory.MIN_HAND_SPEED_MULT, 0.001, "an extreme penalty never fully freezes movement")

func test_hand_slot_loot_blocks_vents_and_climb() -> void:
	var inv := Inventory.new()
	var painting := TestHelper.make_loot(6.0, 8.0)
	painting.hand_slots = 2
	assert_true(inv.pick_up_direct(painting))
	var state := inv.penalty_state(0.25, 0.0)
	assert_true(state["blocks_climb"], "Hands full of bulky loot must block climbing")
	assert_true(state["blocks_vents"], "Hands full of bulky loot must block vents")

func test_empty_hands_do_not_block() -> void:
	var inv := Inventory.new()
	var state := inv.penalty_state(0.25, 0.0)
	assert_false(state["blocks_climb"])
	assert_false(state["blocks_vents"])
	assert_almost_eq(state["speed_mult"], 1.0, 0.001)

func test_pocketable_loot_does_not_occupy_hands() -> void:
	var inv := Inventory.new()
	var jewelry := TestHelper.make_loot(0.3, 0.2)
	inv.pick_up_direct(jewelry)
	assert_eq(inv.hand_slots_used(), 0, "Pocketable loot is grabbed directly, hands stay free")
