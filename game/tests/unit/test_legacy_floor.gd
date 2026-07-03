extends GutTest
## Task 12 (FR-12-9): the anti-frustration floor. Even a minimal (zero-Notoriety) Streak pays out
## enough Legacy to afford *something* — at least the cheapest Training level or Perk on offer.

func before_each() -> void:
	ProgressionManager.legacy = 0
	RunManager.notoriety = 0
	RunManager.heat = 0.0
	RunManager.edges.clear()

func _cheapest_purchase() -> int:
	var cheapest := 1 << 30
	for a in Content.attributes.all():
		var curve = a.get("cost_curve")
		if curve is Array and not curve.is_empty():
			cheapest = mini(cheapest, int(curve[0]))
	for p in Content.perks.all():
		cheapest = mini(cheapest, int(p.get("legacy_cost")))
	return cheapest

func test_minimal_run_still_affords_the_cheapest_purchase() -> void:
	var cheapest := _cheapest_purchase()
	assert_gt(cheapest, 0, "there is at least one purchasable thing")
	var awarded := RunManager.end_streak("caught")
	assert_true(awarded >= cheapest,
		"a minimal Catch (%d Legacy) must cover the cheapest purchase (%d)" % [awarded, cheapest])

func test_floor_matches_config() -> void:
	var cfg := ProgressionConfigDef.new()
	var awarded := RunManager.convert_to_legacy(0, 1.0, cfg.legacy_floor)
	assert_eq(awarded, cfg.legacy_floor, "a zero-Notoriety run pays exactly the floor")
