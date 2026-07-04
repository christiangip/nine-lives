extends GutTest
## Task 14 (FR-14-4): every cost/value/curve table loads and passes EconomyValidator's schema + range
## checks — loot values, gear costs, attribute curves, perk costs, Intel prices, and economy.json dials.

func test_all_economy_tables_valid() -> void:
	var errors := EconomyValidator.validate()
	assert_eq(errors.size(), 0, "economy tables have no violations, got: %s" % str(errors))

func test_validator_is_not_a_rubber_stamp() -> void:
	# Prove the validator actually rejects bad data: temporarily break a curve, expect a violation,
	# then restore so the rest of the suite sees clean content.
	var def := Content.attributes.get_def(&"lockpicking") as AttributeDef
	assert_not_null(def, "lockpicking attribute exists")
	var saved := def.cost_curve.duplicate()
	def.cost_curve = [100, 50] as Array[int]   # non-monotonic AND wrong length
	var errors := EconomyValidator.validate()
	assert_gt(errors.size(), 0, "the validator flags a broken cost_curve")
	def.cost_curve = saved   # restore
	assert_eq(EconomyValidator.validate().size(), 0, "restored data validates clean again")

func test_floor_affords_the_cheapest_first_buy() -> void:
	# The anti-frustration invariant, checked directly against the data (FR-14-5).
	var econ := EconomyConfigDef.resolve()
	var cheapest := 1 << 30
	for res in Content.attributes.all():
		var def := res as AttributeDef
		if def != null and not def.cost_curve.is_empty():
			cheapest = mini(cheapest, def.cost_curve[0])
	assert_true(econ.legacy_floor >= cheapest,
		"legacy_floor %d affords the cheapest first Training buy %d" % [econ.legacy_floor, cheapest])
