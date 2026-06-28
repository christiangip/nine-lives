extends Resource
class_name GearDef
## Tool / gadget / weapon / utility definition. Instances in game/resources/gear/.
## See docs/tasks/09_loadout_gear_gadgets.md and GDD §11.

enum Slot { TOOL, BREACH, GADGET, WEAPON, UTILITY, APPAREL }

@export var id: StringName
@export var display_name: String
@export var slot: Slot = Slot.TOOL
@export var consumable: bool = false
@export var research_cost: int = 0         ## Legacy to unlock at Workshop
@export var restock_cost: int = 0          ## Take to restock consumables
@export var params: Dictionary = {}        ## tuning (e.g. {drill_speed: 1.0})
@export var scene: PackedScene
