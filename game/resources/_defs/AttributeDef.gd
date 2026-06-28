extends Resource
class_name AttributeDef
## Trainable player attribute. Instances in game/resources/attributes/.
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.5.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var max_level: int = 10
@export var cost_curve: Array[int] = []    ## Legacy cost per level
@export var effect_per_level: float = 0.0
