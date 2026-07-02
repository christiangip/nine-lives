extends Resource
class_name ArchetypeDef
## Location archetype (Bank, Museum, Mansion, Casino, Lab, Warehouse).
## Instances in game/resources/archetypes/. See docs/tasks/11_mission_generation.md.

@export var id: StringName
@export var display_name: String
@export var section_pool: Array[PackedScene] = []   ## allowed prefab sections (direct scene refs; optional)
@export var setpieces: Array[PackedScene] = []      ## marquee handcrafted rooms (direct scene refs; optional)
@export var loot_table: Array[LootDef] = []
@export var security_flavor: Dictionary = {}        ## camera/laser/lock density bias
@export var min_sections: int = 4
@export var max_sections: int = 9

## Id-reference pools the generator (task 11) resolves via the Content registries — the house
## "content by id" idiom (matches EnemyDef.loadout, ObstacleDef.required_item, and
## ContentRegistry._hydrate's "resolved later" note). Authorable in a .tres or data/*.json without
## embedding Resource sub-references. See docs/tasks/11_mission_generation.md.
@export var section_ids: Array[StringName] = []     ## SectionDef ids (Content.sections) to stitch
@export var setpiece_ids: Array[StringName] = []    ## marquee OBJECTIVE/SETPIECE section ids
@export var objective_ids: Array[StringName] = []   ## ObjectiveDef ids valid for this archetype
@export var modifier_pool: Array[StringName] = []   ## ModifierDef ids that can roll on this archetype
@export var enemy_roster: Array[StringName] = []    ## EnemyDef ids populated as patrols/guards
@export var loot_ids: Array[StringName] = []        ## LootDef ids scattered at loot anchors
