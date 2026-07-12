extends MeshInstance3D
class_name DetectionConeDebug
## Dev-only readability aid: draws a flat translucent wedge for a DetectionSensor's cone,
## tinted by detection state (green→yellow→orange→red) and brightened by the fill meter.
## No gameplay logic — the real HUD (directional eye, cone-fill, noise ring) is task 15.
## Attach as a child of a DetectionSensor (or set sensor_path). See docs/tasks/04_stealth_detection.md.

@export var sensor_path: NodePath
@export var segments: int = 20
@export var ground_y: float = 0.05   ## lift off the floor to avoid z-fighting

var _sensor: DetectionSensor
var _im: ImmediateMesh
var _mat: StandardMaterial3D

func _ready() -> void:
	_sensor = get_node_or_null(sensor_path) as DetectionSensor
	if _sensor == null:
		_sensor = get_parent() as DetectionSensor
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat

func _process(_delta: float) -> void:
	if _sensor == null:
		return
	var half := deg_to_rad(_sensor.cone_angle_deg() * 0.5)
	var r := _sensor.cone_range()
	var col := _state_color(_sensor.state)
	col.a = 0.12 + 0.33 * clampf(_sensor.fill, 0.0, 1.0)
	_mat.albedo_color = col

	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 := lerpf(-half, half, float(i) / float(segments))
		var a1 := lerpf(-half, half, float(i + 1) / float(segments))
		_im.surface_add_vertex(Vector3(0, ground_y, 0))
		_im.surface_add_vertex(_edge(a0, r))
		_im.surface_add_vertex(_edge(a1, r))
	_im.surface_end()

func _edge(angle: float, r: float) -> Vector3:
	# angle 0 points along local -Z (Node3D forward).
	return Vector3(sin(angle) * r, ground_y, -cos(angle) * r)

func _state_color(state: int) -> Color:
	match state:
		DetectionSensor.DetectionState.SUSPICIOUS: return Color(0.95, 0.85, 0.2)
		DetectionSensor.DetectionState.SEARCHING: return Color(0.98, 0.55, 0.1)
		DetectionSensor.DetectionState.ALERTED: return Color(0.95, 0.15, 0.15)
		_: return Color(0.2, 0.85, 0.35)
