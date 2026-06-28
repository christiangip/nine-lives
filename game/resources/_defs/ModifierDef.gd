extends Resource
class_name ModifierDef
## Contract modifier (e.g. "extra patrols","blackout","silent-alarm heavy").
## Instances in game/resources/modifiers/. See docs/tasks/14_economy_balancing.md.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var difficulty_delta: int = 0
@export var reward_multiplier: float = 1.0
@export var effects: Dictionary = {}
