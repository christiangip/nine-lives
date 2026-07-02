extends GutTest
## Task 09 (FR-09-4): gear locked behind Workshop research (permanent Legacy unlock) can't be equipped
## until it's unlocked in ProgressionManager. The Workshop UI is task 13; this locks the gate logic.

var _saved_unlocked: Array

func before_each() -> void:
	_saved_unlocked = ProgressionManager.unlocked_gear.duplicate()

func after_each() -> void:
	ProgressionManager.unlocked_gear = _saved_unlocked

func test_locked_gear_cannot_equip_until_researched() -> void:
	# Rifle has research_cost > 0 — a fresh account hasn't unlocked it.
	ProgressionManager.unlocked_gear = [] as Array[StringName]
	var rifle := Content.gear.get_def(&"rifle") as GearDef
	assert_not_null(rifle, "gear registry populated (run --import first)")
	assert_true(rifle.research_cost > 0, "rifle is a researched weapon")
	var lo := Loadout.new()
	assert_false(lo.can_equip(rifle), "locked gear is not equippable")
	assert_false(lo.equip(rifle), "equip refused while locked")

	# Research it (Workshop unlock) → now equippable.
	ProgressionManager.unlocked_gear.append(&"rifle")
	assert_true(lo.can_equip(rifle), "unlocked gear is equippable")
	assert_true(lo.equip(rifle), "equip succeeds after research")
	assert_true(lo.is_equipped(&"rifle"), "rifle is now in the loadout")
