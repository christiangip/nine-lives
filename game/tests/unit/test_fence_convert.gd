extends GutTest
## Task 13 (FR-13-10, closes ↩ From 09.2): the Fence converts a delivered special loot into The Take
## (removing the trophy from the Stash) and restocks consumables. convert_stash_item returns the cash
## value the sale grants; the station banks it into RunManager.take.

func before_each() -> void:
	ProgressionManager.stash.clear()
	RunManager.take = 0

func test_convert_removes_trophy_and_returns_its_value() -> void:
	var def := _loot_by_hook(&"stash_trophy_painting")
	assert_not_null(def, "a special loot with that hook exists as data")
	ProgressionManager.add_to_stash(&"stash_trophy_painting")
	var value := ProgressionManager.convert_stash_item(&"stash_trophy_painting")
	assert_eq(value, def.value, "the fenced value equals the loot's cash value")
	assert_false(&"stash_trophy_painting" in ProgressionManager.stash, "the trophy left the Stash")

func test_convert_of_absent_trophy_yields_nothing() -> void:
	assert_eq(ProgressionManager.convert_stash_item(&"not_delivered"), 0, "nothing to fence → 0")

func test_convert_value_seam_is_pure() -> void:
	var def := _loot_by_hook(&"stash_trophy_painting")
	assert_eq(ProgressionManager.convert_value(def), def.value, "pure value passthrough")
	assert_eq(ProgressionManager.convert_value(null), 0, "unknown loot → 0")

func _loot_by_hook(hook: StringName) -> LootDef:
	for res in Content.loot.all():
		var def := res as LootDef
		if def != null and def.special_hook == hook:
			return def
	return null
