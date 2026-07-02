extends GutTest
## Task 09 (FR-09-6): restocking a consumable spends The Take and increments its count, capped at
## max_count and gated by affordability. Tests the pure can_restock() seam + real Take spend.

var _saved_unlocked: Array
var _saved_take: int

func before_each() -> void:
	_saved_unlocked = ProgressionManager.unlocked_gear.duplicate()
	_saved_take = RunManager.take

func after_each() -> void:
	ProgressionManager.unlocked_gear = _saved_unlocked
	RunManager.take = _saved_take

func test_can_restock_seam() -> void:
	assert_true(Loadout.can_restock(100, 20, 2, 0, 4), "40 affordable from 100, under cap")
	assert_false(Loadout.can_restock(30, 20, 2, 0, 4), "40 unaffordable from 30")
	assert_false(Loadout.can_restock(100, 20, 3, 2, 4), "2+3 exceeds max_count 4")
	assert_false(Loadout.can_restock(100, 20, 0, 0, 4), "zero qty is a no-op")

func test_restock_spends_take_and_counts_up() -> void:
	if &"emp" not in ProgressionManager.unlocked_gear:
		ProgressionManager.unlocked_gear.append(&"emp")
	var emp := Content.gear.get_def(&"emp") as GearDef
	assert_not_null(emp, "gear registry populated (run --import first)")
	RunManager.take = 100
	var lo := Loadout.new()
	var before := lo.consumable_count(&"emp")
	var added := lo.restock(emp, 2)
	assert_eq(added, 2, "two units restocked")
	assert_eq(lo.consumable_count(&"emp"), before + 2, "count incremented by 2")
	assert_eq(RunManager.take, 100 - emp.restock_cost * 2, "Take spent per unit")

func test_restock_refused_when_broke() -> void:
	if &"emp" not in ProgressionManager.unlocked_gear:
		ProgressionManager.unlocked_gear.append(&"emp")
	var emp := Content.gear.get_def(&"emp") as GearDef
	RunManager.take = 1
	var lo := Loadout.new()
	assert_eq(lo.restock(emp, 1), 0, "cannot afford → no restock")
	assert_eq(RunManager.take, 1, "Take untouched on a refused restock")
