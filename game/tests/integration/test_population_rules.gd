extends GutTest
## Task 11 / FR-11-4: designer placement rules hold — the Mark spawns in a high-security wing, ≥1
## alternate entry exists, patrols/loot/Drop Points populate. See docs/tasks/11_mission_generation.md.

func _contract(seed_v: int, objective: StringName, tier: int = 2) -> Contract:
	var c := Contract.new()
	c.archetype_id = &"bank"
	c.objective_id = objective
	c.mission_seed = seed_v
	c.tier = tier
	c.difficulty = tier
	return c

func test_mark_lands_in_a_high_security_wing() -> void:
	var placed_any := false
	for s in range(1, 20):
		var layout := MissionGenerator.generate_layout(_contract(s, &"mark_high_value", 2))
		for l in layout.loot:
			if bool(l.get("is_mark", false)):
				placed_any = true
				var sec: int = layout.sections[int(l.get("section", 0))].def.security_tier
				assert_true(sec >= 2, "seed %d: the Mark sits in a high-security wing (tier %d)" % [s, sec])
	assert_true(placed_any, "a Mark objective placed a marked item")

func test_at_least_one_alternate_entry() -> void:
	for s in range(1, 20):
		var layout := MissionGenerator.generate_layout(_contract(s, &"grab_value", 1))
		assert_true(layout.entry_indices().size() >= 2, "seed %d: ≥1 alternate entry (%d entry sections)" % [s, layout.entry_indices().size()])

func test_patrols_loot_and_drops_populate() -> void:
	var layout := MissionGenerator.generate_layout(_contract(5, &"grab_value", 2))
	assert_true(layout.actors.size() > 0, "guards populated at patrol anchors")
	assert_true(layout.loot.size() > 0, "loot scattered at loot anchors")
	assert_true(layout.drop_points.size() > 0, "≥1 reachable Drop Point")
	assert_true(layout.civilians.size() > 0, "a pickpockable keycard civilian was placed (↩ From 07/09)")

func test_higher_tier_scales_guard_skill() -> void:
	# Guard skill (EnemyDef.scaled mult) rises with Difficulty Tier (FR-11-9).
	var low := MissionGenerator.generate_layout(_contract(9, &"grab_value", 1))
	var high := MissionGenerator.generate_layout(_contract(9, &"grab_value", 4))
	assert_true(_max_skill(high) > _max_skill(low), "higher Tier scales guard skill up")

func _max_skill(layout: MissionLayout) -> float:
	var m := 0.0
	for a in layout.actors:
		m = maxf(m, float(a.get("skill_mult", 1.0)))
	return m
