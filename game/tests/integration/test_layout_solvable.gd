extends GutTest
## Task 11 / FR-11-3 (CI gate): every generated layout is stealth-solvable — MissionValidator proves a
## reachable entry→objective→escape path plus a reachable Drop Point, across a fixed seed set and all
## generatable archetypes. Also proves validate() is a REAL check: a key stranded behind its own door
## must fail. See docs/tasks/11_mission_generation.md.

func _contract(seed_v: int, objective: StringName = &"grab_value", archetype: StringName = &"bank", tier: int = 1) -> Contract:
	var c := Contract.new()
	c.archetype_id = archetype
	c.objective_id = objective
	c.mission_seed = seed_v
	c.tier = tier
	c.difficulty = tier
	return c

func test_all_seeds_and_archetypes_solvable() -> void:
	var archetypes := MissionBoard.generatable_archetypes()
	assert_true(archetypes.size() >= 1, "there is at least one generatable archetype")
	for arch in archetypes:
		for s in range(1, 25):
			var c := _contract(s, &"grab_value", arch.id, 1 + s % 4)
			var layout := MissionGenerator.generate_layout(c)
			assert_false(layout.sections.is_empty(), "%s seed %d generated a layout" % [arch.id, s])
			assert_true(MissionValidator.validate(layout), "%s seed %d is solvable" % [arch.id, s])

func test_objective_variety_stays_solvable() -> void:
	for obj in [&"grab_value", &"mark_high_value", &"crack_vault"]:
		for s in range(1, 12):
			var layout := MissionGenerator.generate_layout(_contract(s, obj, &"bank", 2))
			assert_true(MissionValidator.validate(layout), "bank %s seed %d solvable" % [obj, s])

func test_validate_hook_on_autoload() -> void:
	var layout := MissionGenerator.generate_layout(_contract(7))
	assert_true(MissionGenerator.validate_layout(layout), "the autoload validate_layout() accepts a MissionLayout")

func test_key_stranded_behind_its_gate_is_unsolvable() -> void:
	# Bank gates its vault with a keycard door; the found keycard is placed reachably. Move it behind
	# the door and the layout must become unsolvable — proving validate() isn't a rubber stamp.
	var layout := MissionGenerator.generate_layout(_contract(3, &"crack_vault", &"bank", 1))
	assert_true(MissionValidator.validate(layout), "baseline bank is solvable")
	var had_key := false
	for k in layout.keys:
		k["section"] = layout.objective_index
		had_key = true
	assert_true(had_key, "the bank vault is gated by a found key")
	assert_false(MissionValidator.validate(layout), "a key stranded behind its own door breaks solvability")
