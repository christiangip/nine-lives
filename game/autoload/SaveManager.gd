extends Node
## SaveManager — 10-slot save I/O, autosave, and scan-for-saves.
## Autoload. Drives the Main Menu "Continue" enabled state.
## See docs/tasks/16_save_system.md and GDD §15.4 / §16.3.

const SLOT_COUNT := 10
const SAVE_DIR := "user://saves"
const SCHEMA_VERSION := 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

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
