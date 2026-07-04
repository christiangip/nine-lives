extends GutTest
## Task 13 (FR-13-2): stations lock/unlock by Legacy cost OR by delivering the named special loot.
## The pure can_unlock_station seam + the ProgressionManager try_unlock_station glue (spends Legacy,
## or ratifies a loot-gated station for free once its loot is in the Stash).

func before_each() -> void:
	ProgressionManager.legacy = 0
	ProgressionManager.stations_unlocked.clear()
	ProgressionManager.stash.clear()

func _station(id: StringName, cost: int, loot: StringName) -> StationDef:
	var def := StationDef.new()
	def.id = id
	def.unlock_legacy_cost = cost
	def.unlock_special_loot = loot
	return def

# --- Legacy-paid unlock ----------------------------------------------------
func test_legacy_gated_station_unlocks_when_paid() -> void:
	var def := _station(&"armory", 300, &"")
	assert_false(ProgressionManager.is_station_unlocked(def), "locked before payment")
	ProgressionManager.legacy = 300
	assert_true(ProgressionManager.try_unlock_station(def), "affordable → unlocks")
	assert_eq(ProgressionManager.legacy, 0, "exactly the cost was spent")
	assert_true(ProgressionManager.is_station_unlocked(def), "now open")
	assert_false(ProgressionManager.try_unlock_station(def), "re-unlocking is a no-op")

func test_legacy_gated_station_rejected_when_broke() -> void:
	var def := _station(&"armory", 300, &"")
	ProgressionManager.legacy = 100
	assert_false(ProgressionManager.can_unlock_station(def, ProgressionManager.legacy, ProgressionManager.stash),
		"can't afford → the seam says no")
	assert_false(ProgressionManager.try_unlock_station(def), "broke → stays locked")
	assert_eq(ProgressionManager.legacy, 100, "no Legacy spent on a failed unlock")

# --- Loot-gated unlock (no Legacy spent) -----------------------------------
func test_loot_gated_station_opens_on_delivery() -> void:
	var def := _station(&"stash", 0, &"stash_trophy_painting")
	assert_false(ProgressionManager.is_station_unlocked(def), "locked with an empty Stash")
	ProgressionManager.legacy = 999
	ProgressionManager.add_to_stash(&"stash_trophy_painting")
	assert_true(ProgressionManager.is_station_unlocked(def),
		"delivering the named loot opens it — even before try_unlock")
	assert_true(ProgressionManager.try_unlock_station(def), "ratifies the loot-gated unlock")
	assert_eq(ProgressionManager.legacy, 999, "loot-gated unlock spends NO Legacy")
