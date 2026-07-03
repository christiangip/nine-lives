## Reusable prop prefab base (task 18 / phase-1-art Tier 2). A StaticBody3D that
## wraps a chosen kit model and auto-fits a box collider to the model's bounds, so
## a raw mesh becomes a game-ready "part" with collision — scale/pivot already
## baked by the per-kit import pass. @tool so the collider previews in-editor.
## Behaviour props (obstacles, loot) can extend this later; def wiring (spawn via
## SectionDef/ObstacleDef.scene in MissionController) is task 11. Not shipped as-is.
@tool
class_name PropPrefab
extends StaticBody3D

## Rebuild the fitted collider in-editor when toggled (tool convenience).
@export var rebuild_collider: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_fit_collider()

const COLLIDER_NAME := "Collider"

func _ready() -> void:
	if get_node_or_null(COLLIDER_NAME) == null:
		_fit_collider()

## Sits the model on a base-centred pivot (origin = floor centre) and fits a
## BoxShape3D collider to it, so the prefab drops straight onto a floor.
func _fit_collider() -> void:
	var existing := get_node_or_null(COLLIDER_NAME)
	if existing != null:
		existing.free()
	var aabb := _model_aabb()
	if aabb.size == Vector3.ZERO:
		return

	# Recentre the model so its base sits on y=0, centred on x/z.
	var offset := Vector3(aabb.position.x + aabb.size.x * 0.5, aabb.position.y, aabb.position.z + aabb.size.z * 0.5)
	for child in get_children():
		if child is Node3D:
			(child as Node3D).position -= offset

	var shape := BoxShape3D.new()
	shape.size = aabb.size
	var col := CollisionShape3D.new()
	col.name = COLLIDER_NAME
	col.shape = shape
	col.position = Vector3(0.0, aabb.size.y * 0.5, 0.0)
	add_child(col)
	if Engine.is_editor_hint():
		col.owner = get_tree().edited_scene_root

## Merged AABB (metres) of every MeshInstance3D under this prefab, in this node's
## local space. Uses the local-transform chain (not global_transform) so it is
## correct even before the scene tree has propagated transforms (e.g. at _ready).
func _model_aabb() -> AABB:
	var acc := AABB()
	var seeded := false
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var world: AABB = _relative_to_self(m) * m.mesh.get_aabb()
		if not seeded:
			acc = world
			seeded = true
		else:
			acc = acc.merge(world)
	return acc

## Transform of `node` relative to this prefab, from local transforms up the chain.
func _relative_to_self(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != self:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
