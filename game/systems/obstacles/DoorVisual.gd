class_name DoorVisual
extends Node3D
## Opens a door spawn's leaf when its Obstacle solves (misc-fixes-2 issues 5–7): the leaf SWINGS on a
## hinge (lockpick), SLIDES into the wall (keycard/clone/hack/found_code/power_cut — and any unmapped
## future method, so a door never stays shut on a solve), or SHATTERS into falling chunks (drill/
## thermite/c4). Every path clears the leaf's collision so the player walks through; the static
## jamb+lintel frame built by MissionController stays. Driven by the existing local
## `Obstacle.obstacle_solved(by_method)` signal (single-shot by construction) — EventBus stays frozen.
## The animation maths are pure static seams (headless-tested); only the Tween/physics glue touches
## nodes. Node layout after adopt(): DoorVisual → Hinge (-w/2) → leaf (+w/2), net leaf transform
## unchanged while closed. See misc-fixes-2.md.

# Presentation constants (greybox house pattern — cf. SectionShell's dims).
const SLIDE_SECONDS := 0.6
const SWING_SECONDS := 0.7
const SHATTER_COUNT := 8
const SHATTER_LIFETIME := 5.0   ## chunks free themselves after this (perf)
const SHATTER_IMPULSE := 2.5
const SHATTER_THICKNESS := 0.08

var leaf: Node3D = null
var leaf_width: float = 1.0
var leaf_height: float = 2.0

var _hinge: Node3D = null
var _opened := false

## Reparent `door_leaf` (the instanced PropPrefab, already in the tree with its fitted Collider) under
## an internal Hinge pivot at the leaf's edge, so swing rotates about the edge and slide/shatter work in
## the same local space. Safe: PropPrefab fits its collider once in its own _ready.
func adopt(door_leaf: Node3D, width: float, height: float) -> void:
	leaf = door_leaf
	leaf_width = maxf(0.05, width)
	leaf_height = maxf(0.05, height)
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-leaf_width * 0.5, 0.0, 0.0)
	add_child(_hinge)
	var old_parent := door_leaf.get_parent()
	if old_parent != null:
		old_parent.remove_child(door_leaf)
	door_leaf.position = Vector3(leaf_width * 0.5, 0.0, 0.0)
	_hinge.add_child(door_leaf)

# --- Pure static seams (headless-tested, no Tween) ---------------------------
## Which animation a solve method plays. Anything unmapped SLIDES — the door is a real barrier now, so
## a future method must still open it. (`alt_route` never reaches _mark_solved — generator concept.)
static func animation_for(method: StringName) -> StringName:
	match method:
		&"lockpick":
			return &"swing"
		&"drill", &"thermite", &"c4":
			return &"shatter"
		_:
			return &"slide"

## Local translation that hides the leaf into the wall beside the opening.
static func slide_offset(width: float) -> Vector3:
	return Vector3(width, 0.0, 0.0)

## Hinge rotation for a fully swung-open leaf.
static func swing_angle() -> float:
	return PI * 0.5

## Local {pos, size} boxes tiling a width×height leaf into `count` fracture chunks (2-column grid),
## positions in the leaf's closed local space (x centred on the opening, y up from the floor).
static func shatter_pieces(width: float, height: float, count: int) -> Array:
	var out: Array = []
	var n := maxi(1, count)
	var cols := mini(2, n)
	var rows := int(ceil(float(n) / float(cols)))
	var piece := Vector3(width / float(cols), height / float(rows), SHATTER_THICKNESS)
	for i in n:
		var col := i % cols
		var row := int(floor(float(i) / float(cols)))
		var x := (float(col) + 0.5) * piece.x - width * 0.5
		var y := (float(row) + 0.5) * piece.y
		out.append({"pos": Vector3(x, y, 0.0), "size": piece})
	return out

# --- Glue (Tween / physics) ---------------------------------------------------
## Single-shot: play the animation for `method` and clear the leaf's collision so the player can pass.
## Connected to Obstacle.obstacle_solved by MissionController for door spawns.
func open(method: StringName) -> void:
	if _opened or leaf == null:
		return
	_opened = true
	_clear_collision()
	match animation_for(method):
		&"swing":
			_swing_open()
		&"shatter":
			_shatter()
		_:
			_slide_open()

## Disable the prop's fitted Collider AND zero the body's layers (belt-and-suspenders — either alone
## clears movement + the interaction ray; the obstacle is solved so it no longer needs ray hits).
func _clear_collision() -> void:
	var col := leaf.get_node_or_null("Collider")
	if col is CollisionShape3D:
		(col as CollisionShape3D).set_deferred("disabled", true)
	if leaf is CollisionObject3D:
		(leaf as CollisionObject3D).set_deferred("collision_layer", 0)
		(leaf as CollisionObject3D).set_deferred("collision_mask", 0)

func _slide_open() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(leaf, "position", leaf.position + slide_offset(leaf_width), SLIDE_SECONDS)

func _swing_open() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_hinge, "rotation:y", swing_angle(), SWING_SECONDS)

## Hide the leaf and spawn falling RigidBody3D chunks with an outward+downward impulse. No flashes —
## reduce-flashing has no bearing here.
func _shatter() -> void:
	leaf.visible = false
	var pieces := shatter_pieces(leaf_width, leaf_height, SHATTER_COUNT)
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var chunk := RigidBody3D.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p["size"]
		mi.mesh = bm
		mi.material_override = Palette.material(&"metal")
		chunk.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = p["size"]
		cs.shape = bs
		chunk.add_child(cs)
		chunk.position = p["pos"]
		add_child(chunk)
		var side := 1.0 if (i % 2) == 0 else -1.0
		var scatter := global_transform.basis.x * (float(i % 3) - 1.0) * 0.3
		var dir := (global_transform.basis.z * side + Vector3(0, -0.4, 0) + scatter).normalized()
		chunk.apply_impulse(dir * SHATTER_IMPULSE)
		get_tree().create_timer(SHATTER_LIFETIME).timeout.connect(chunk.queue_free)
