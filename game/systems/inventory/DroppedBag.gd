extends Interactable
class_name DroppedBag
## A thrown Bag that missed a Drop Point and came to rest — reclaimable exactly like any other
## world pickup (GDD §10.3: "loot is physically picked up"). ThrownBag (the physics glue) swaps
## itself for one of these once it settles: a RigidBody3D can't also be an Interactable
## (GDScript has no multiple inheritance), and the raycast-based interaction system only
## resolves Interactable ancestors, so a settled bag needs its own lightweight pickup
## representation. Interacting hands the same Bag (with its accumulated contents/value) back
## into the picker's Inventory via Inventory.adopt_bag() — the exact reverse of
## release_bag_for_throw(). See docs/tasks/08_loot_inventory.md (FR-08-4).

const _RADIUS: float = 0.18
const _MESH_COLOR: Color = Color(0.55, 0.45, 0.15, 1.0)   ## matches ThrownBag's in-flight color

var bag: Bag
var _consumed: bool = false   ## mirrors LootPickup._consumed: reclaimed once, never twice

func _ready() -> void:
	prompt = "Pick Up Bag"
	_ensure_collider()
	_ensure_mesh()

func _ensure_collider() -> void:
	if has_node("Col"):
		return
	var col := StaticBody3D.new()
	col.name = "Col"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _RADIUS
	shape.shape = sphere
	col.add_child(shape)
	add_child(col)

func _ensure_mesh() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			return
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _RADIUS
	sphere.height = _RADIUS * 2.0
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _MESH_COLOR
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func can_interact(by: Node) -> bool:
	if _consumed:
		return false
	var inv = by.get("inventory") if by != null else null
	return inv != null and bag != null

## Hands the Bag back to the picker. queue_free() is deferred, so this node can still be interacted
## with for the rest of the frame — the _consumed latch (and dropping the Bag reference) is what
## makes a reclaim strictly once-only.
func interact(by: Node) -> void:
	if _consumed:
		return
	var inv = by.get("inventory") if by != null else null
	if inv == null or bag == null:
		return
	if inv.adopt_bag(bag):
		_consumed = true
		bag = null
		EventBus.carry_changed.emit(inv.current_weight(), inv.current_volume())
		queue_free()
