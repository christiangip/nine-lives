extends Node
## SaveManager — 10-slot save I/O, autosave, and scan-for-saves.
## Autoload. Drives the Main Menu "Continue" enabled state.
## See docs/tasks/16_save_system.md and GDD §15.4 / §16.3.

const SLOT_COUNT := 10
const SAVE_DIR := "user://saves"
const SCHEMA_VERSION := 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

## Schema-migration entry-point (the hook task 16 fills in). Brings an older save
## dictionary up to the current SCHEMA_VERSION, then stamps it. v1 is the baseline
## (no-op); later versions add stepwise transforms keyed off `version`.
func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("schema_version", SCHEMA_VERSION))
	if version < SCHEMA_VERSION:
		pass # TODO[16]: apply stepwise migrations (e.g. _migrate_1_to_2(data)) up to current
	data["schema_version"] = SCHEMA_VERSION
	return data

## Returns an Array[bool] of length SLOT_COUNT; true = populated.
func scan_slots() -> Array:
	var out := []
	for i in SLOT_COUNT:
		out.append(false) # TODO[16]: check file exists + valid header
	return out

func populated_count() -> int:
	return scan_slots().count(true)

func slot_summary(slot: int) -> Dictionary:
	return {} # TODO[16]: {streak_len, legacy, playtime, last_played, last_contract}

func save_slot(slot: int) -> bool:
	return false # TODO[16]: serialize ProgressionManager + RunManager + meta

func load_slot(slot: int) -> bool:
	return false # TODO[16]

func delete_slot(slot: int) -> bool:
	return false # TODO[16]

func autosave() -> void:
	pass # TODO[16]: hideout + between-mission checkpoints only (strict policy)
