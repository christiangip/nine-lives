extends GutTest
## Task 13 (FR-13-5): the Workshop spends Legacy to permanently research gear, which the research gate
## Loadout.can_equip already enforces. Pure can_research seam (cost + optional prereq) + the glue that
## appends to ProgressionManager.unlocked_gear.

func before_each() -> void:
	ProgressionManager.legacy = 0
	ProgressionManager.unlocked_gear.clear()
	ProgressionManager.research_done.clear()

func test_research_spends_legacy_and_unlocks_gear() -> void:
	var def := Content.gear.get_def(&"emp") as GearDef
	assert_not_null(def, "the gear exists as data")
	assert_gt(def.research_cost, 0, "it is researchable")
	assert_false(ProgressionManager.is_unlocked(&"emp"), "locked before research")
	ProgressionManager.legacy = def.research_cost
	assert_true(ProgressionManager.research_gear(&"emp"), "affordable → researched")
	assert_eq(ProgressionManager.legacy, 0, "exactly the research cost was spent")
	assert_true(ProgressionManager.is_unlocked(&"emp"), "now permanently unlocked (Loadout can equip it)")
	assert_false(ProgressionManager.research_gear(&"emp"), "re-researching is a no-op")

func test_research_rejected_when_unaffordable() -> void:
	var def := Content.gear.get_def(&"emp") as GearDef
	ProgressionManager.legacy = def.research_cost - 1
	assert_false(ProgressionManager.research_gear(&"emp"), "broke → not researched")
	assert_false(ProgressionManager.is_unlocked(&"emp"), "still locked")

func test_research_prereq_gates_the_pure_seam() -> void:
	var gated := GearDef.new()
	gated.id = &"fancy_tool"
	gated.research_cost = 50
	gated.params = {"research_prereq": &"emp"}
	assert_false(ProgressionManager.can_research(gated, [], 1000),
		"prereq not owned → cannot research")
	assert_true(ProgressionManager.can_research(gated, [&"emp"], 1000),
		"prereq owned + affordable → can research")
