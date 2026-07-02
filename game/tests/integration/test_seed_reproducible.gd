extends GutTest
## Task 11 / FR-11-8: a seed fully determines a layout + board. Same seed → byte-identical fingerprint;
## different seeds diverge. Fingerprint = MissionLayout.to_dict() serialized to JSON (deterministic key
## order because generation is deterministic). See docs/tasks/11_mission_generation.md.

func _contract(seed_v: int, objective: StringName = &"grab_value", tier: int = 2) -> Contract:
	var c := Contract.new()
	c.archetype_id = &"bank"
	c.objective_id = objective
	c.mission_seed = seed_v
	c.tier = tier
	c.difficulty = tier
	return c

func _fingerprint(layout: MissionLayout) -> String:
	return JSON.stringify(layout.to_dict())

func test_same_seed_identical_layout() -> void:
	var a := MissionGenerator.generate_layout(_contract(42, &"mark_high_value", 3))
	var b := MissionGenerator.generate_layout(_contract(42, &"mark_high_value", 3))
	assert_eq(_fingerprint(a), _fingerprint(b), "same seed → identical layout + population")

func test_different_seed_differs() -> void:
	var a := MissionGenerator.generate_layout(_contract(1))
	var b := MissionGenerator.generate_layout(_contract(2))
	assert_ne(_fingerprint(a), _fingerprint(b), "different seed → different layout")

func test_board_reproducible_for_same_inputs() -> void:
	var b1 := MissionGenerator.refresh_board(3, 0.2, 4)
	var b2 := MissionGenerator.refresh_board(3, 0.2, 4)
	assert_eq(_board_str(b1), _board_str(b2), "same (floor, heat) → identical board")

func _board_str(board: Array) -> String:
	var parts: Array = []
	for c in board:
		parts.append(JSON.stringify(c.to_dict()))
	return "|".join(parts)
