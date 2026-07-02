extends GutTest
## Task 09 (FR-09-1): a slot's per-slot capacity is enforced — equipping past it is rejected at the
## Armory. Tests the pure fits() seam + the real integration through Content.gear + Content.loadout.

var _saved_unlocked: Array

func before_each() -> void:
	_saved_unlocked = ProgressionManager.unlocked_gear.duplicate()

func after_each() -> void:
	ProgressionManager.unlocked_gear = _saved_unlocked

func test_fits_seam() -> void:
	assert_true(Loadout.fits(0, 2, 1), "empty slot has room")
	assert_true(Loadout.fits(1, 2, 1), "one unit still fits capacity 2")
	assert_false(Loadout.fits(2, 2, 1), "a third unit exceeds capacity 2")
	assert_false(Loadout.fits(0, 1, 2), "a cost-2 item exceeds capacity 1")

func test_weapon_slot_capacity_enforced() -> void:
	# WEAPON capacity is 2 (default_loadout.tres); a third 1-cost weapon must be rejected.
	for gid in [&"suppressed_pistol", &"smg", &"rifle"]:
		if gid not in ProgressionManager.unlocked_gear:
			ProgressionManager.unlocked_gear.append(gid)
	var lo := Loadout.new()
	var pistol := Content.gear.get_def(&"suppressed_pistol") as GearDef
	var smg := Content.gear.get_def(&"smg") as GearDef
	var rifle := Content.gear.get_def(&"rifle") as GearDef
	assert_not_null(pistol, "gear registry populated (run --import first)")
	assert_true(lo.equip(pistol), "first weapon fits")
	assert_true(lo.equip(smg), "second weapon fills the slot")
	assert_false(lo.can_equip(rifle), "third weapon exceeds WEAPON capacity")
	assert_false(lo.equip(rifle), "and equip is refused")
	assert_eq(lo.slot_used(GearDef.Slot.WEAPON), 2, "only two weapons equipped")
