extends Resource
class_name IntelDef
## Purchasable intel type (reveals modifiers, silent alarms, manifest).
## Instances in game/resources/intel/. See docs/tasks/14_economy_balancing.md.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var take_cost: int = 0
@export var legacy_cost: int = 0              ## optional Legacy price (Planning Table pays Take and/or Legacy, GDD §6.1)
@export var reveals: Array[StringName] = []   ## "modifiers","silent_alarms","manifest"
