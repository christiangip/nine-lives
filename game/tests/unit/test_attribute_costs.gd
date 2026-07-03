extends GutTest
## Task 12 (FR-12-6/7): the permanent Legacy line. Training spends the AttributeDef cost curve and
## raises the level (whose effect feeds systems via attribute_effect); Legacy Perks require their
## prerequisites + cost and are permanent/idempotent once bought.

func before_each() -> void:
	ProgressionManager.legacy = 0
	ProgressionManager.attributes.clear()
	ProgressionManager.meta_perks.clear()

# --- Training (attributes) -------------------------------------------------
func test_training_spends_the_curve_cost_and_raises_the_level() -> void:
	var def := Content.attributes.get_def(&"lockpicking") as AttributeDef
	assert_not_null(def, "lockpicking attribute exists")
	var cost0 := ProgressionManager.attribute_cost(def, 0)
	assert_gt(cost0, 0, "the first level has an authored cost")
	ProgressionManager.legacy = cost0
	assert_true(ProgressionManager.train_attribute(&"lockpicking"), "affordable → trains")
	assert_eq(ProgressionManager.attribute_level(&"lockpicking"), 1, "the level rose")
	assert_eq(ProgressionManager.legacy, 0, "exactly the cost was spent")

func test_training_is_rejected_when_unaffordable() -> void:
	ProgressionManager.legacy = 0
	assert_false(ProgressionManager.train_attribute(&"lockpicking"), "broke → cannot train")
	assert_eq(ProgressionManager.attribute_level(&"lockpicking"), 0, "no level gained")

func test_attribute_effect_scales_with_level() -> void:
	var def := Content.attributes.get_def(&"lockpicking") as AttributeDef
	ProgressionManager.attributes[&"lockpicking"] = 3
	assert_almost_eq(ProgressionManager.attribute_effect(&"lockpicking"),
		3.0 * def.effect_per_level, 0.0001, "effect = level × effect_per_level")

func test_cost_is_minus_one_when_maxed() -> void:
	var def := Content.attributes.get_def(&"lockpicking") as AttributeDef
	assert_eq(ProgressionManager.attribute_cost(def, def.max_level), -1, "a maxed attribute can't be trained")

# --- Legacy Perks ----------------------------------------------------------
func test_perk_requires_prerequisite() -> void:
	ProgressionManager.legacy = 100000
	assert_false(ProgressionManager.buy_perk(&"ghost_protocol"), "prereq (nimble) missing → rejected")
	assert_true(ProgressionManager.buy_perk(&"nimble"), "no prereq, affordable → bought")
	assert_true(ProgressionManager.buy_perk(&"ghost_protocol"), "prereq now owned → bought")
	assert_true(ProgressionManager.has_perk(&"ghost_protocol"), "the Perk is permanently held")

func test_perk_spends_legacy_and_is_idempotent() -> void:
	var def := Content.perks.get_def(&"nimble") as PerkDef
	ProgressionManager.legacy = def.legacy_cost
	assert_true(ProgressionManager.buy_perk(&"nimble"), "affordable → bought")
	assert_eq(ProgressionManager.legacy, 0, "its Legacy cost was spent")
	assert_false(ProgressionManager.buy_perk(&"nimble"), "re-buying an owned Perk is a no-op")
