extends GutTest
## Spec: GameManager validates state transitions — legal ones apply and announce
## EventBus.game_state_changed(prev, next); illegal ones are rejected with no state
## change and no emission (FR-02-2). docs/tasks/02_core_architecture.md.

var _saved_state: int

func before_all() -> void:
	_saved_state = GameManager.state

func after_all() -> void:
	GameManager.state = _saved_state

func before_each() -> void:
	GameManager.state = GameManager.State.BOOT
	watch_signals(EventBus)

func test_legal_transition_applies_and_emits() -> void:
	var ok := GameManager.transition_to(GameManager.State.MAIN_MENU)
	assert_true(ok, "BOOT -> MAIN_MENU is legal")
	assert_eq(GameManager.state, GameManager.State.MAIN_MENU, "state advances on a legal transition")
	assert_signal_emitted(EventBus, "game_state_changed",
		"a legal transition announces game_state_changed")

func test_signal_carries_previous_and_next() -> void:
	GameManager.transition_to(GameManager.State.MAIN_MENU)
	assert_signal_emitted_with_parameters(EventBus, "game_state_changed",
		[GameManager.State.BOOT, GameManager.State.MAIN_MENU])

func test_illegal_transition_is_rejected() -> void:
	var ok := GameManager.transition_to(GameManager.State.MISSION) # BOOT -> MISSION is illegal
	assert_false(ok, "BOOT -> MISSION is illegal")
	assert_eq(GameManager.state, GameManager.State.BOOT, "state is unchanged on rejection")
	assert_signal_not_emitted(EventBus, "game_state_changed",
		"a rejected transition emits nothing")

func test_can_transition_matches_table() -> void:
	GameManager.state = GameManager.State.HIDEOUT
	assert_true(GameManager.can_transition(GameManager.State.MISSION), "HIDEOUT -> MISSION is legal")
	assert_true(GameManager.can_transition(GameManager.State.MAIN_MENU), "HIDEOUT -> MAIN_MENU is legal")
	assert_false(GameManager.can_transition(GameManager.State.MISSION_RESULTS),
		"HIDEOUT -> MISSION_RESULTS is not allowed")
