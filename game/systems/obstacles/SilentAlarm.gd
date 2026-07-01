extends Obstacle
class_name SilentAlarm
## A silent alarm (FR-06-7, GDD §9.4). Invisible in the world: crossing its trigger summons police (a
## "silent" alarm, not just local guards). It is revealed by buying Intel (task 13) or by careful
## Casing with high Perception (task 08) — otherwise it rewards exploration. Counter-play once known:
## avoid it, disarm the linked panel (hack), or cut the zone's power. Powered device.
## The trigger volume is an Area3D (node glue); the reveal + trip rules are here.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-7).

signal tripped

var armed: bool = true
var revealed: bool = false   ## surfaced by Intel (13) / Casing Perception (08)

## Is the alarm visible to the player? Intel-marked, or Perception clears the reveal threshold. Pure.
static func detectable(perception_level: float, threshold: float, intel_marked: bool) -> bool:
	return intel_marked or perception_level >= threshold

## Reveal it (Intel purchase or Casing). TODO[13]: Intel drives this at contract launch.
func reveal() -> void:
	if not revealed:
		revealed = true
		state_changed.emit()

## Cutting power or disarming the panel takes it offline.
func set_powered(on: bool) -> void:
	armed = on
	state_changed.emit()

func disarm() -> void:
	armed = false
	state_changed.emit()

## Report an intruder crossing the (invisible) trigger.
func cross() -> void:
	if armed:
		tripped.emit()
		_trip_alarm("silent")   # summons police (GDD §9.4)
