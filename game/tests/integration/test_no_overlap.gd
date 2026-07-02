extends GutTest
## Task 11 / FR-11-2: assembled sections never share a grid cell and no section exceeds its declared
## socket count (matched-or-capped). Checked across a seed sweep + both larger archetypes.
## See docs/tasks/11_mission_generation.md.

func _contract(seed_v: int, archetype: StringName = &"bank", tier: int = 1) -> Contract:
	var c := Contract.new()
	c.archetype_id = archetype
	c.objective_id = &"grab_value"
	c.mission_seed = seed_v
	c.tier = tier
	c.difficulty = tier
	return c

func test_sections_never_overlap() -> void:
	for arch in [&"bank", &"museum", &"warehouse"]:
		for s in range(1, 30):
			var layout := MissionGenerator.generate_layout(_contract(s, arch, 1 + s % 3))
			assert_false(layout.sections.is_empty(), "%s seed %d generated" % [arch, s])
			assert_true(MissionValidator.no_overlap(layout), "%s seed %d: no overlap + sockets capped" % [arch, s])

func test_cells_are_distinct() -> void:
	for s in range(1, 20):
		var layout := MissionGenerator.generate_layout(_contract(s, &"bank", 2))
		var seen: Dictionary = {}
		var distinct := true
		for ps in layout.sections:
			for cell in ps.cells():
				if seen.has(cell):
					distinct = false
				seen[cell] = true
		assert_true(distinct, "seed %d: every occupied grid cell belongs to exactly one section" % s)

func test_sockets_matched_or_capped() -> void:
	for s in range(1, 20):
		var layout := MissionGenerator.generate_layout(_contract(s, &"bank", 1))
		for ps in layout.sections:
			assert_true(ps.sockets_used <= ps.def.socket_count,
				"seed %d: section '%s' uses %d/%d sockets" % [s, ps.def.id, ps.sockets_used, ps.def.socket_count])
