extends Obstacle
class_name MotionSensor
## A motion sensor (FR-06-6, GDD §9.4). Trips on FAST movement, so you slip under it by moving slow
## (crouch/prone), or disable it (interact) or cut its zone's power. Powered device.
## Beam volume is an Area3D (node glue); the speed rule + power are here.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-6).

signal tripped

var active: bool = true

## Trips only while active and the intruder moves faster than the threshold. Pure.
static func trips(active_sensor: bool, speed: float, threshold: float) -> bool:
	return active_sensor and speed > threshold

func set_powered(on: bool) -> void:
	active = on
	state_changed.emit()

## Disable by interacting directly (FR-06-6).
func interact(_by: Node) -> void:
	active = false
	state_changed.emit()

## Report an intruder's speed inside the volume (from the Area3D).
func report_motion(speed: float) -> void:
	var threshold: float = float(def.params.get("speed_threshold", 1.5)) if def != null else 1.5
	if trips(active, speed, threshold):
		tripped.emit()
		_trip_alarm(String(def.params.get("alarm_kind", "silent")) if def != null else "silent")
