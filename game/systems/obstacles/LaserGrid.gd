extends Obstacle
class_name LaserGrid
## A laser grid / tripwire (FR-06-6, GDD §9.4). Counter-play: AVOID it (path around), DISABLE it at a
## junction box (a FuseBox on the grid's power zone cuts the beams), REVEAL it with Thief Vision or an
## aerosol so it can be threaded, or EMP it (temporary). Crossing a live beam trips the alarm.
## Beam-crossing detection is an Area3D (node glue); the trip rule + power/EMP/reveal are here.
## Powered device: FuseBox.cut_power in its zone kills the beams (the junction-box solution, FR-06-8).
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-6).

signal tripped

var active: bool = true       ## beams live
var revealed: bool = false    ## made visible by Thief Vision / aerosol (visual only; still live)
var _emp_remaining: float = 0.0

# --- Pure seam (deterministic; unit-tested headless) -----------------------
## Does an actor crossing the plane trip it? Only while the beams are live. Pure.
static func trips(active_beams: bool, crossed: bool) -> bool:
	return active_beams and crossed

# --- Counter-play ----------------------------------------------------------
## Thief Vision / aerosol reveal — visible but still live (task 08 Casing / task 09 aerosol).
func reveal() -> void:
	if not revealed:
		revealed = true
		state_changed.emit()

## EMP gadget (task 09): drop the beams for `seconds`. Temporary.
func emp(seconds: float) -> void:
	active = false
	_emp_remaining = seconds
	state_changed.emit()

## Junction box / fuse cut power → beams off (permanent until power restored).
func set_powered(on: bool) -> void:
	active = on
	state_changed.emit()

## Report a beam crossing (from the Area3D). Trips a (configurable) alarm once while live.
func cross() -> void:
	if trips(active, true):
		tripped.emit()
		_trip_alarm(String(def.params.get("alarm_kind", "loud")) if def != null else "loud")

func _process(delta: float) -> void:
	if _emp_remaining > 0.0:
		_emp_remaining -= delta
		if _emp_remaining <= 0.0:
			active = true
			state_changed.emit()
