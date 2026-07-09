extends RefCounted
class_name MissionAssembler
## Seeded, rule-based section assembler (task 11, FR-11-2). Stitches an archetype's SectionDefs onto
## an integer grid — entry → interior graph → objective (vault) leaf → escape leaf — with **no overlaps
## by construction** (every child is placed at the first free grid rectangle near its parent) and a
## socket-matched-or-capped graph. Pure/deterministic given the seeded rng, so it validates and
## reproduces headlessly. M2 adds one cross-link for a loop / alternate route.
## See docs/tasks/11_mission_generation.md and GDD §7.5.

func assemble(archetype: ArchetypeDef, contract: Contract, rng: RandomNumberGenerator) -> MissionLayout:
	var layout := MissionLayout.new()
	layout.archetype_id = archetype.id
	layout.mission_seed = contract.mission_seed
	layout.tier = contract.tier
	layout.difficulty = contract.difficulty
	layout.objective_id = contract.objective_id
	layout.modifier_ids = contract.modifier_ids.duplicate()

	var defs := _resolve_sections(archetype)
	var entry_def := _first_of_kind(defs, SectionDef.Kind.ENTRY)
	var escape_def := _first_of_kind(defs, SectionDef.Kind.ESCAPE)
	var interior_pool := _all_of_kind(defs, SectionDef.Kind.INTERIOR)
	var objective_def := _resolve_objective_section(archetype)
	if entry_def == null or escape_def == null or objective_def == null or interior_pool.is_empty():
		return layout   # not generatable — caller checks layout.sections.is_empty()

	# 1. Entry at the origin.
	var entry_ps := _place(layout, entry_def, Vector2i.ZERO)
	layout.entry_index = entry_ps.index

	# 2. Interior graph (reserve 3 slots for entry + objective + escape).
	var total := clampi(rng.randi_range(archetype.min_sections, archetype.max_sections), 4, 64)
	var interior_target := maxi(1, total - 3)
	var frontier: Array = [entry_ps.index]
	for _i in interior_target:
		if _total_spare(layout) <= 2:
			break   # reserve two attach points for the objective + escape leaves
		var parent_i: int = _pick_parent(layout, frontier, rng)
		if parent_i < 0:
			break
		var sdef: SectionDef = interior_pool[rng.randi_range(0, interior_pool.size() - 1)]
		frontier.append(_attach(layout, parent_i, sdef, rng).index)

	# 3. Objective (vault) as a deep leaf, then 4. escape as its own leaf — both respect socket capacity.
	var obj_parent := _deepest_available(layout, frontier)
	if obj_parent >= 0:
		layout.objective_index = _attach(layout, obj_parent, objective_def, rng).index
	var esc_parent := _pick_parent(layout, frontier, rng)
	if esc_parent >= 0:
		layout.escape_index = _attach(layout, esc_parent, escape_def, rng).index

	# 5. M2: one cross-link between adjacent sections → a loop / alternate route.
	_maybe_crosslink(layout, rng)
	return layout

# --- Section resolution ----------------------------------------------------
func _resolve_sections(archetype: ArchetypeDef) -> Array:
	var out: Array = []
	for sid in archetype.section_ids:
		var d := _section(sid)
		if d != null:
			out.append(d)
	return out

func _resolve_objective_section(archetype: ArchetypeDef) -> SectionDef:
	for sid in archetype.setpiece_ids:
		var d := _section(sid)
		if d != null:
			return d
	# fall back to any OBJECTIVE/SETPIECE section declared in the main pool
	for sid in archetype.section_ids:
		var d := _section(sid)
		if d != null and (d.kind == SectionDef.Kind.OBJECTIVE or d.kind == SectionDef.Kind.SETPIECE):
			return d
	return null

func _section(id: StringName) -> SectionDef:
	if Content != null and Content.sections != null:
		return Content.sections.get_def(id) as SectionDef
	return null

func _first_of_kind(defs: Array, kind: int) -> SectionDef:
	for d in defs:
		if d.kind == kind:
			return d
	return null

func _all_of_kind(defs: Array, kind: int) -> Array:
	var out: Array = []
	for d in defs:
		if d.kind == kind:
			out.append(d)
	return out

# --- Placement -------------------------------------------------------------
func _place(layout: MissionLayout, def: SectionDef, origin: Vector2i) -> PlacedSection:
	var ps := PlacedSection.new()
	ps.def = def
	ps.origin = origin
	layout.add_section(ps)
	return ps

func _attach(layout: MissionLayout, parent_i: int, def: SectionDef, rng: RandomNumberGenerator) -> PlacedSection:
	var parent: PlacedSection = layout.sections[parent_i]
	var origin := _find_free_origin(layout, parent, def.footprint, rng)
	var ps := _place(layout, def, origin)
	layout.edges.append({"a": parent_i, "b": ps.index, "gate": -1})
	parent.sockets_used += 1
	ps.sockets_used += 1
	return ps

## First free grid rectangle near the parent, scanning outward deterministically (adjacent first, then
## perpendicular offsets, then larger gaps). The grid is unbounded/sparse, so a spot always exists.
## Pass 1 prefers a placement that shares a real wall face with the parent (≥1 cell of perpendicular
## overlap) so the edge realizes as an aligned doorway / straight corridor rather than a diagonal elbow
## (world-gen Phase 2D — fewer corridor clips). Pass 2 falls back to any free spot, and an unbounded
## east scan guarantees success without the old far-jump fallback that could strand a room (lock-out).
func _find_free_origin(layout: MissionLayout, parent: PlacedSection, fp: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var pr := parent.rect()
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	_shuffle(dirs, rng)
	# Pass 1 — face-sharing placements only (aligned doors / straight corridors, never a diagonal).
	for gap in range(0, 48):
		for d in dirs:
			for perp_i in range(0, 10):
				var origin := _origin_for(pr, fp, d, gap, _perp_offset(perp_i))
				if _shares_face(pr, origin, fp, d) and layout.rect_free(Rect2i(origin, fp)):
					return origin
	# Pass 2 — any free spot (a diagonal elbow only if no aligned spot exists in range; corridors handle it).
	for gap in range(0, 48):
		for d in dirs:
			for perp_i in range(0, 10):
				var origin := _origin_for(pr, fp, d, gap, _perp_offset(perp_i))
				if layout.rect_free(Rect2i(origin, fp)):
					return origin
	# Guaranteed terminator: scan straight east from the parent until a free strip (sparse grid → quick).
	var ox := pr.end.x
	while not layout.rect_free(Rect2i(Vector2i(ox, pr.position.y), fp)):
		ox += 1
	return Vector2i(ox, pr.position.y)

## Would a child placed at `origin` (footprint `fp`, attached in direction `d`) share ≥1 cell of wall face
## with the parent `pr` — i.e. overlap on the axis perpendicular to `d`? Face overlap → the realizer opens
## an aligned doorway (shared/straight) instead of routing a diagonal corridor.
func _shares_face(pr: Rect2i, origin: Vector2i, fp: Vector2i, d: Vector2i) -> bool:
	if d.x != 0:   # east/west adjacency → need overlap on the Z (grid-y) axis
		return mini(pr.end.y, origin.y + fp.y) - maxi(pr.position.y, origin.y) >= 1
	return mini(pr.end.x, origin.x + fp.x) - maxi(pr.position.x, origin.x) >= 1

func _origin_for(pr: Rect2i, fp: Vector2i, d: Vector2i, gap: int, perp: int) -> Vector2i:
	if d == Vector2i(1, 0):
		return Vector2i(pr.position.x + pr.size.x + gap, pr.position.y + perp)
	elif d == Vector2i(-1, 0):
		return Vector2i(pr.position.x - gap - fp.x, pr.position.y + perp)
	elif d == Vector2i(0, 1):
		return Vector2i(pr.position.x + perp, pr.position.y + pr.size.y + gap)
	else:
		return Vector2i(pr.position.x + perp, pr.position.y - gap - fp.y)

func _perp_offset(i: int) -> int:
	if i == 0:
		return 0
	@warning_ignore("integer_division")
	var m := (i + 1) / 2
	return m if i % 2 == 1 else -m

# --- Parent selection ------------------------------------------------------
## A frontier section with a spare socket, or -1 if none (never over-fills a section, FR-11-2).
func _pick_parent(layout: MissionLayout, frontier: Array, rng: RandomNumberGenerator) -> int:
	var open: Array = []
	for i in frontier:
		if _has_spare(layout.sections[i]):
			open.append(i)
	if open.is_empty():
		return -1
	return open[rng.randi_range(0, open.size() - 1)]

## Deepest (last-added) frontier section that still has a spare socket — where the vault hangs off; -1 if none.
func _deepest_available(layout: MissionLayout, frontier: Array) -> int:
	for i in range(frontier.size() - 1, -1, -1):
		if _has_spare(layout.sections[frontier[i]]):
			return frontier[i]
	return -1

func _has_spare(ps: PlacedSection) -> bool:
	return ps.sockets_used < ps.def.socket_count

func _total_spare(layout: MissionLayout) -> int:
	var n := 0
	for ps in layout.sections:
		n += maxi(0, ps.def.socket_count - ps.sockets_used)
	return n

# --- M2 cross-link ---------------------------------------------------------
func _maybe_crosslink(layout: MissionLayout, rng: RandomNumberGenerator) -> void:
	if layout.sections.size() < 4 or rng.randf() > 0.75:
		return
	var candidates: Array = []
	for a in layout.sections.size():
		for b in range(a + 1, layout.sections.size()):
			if _already_edged(layout, a, b):
				continue
			if b == layout.objective_index or a == layout.objective_index:
				continue   # keep the vault a single-entrance leaf (its gate must matter)
			if not (_has_spare(layout.sections[a]) and _has_spare(layout.sections[b])):
				continue   # never over-fill a section's sockets (FR-11-2)
			if not _rects_adjacent(layout.sections[a].rect(), layout.sections[b].rect()):
				continue
			candidates.append([a, b])
	if candidates.is_empty():
		return
	var pair: Array = candidates[rng.randi_range(0, candidates.size() - 1)]
	layout.edges.append({"a": pair[0], "b": pair[1], "gate": -1})
	layout.sections[pair[0]].sockets_used += 1
	layout.sections[pair[1]].sockets_used += 1

func _already_edged(layout: MissionLayout, a: int, b: int) -> bool:
	for e in layout.edges:
		if (e.a == a and e.b == b) or (e.a == b and e.b == a):
			return true
	return false

func _rects_adjacent(r1: Rect2i, r2: Rect2i) -> bool:
	var vert_overlap: int = mini(r1.end.y, r2.end.y) - maxi(r1.position.y, r2.position.y)
	var horz_overlap: int = mini(r1.end.x, r2.end.x) - maxi(r1.position.x, r2.position.x)
	if (r1.end.x == r2.position.x or r2.end.x == r1.position.x) and vert_overlap > 0:
		return true
	if (r1.end.y == r2.position.y or r2.end.y == r1.position.y) and horz_overlap > 0:
		return true
	return false

func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
