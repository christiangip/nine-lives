extends Obstacle
class_name FuseBox
## A fuse/power box (FR-06-8, GDD §9.5). Cutting it kills power to every powered device sharing its
## zone — cameras, e-locks, lights, motion sensors — but (a) starts a backup-generator timer that
## restores power after `backup_seconds`, and (b) makes noise that draws a patrol to investigate the
## outage. A "junction box" that kills a laser grid is just a FuseBox authored with the grid's zone.
## Reuses the frozen EventBus (noise_emitted) for the investigate-draw — no new signals.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-8).

var powered_cut: bool = false
var backup_active: bool = false
var backup_remaining: float = 0.0

# --- Pure seam (deterministic; unit-tested headless) -----------------------
## Does a device in `device_zone` belong to this box's `box_zone`? Empty zones never match. Pure.
static func affects(device_zone, box_zone) -> bool:
	var bz := StringName(box_zone)
	if String(bz).is_empty():
		return false
	return StringName(device_zone) == bz

# --- Power cut -------------------------------------------------------------
## Cut power to the zone: disable matching powered devices, arm the backup timer, and ping a noise
## ring so a nearby guard peels off to investigate (task 05 listens on noise_emitted).
func cut_power() -> void:
	if powered_cut or def == null:
		return
	powered_cut = true
	_set_zone_powered(false)
	backup_active = true
	backup_remaining = def.backup_seconds
	var draw: float = def.noise_for(&"power_cut")
	if draw > 0.0:
		EventBus.noise_emitted.emit(global_position, draw, "power")   # investigate-draw
	state_changed.emit()

## Restore power (backup generator kicked in, or re-flipped). Devices decide what re-powering means
## (a camera comes back; an already-opened e-lock stays open).
func restore_power() -> void:
	if not powered_cut:
		return
	powered_cut = false
	backup_active = false
	backup_remaining = 0.0
	_set_zone_powered(true)
	state_changed.emit()

func _set_zone_powered(on: bool) -> void:
	for node in get_tree().get_nodes_in_group(&"powered_device"):
		if node.has_method("set_powered") and FuseBox.affects(node.get(&"power_zone"), def.power_zone):
			node.set_powered(on)

func _process(delta: float) -> void:
	if backup_active:
		backup_remaining -= delta
		if backup_remaining <= 0.0:
			restore_power()

func interact(_by: Node) -> void:
	cut_power()
