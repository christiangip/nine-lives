extends Resource
class_name EnemyDef
## AI actor archetype. Instances in game/resources/enemies/.
## See docs/tasks/05_ai_actors.md and GDD §8.4.

enum Kind { GUARD, CAMERA, OPERATOR, DOG, CIVILIAN, INSPECTOR, RESPONDER, TACTICAL }

@export var id: StringName
@export var kind: Kind = Kind.GUARD
@export var display_name: String
@export var tier: int = 1                       ## difficulty tier (1 = base); higher = scaled-up (FR-05-9)
@export var vision_angle: float = 90.0
@export var vision_range: float = 14.0
@export var hearing_radius: float = 8.0
@export var health: int = 100
@export var move_speed: float = 2.5
@export var loadout: Array[StringName] = []   ## weapons for cover-shooter pursuit
@export var carried_item: StringName = &""    ## keycard/key id yielded by pickpocket/takedown; the Inspector's must-have gate key (FR-06-3, ↩ from 05)
@export var model: PackedScene                ## optional character art (task 18); collider + detection cone + role tint stay procedural. Realized by MissionController._spawn_guard.
@export var params: Dictionary = {}

## Returns a duplicate scaled by `mult` on the senses/health/speed axes — the data-driven
## difficulty-tier knob (FR-05-9). Pure: leaves this def untouched. `mult > 1` makes a tougher
## actor (wider/longer cones, keener ears, more health, faster). TODO[05].
func scaled(mult: float) -> EnemyDef:
	var out: EnemyDef = duplicate(true)
	out.vision_angle = vision_angle * mult
	out.vision_range = vision_range * mult
	out.hearing_radius = hearing_radius * mult
	out.health = int(round(float(health) * mult))
	out.move_speed = move_speed * mult
	return out
