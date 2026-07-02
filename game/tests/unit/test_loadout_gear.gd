extends GutTest
## Task 09: loadout serialization round-trip (FR-09-8) + the gadget-flag queries that close the
## ↩ From 06 hooks (glasscutter / cloner / spoof / stethoscope), and consumable spend.

var _saved_unlocked: Array

func before_each() -> void:
	_saved_unlocked = ProgressionManager.unlocked_gear.duplicate()

func after_each() -> void:
	ProgressionManager.unlocked_gear = _saved_unlocked

func _unlock(ids: Array) -> void:
	for gid in ids:
		if gid not in ProgressionManager.unlocked_gear:
			ProgressionManager.unlocked_gear.append(gid)

func test_serialization_round_trip() -> void:
	_unlock([&"glasscutter", &"suppressed_pistol"])
	var lo := Loadout.new()
	lo.equip(Content.gear.get_def(&"glasscutter"))
	lo.equip(Content.gear.get_def(&"suppressed_pistol"))
	var data := lo.to_dict()
	var restored := Loadout.new()
	restored.from_dict(data)
	assert_true(restored.is_equipped(&"glasscutter"), "tool survives the round trip")
	assert_true(restored.is_equipped(&"suppressed_pistol"), "weapon survives the round trip")

func test_gadget_flags_close_obstacle_hooks() -> void:
	_unlock([&"glasscutter", &"keycard_cloner", &"stethoscope"])
	var lo := Loadout.new()
	lo.equip(Content.gear.get_def(&"glasscutter"))
	lo.equip(Content.gear.get_def(&"keycard_cloner"))
	lo.equip(Content.gear.get_def(&"stethoscope"))
	assert_true(lo.has_gadget(&"glasscutter"), "DisplayCase.cut hook")
	assert_true(lo.has_gadget(&"keycard_cloner"), "KeycardDoor clone hook")
	assert_false(lo.has_gadget(&"biometric_spoof"), "unequipped gadget is absent")
	var flags := lo.gear_flags()
	assert_true(flags.get("stethoscope", false), "stethoscope flag reaches the MinigameHost")

func test_consumable_gadget_needs_stock() -> void:
	_unlock([&"emp"])
	var lo := Loadout.new()
	lo.equip(Content.gear.get_def(&"emp"))
	assert_false(lo.has_gadget(&"emp"), "an equipped consumable with 0 stock is unavailable")
	lo._consumables[&"emp"] = 1
	assert_true(lo.has_gadget(&"emp"), "in stock → available")
	assert_true(lo.consume(&"emp"), "one use spends a unit")
	assert_false(lo.has_gadget(&"emp"), "out of stock again after use")
