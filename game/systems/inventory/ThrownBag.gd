extends RigidBody3D
class_name ThrownBag
## Physics glue for a thrown Bag (FR-08-4): PlayerController spawns this on the `throw` action
## and gives it an initial velocity toward the aim point; gravity does the rest of the arc.
## Excludes `thrower` from its own collisions (it spawns close to the player's own capsule and
## would otherwise register an immediate self-hit and settle before ever leaving the throw). On
## the first real collision it either lands inside a DropPoint — banking via the exact same
## DropPoint.receive_bag() a headless test calls directly, so no physics simulation is needed to
## unit-test "landing in a Drop Point banks its value" — or settles by swapping itself for a
## reclaimable DroppedBag (a RigidBody3D can't also be the Interactable the raycast-based
## interaction system resolves, so a settled bag needs its own lightweight pickup).
## This node is pure glue: no gameplay math lives here (see Inventory.throw_distance() for that).
## See docs/tasks/08_loot_inventory.md (FR-08-4).

var bag: Bag
var thrower_inventory: Inventory
var thrower: Node3D   ## excluded from this projectile's own collisions (avoid a self-hit at spawn)

const _RADIUS: float = 0.18
const _MESH_COLOR: Color = Color(0.55, 0.45, 0.15, 1.0)

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
	var sphere := SphereShape3D.new()
	sphere.radius = _RADIUS
	shape.shape = sphere
	add_child(shape)

func _ensure_mesh() -> void:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _RADIUS
	sphere.height = _RADIUS * 2.0
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _MESH_COLOR
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func launch(from: Vector3, velocity: Vector3) -> void:
	global_position = from
	linear_velocity = velocity

func _on_body_entered(node: Node) -> void:
	var drop := _find_drop_point(node)
	if drop != null:
		drop.receive_bag(bag, thrower_inventory)
		queue_free()
		return
	_settle()

## Landed on plain geometry: swap this physics projectile for a reclaimable DroppedBag pickup at
## the same spot. Added to the tree before its global_position is set (Node3D's global transform
## is only meaningful once inside the tree).
func _settle() -> void:
	var dropped := DroppedBag.new()
	dropped.bag = bag
	var host := get_parent()
	if host != null:
		host.add_child(dropped)
		dropped.global_position = global_position
	queue_free()

func _find_drop_point(node: Node) -> DropPoint:
	var n := node
	while n != null:
		if n is DropPoint:
			return n as DropPoint
		n = n.get_parent()
	return null
