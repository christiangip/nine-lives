extends Resource
class_name ArchetypeDef
## Location archetype (Bank, Museum, Mansion, Casino, Lab, Warehouse).
## Instances in game/resources/archetypes/. See docs/tasks/11_mission_generation.md.

@export var id: StringName
@export var display_name: String
@export var section_pool: Array[PackedScene] = []   ## allowed prefab sections
@export var setpieces: Array[PackedScene] = []      ## marquee handcrafted rooms
@export var loot_table: Array[LootDef] = []
@export var security_flavor: Dictionary = {}        ## camera/laser/lock density bias
@export var min_sections: int = 4
@export var max_sections: int = 9
