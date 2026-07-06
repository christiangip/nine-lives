extends Resource
class_name MilestoneDef
## A long-arc milestone unlock (task 20, FR-20-1). When a permanent threshold is met — a lifetime
## Legacy total and/or a delivered special-loot trophy — the milestone AUTO-UNLOCKS its grants for
## free (stations/gear/archetypes) and announces itself, so the safehouse & arsenal visibly grow over
## many runs. A layer ABOVE the spend-Legacy station buys (task 13); grants should target otherwise-
## gated content so they never conflict. Data-driven & pack-extensible (task 19): a new .tres in
## game/resources/milestones/ (or a pack's milestones/ folder) is a new arc with no code edit.
## Instances in game/resources/milestones/. See docs/tasks/20_progression_milestones.md.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var threshold_legacy: int = 0            ## lifetime Legacy earned to reach this milestone (0 = no Legacy gate)
@export var require_special_loot: StringName = &""  ## stash hook that must be delivered too (&"" = none)
@export var grant_stations: Array[StringName] = []  ## StationDef ids auto-unlocked for free
@export var grant_gear: Array[StringName] = []      ## GearDef ids auto-unlocked for free
@export var grant_archetypes: Array[StringName] = []  ## ArchetypeDef ids (gated by unlock_milestone) that land on the board
@export var reward_legacy: int = 0               ## one-off Legacy bonus granted on reach (0 = none)
@export var order: int = 0                        ## UI ordering on the Live Board
