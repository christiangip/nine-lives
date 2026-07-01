extends GutTest
## Spec: the keypad is Mastermind-style — a guess yields [exact, partial] feedback, a full set of exact
## solves it, and a FOUND CODE (on the HackTarget obstacle) instant-solves with no minigame (FR-07-6,
## Phase 07.3). docs/tasks/07_minigames.md, GDD §9.2.

## begin_hack(by: Node) is Node-typed, so this stub MUST extend Node (see the false-green trap memory).
class KeypadActor extends Node:
	var _items: Array
	func _init(items: Array = []) -> void:
		_items = items
	func has_item(id: StringName) -> bool:
		return id in _items

func _keypad(clue: StringName = &"") -> HackTarget:
	var d := ObstacleDef.new()
	d.id = &"test_keypad"
	d.category = ObstacleDef.Category.HACK_TARGET
	d.clue_id = clue
	d.params = {"device": "keypad"}
	var h := HackTarget.new()
	h.def = d
	add_child_autofree(h)
	return h

func test_evaluate_guess_exact_and_partial() -> void:
	assert_eq(KeypadMinigame.evaluate_guess([1, 2, 3], [1, 2, 3]), [3, 0], "all right")
	assert_eq(KeypadMinigame.evaluate_guess([3, 2, 1], [1, 2, 3]), [1, 2], "middle exact, ends transposed")
	assert_eq(KeypadMinigame.evaluate_guess([0, 0, 0], [1, 2, 3]), [0, 0], "nothing matches")

func test_duplicates_are_counted_once() -> void:
	assert_eq(KeypadMinigame.evaluate_guess([1, 1, 2], [1, 3, 1]), [1, 1],
		"pos0 exact; the spare 1 is a single partial, not two")

func test_is_solved_needs_all_exact() -> void:
	assert_true(KeypadMinigame.is_solved([3, 0], 3), "3 exact of 3 solves")
	assert_false(KeypadMinigame.is_solved([2, 1], 3), "2 exact + a partial is not solved")

func test_code_length_grows_with_tier() -> void:
	assert_eq(KeypadMinigame.code_length_for_tier(3, 1, 1), 3)
	assert_eq(KeypadMinigame.code_length_for_tier(3, 3, 1), 5)

func test_found_code_instant_solves_the_keypad() -> void:
	var h := _keypad(&"kp_code")
	var by := KeypadActor.new([&"kp_code"])
	autofree(by)
	assert_true(h.begin_hack(by), "holding the code resolves instantly")
	assert_true(h.solved, "no deduction needed")

func test_keypad_without_code_requests_the_overlay() -> void:
	var h := _keypad()
	watch_signals(h)
	h.begin_hack(null)
	assert_false(h.solved, "still locked pending the deduction")
	assert_signal_emitted(h, "minigame_requested")
	assert_false(h.hacking, "a keypad does not run the autonomous fill timer — the overlay drives it")
