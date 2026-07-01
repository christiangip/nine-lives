extends Obstacle
class_name PressurePlate
## A pressure plate (FR-06-6, GDD §9.4). Counter-play: AVOID it (step over / route around), WEIGH IT
## DOWN with a placed/thrown object so stepping off won't spring it, or DISABLE it. Passive trap.
## The trigger volume is an Area3D (node glue); the trip rule is here.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-6).

signal tripped

var armed: bool = true
var neutralized: bool = false   ## a counterweight object is holding it down (weigh-down solution)

## Trips only while armed, stepped on, and not held down by a counterweight. Pure.
static func trips(armed_plate: bool, stepped: bool, is_neutralized: bool) -> bool:
	return armed_plate and stepped and not is_neutralized

func weigh_down() -> void:
	neutralized = true
	state_changed.emit()

func interact(_by: Node) -> void:
	armed = false   # disabled
	state_changed.emit()

func step(pressed: bool) -> void:
	if trips(armed, pressed, neutralized):
		tripped.emit()
		_trip_alarm(String(def.params.get("alarm_kind", "silent")) if def != null else "silent")
