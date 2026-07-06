extends Resource
class_name ObstacleDef
## A heist obstacle archetype — the data half of the puzzle-box catalogue (GDD §9.1–9.7). Every
## obstacle is a reusable Interactable with a declared counter-play set, so the generator (11) and
## Intel (13) can read its difficulty + valid solutions, and content ships as data, not code.
## Instances live in game/resources/obstacles/*.tres; indexed by id in Content.obstacles.
## Behaviour branches on `category` (a property), never on id. See docs/tasks/06_heist_mechanics_obstacles.md.

## Which obstacle behaviour this def drives (FR-06-1..9).
enum Category {
	LOCK,            ## pin-tumbler lock — lockpick minigame (FR-06-1)
	KEYCARD_DOOR,    ## key/keycard-gated door (FR-06-3)
	SAFE,            ## dial-combination safe (FR-06-2)
	DISPLAY_CASE,    ## key / hack / glasscutter / smash (FR-06-4)
	HACK_TARGET,     ## e-lock / keypad / camera / alarm-panel / time-lock / data-loot (FR-06-5)
	LASER_GRID,      ## laser grid / tripwire (FR-06-6)
	MOTION_SENSOR,   ## trips on fast movement (FR-06-6)
	PRESSURE_PLATE,  ## trips on weight (FR-06-6)
	BIOMETRIC_LOCK,  ## retinal / magnetic — gates premium loot (FR-06-6)
	SILENT_ALARM,    ## invisible; Intel / casing reveals (FR-06-7)
	FUSE_BOX,        ## zone power cut + backup timer (FR-06-8)
	LIGHT,           ## switch / shoot to expand shadow (FR-06-8)
	BREACH_POINT,    ## drill / thermite / C4 (FR-06-9)
}

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.LOCK
@export var difficulty_tier: int = 1                  ## 1 = base; scales minigame/timer/snap (FR-06-10)
@export var valid_solutions: Array[StringName] = []   ## counter-play set exposed to generator/Intel (FR-06-10)
@export var noise_by_solution: Dictionary = {}        ## solution name (String) -> noise radius (m); absent = silent
@export var tags: Array[String] = []                  ## optional ContentRegistry.filter() facet

# --- Interaction (copied onto the Interactable at spawn) --------------------
@export var prompt: String = "Interact"
@export var hold_seconds: float = 0.0                 ## 0 = instant tap

# --- Shared tunables (each category reads what it needs; keeps logic magic-number-free) -----
@export var time_seconds: float = 0.0        ## hack / breach duration to completion (FR-06-5/9)
@export var proximity_range: float = 3.0     ## hack proximity-lock radius; leave it and progress pauses (FR-06-5)
@export var snap_base_chance: float = 0.25   ## lock: base pick-snap chance on a failed attempt (FR-06-1)
@export var backup_seconds: float = 20.0     ## fuse box: backup-generator restore timer (FR-06-8)
@export var power_zone: StringName = &""     ## fuse box <-> powered-device zone key (FR-06-8)
@export var required_item: StringName = &""  ## keycard / key id that gates or bypasses this (FR-06-3)
@export var clue_id: StringName = &""        ## found combo / code id that skips the minigame (FR-06-2/5)

@export var params: Dictionary = {}          ## category-specific extras (e.g. camera "mode", breach "method")
@export var scene: PackedScene               ## optional art geometry (task 18); marker body built if null. Realized by MissionController.

## Solution ids that ARE a skill-minigame (task 07). Any other solution counts as an alternate.
const MINIGAME_SOLUTIONS: Array[StringName] = [&"lockpick", &"safe_dial", &"hack", &"keypad", &"pickpocket"]

## True iff `sol` is in this obstacle's declared counter-play set. Pure.
func has_solution(sol) -> bool:
	return StringName(sol) in valid_solutions

## Noise radius emitted by a given solution (0.0 = silent / unlisted). Pure.
func noise_for(sol) -> float:
	return float(noise_by_solution.get(String(sol), 0.0))

## True iff the only way through is a skill-minigame — no clue/gadget/route/power alternate. The GDD
## forbids this for every obstacle except the pin-tumbler LOCK (§9.1); test_solution_set enforces it. Pure.
func is_minigame_only() -> bool:
	if valid_solutions.is_empty():
		return false
	for s in valid_solutions:
		if s not in MINIGAME_SOLUTIONS:
			return false
	return true
