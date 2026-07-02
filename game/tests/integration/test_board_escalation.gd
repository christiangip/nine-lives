extends GutTest
## Task 11 / FR-11-10: the Job Map board escalates — a longer Streak (higher difficulty floor) and more
## Heat raise the board's difficulty floor, and difficulty ramps across the 3–5 slots.
## See docs/tasks/11_mission_generation.md.

func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

func test_longer_streak_raises_the_floor() -> void:
	var low := MissionBoard.build_board(1, 0.0, 5, _rng(99))
	var high := MissionBoard.build_board(6, 0.0, 5, _rng(99))
	assert_true(MissionBoard.board_difficulty_floor(high) > MissionBoard.board_difficulty_floor(low),
		"a longer Streak raises the board's difficulty floor (%d > %d)" % [
			MissionBoard.board_difficulty_floor(high), MissionBoard.board_difficulty_floor(low)])

func test_heat_raises_the_floor() -> void:
	var cool := MissionBoard.build_board(2, 0.0, 4, _rng(7))
	var hot := MissionBoard.build_board(2, 1.0, 4, _rng(7))
	assert_true(MissionBoard.board_difficulty_floor(hot) > MissionBoard.board_difficulty_floor(cool),
		"Heat raises the board's difficulty floor")

func test_board_size_and_escalation() -> void:
	var board := MissionBoard.build_board(1, 0.0, 4, _rng(5))
	assert_true(board.size() >= 3 and board.size() <= 5, "the board offers 3–5 contracts")
	assert_true(board.back().difficulty >= board.front().difficulty, "difficulty ramps across the board")
	for c in board:
		assert_true(c.tier >= 1, "every contract has a Difficulty Tier")
		assert_true(c.archetype_id != &"", "every contract names an archetype")

func test_pure_escalation_seams() -> void:
	assert_eq(MissionBoard.contract_difficulty(1, 0.0, 0), 1, "floor 1, no heat, slot 0 → difficulty 1")
	assert_true(MissionBoard.contract_difficulty(1, 0.0, 3) > MissionBoard.contract_difficulty(1, 0.0, 0),
		"later board slots read tougher")
	assert_true(MissionBoard.contract_difficulty(1, 1.0, 0) > MissionBoard.contract_difficulty(1, 0.0, 0),
		"Heat bumps difficulty")
	assert_eq(MissionBoard.tier_for_difficulty(1), 1, "difficulty 1 → tier 1")
	assert_true(MissionBoard.tier_for_difficulty(9) > MissionBoard.tier_for_difficulty(1), "tier climbs with difficulty")
