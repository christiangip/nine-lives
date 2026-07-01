extends Obstacle
class_name ControllableLight
## A switchable/shootable light (FR-06-8, GDD §9.5). Killing it expands the shadow the player hides in,
## feeding task-04 light sampling. SWITCH is silent; SHOOT (task 10 weapon) is instant but loud. Cutting
## the zone's power (FuseBox) also drops it. When dark, its shadow Area3D joins the &"shadow" group that
## DetectionSensor samples, so detection actually eases there.
## The light node + a `Shadow` Area3D child are wired in the scene; this toggles them.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-8).

@export var light_path: NodePath          ## the Light3D to toggle
@export var shadow_path: NodePath         ## an Area3D added to group &"shadow" while dark (task 04)

var lit: bool = true

func _ready() -> void:
	super._ready()
	_apply()

# --- Control ---------------------------------------------------------------
func switch_off() -> void:
	_set_lit(false, &"switch")   # silent

func switch_on() -> void:
	_set_lit(true, &"switch")

## Shot out by a firearm (task 10) — instant + loud.
func shoot() -> void:
	if lit:
		_set_lit(false, &"shoot")
		_emit_noise_for(&"shoot")

func set_powered(on: bool) -> void:
	_set_lit(on, &"switch")

func _set_lit(value: bool, _method: StringName) -> void:
	if lit == value:
		return
	lit = value
	_apply()
	state_changed.emit()

## Expanding shadow = the light's shadow area registers with the group task 04 samples.
func _apply() -> void:
	var light := get_node_or_null(light_path)
	if light != null:
		light.visible = lit
	var shadow := get_node_or_null(shadow_path)
	if shadow != null:
		if lit:
			shadow.remove_from_group(&"shadow")
		elif not shadow.is_in_group(&"shadow"):
			shadow.add_to_group(&"shadow")

func can_interact(_by: Node) -> bool:
	return lit   # something to switch off

func interact(_by: Node) -> void:
	switch_off()
