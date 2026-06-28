extends Resource
class_name PerkDef
## Permanent always-on passive (Legacy Board). Instances in game/resources/perks/.
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.2.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var legacy_cost: int = 0
@export var prerequisites: Array[StringName] = []
@export var modifiers: Dictionary = {}
