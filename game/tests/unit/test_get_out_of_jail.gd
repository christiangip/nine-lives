extends GutTest
## Task 10 (FR-10-7): the Get-Out-of-Jail consumable grants a one-time timing skill-check at capture.
## A pass escapes the Catch and consumes the item; a miss (or no item left) locks in CAPTURED.

const HS := Health.State

func _loadout(count: int = 1) -> Loadout:
	var l := Loadout.new()
	l.from_dict({"consumables": {"get_out_of_jail": count}})
	return l

func _health() -> Health:
	var cfg := PursuitConfigDef.new()
	cfg.jail_skill_tolerance = 0.15
	return Health.new(100.0, null, cfg)

func test_skill_check_pass_is_deterministic() -> void:
	assert_true(Health.skill_check_pass(0.5, 0.15), "the sweet spot passes")
	assert_true(Health.skill_check_pass(0.6, 0.15), "just inside tolerance passes")
	assert_false(Health.skill_check_pass(0.9, 0.15), "way off the mark misses")

func test_successful_check_escapes_and_consumes() -> void:
	var l := _loadout(1)
	var h := _health()
	var escaped := h.capture(l, 0.5)   # perfect timing
	assert_true(escaped, "a passing skill-check escapes capture")
	assert_eq(l.consumable_count(&"get_out_of_jail"), 0, "the item is consumed on use")
	assert_eq(h.state, HS.ESCAPED)

func test_second_capture_without_item_is_captured() -> void:
	var l := _loadout(1)
	var first := _health()
	first.capture(l, 0.5)              # spends the one charge
	var second := _health()
	var escaped := second.capture(l, 0.5)   # nothing left to spend
	assert_false(escaped, "no charge left -> captured")
	assert_eq(second.state, HS.CAPTURED)

func test_missed_check_is_captured_and_keeps_item() -> void:
	var l := _loadout(1)
	var h := _health()
	var escaped := h.capture(l, 0.95)   # far off the sweet spot
	assert_false(escaped)
	assert_eq(h.state, HS.CAPTURED)
	assert_eq(l.consumable_count(&"get_out_of_jail"), 1, "a missed attempt doesn't consume the item")
