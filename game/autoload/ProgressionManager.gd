extends Node
## ProgressionManager — permanent (cross-run) account. Survives the Catch.
## Autoload. Legacy currency, attribute levels, unlocks/research, hideout state.
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.2 / §5.5.

var legacy: int = 0                     ## permanent meta-currency (was "Soul XP")
var attributes: Dictionary = {}         ## attr_id -> level (see GDD §5.5)
var unlocked_gear: Array[StringName] = []
var research_done: Array[StringName] = []
var meta_perks: Array[StringName] = []  ## always-on permanent passives (Legacy Board)
var stations_unlocked: Array[StringName] = []
var stash: Array[StringName] = []       ## delivered special/unique loot
var stats: Dictionary = {}              ## lifetime statistics

func add_legacy(amount: int) -> void:
	legacy += amount
	# TODO[16]: trigger autosave

func spend_legacy(amount: int) -> bool:
	if legacy < amount: return false
	legacy -= amount
	return true

func attribute_level(attr_id: StringName) -> int:
	return int(attributes.get(attr_id, 0))

func is_unlocked(gear_id: StringName) -> bool:
	return gear_id in unlocked_gear

## Register a delivered special/unique loot's hook id into the permanent Stash (FR-08-9, GDD
## §10.5). Idempotent. The Stash UI/set-bonus logic is task 12/13's job; this is the append
## task 08's secured-loot banking needs to make "delivering them unlocks... Stash trophies" real.
func add_to_stash(hook_id: StringName) -> void:
	if hook_id != &"" and hook_id not in stash:
		stash.append(hook_id)
