extends Node3D
class_name LightFixture
## A ceiling light fixture (world-gen Phase 1C). Casts a real OmniLight pool + shows an emissive housing,
## and registers in group &"lit" so DetectionSensor can read it: a point is EXPOSED only inside a fixture's
## pool, SHADOWED everywhere else (see DetectionSensor._sample_light_level). Turning it off (dev blackout,
## a FuseBox power cut, or a ControllableLight) removes the pool → the area goes dark → detection eases.
## Pure presentation + a geometric pool test — no autoload deps. See world-gen-fixes.md (Phase 1C).

@export var radius: float = 5.0        ## horizontal pool radius (m) — the exposed disc under the fixture
@export var energy: float = 2.6        ## OmniLight energy
@export var mount_height: float = 3.2  ## light height above the fixture origin (just under the ceiling)
@export var cast_shadow: bool = true
@export var color: Color = Color(1.0, 0.96, 0.86)
@export var on: bool = true

var _light: OmniLight3D
var _housing: MeshInstance3D
var _emit_energy: float = 1.6

func _ready() -> void:
	_build()
	add_to_group(&"lit")
	set_on(on)

func _build() -> void:
	_light = OmniLight3D.new()
	_light.omni_range = radius * 1.7
	_light.light_energy = energy
	_light.light_color = color
	_light.shadow_enabled = cast_shadow
	_light.position = Vector3(0, mount_height, 0)
	add_child(_light)
	_housing = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.18, 0.8)
	_housing.mesh = bm
	_housing.position = Vector3(0, mount_height + 0.15, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = _emit_energy
	_housing.material_override = m
	add_child(_housing)

## Toggle the fixture (light + emissive housing + its detection pool via `on`, read by lights_point).
func set_on(value: bool) -> void:
	on = value
	if _light != null:
		_light.visible = value
	if _housing != null and _housing.material_override is StandardMaterial3D:
		(_housing.material_override as StandardMaterial3D).emission_energy_multiplier = _emit_energy if value else 0.0

func toggle() -> void:
	set_on(not on)

## FuseBox power contract — a fixture on a cut zone goes dark like any powered device.
func set_powered(powered: bool) -> void:
	set_on(powered)

## Does this fixture light `pos`? Only when on and within the horizontal pool radius (height ignored, so a
## crouched/prone or tall target under the pool still reads as exposed). Pure geometry — unit-tested.
func lights_point(pos: Vector3) -> bool:
	if not on:
		return false
	var here := global_position
	return Vector2(pos.x - here.x, pos.z - here.z).length() <= radius
