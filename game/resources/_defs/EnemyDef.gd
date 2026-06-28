extends Resource
class_name EnemyDef
## AI actor archetype. Instances in game/resources/enemies/.
## See docs/tasks/05_ai_actors.md and GDD §8.4.

enum Kind { GUARD, CAMERA, OPERATOR, DOG, CIVILIAN, INSPECTOR, RESPONDER, TACTICAL }

@export var id: StringName
@export var kind: Kind = Kind.GUARD
@export var display_name: String
@export var vision_angle: float = 90.0
@export var vision_range: float = 14.0
@export var hearing_radius: float = 8.0
@export var health: int = 100
@export var move_speed: float = 2.5
@export var loadout: Array[StringName] = []   ## weapons for cover-shooter pursuit
@export var params: Dictionary = {}
