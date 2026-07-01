extends Interactable
class_name Body
## A downed/dead guard left in the world. Discoverable: a patrolling guard that sees an
## un-concealed body (in its cone, clear LoS) raises the alarm and starts searching (GDD §8.5,
## FR-05-2). A Body is a heavy two-handed haul (GDD §10.1): dragging one occupies both hand
## slots (Inventory.pick_up_body / BODY_HAND_SLOTS) and conceals it in transit; putting it down
## restores its default (undiscoverable-unless-un-concealed) state. Also carries whatever item
## its EnemyDef granted (GuardAI._spawn_body copies def.carried_item here) — the exact id
## BiometricLock's is_carrying_keyholder() and KeycardDoor's actor_has_item() gate on once
## dragged (↩ from 05, closes TODO[08]).
## Extends Interactable (not bare Node3D) so the player's interaction raycast resolves it via the
## same parent-walk every obstacle uses. A runtime-spawned Body (GuardAI._spawn_body's bare
## Body.new()) has no scene-authored collider/mesh, so _ready() builds a minimal placeholder of
## each procedurally — the collider always (required for the interact ray to ever hit it), the
## mesh only if a scene author hasn't already placed one (so a hand-authored greybox instance's
## own mesh sibling is left untouched).
## Joins group &"body" so guards can scan for it. See docs/tasks/05_ai_actors.md (Phase 05.1)
## and docs/tasks/08_loot_inventory.md.

const _CAPSULE_RADIUS: float = 0.35
const _CAPSULE_HEIGHT: float = 1.8
const _MESH_COLOR: Color = Color(0.78, 0.18, 0.18, 1.0)   ## matches GuardGreybox.tscn's hand-authored Body0

@export var concealed: bool = false   ## hidden in cover/container → not discoverable
@export var lethal: bool = false      ## killed (vs choked out) — leaves blood; louder alarm later
@export var carried_item: StringName = &""   ## keycard/key id yielded on pickup; set by GuardAI._spawn_body

var discovered: bool = false          ## latched once a guard has raised the alarm on it

func _ready() -> void:
	add_to_group(&"body")
	prompt = "Drag Body"
	_ensure_collider()
	_ensure_mesh()

func _ensure_collider() -> void:
	if has_node("Col"):
		return
	var col := StaticBody3D.new()
	col.name = "Col"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = _CAPSULE_RADIUS
	capsule.height = _CAPSULE_HEIGHT
	shape.shape = capsule
	shape.rotation_degrees.z = 90.0   ## lying flat, matching the mesh orientation
	col.add_child(shape)
	add_child(col)

func _ensure_mesh() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			return   ## a scene author already placed one (e.g. GuardGreybox.tscn's Body0Mesh)
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = _CAPSULE_RADIUS
	capsule.height = _CAPSULE_HEIGHT
	mesh_inst.mesh = capsule
	mesh_inst.rotation_degrees.z = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _MESH_COLOR
	mesh_inst.material_override = mat
	add_child(mesh_inst)

## Drag/hide hook. Called both on pickup/putdown (below) and for a manual conceal-in-place
## (e.g. stuffing a body into cover without carrying it — a future level-design hook).
func set_concealed(value: bool) -> void:
	concealed = value

# --- FR-08 carry (↩ from 05, closes TODO[08]) -------------------------------

func can_interact(by: Node) -> bool:
	var inv = by.get("inventory") if by != null else null
	return inv != null and not inv.is_carrying_body()

## Picking up a Body hands it to the carrier's Inventory (which also grants carried_item —
## "the Inspector keycard pickup") and detaches it from the world; PlayerController re-parents
## it on put-down (drop_loot action). Concealed while carried so it isn't independently
## discoverable in transit.
func interact(by: Node) -> void:
	var inv = by.get("inventory") if by != null else null
	if inv == null or not inv.pick_up_body(self):
		return
	set_concealed(true)
	if get_parent() != null:
		get_parent().remove_child(self)

## Pure: should an observing guard raise the alarm on this body? Only an un-concealed body that
## is inside the guard's cone with a clear line of sight is discoverable.
static func raises_alarm(is_concealed: bool, in_cone: bool, has_los: bool) -> bool:
	return not is_concealed and in_cone and has_los

## Called by a guard that has spotted this body. Latches so the alarm fires once; raises a
## (silent) local alarm and announces the discovery for nearby guards to converge.
func discover() -> void:
	if discovered or concealed:
		return
	discovered = true
	EventBus.body_discovered.emit(global_position)
	EventBus.alarm_tripped.emit("silent", global_position)
