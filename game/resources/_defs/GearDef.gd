extends Resource
class_name GearDef
## Tool / gadget / weapon / utility definition. Instances in game/resources/gear/.
## See docs/tasks/09_loadout_gear_gadgets.md and GDD §11.

enum Slot { TOOL, BREACH, GADGET, WEAPON, UTILITY, APPAREL }

@export var id: StringName
@export var display_name: String
@export var slot: Slot = Slot.TOOL
@export var tier: int = 1                   ## upgrade tier; higher = better params (data-driven, no id branch)
@export var slot_cost: int = 1             ## capacity units consumed in its slot (Armory limits, FR-09-1)
@export var consumable: bool = false
@export var research_cost: int = 0         ## Legacy to unlock at Workshop (FR-09-4; research gating)
@export var restock_cost: int = 0          ## Take to restock ONE unit of a consumable (FR-09-6)
@export var max_count: int = 0             ## consumable stack cap (0 = non-consumable / no cap)
@export var params: Dictionary = {}        ## tuning (weapon/armor/tool specifics; e.g. {drill_speed: 1.0})
@export var scene: PackedScene

## A gadget "flag" id the minigame layer / obstacles query (e.g. &"stethoscope", &"glasscutter").
## Defaults to the gear id, so a piece of gear advertises itself by id unless params override it. Pure.
func gadget_flag() -> StringName:
	return StringName(params.get("gadget_flag", id))

## Tunable read from params with a fallback (keeps behaviour magic-number-free). Pure.
func param(key: StringName, fallback: Variant) -> Variant:
	return params.get(String(key), fallback)
