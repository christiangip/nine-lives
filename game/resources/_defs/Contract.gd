extends Resource
class_name Contract
## A generated contract — a Job Map pin (GDD §7.1/§7.3): Archetype + Objective(s) + Modifiers + Seed +
## Difficulty Tier. Produced by MissionGenerator.refresh_board(), consumed by MissionGenerator.build()
## / GameManager.enter_mission(), stored in RunManager.job_board, and serialized by the save system
## (task 16) via to_dict()/from_dict() (mirrors Loadout). `mission_seed` (not `seed`) avoids shadowing
## the global seed() builtin. See docs/tasks/11_mission_generation.md.

@export var archetype_id: StringName
@export var objective_id: StringName
@export var bonus_objective_id: StringName = &""
@export var modifier_ids: Array[StringName] = []
@export var mission_seed: int = 0
@export var tier: int = 1          ## Difficulty Tier (1..N): guard count/skill, camera/laser/lock density (FR-11-9)
@export var difficulty: int = 1    ## board-escalation score (streak length + Heat) — for ordering/UI (FR-11-10)

func to_dict() -> Dictionary:
	var mods: Array = []
	for m in modifier_ids:
		mods.append(String(m))
	return {
		"archetype_id": String(archetype_id),
		"objective_id": String(objective_id),
		"bonus_objective_id": String(bonus_objective_id),
		"modifier_ids": mods,
		"mission_seed": mission_seed,
		"tier": tier,
		"difficulty": difficulty,
	}

func from_dict(d: Dictionary) -> void:
	archetype_id = StringName(d.get("archetype_id", &""))
	objective_id = StringName(d.get("objective_id", &""))
	bonus_objective_id = StringName(d.get("bonus_objective_id", &""))
	modifier_ids.clear()
	for m in d.get("modifier_ids", []):
		modifier_ids.append(StringName(m))
	mission_seed = int(d.get("mission_seed", 0))
	tier = int(d.get("tier", 1))
	difficulty = int(d.get("difficulty", 1))

## Rebuild a Contract from its serialized dict (save load, task 16).
static func from_data(d: Dictionary) -> Contract:
	var c := Contract.new()
	c.from_dict(d)
	return c
