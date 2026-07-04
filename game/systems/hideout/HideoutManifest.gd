extends RefCounted
class_name HideoutManifest
## The Hideout's "no central switch" station loader (task 13, FR-13-1 — the station-level mirror of
## FR-02-5's "add content without code"). It reads every StationDef from Content.stations and pairs
## each with its unlock state (ProgressionManager) + a human requirement string, so the Hideout scene
## can build its station list purely from data: dropping a StationDef .tres + a panel scene makes a new
## station appear with zero code edits. Pure-ish RefCounted (like Inventory/Loadout) so the manifest
## build is unit-testable headlessly. See docs/tasks/13_hideout_stations.md and GDD §6.2.

## Build the ordered station manifest: an Array of { def, unlocked, requirement } dictionaries, one per
## StationDef in the registry. `unlocked_ids`/`stash` default to the live ProgressionManager account but
## are injectable so tests can drive the pure logic with a hand-built registry + state.
static func build(stations: Array, unlocked_ids: Array = [], stash: Array = []) -> Array:
	var out: Array = []
	for res in stations:
		var def := res as StationDef
		if def == null:
			continue
		out.append({
			"def": def,
			"unlocked": is_station_unlocked(def, unlocked_ids, stash),
			"requirement": requirement_text(def),
		})
	return out

## Build straight from the live autoloads (Content + ProgressionManager) — the seam the Hideout scene
## calls. Falls back to an empty list headlessly with no content.
static func build_live() -> Array:
	var content := Services.content()
	if content == null or content.stations == null:
		return []
	var prog := Services.progression()
	var unlocked: Array = prog.stations_unlocked if prog != null else []
	var stash: Array = prog.stash if prog != null else []
	return build(content.stations.all(), unlocked, stash)

## Is a station open? Free stations (no Legacy cost + no loot gate) are always open; the rest need an id
## in `unlocked_ids` or their named special loot delivered to the Stash. Pure — mirrors
## ProgressionManager.is_station_unlocked but takes explicit state so it's dependency-free. (FR-13-2)
static func is_station_unlocked(def: StationDef, unlocked_ids: Array, stash: Array) -> bool:
	if def == null:
		return false
	if def.unlock_legacy_cost <= 0 and def.unlock_special_loot == &"":
		return true
	if def.id in unlocked_ids:
		return true
	return def.unlock_special_loot != &"" and def.unlock_special_loot in stash

## The locked-state requirement label a station shows until it opens (FR-13-2). Empty for a free station.
static func requirement_text(def: StationDef) -> String:
	if def == null:
		return ""
	if def.unlock_special_loot != &"":
		return "Locked — deliver %s" % def.unlock_special_loot
	if def.unlock_legacy_cost > 0:
		return "Locked — %d Legacy" % def.unlock_legacy_cost
	return ""
