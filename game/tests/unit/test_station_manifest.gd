extends GutTest
## Task 13 (FR-13-1): the Hideout is manifest-driven — HideoutManifest builds its station list purely
## from StationDef data, so dropping a new StationDef makes a station appear with NO central-switch
## edit (the station-level mirror of FR-02-5). Also proves free vs locked stations report correctly.

# --- The "add a station with no code" proof --------------------------------
func test_a_new_stationdef_appears_in_the_manifest() -> void:
	var a := _station(&"aaa", 0, &"")
	var b := _station(&"bbb", 0, &"")
	var before := HideoutManifest.build([a])
	assert_eq(before.size(), 1, "one def → one entry")
	var after := HideoutManifest.build([a, b])
	assert_eq(after.size(), 2, "adding a StationDef adds an entry — no code change")
	assert_eq(after[1]["def"].id, &"bbb", "the new station is present by data alone")

func test_manifest_marks_free_stations_unlocked() -> void:
	var free := _station(&"free_one", 0, &"")
	var entries := HideoutManifest.build([free], [], [])
	assert_true(entries[0]["unlocked"], "a station with no cost + no loot gate is always open")
	assert_eq(entries[0]["requirement"], "", "a free station shows no requirement text")

func test_manifest_marks_gated_stations_locked_with_a_requirement() -> void:
	var paid := _station(&"paid_one", 500, &"")
	var entries := HideoutManifest.build([paid], [], [])
	assert_false(entries[0]["unlocked"], "an unpaid Legacy-gated station is locked")
	assert_string_contains(entries[0]["requirement"], "500", "the Legacy cost is surfaced")

func test_manifest_unlocks_via_owned_ids_and_delivered_loot() -> void:
	var paid := _station(&"paid_two", 500, &"")
	var loot := _station(&"loot_gate", 0, &"trophy_x")
	var by_id := HideoutManifest.build([paid], [&"paid_two"], [])
	assert_true(by_id[0]["unlocked"], "a station in the owned set is unlocked")
	var by_loot := HideoutManifest.build([loot], [], [&"trophy_x"])
	assert_true(by_loot[0]["unlocked"], "a loot-gated station opens when its loot is delivered")

# --- The live registry actually carries the eight launch stations ----------
func test_live_manifest_reads_the_station_registry() -> void:
	var entries := HideoutManifest.build_live()
	assert_gte(entries.size(), 8, "all eight launch stations are registered as data")
	var ids := {}
	for e in entries:
		ids[e["def"].id] = true
	for want in [&"job_map", &"training", &"workshop", &"armory", &"legacy_board",
			&"planning_table", &"stash", &"fence"]:
		assert_true(ids.has(want), "station '%s' is in the manifest" % want)

func _station(id: StringName, cost: int, loot: StringName) -> StationDef:
	var def := StationDef.new()
	def.id = id
	def.display_name = String(id)
	def.unlock_legacy_cost = cost
	def.unlock_special_loot = loot
	return def
