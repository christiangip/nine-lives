extends GutTest
## Task 13 (FR-13-3/8, closes the ↩ From 06 reveal half): buying Intel at the Planning Table reveals a
## contract's otherwise-hidden modifiers/manifest. Spends The Take, records the reveal against the
## contract's seed, and flips has_intel/revealed_modifiers hidden→visible.

func before_each() -> void:
	RunManager.take = 0
	RunManager.intel_by_seed.clear()
	ProgressionManager.legacy = 0

func _contract(seed_value: int) -> Contract:
	var c := Contract.new()
	c.mission_seed = seed_value
	c.archetype_id = &"bank"
	c.objective_id = &"grab_cash"
	c.modifier_ids = [&"extra_patrols", &"blackout"]
	return c

func test_modifiers_hidden_until_intel_bought() -> void:
	var c := _contract(1234)
	assert_false(RunManager.has_intel(c, "modifiers"), "no Intel yet")
	assert_true(RunManager.revealed_modifiers(c).is_empty(), "modifiers hidden on the Job Map")

func test_buying_intel_spends_take_and_reveals() -> void:
	var c := _contract(1234)
	var intel := Content.intel.get_def(&"intel_modifiers") as IntelDef
	assert_not_null(intel, "the modifiers Intel packet exists as data")
	RunManager.take = intel.take_cost
	assert_true(RunManager.buy_intel(c, intel), "affordable → bought")
	assert_eq(RunManager.take, 0, "The Take paid exactly the Intel cost")
	assert_true(RunManager.has_intel(c, "modifiers"), "the reveal is recorded")
	assert_eq(RunManager.revealed_modifiers(c).size(), 2, "both modifiers are now visible")

func test_intel_is_per_contract_seed() -> void:
	var bought := _contract(1234)
	var other := _contract(5678)
	var intel := Content.intel.get_def(&"intel_modifiers") as IntelDef
	RunManager.take = intel.take_cost
	RunManager.buy_intel(bought, intel)
	assert_true(RunManager.has_intel(bought, "modifiers"), "reveal applies to the bought contract")
	assert_false(RunManager.has_intel(other, "modifiers"), "a different seed stays hidden")

func test_intel_rejected_when_unaffordable() -> void:
	var c := _contract(1234)
	var intel := Content.intel.get_def(&"intel_modifiers") as IntelDef
	RunManager.take = intel.take_cost - 1
	assert_false(RunManager.buy_intel(c, intel), "broke → no purchase")
	assert_false(RunManager.has_intel(c, "modifiers"), "nothing revealed")
