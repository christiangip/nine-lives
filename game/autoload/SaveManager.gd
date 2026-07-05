extends Node
## SaveManager — 10-slot save I/O, autosave, and scan-for-saves.
## Autoload. Drives the Main Menu "Continue" enabled state. Serializes the permanent account
## (ProgressionManager) + the current Streak (RunManager) as JSON, one file per slot, with atomic
## write-then-rename, cheap-meta reads, schema migration, and the strict integrity policy (Q5):
## a hot-quit while committed resolves as the Catch on next launch.
## See docs/tasks/16_save_system.md and GDD §15.4 / §16.3.

const SLOT_COUNT := 10
const SAVE_DIR := "user://saves"
const SCHEMA_VERSION := 2

## Wall-clock mark for lifetime-playtime accumulation (added into ProgressionManager on each save/load).
var _last_playtime_mark_msec: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_last_playtime_mark_msec = Time.get_ticks_msec()

# --- Paths / atomic I/O ----------------------------------------------------
func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

## Write `text` to `path` durably: fill a sibling `.tmp` first, then swap it into place. An
## interrupted write only ever damages the throwaway `.tmp`, so the previous save stays intact
## (FR-16-8). Returns false if the temp file couldn't be opened or the swap failed.
func _write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	# rename_absolute won't overwrite an existing file on every platform (Windows); clear it first.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK

## Read + parse a slot, returning {} for missing / unparseable / bad-header files (FR-16-8: corrupt
## slots read as empty rather than crashing).
func _read_slot(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	# Instance parse() returns an error code without pushing to the engine log (so a corrupt slot reads
	# as empty quietly, FR-16-8), unlike the static JSON.parse_string().
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed = json.data
	if parsed is Dictionary and _valid_header(parsed):
		return parsed
	return {}

## A save is structurally valid if it carries the schema stamp and both state blocks.
func _valid_header(d: Dictionary) -> bool:
	return d.has("schema_version") and d.has("permanent") and d.has("streak")

# --- Schema migration (FR-16-7) --------------------------------------------
## Brings an older save dictionary up to the current SCHEMA_VERSION via stepwise transforms, then
## stamps it. v1 is the pre-task-16 baseline; each _migrate_N_to_(N+1) upgrades one version.
func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("schema_version", SCHEMA_VERSION))
	while version < SCHEMA_VERSION:
		match version:
			1:
				_migrate_1_to_2(data)
		version += 1
	data["schema_version"] = SCHEMA_VERSION
	return data

## v1 → v2: v1 saves predate the lifetime playtime counter and the hot-quit checkpoint flag; default
## them so an old save loads cleanly. The concrete example the migration framework is proven against.
func _migrate_1_to_2(data: Dictionary) -> void:
	if not data.has("active_mission_committed"):
		data["active_mission_committed"] = false
	var perm = data.get("permanent", {})
	if perm is Dictionary and not perm.has("playtime_seconds"):
		perm["playtime_seconds"] = 0.0
		data["permanent"] = perm

# --- Build / meta ----------------------------------------------------------
## Fold this session's elapsed wall-clock into the permanent playtime counter (source for the meta
## summary + the Options "playtime" readout). Called on every save and reset on every load.
func _accumulate_playtime() -> void:
	var now := Time.get_ticks_msec()
	if ProgressionManager != null:
		ProgressionManager.playtime_seconds += float(now - _last_playtime_mark_msec) / 1000.0
	_last_playtime_mark_msec = now

## The five cheap-read summary fields SlotPopup.format_slot renders (FR-16-3).
func _build_meta() -> Dictionary:
	var streak_len := 0
	var legacy := 0
	var playtime := 0
	var last_contract := "—"
	if RunManager != null:
		streak_len = RunManager.streak_length
		if RunManager.last_contract != "":
			last_contract = RunManager.last_contract
	if ProgressionManager != null:
		legacy = ProgressionManager.legacy
		playtime = int(ProgressionManager.playtime_seconds)
	return {
		"streak_len": streak_len,
		"legacy": legacy,
		"playtime": playtime,
		"last_played": Time.get_datetime_string_from_system(),
		"last_contract": last_contract,
	}

## Compose the full save schema from the two managers + meta. `active_mission_committed` is written
## false here (a between-mission save is a safe checkpoint); only mark_committed() flips it true.
func _build_save_dict() -> Dictionary:
	_accumulate_playtime()
	return {
		"schema_version": SCHEMA_VERSION,
		"active_mission_committed": false,
		"meta": _build_meta(),
		"permanent": ProgressionManager.to_dict() if ProgressionManager != null else {},
		"streak": RunManager.to_dict() if RunManager != null else {},
	}

# --- Scan / summary (FR-16-1, FR-16-3) -------------------------------------
## Returns an Array[bool] of length SLOT_COUNT; true = a populated, valid save.
func scan_slots() -> Array:
	var out := []
	for i in SLOT_COUNT:
		out.append(not _read_slot(i).is_empty())
	return out

func populated_count() -> int:
	return scan_slots().count(true)

## Cheap meta read for the slot rows — parses the slot but returns only its meta block (FR-16-3).
func slot_summary(slot: int) -> Dictionary:
	var d := _read_slot(slot)
	return d.get("meta", {}) if not d.is_empty() else {}

# --- Save / load / delete (FR-16-1, FR-16-6) -------------------------------
func save_slot(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	return _write_atomic(_slot_path(slot), JSON.stringify(_build_save_dict(), "\t"))

## Rehydrate both managers from a slot. If the slot was flagged mid-mission-committed (a hot-quit
## while on the hook), resolve it as the Catch (FR-16-5) and persist the cleared, fresh Streak back.
func load_slot(slot: int) -> bool:
	var d := _read_slot(slot)
	if d.is_empty():
		return false
	d = migrate(d)
	if ProgressionManager != null:
		ProgressionManager.from_dict(d.get("permanent", {}))
	if RunManager != null:
		RunManager.from_dict(d.get("streak", {}))
	_last_playtime_mark_msec = Time.get_ticks_msec()
	if bool(d.get("active_mission_committed", false)) and RunManager != null:
		RunManager.end_streak("caught_hot_quit")
		save_slot(slot)
	return true

func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	var existed := FileAccess.file_exists(path)
	if existed:
		DirAccess.remove_absolute(path)
	var tmp := path + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	return existed

# --- Autosave + strict-commit checkpoint (FR-16-4, FR-16-5) ----------------
## Persist the active slot at a between-mission checkpoint (Hideout entry, post-mission, station
## spend). No-op with no active slot. Never called mid-mission (strict policy — no save-scumming).
func autosave() -> void:
	var slot := _active_slot()
	if slot >= 0:
		save_slot(slot)

## Flip the on-disk checkpoint flag when the Streak commits mid-mission (an alarm). Rewrites only the
## flag on the existing save — no mission progress is stored — so a hot-quit resolves as the Catch.
func mark_committed() -> void:
	var slot := _active_slot()
	if slot < 0:
		return
	var d := _read_slot(slot)
	if d.is_empty():
		return
	d["active_mission_committed"] = true
	_write_atomic(_slot_path(slot), JSON.stringify(d, "\t"))

func _active_slot() -> int:
	return GameManager.active_slot if GameManager != null else -1
