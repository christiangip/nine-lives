@tool
class_name SectionShell
extends Node3D
## A real, master-materialed section shell for the M2 Bank slice (task 18, FR-18-7). Instanced by
## MissionController via SectionDef.scene at ps.center_world(CELL) — its local origin is the section
## centre. Builds a floor pad, corner pillars and edge walls that leave a central doorway on EVERY
## edge, so it never blocks the generator's socket connections whatever orientation assembly picks
## (the de-risked shell — full sealed rooms live in the hand-aligned bank_test.tscn showcase). Decor
## is sparse + wall-hugging so it doesn't clutter the gameplay obstacles/loot the generator spawns on
## top. Built in code (the greybox house pattern) and read its dims from `footprint` (set by the
## realizer from the def). @tool so it previews in-editor. See docs/tasks/18_art_asset_pipeline.md.

const CELL := 6.0        ## metres per grid cell — mirrors MissionLayout.CELL_SIZE (kept local: no missiongen dep)
const WALL_H := 3.4
const WALL_T := 0.3
const DOOR_W := 3.4      ## central doorway left open on each edge (≥ the mission's connective gap)
const PILLAR := 0.6
const DECOR_INSET := 1.3 ## how far wall-hugging decor sits inside a wall

## Footprint in grid cells (the realizer sets this from SectionDef.footprint; the .tscn default matches its def).
@export var footprint: Vector2i = Vector2i(2, 2)
## Which edges get a central doorway: &"north"(+Z) / &"south"(-Z) / &"east"(+X) / &"west"(-X). The realizer
## sets this to the sides facing graph-neighbours so the room seals on its outward walls (world-gen Phase 1B).
## EMPTY = all four open (back-compat for hand-authored showcase scenes that predate this).
@export var open_sides: Array[StringName] = []
## Positioned doorways (world-gen Phase 2): each {side:StringName, offset:float} cuts a DOOR_W opening at
## `offset` metres along that edge from its centre, so a doorway lines up with its neighbour's instead of
## always centring on the room's own face (the Phase-1 lock-out). NON-EMPTY takes precedence over
## `open_sides`; a side may carry several doors. The realizer derives these from MissionGeometry.connect().
@export var doors: Array[Dictionary] = []
## Dressing preset: &"vault" / &"lobby" / &"office" / &"dock" / &"generic" — chooses wall material + decor.
@export var dressing: StringName = &"generic"
## Editor convenience: toggle to rebuild the preview.
@export var rebuild: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_build()

const _CABINET := preload("res://game/prefabs/props/cabinet.tscn")
const _SERVER := preload("res://game/prefabs/props/server_rack.tscn")
const _TELLER := preload("res://game/prefabs/props/teller_counter.tscn")
const _CRATE := preload("res://game/prefabs/props/crate.tscn")

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.free()
	var fx: int = maxi(1, footprint.x)
	var fz: int = maxi(1, footprint.y)
	var half := Vector3(float(fx) * CELL * 0.5, 0.0, float(fz) * CELL * 0.5)
	_build_floor(half)
	_build_ceiling(half)
	_build_pillars(half)
	_build_edge(&"north", Vector3(0, 0, half.z), Vector3(1, 0, 0), float(fx) * CELL, _door_offsets_for(&"north"))
	_build_edge(&"south", Vector3(0, 0, -half.z), Vector3(1, 0, 0), float(fx) * CELL, _door_offsets_for(&"south"))
	_build_edge(&"east", Vector3(half.x, 0, 0), Vector3(0, 0, 1), float(fz) * CELL, _door_offsets_for(&"east"))
	_build_edge(&"west", Vector3(-half.x, 0, 0), Vector3(0, 0, 1), float(fz) * CELL, _door_offsets_for(&"west"))
	_dress(half)

func _build_floor(half: Vector3) -> void:
	_box(Vector3(0, -0.1, 0), Vector3(half.x * 2.0 - 0.4, 0.2, half.z * 2.0 - 0.4), &"floor")

## A ceiling caps the room so the exterior sun no longer floods it — interiors go dark and the light
## fixtures (world-gen Phase 1C) create the lit pools stealth reads. Sits just above the wall tops.
func _build_ceiling(half: Vector3) -> void:
	_box(Vector3(0, WALL_H + 0.1, 0), Vector3(half.x * 2.0 - 0.4, 0.2, half.z * 2.0 - 0.4), &"trim")

func _build_pillars(half: Vector3) -> void:
	var m: StringName = &"metal" if dressing == &"vault" else &"trim"
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (half.x - PILLAR * 0.5), WALL_H * 0.5, sz * (half.z - PILLAR * 0.5))
			_box(p, Vector3(PILLAR, WALL_H, PILLAR), m)

## One wall along an edge, with a DOOR_W opening at each offset in `offsets` (metres along the edge from
## its centre) and solid wall filling the rest — so several positioned doorways can share a side and each
## lines up with its neighbour (world-gen Phase 2). No offsets → a solid full-length wall (sealed outward
## face). `edge` is the edge-centre (local), `along` a unit direction, `length` the edge length.
func _build_edge(side: StringName, edge: Vector3, along: Vector3, length: float, offsets: Array) -> void:
	var mat: StringName = _wall_material()
	var half_len := length * 0.5
	if offsets.is_empty():
		var solid := Vector3(length, WALL_H, WALL_T) if along.x > 0.5 else Vector3(WALL_T, WALL_H, length)
		_box(edge + Vector3(0, WALL_H * 0.5, 0), solid, mat)
		return
	# Merge the door openings, then wall the gaps between/around them.
	var openings: Array = []
	for o in offsets:
		var oc: float = clampf(float(o), -half_len, half_len)
		openings.append([maxf(-half_len, oc - DOOR_W * 0.5), minf(half_len, oc + DOOR_W * 0.5)])
	openings.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var cursor := -half_len
	for op in openings:
		if float(op[0]) > cursor + 0.01:
			_wall_segment(edge, along, cursor, float(op[0]), mat)
		cursor = maxf(cursor, float(op[1]))
	if cursor < half_len - 0.01:
		_wall_segment(edge, along, cursor, half_len, mat)

## A solid wall run covering the edge-coordinate interval [s0, s1] (both in the `along` direction).
func _wall_segment(edge: Vector3, along: Vector3, s0: float, s1: float, mat: StringName) -> void:
	var seg_len := s1 - s0
	if seg_len <= 0.01:
		return
	var center_s := (s0 + s1) * 0.5
	var size := Vector3(seg_len, WALL_H, WALL_T) if along.x > 0.5 else Vector3(WALL_T, WALL_H, seg_len)
	_box(edge + along * center_s + Vector3(0, WALL_H * 0.5, 0), size, mat)

## Door offsets (metres along the edge from its centre) for a side. `doors` (positioned, Phase 2) wins;
## else fall back to `open_sides` (empty = every side centred, hand-authored back-compat).
func _door_offsets_for(side: StringName) -> Array:
	if not doors.is_empty():
		var out: Array = []
		for d in doors:
			if StringName(d.get("side", &"")) == side:
				out.append(float(d.get("offset", 0.0)))
		return out
	if open_sides.is_empty():
		return [0.0]
	return [0.0] if side in open_sides else []

func _wall_material() -> StringName:
	match dressing:
		&"vault": return &"trim"
		&"lobby": return &"wall"
		_: return &"wall"

## Sparse, wall-hugging decor keyed by dressing. The centre is left clear for the generator's spawns.
func _dress(half: Vector3) -> void:
	match dressing:
		&"vault":
			_place(_SERVER, Vector3(-half.x + DECOR_INSET, 0, 0), 90.0)
			_place(_SERVER, Vector3(-half.x + DECOR_INSET, 0, 2.2), 90.0)
			_place(_CABINET, Vector3(half.x - DECOR_INSET, 0, -half.z + 2.0), -90.0)
			_accent_dais(half)
		&"lobby":
			for i in 3:
				_place(_TELLER, Vector3(-half.x + DECOR_INSET + 0.4, 0, -2.2 + float(i) * 2.2), 90.0)
			_place(_CABINET, Vector3(half.x - DECOR_INSET, 0, half.z - DECOR_INSET))
		&"dock":
			_place(_CRATE, Vector3(half.x - DECOR_INSET, 0, half.z - DECOR_INSET))
			_place(_CRATE, Vector3(half.x - DECOR_INSET - 1.2, 0, half.z - DECOR_INSET))
		_:
			_place(_CABINET, Vector3(-half.x + DECOR_INSET, 0, -half.z + DECOR_INSET))

## A low brass-accent platform against the vault's back wall — reads as the "premium" setpiece
## without occupying the central floor the generator populates.
func _accent_dais(half: Vector3) -> void:
	_box(Vector3(0, 0.06, half.z - 1.2), Vector3(half.x * 1.2, 0.12, 1.6), &"accent")

# --- helpers ---------------------------------------------------------------
func _box(center: Vector3, size: Vector3, mat_name: StringName) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Palette.material(mat_name)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	add_child(body)
	if Engine.is_editor_hint() and get_tree() != null:
		body.owner = get_tree().edited_scene_root

func _place(scene: PackedScene, pos: Vector3, rot_y_deg: float = 0.0) -> void:
	if scene == null:
		return
	var inst := scene.instantiate()
	if inst is Node3D:
		(inst as Node3D).position = pos
		(inst as Node3D).rotation_degrees = Vector3(0, rot_y_deg, 0)
	add_child(inst)
	if Engine.is_editor_hint() and get_tree() != null:
		inst.owner = get_tree().edited_scene_root
