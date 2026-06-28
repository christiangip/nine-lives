extends GutTest
## Example/spec test for the two-axis carry system (docs/tasks/08_loot_inventory.md).
## RED until Inventory is implemented — this encodes the functional requirement.

var inv

func before_each() -> void:
	inv = preload("res://game/systems/inventory/Inventory.gd").new() if \
		ResourceLoader.exists("res://game/systems/inventory/Inventory.gd") else null

func test_rejects_when_over_weight_cap() -> void:
	if inv == null: pending("Inventory not implemented yet (Phase 08.1)"); return
	inv.weight_cap = 10.0
	var heavy := TestHelper.make_loot(12.0, 1.0)
	assert_false(inv.can_pick_up(heavy), "Must reject loot exceeding Carry Weight cap")

func test_rejects_when_over_volume_cap() -> void:
	if inv == null: pending("Inventory not implemented yet (Phase 08.1)"); return
	inv.volume_cap = 5.0
	var bulky := TestHelper.make_loot(1.0, 9.0)
	assert_false(inv.can_pick_up(bulky), "Must reject loot exceeding Carry Volume cap")
