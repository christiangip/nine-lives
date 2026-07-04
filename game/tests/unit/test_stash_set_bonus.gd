extends GutTest
## Task 13 (FR-13-9): the Stash's delivered special loot can grant set bonuses, summed the same way
## Edges/Perks are (a modifier key → total). Data-driven from LootDef.params["set_bonus"].

func before_each() -> void:
	ProgressionManager.stash.clear()

func test_no_trophies_no_bonus() -> void:
	assert_almost_eq(ProgressionManager.stash_set_bonus_total("notoriety_mult"), 0.0, 0.0001,
		"an empty Stash grants no set bonus")

func test_delivered_trophy_grants_its_set_bonus() -> void:
	var def := _loot_by_hook(&"stash_trophy_painting")
	assert_not_null(def, "the trophy exists as data")
	var bonus = def.params.get("set_bonus", {})
	assert_true(bonus is Dictionary and bonus.has("notoriety_mult"),
		"the trophy authors a notoriety_mult set bonus")
	ProgressionManager.add_to_stash(&"stash_trophy_painting")
	assert_almost_eq(ProgressionManager.stash_set_bonus_total("notoriety_mult"),
		float(bonus["notoriety_mult"]), 0.0001, "the delivered trophy's bonus is summed")

func _loot_by_hook(hook: StringName) -> LootDef:
	for res in Content.loot.all():
		var def := res as LootDef
		if def != null and def.special_hook == hook:
			return def
	return null
