extends GutTest
## Spec: value banked at a Drop Point (secure_from) persists through a later simulated Catch;
## value still in hand at a Catch is lost. Also covers RunManager banking and the FR-08-9
## special-hook-to-Stash delivery. docs/tasks/08_loot_inventory.md (FR-08-5/6/9).

func test_secured_value_survives_a_simulated_catch() -> void:
	var inv := Inventory.new()
	inv.pick_up_direct(TestHelper.make_loot(1.0, 1.0, 5000))
	var drop: DropPoint = autofree(DropPoint.new())
	drop.secure_from(inv)
	assert_eq(inv.secured_value(), 5000, "Value must be secured at the Drop Point")

	inv.lose_in_hand_on_catch()
	assert_eq(inv.secured_value(), 5000, "Secured value must survive a Catch")

func test_in_hand_value_is_lost_on_catch() -> void:
	var inv := Inventory.new()
	inv.pick_up_direct(TestHelper.make_loot(1.0, 1.0, 3000))
	assert_eq(inv.in_hand_value(), 3000)
	var lost := inv.lose_in_hand_on_catch()
	assert_eq(lost, 3000, "lose_in_hand_on_catch must report the lost amount")
	assert_eq(inv.in_hand_value(), 0, "In-hand value must be zeroed after a Catch")
	assert_eq(inv.secured_value(), 0, "Never-secured loot has nothing to survive")

func test_secure_from_updates_run_manager() -> void:
	var starting_notoriety: int = RunManager.notoriety
	var starting_take: int = RunManager.take
	var inv := Inventory.new()
	inv.pick_up_direct(TestHelper.make_loot(1.0, 1.0, 1200))
	var drop: DropPoint = autofree(DropPoint.new())
	drop.secure_from(inv)
	assert_eq(RunManager.notoriety, starting_notoriety + 1200, "Securing loot must bank the full Notoriety")
	# The Take is only the launderable fraction of the secured cash now (FR-14-2), not 1:1.
	var expected_take := EconomyConfigDef.take_cut(1200, EconomyConfigDef.resolve().take_fraction)
	assert_eq(RunManager.take, starting_take + expected_take, "Securing loot banks the Take fraction")

func test_special_hook_delivers_to_stash_on_secure() -> void:
	ProgressionManager.stash.clear()
	var inv := Inventory.new()
	var painting := TestHelper.make_loot(6.0, 8.0, 120000)
	painting.hand_slots = 2
	painting.special_hook = &"stash_trophy_painting"
	inv.pick_up_direct(painting)
	var drop: DropPoint = autofree(DropPoint.new())
	drop.secure_from(inv)
	assert_true(&"stash_trophy_painting" in ProgressionManager.stash, "FR-08-9: delivering special loot unlocks a Stash trophy")
