extends RefCounted
class_name MissionGeometry
## Pure geometry-resolution layer between the abstract layout and its realization (world-gen Phase 2).
## Resolves each MissionLayout graph edge into a *physical* connection between two placed rooms — an
## aligned doorway on the shared wall, a straight corridor across a gap, or an elbow corridor for
## diagonal neighbours — so graph-connected rooms are never locked out. The Phase-1 realizer opened
## each doorway centred on a room's own full face, so two flush neighbours with different footprints or
## a perpendicular offset got doorways at different positions along the shared wall and one opened onto
## the other's solid wall (the reported lock-out). Here both doors of an edge land at the SAME world
## point (the centre of the shared overlap), so they line up. All static/deterministic → MissionController
## realizes it and test_mission_geometry proves it headlessly. See world-gen-fixes.md Phase 2.

const CELL := MissionLayout.CELL_SIZE   ## metres per grid cell
const DOOR_W := SectionShell.DOOR_W     ## doorway/corridor width — single source of truth (no drift)

const SIDE_EAST := &"east"
const SIDE_WEST := &"west"
const SIDE_NORTH := &"north"
const SIDE_SOUTH := &"south"

## Resolve the physical connection between two placed-section rects (grid cells; Rect2i.y = grid Z).
## (Named `resolve`, not `connect` — the latter shadows Object.connect and breaks the parser.)
## Returns:
##   kind    "shared" | "straight" | "elbow"
##   axis    "x" | "z" | ""   (the wall-normal axis for shared/straight)
##   door_a/door_b  {side:StringName, offset:float}  — offset is metres along that room's face from its centre
##   gate    Vector3  — the world point (y=0) to host this edge's locked door (in the doorway/corridor)
##   runs    Array of {from:Vector3, to:Vector3}  — DOOR_W-wide corridor centrelines (empty for "shared")
##   cells   Array[Vector2i]  — grid cells the corridor centreline crosses (clip/faithfulness reporting)
static func resolve(a: Rect2i, b: Rect2i) -> Dictionary:
	var z_lo: int = maxi(a.position.y, b.position.y)
	var z_hi: int = mini(a.end.y, b.end.y)
	var x_lo: int = maxi(a.position.x, b.position.x)
	var x_hi: int = mini(a.end.x, b.end.x)
	# X-facing: rooms side by side along X, sharing a vertical wall — needs ≥1 cell of Z overlap.
	if (z_hi - z_lo) >= 1 and (a.end.x <= b.position.x or b.end.x <= a.position.x):
		return _axis_connection(a, b, true, z_lo, z_hi)
	# Z-facing: rooms stacked along Z, sharing a horizontal wall — needs ≥1 cell of X overlap.
	if (x_hi - x_lo) >= 1 and (a.end.y <= b.position.y or b.end.y <= a.position.y):
		return _axis_connection(a, b, false, x_lo, x_hi)
	return _elbow_connection(a, b)

## Shared/straight connection along one axis (along_x = rooms side-by-side in X). `ov_lo/ov_hi` are the
## overlapping cell interval on the *other* axis; the doorway centres on that overlap so both rooms align.
static func _axis_connection(a: Rect2i, b: Rect2i, along_x: bool, ov_lo: int, ov_hi: int) -> Dictionary:
	var overlap_center := float(ov_lo + ov_hi) * 0.5 * CELL   # world coord on the overlap axis
	if along_x:
		var a_is_west := a.end.x <= b.position.x
		var wall_a := float(a.end.x if a_is_west else a.position.x) * CELL
		var wall_b := float(b.position.x if a_is_west else b.end.x) * CELL
		var gap_cells := (b.position.x - a.end.x) if a_is_west else (a.position.x - b.end.x)
		var a_center := (float(a.position.y) + float(a.size.y) * 0.5) * CELL
		var b_center := (float(b.position.y) + float(b.size.y) * 0.5) * CELL
		var conn := {
			"kind": "shared" if gap_cells <= 0 else "straight",
			"axis": "x",
			"door_a": {"side": SIDE_EAST if a_is_west else SIDE_WEST, "offset": _clamp_offset(overlap_center - a_center, a.size.y)},
			"door_b": {"side": SIDE_WEST if a_is_west else SIDE_EAST, "offset": _clamp_offset(overlap_center - b_center, b.size.y)},
			"gate": Vector3((wall_a + wall_b) * 0.5, 0.0, overlap_center),
			"runs": [],
			"cells": [],
		}
		if gap_cells > 0:
			conn.runs = [{"from": Vector3(wall_a, 0.0, overlap_center), "to": Vector3(wall_b, 0.0, overlap_center)}]
			var col_lo: int = a.end.x if a_is_west else b.end.x
			var col_hi: int = b.position.x if a_is_west else a.position.x
			conn.cells = _rect_cells(col_lo, col_hi, ov_lo, ov_hi)
		return conn
	else:
		# Z-facing (rooms stacked along grid Z): doorway offset runs along X.
		var a_is_south := a.end.y <= b.position.y
		var wall_a := float(a.end.y if a_is_south else a.position.y) * CELL
		var wall_b := float(b.position.y if a_is_south else b.end.y) * CELL
		var gap_cells := (b.position.y - a.end.y) if a_is_south else (a.position.y - b.end.y)
		var a_center := (float(a.position.x) + float(a.size.x) * 0.5) * CELL
		var b_center := (float(b.position.x) + float(b.size.x) * 0.5) * CELL
		var conn := {
			"kind": "shared" if gap_cells <= 0 else "straight",
			"axis": "z",
			"door_a": {"side": SIDE_NORTH if a_is_south else SIDE_SOUTH, "offset": _clamp_offset(overlap_center - a_center, a.size.x)},
			"door_b": {"side": SIDE_SOUTH if a_is_south else SIDE_NORTH, "offset": _clamp_offset(overlap_center - b_center, b.size.x)},
			"gate": Vector3(overlap_center, 0.0, (wall_a + wall_b) * 0.5),
			"runs": [],
			"cells": [],
		}
		if gap_cells > 0:
			conn.runs = [{"from": Vector3(overlap_center, 0.0, wall_a), "to": Vector3(overlap_center, 0.0, wall_b)}]
			var row_lo: int = a.end.y if a_is_south else b.end.y
			var row_hi: int = b.position.y if a_is_south else a.position.y
			conn.cells = _rect_cells(ov_lo, ov_hi, row_lo, row_hi)
		return conn

## Diagonal neighbours (no shared-face overlap) — an L corridor. Each room opens on the cardinal side
## facing the other's centre; the two legs meet at an elbow. May visually clip a third room (cosmetic —
## the safety floor slab keeps it traversable, and faithful() reports the clip); free-cell routing is a
## documented follow-up.
static func _elbow_connection(a: Rect2i, b: Rect2i) -> Dictionary:
	var ca := _center(a)
	var cb := _center(b)
	var side_a := _dominant_side(ca, cb)
	var side_b := _dominant_side(cb, ca)
	var da := _face_point(a, side_a)
	var db := _face_point(b, side_b)
	var elbow: Vector3
	if side_a == SIDE_EAST or side_a == SIDE_WEST:
		elbow = Vector3(db.x, 0.0, da.z)   # leave A along X, then turn along Z to reach B
	else:
		elbow = Vector3(da.x, 0.0, db.z)   # leave A along Z, then turn along X to reach B
	var runs := [
		{"from": da, "to": elbow},
		{"from": elbow, "to": db},
	]
	return {
		"kind": "elbow",
		"axis": "",
		"door_a": {"side": side_a, "offset": 0.0},
		"door_b": {"side": side_b, "offset": 0.0},
		"gate": elbow,
		"runs": runs,
		"cells": _runs_cells(runs),
	}

## Best-effort Manhattan L between two door cells through *free* cells (deterministic). Tries both elbow
## orientations and returns the one crossing fewer occupied cells; falls back to the direct L. Exposed as
## a pure seam for tests; the realizer/elbow path can route with it when an occupancy map is available.
static func route_corridor(start_cell: Vector2i, end_cell: Vector2i, occupied: Dictionary, _rng: RandomNumberGenerator = null) -> Array:
	var horizontal_first := _l_path(start_cell, end_cell, true)
	var vertical_first := _l_path(start_cell, end_cell, false)
	var h_blocked := _count_blocked(horizontal_first, occupied)
	var v_blocked := _count_blocked(vertical_first, occupied)
	return horizontal_first if h_blocked <= v_blocked else vertical_first

## Geometry-faithfulness proof (world-gen Phase 2C): every edge resolves to a fitting door/corridor and
## every section is reachable from the entries over those connections. Returns
## { ok, unreachable:Array[int], unconnectable:Array[[a,b]], clip_cells:int }. A disconnected room (the
## lock-out class) makes ok=false — a genuine check, not a rubber stamp.
static func faithful(layout: MissionLayout) -> Dictionary:
	var res := {"ok": true, "unreachable": [], "unconnectable": [], "clip_cells": 0}
	if layout == null or layout.sections.is_empty():
		res.ok = false
		return res
	var occ: Dictionary = {}
	for ps in layout.sections:
		for c in ps.cells():
			occ[c] = ps.index
	var adj: Dictionary = {}
	for e in layout.edges:
		var ai := int(e.get("a", -1))
		var bi := int(e.get("b", -1))
		if ai < 0 or bi < 0 or ai >= layout.sections.size() or bi >= layout.sections.size():
			continue
		var conn := resolve(layout.sections[ai].rect(), layout.sections[bi].rect())
		if not _connection_fits(conn, layout.sections[ai].rect(), layout.sections[bi].rect()):
			res.unconnectable.append([ai, bi])
			res.ok = false
			continue
		for c in conn.get("cells", []):
			if occ.has(c) and occ[c] != ai and occ[c] != bi:
				res.clip_cells += 1
		if not adj.has(ai):
			adj[ai] = []
		if not adj.has(bi):
			adj[bi] = []
		adj[ai].append(bi)
		adj[bi].append(ai)
	var reachable: Dictionary = {}
	var stack: Array = layout.entry_indices()
	for s in stack:
		reachable[s] = true
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		for nb in adj.get(cur, []):
			if not reachable.has(nb):
				reachable[nb] = true
				stack.append(nb)
	for ps in layout.sections:
		if not reachable.has(ps.index):
			res.unreachable.append(ps.index)
			res.ok = false
	return res

# --- helpers ---------------------------------------------------------------

## Keep the ±DOOR_W/2 opening inside the wall face (never runs past a corner). Face is `face_cells` cells long.
static func _clamp_offset(off: float, face_cells: int) -> float:
	var max_off := maxf(0.0, float(face_cells) * CELL * 0.5 - DOOR_W * 0.5)
	return clampf(off, -max_off, max_off)

## A door/corridor exists and its opening fits on both faces. Overlap ≥1 cell (6 m) ≥ DOOR_W (3.4 m), so
## a shared/straight door always fits; an elbow always resolves — this stays true for any real room rects.
static func _connection_fits(conn: Dictionary, a: Rect2i, b: Rect2i) -> bool:
	var kind := String(conn.get("kind", ""))
	if kind != "shared" and kind != "straight" and kind != "elbow":
		return false
	return _door_fits(conn.get("door_a", {}), a) and _door_fits(conn.get("door_b", {}), b)

static func _door_fits(door: Dictionary, rect: Rect2i) -> bool:
	var side := StringName(door.get("side", &""))
	var face_cells := rect.size.y if (side == SIDE_EAST or side == SIDE_WEST) else rect.size.x
	return float(face_cells) * CELL >= DOOR_W and absf(float(door.get("offset", 0.0))) <= maxf(0.0, float(face_cells) * CELL * 0.5 - DOOR_W * 0.5) + 0.001

static func _center(rect: Rect2i) -> Vector3:
	return Vector3(float(rect.position.x) + float(rect.size.x) * 0.5, 0.0, float(rect.position.y) + float(rect.size.y) * 0.5) * CELL

## Centre of a room's cardinal wall face, in world space (y=0).
static func _face_point(rect: Rect2i, side: StringName) -> Vector3:
	var cx := (float(rect.position.x) + float(rect.size.x) * 0.5) * CELL
	var cz := (float(rect.position.y) + float(rect.size.y) * 0.5) * CELL
	match side:
		SIDE_EAST: return Vector3(float(rect.end.x) * CELL, 0.0, cz)
		SIDE_WEST: return Vector3(float(rect.position.x) * CELL, 0.0, cz)
		SIDE_NORTH: return Vector3(cx, 0.0, float(rect.end.y) * CELL)
		_: return Vector3(cx, 0.0, float(rect.position.y) * CELL)   # south

## Cardinal side of `from` that faces `to` (mirrors MissionController.dominant_side; inlined so this pure
## module has no dependency on the Node controller).
static func _dominant_side(from_center: Vector3, to_center: Vector3) -> StringName:
	var dx := to_center.x - from_center.x
	var dz := to_center.z - from_center.z
	if absf(dx) >= absf(dz):
		return SIDE_EAST if dx >= 0.0 else SIDE_WEST
	return SIDE_NORTH if dz >= 0.0 else SIDE_SOUTH

static func _rect_cells(x0: int, x1: int, z0: int, z1: int) -> Array:
	var out: Array = []
	for cx in range(mini(x0, x1), maxi(x0, x1)):
		for cz in range(mini(z0, z1), maxi(z0, z1)):
			out.append(Vector2i(cx, cz))
	return out

static func _runs_cells(runs: Array) -> Array:
	var out: Array = []
	for r in runs:
		var f: Vector3 = r["from"]
		var t: Vector3 = r["to"]
		var steps := maxi(1, int(ceil(f.distance_to(t) / CELL)))
		for i in steps + 1:
			var p: Vector3 = f.lerp(t, float(i) / float(steps))
			var cell := Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))
			if cell not in out:
				out.append(cell)
	return out

## An L path of cells from start to end (horizontal-first or vertical-first).
static func _l_path(start_cell: Vector2i, end_cell: Vector2i, horizontal_first: bool) -> Array:
	var out: Array = [start_cell]
	var cur := start_cell
	var corner := Vector2i(end_cell.x, start_cell.y) if horizontal_first else Vector2i(start_cell.x, end_cell.y)
	for step in [corner, end_cell]:
		while cur.x != step.x:
			cur.x += signi(step.x - cur.x)
			if cur not in out:
				out.append(cur)
		while cur.y != step.y:
			cur.y += signi(step.y - cur.y)
			if cur not in out:
				out.append(cur)
	return out

static func _count_blocked(path: Array, occupied: Dictionary) -> int:
	var n := 0
	for c in path:
		if occupied.has(c):
			n += 1
	return n
