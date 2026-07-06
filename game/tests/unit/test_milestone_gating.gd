extends GutTest
## Task 20 (FR-20-1): a milestone unlock arc reveals content exactly at its Legacy / special-loot
## threshold, then AUTO-GRANTS its unlocks for free (stations/gear/archetypes), announces once, and is
## idempotent — and a milestone-gated archetype only reaches the board once granted. Mixes the pure
## milestones_satisfied seam (fixture defs) with check_milestones over the real base milestones.
## See docs/tasks/20_progression_milestones.md.

func before_each() -> void:
	# Reset the permanent-account fields this test drives (shared autoload, the established convention).
	ProgressionManager.legacy = 0
	ProgressionManager.stats = {}
	ProgressionManager.stash = []
	ProgressionManager.milestones_reached = []
	ProgressionManager.unlocked_gear = []
	ProgressionManager.unlocked_archetypes = []
	ProgressionManager.stations_unlocked = []
	ProgressionManager._pending_milestone_toasts = []

# --- Pure seam: milestones_satisfied ---------------------------------------
func test_legacy_threshold_boundary() -> void:
	var m := MilestoneDef.new()
	m.id = &"m_legacy"
	m.threshold_legacy = 1000
	assert_eq(ProgressionManager.milestones_satisfied([m], 999, [], []), [], "one below threshold → not satisfied")
	assert_eq(ProgressionManager.milestones_satisfied([m], 1000, [], []), [&"m_legacy"], "exactly at threshold → satisfied")
	assert_eq(ProgressionManager.milestones_satisfied([m], 5000, [], [&"m_legacy"]), [], "already reached → excluded")

func test_special_loot_gate() -> void:
	var m := MilestoneDef.new()
	m.id = &"m_loot"
	m.threshold_legacy = 0
	m.require_special_loot = &"trophy_x"
	assert_eq(ProgressionManager.milestones_satisfied([m], 0, [], []), [], "trophy not delivered → not satisfied")
	assert_eq(ProgressionManager.milestones_satisfied([m], 0, [&"trophy_x"], []), [&"m_loot"], "trophy in stash → satisfied")

func test_combined_gate_needs_both() -> void:
	var m := MilestoneDef.new()
	m.id = &"m_both"
	m.threshold_legacy = 500
	m.require_special_loot = &"trophy_x"
	assert_eq(ProgressionManager.milestones_satisfied([m], 500, [], []), [], "loot missing → not satisfied even at Legacy threshold")
	assert_eq(ProgressionManager.milestones_satisfied([m], 400, [&"trophy_x"], []), [], "under Legacy → not satisfied even with loot")
	assert_eq(ProgressionManager.milestones_satisfied([m], 500, [&"trophy_x"], []), [&"m_both"], "both met → satisfied")

# --- check_milestones over real base content -------------------------------
func test_check_grants_reward_and_announces_once() -> void:
	watch_signals(ProgressionManager)
	var def := Content.milestones.get_def(&"first_score") as MilestoneDef
	assert_not_null(def, "the first_score milestone ships as data")
	ProgressionManager.stats[&"legacy_earned"] = def.threshold_legacy   # exactly reach it
	var granted := ProgressionManager.check_milestones()
	assert_true(&"first_score" in granted, "first_score is granted at its threshold: %s" % str(granted))
	assert_eq(ProgressionManager.legacy, def.reward_legacy, "its one-off Legacy reward was banked")
	assert_true(&"first_score" in ProgressionManager.milestones_reached, "recorded as reached")
	assert_signal_emitted(ProgressionManager, "milestone_unlocked")
	# Idempotent: a second pass grants nothing more.
	var again := ProgressionManager.check_milestones()
	assert_false(&"first_score" in again, "not re-granted on a second pass")
	assert_eq(ProgressionManager.legacy, def.reward_legacy, "reward not double-paid")

func test_check_grants_station_gear_and_archetype() -> void:
	ProgressionManager.stats[&"legacy_earned"] = 1000000   # clear every Legacy-gated milestone at once
	ProgressionManager.check_milestones()
	assert_true(&"fence" in ProgressionManager.stations_unlocked, "safe_house grants the Fence station for free")
	assert_true(&"casing_visor" in ProgressionManager.unlocked_gear, "well_connected grants the gear for free")
	assert_true(&"federal_reserve" in ProgressionManager.unlocked_archetypes, "master_vault reveals the premium archetype")

func test_gated_archetype_only_on_board_once_unlocked() -> void:
	# federal_reserve carries unlock_milestone = master_vault → off the board until granted.
	assert_false(_generatable_has(&"federal_reserve", []), "gated archetype is off the default board")
	ProgressionManager.stats[&"legacy_earned"] = 1000000
	ProgressionManager.check_milestones()
	assert_true(_generatable_has(&"federal_reserve", ProgressionManager.unlocked_archetypes),
		"once its milestone is reached, the archetype is generatable — it lands on the board")

func _generatable_has(id: StringName, unlocked: Array) -> bool:
	for a in MissionBoard.generatable_archetypes(unlocked):
		if (a as ArchetypeDef).id == id:
			return true
	return false
