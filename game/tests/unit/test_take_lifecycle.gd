extends GutTest
## Task 14 (FR-14-1/2): The Take is a % of secured cash (not 1:1), is a spendable per-Streak pool
## (Fence/Planning Table), resets on the Catch, and NEVER converts to Legacy.

func before_each() -> void:
	RunManager.notoriety = 0
	RunManager.take = 0
	RunManager.heat = 0.0
	RunManager.committed = false
	RunManager.edges.clear()
	RunManager.intel_by_seed.clear()
	ProgressionManager.legacy = 0
	ProgressionManager.meta_perks.clear()

func test_take_cut_seam() -> void:
	assert_eq(EconomyConfigDef.take_cut(1000, 0.35), 350, "35% of 1000 → 350 Take")
	assert_eq(EconomyConfigDef.take_cut(1000, 0.0), 0, "0% → nothing")
	assert_eq(EconomyConfigDef.take_cut(1000, 1.0), 1000, "100% → full value")
	assert_eq(EconomyConfigDef.take_cut(1000, 2.0), 1000, "fraction clamps to 1.0")
	assert_eq(EconomyConfigDef.take_cut(0, 0.5), 0, "no cash → no Take")

func test_bank_splits_notoriety_full_take_fraction() -> void:
	var econ := EconomyConfigDef.resolve()
	DropPoint.bank(1000, "haul")
	assert_eq(RunManager.notoriety, 1000, "Notoriety banks the FULL street value")
	assert_eq(RunManager.take, EconomyConfigDef.take_cut(1000, econ.take_fraction),
		"Take banks only the launderable fraction")
	assert_lt(RunManager.take, 1000, "Take is less than the full value (fraction < 1)")

func test_take_spends_at_planning_table() -> void:
	# A real Take sink: buying Intel at the Planning Table spends exactly its take_cost.
	var intel := Content.intel.get_def(&"intel_modifiers") as IntelDef
	assert_not_null(intel, "intel_modifiers exists in content")
	var contract := Contract.new()
	contract.mission_seed = 918273
	RunManager.take = intel.take_cost + 500
	var ok := RunManager.buy_intel(contract, intel)
	assert_true(ok, "bought Intel with The Take")
	assert_eq(RunManager.take, 500, "The Take was spent by exactly the Intel's take_cost")

func test_take_resets_on_catch_and_never_becomes_legacy() -> void:
	RunManager.take = 5000
	RunManager.notoriety = 0   # no Notoriety → the conversion is only the anti-frustration floor
	var before_legacy := ProgressionManager.legacy
	var awarded := RunManager.end_streak("caught")
	assert_eq(RunManager.take, 0, "The Take resets to 0 on the Catch (GDD §5.3)")
	assert_eq(ProgressionManager.legacy, before_legacy + awarded, "only the Notoriety conversion banked to Legacy")
	var econ := EconomyConfigDef.resolve()
	assert_eq(awarded, econ.legacy_floor, "0 Notoriety → floor payout; the 5000 Take contributed nothing")
