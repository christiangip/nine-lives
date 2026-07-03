extends GutTest
## Task 12 (FR-12-2/8): a Streak level-up offers a choice of exactly 3 distinct Edges (rarity-
## weighted draw); choosing one applies its modifier while held; a reset (the Catch) removes it.

func _edge(id: StringName, rarity: int) -> EdgeDef:
	var e := EdgeDef.new()
	e.id = id
	e.rarity = rarity
	return e

func test_draw_offers_exactly_three_distinct() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pool := [_edge(&"a", 0), _edge(&"b", 0), _edge(&"c", 1), _edge(&"d", 2), _edge(&"e", 3)]
	var choices := RunManager.draw_edges(pool, 3, [1.0, 0.5, 0.2, 0.05], rng)
	assert_eq(choices.size(), 3, "a level-up offers 3 Edges")
	var seen := {}
	for c in choices:
		seen[c] = true
	assert_eq(seen.size(), 3, "the 3 offered Edges are distinct")

func test_draw_caps_at_pool_size() -> void:
	var rng := RandomNumberGenerator.new()
	var choices := RunManager.draw_edges([_edge(&"a", 0), _edge(&"b", 0)], 3, [1.0], rng)
	assert_eq(choices.size(), 2, "can't offer more Edges than exist in the pool")

func test_draw_returns_edge_ids() -> void:
	var rng := RandomNumberGenerator.new()
	var choices := RunManager.draw_edges([_edge(&"only_one", 0)], 1, [1.0], rng)
	assert_eq(choices[0], &"only_one", "the draw yields Edge ids, not defs")

func test_choosing_an_edge_applies_its_modifier_then_reset_removes_it() -> void:
	# fence_connections grants +10% Notoriety (a real authored Edge).
	RunManager.edges.clear()
	RunManager.notoriety = 0
	RunManager.streak_level = 1
	RunManager.choose_edge(&"fence_connections")
	assert_almost_eq(RunManager.edge_modifier_total("notoriety_mult"), 0.1, 0.0001, "held Edge applies")
	RunManager.add_notoriety(1000)
	assert_eq(RunManager.notoriety, 1100, "the +10% Edge scales the Notoriety gain")

	RunManager.start_new_streak()   # the Catch resets the Streak
	assert_true(RunManager.edges.is_empty(), "Edges vanish on reset")
	assert_almost_eq(RunManager.edge_modifier_total("notoriety_mult"), 0.0, 0.0001, "the Edge's effect is gone")

func test_choose_edge_ignores_duplicates() -> void:
	RunManager.edges.clear()
	RunManager.choose_edge(&"mule")
	RunManager.choose_edge(&"mule")
	assert_eq(RunManager.edges.size(), 1, "the same Edge can't be held twice")
	RunManager.edges.clear()
