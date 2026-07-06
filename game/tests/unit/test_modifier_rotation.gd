extends GutTest
## Task 20 (FR-20-3): the rotating-modifier scheduler applies the scheduled global modifier for its
## period and rotates to the next at the boundary (empty slots are calm weeks). Pure + time-injectable
## (LiveOps.active_modifiers takes the config dict + a Unix timestamp). See docs/tasks/20_progression_milestones.md.

const CFG := {
	"modifier_rotation": {
		"epoch_unix": 0,
		"period_days": 7,
		"slots": ["", "extra_patrols", "blackout"],
	}
}

func test_calm_slot_yields_no_modifier() -> void:
	assert_eq(LiveOps.active_modifiers(CFG, 0), [], "day 0 → slot 0 (empty) → no global event")
	assert_eq(LiveOps.active_modifiers(CFG, 3 * 86400), [], "still slot 0 mid-week")

func test_active_slot_applies_its_modifier() -> void:
	assert_eq(LiveOps.active_modifiers(CFG, 7 * 86400), [&"extra_patrols"], "week 1 → slot 1")
	assert_eq(LiveOps.active_modifiers(CFG, 14 * 86400), [&"blackout"], "week 2 → slot 2")

func test_rotation_is_stable_within_a_period() -> void:
	var start := LiveOps.active_modifiers(CFG, 7 * 86400)
	var mid := LiveOps.active_modifiers(CFG, 7 * 86400 + 5 * 86400)   # +5 days, same slot
	assert_eq(start, mid, "the active modifier holds for the whole period")

func test_rotation_wraps_the_ring() -> void:
	assert_eq(LiveOps.active_modifiers(CFG, 21 * 86400), [], "week 3 wraps back to slot 0 (calm)")
	assert_eq(LiveOps.active_modifiers(CFG, 28 * 86400), [&"extra_patrols"], "week 4 → slot 1 again")

func test_missing_config_is_safe() -> void:
	assert_eq(LiveOps.active_modifiers({}, 12345), [], "no rotation config → no modifier, no crash")

func test_shipped_manifest_rotation_is_readable() -> void:
	# The real data/liveops.json parses and its rotation resolves to a valid modifier id (or a calm week).
	var cfg := LiveOps.config()
	assert_true(cfg.has("modifier_rotation"), "the shipped manifest carries a rotation")
	var active := LiveOps.active_modifiers(cfg, 8 * 86400)   # second slot of the shipped ring
	for mid in active:
		assert_true(Content.modifiers.has(mid), "a scheduled modifier '%s' exists as content" % mid)
