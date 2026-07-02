extends GutTest
## Task 09 (FR-09-5): the armor layer soaks damage (overflow to Health), regenerates after a lull, and
## its weight trades off against agility. Damage routing/Downed flow is task 10; this locks the model.

func test_split_overflows_to_health() -> void:
	var r := Armor.split(30.0, 20.0)
	assert_almost_eq(r["to_armor"], 20.0, 0.001, "armor soaks up to its HP")
	assert_almost_eq(r["to_health"], 10.0, 0.001, "the rest overflows to health")
	assert_almost_eq(r["remaining_armor"], 0.0, 0.001, "armor is depleted")

func test_split_fully_absorbed() -> void:
	var r := Armor.split(10.0, 50.0)
	assert_almost_eq(r["to_health"], 0.0, 0.001, "health untouched when armor covers it")
	assert_almost_eq(r["remaining_armor"], 40.0, 0.001, "armor drops by the damage")

func test_absorb_and_regen() -> void:
	var plates := Content.gear.get_def(&"armor_plates") as GearDef
	assert_not_null(plates, "gear registry populated (run --import first)")
	var armor := Armor.new(plates)
	var full := armor.maximum()
	assert_gt(full, 0.0, "armor has capacity")
	var overflow := armor.absorb(full + 15.0)
	assert_almost_eq(overflow, 15.0, 0.001, "overflow past full armor hits health")
	assert_almost_eq(armor.current, 0.0, 0.001, "armor depleted")
	# Regen only after the delay elapses.
	armor.regen(1.0)
	assert_almost_eq(armor.current, 0.0, 0.001, "no regen during the post-hit delay")
	armor.regen(armor.config.armor_regen_delay + 1.0)
	assert_gt(armor.current, 0.0, "armor regenerates after the lull")

func test_agility_tradeoff() -> void:
	assert_almost_eq(Armor.agility_mult(0.0, 0.01), 1.0, 0.001, "no armor → no penalty")
	assert_lt(Armor.agility_mult(10.0, 0.01), 1.0, "heavier armor slows you")
	assert_gte(Armor.agility_mult(1000.0, 0.01), 0.4, "penalty is floored")
