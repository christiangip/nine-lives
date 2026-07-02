extends RigidBody3D
class_name ThrownBody
## Physics glue for a thrown Body (mirrors ThrownBag exactly — GDScript can't make one node both
## a RigidBody3D and the Interactable a dragged/settled Body needs to be). PlayerController
## spawns this on the `throw` action while dragging a body, excludes the thrower from its own
## collision (the same self-hit-at-spawn problem ThrownBag has, since it spawns near our own
## capsule), and on the first landing re-deposits the real Body node into the world at rest —
## draggable/interactable again immediately, same as if it had just been put down.
## See docs/tasks/08_loot_inventory.md (FR-08-2/4).

var body: Body        ## the real Body this projectile carries; deposited on landing
var thrower: Node3D    ## excluded from this projectile's own collisions

const _RADIUS: float = 0.35
const _HEIGHT: float = 1.8
const _MESH_COLOR: Color = Color(0.78, 0.18, 0.18, 1.0)   ## matches Body's own placeholder capsule

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	_ensure_collider()
	_ensure_mesh()
	body_entered.connect(_on_body_entered)
	if thrower is CollisionObject3D:
		add_collision_exception_with(thrower)

func _ensure_collider() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = _RADIUS
	capsule.height = _HEIGHT
	shape.shape = capsule
	shape.rotation_degrees.z = 90.0
	add_child(shape)

func _ensure_mesh() -> void:
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _RADIUS
	capsule.height = _HEIGHT
	mesh_inst.mesh = capsule
	mesh_inst.rotation_degrees.z = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _MESH_COLOR
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func launch(from: Vector3, velocity: Vector3) -> void:
	global_position = from
	linear_velocity = velocity

func _on_body_entered(_node: Node) -> void:
	_settle()

## Landed: deposit the real Body back into the world at rest, draggable again via the usual
## interact path. Added to the tree before global_position is set — Node3D's global transform is
## only meaningful once inside the tree (matches ThrownBag._settle()'s ordering).
func _settle() -> void:
	var host := get_parent()
	if host != null and body != null:
		host.add_child(body)
		body.global_position = global_position
		body.set_concealed(false)
	queue_free()
