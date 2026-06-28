extends Resource
class_name ObjectiveDef
## Objective definition. See docs/tasks/11_mission_generation.md and GDD §7.3.

enum Kind { GRAB, MARK, CRACK, RETRIEVE_DELIVER, SABOTAGE, PUZZLE_ROOM }

@export var id: StringName
@export var kind: Kind = Kind.GRAB
@export var display_name: String
@export var params: Dictionary = {}        ## e.g. {value_target: 50000}
@export var is_bonus: bool = false
@export var notoriety_reward: int = 0
