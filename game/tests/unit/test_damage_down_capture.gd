extends GutTest
## Task 10 (FR-10-6): damage routes through Armor then Health; emptying Health drops to DOWNED with a
## self-revive window that, if it lapses, becomes CAUGHT; a surround becomes CAPTURED.

const HS := Health.State

func _armor(plate_hp: float, plates: int) -> Armor:
	var g := GearDef.new()
	g.params = {"plate_hp": plate_hp, "plates": plates, "weight_kg": 4.0}
	return Armor.new(g)

func _health(hp: float = 100.0, armor: Armor = null, revive_window: float = 1.0) -> Health:
	var cfg := PursuitConfigDef.new()
	cfg.self_revive_window = revive_window
	cfg.revive_health_fraction = 0.5
	return Health.new(hp, armor, cfg)

func test_route_damage_pure_split() -> void:
	var r := Health.route_damage(70.0, 50.0, 100.0)
	assert_almost_eq(float(r["to_armor"]), 50.0, 0.001)
	assert_almost_eq(float(r["to_health"]), 20.0, 0.001)
	assert_almost_eq(float(r["remaining_health"]), 80.0, 0.001)

func test_armor_soaks_before_health() -> void:
	var h := _health(100.0, _armor(50.0, 1))
	var overflow := h.take_damage(30.0)
	assert_eq(overflow, 0.0, "a small hit is fully soaked by armor")
	assert_almost_eq(h.current, 100.0, 0.001, "health is untouched")
	assert_almost_eq(h.armor.current, 20.0, 0.001, "armor absorbed the hit")

func test_overflow_bleeds_health() -> void:
	var h := _health(100.0, _armor(50.0, 1))
	h.take_damage(70.0)   # 50 to armor, 20 overflow to health
	assert_almost_eq(h.current, 80.0, 0.001)
	assert_eq(h.state, HS.ALIVE)

func test_lethal_downs_then_caught_without_revive() -> void:
	var h := _health(40.0)
	h.take_damage(50.0)
	assert_eq(h.state, HS.DOWNED, "emptying Health drops to Downed")
	h.tick(1.1)   # the 1.0s self-revive window lapses
	assert_eq(h.state, HS.CAUGHT, "a lapsed window becomes Caught")

func test_self_revive_within_window() -> void:
	var h := _health(40.0)
	h.take_damage(50.0)
	assert_true(h.revive(), "a Downed player can self-revive in the window")
	assert_eq(h.state, HS.ALIVE)
	assert_almost_eq(h.current, 20.0, 0.001, "revives at the configured health fraction")

func test_damage_after_down_is_ignored() -> void:
	var h := _health(40.0)
	h.take_damage(50.0)
	var extra := h.take_damage(999.0)
	assert_eq(extra, 0.0, "no further damage once Downed")
