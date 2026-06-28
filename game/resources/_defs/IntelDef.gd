extends Resource
class_name IntelDef
## Purchasable intel type (reveals modifiers, silent alarms, manifest).
## Instances in game/resources/intel/. See docs/tasks/14_economy_balancing.md.

@export var id: StringName
@export var display_name: String
@export var take_cost: int = 0
@export var reveals: Array[StringName] = []   ## "modifiers","silent_alarms","manifest"
