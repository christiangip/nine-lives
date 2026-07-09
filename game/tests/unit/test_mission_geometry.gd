extends GutTest
## World-gen Phase 2 seams: MissionGeometry resolves each graph edge into an aligned doorway / corridor,
## so graph-connected rooms are never physically locked out. Proves the door-alignment fix (both rooms of
## an edge open at the SAME world point), corridor resolution (straight + elbow), the deterministic
## free-cell router, and the geometry-faithfulness sweep across every generatable archetype × seeds — the
## headless lock-out proof. See world-gen-fixes.md (Phase 2).

const CELL := MissionLayout.CELL_SIZE

func _contract(seed_v: int, archetype: StringName, tier: int = 1) -> Contract:
	var c := Contract.new()
	c.archetype_id = archetype
	c.objective_id = &"grab_value"
	c.mission_seed = seed_v
	c.tier = tier
	c.difficulty = tier
	return c

## World position of a resolved door on a room's face (mirrors SectionShell's placement).
func _door_world(rect: Rect2i, door: Dictionary) -> Vector3:
	var off := float(door.get("offset", 0.0))
	var cx := (float(rect.position.x) + float(rect.size.x) * 0.5) * CELL
	var cz := (float(rect.position.y) + float(rect.size.y) * 0.5) * CELL
	match StringName(door.get("side", &"")):
		&"east": return Vector3(float(rect.end.x) * CELL, 0.0, cz + off)
		&"west": return Vector3(float(rect.position.x) * CELL, 0.0, cz + off)
		&"north": return Vector3(cx + off, 0.0, float(rect.end.y) * CELL)
		_: return Vector3(cx + off, 0.0, float(rect.position.y) * CELL)

# --- 2A/2B: the door-alignment fix (pure) ----------------------------------

## The exact Phase-1 lock-out: two flush neighbours with different footprints. Old code centred each
## doorway on its own face (A@z=6, B@z=9) → misaligned by 3 m → sealed. Now both resolve to z=6.
func test_shared_doors_align_on_shared_wall() -> void:
	var a := Rect2i(0, 0, 3, 2)   # east wall x=18, face centre z=6
	var b := Rect2i(3, 0, 2, 3)   # west wall x=18, face centre z=9
	var conn := MissionGeometry.resolve(a, b)
	assert_eq(String(conn["kind"]), "shared", "flush neighbours share a wall")
	assert_eq(String(conn["door_a"]["side"]), "east", "A opens east toward B")
	assert_eq(String(conn["door_b"]["side"]), "west", "B opens west toward A")
	var wa := _door_world(a, conn["door_a"])
	var wb := _door_world(b, conn["door_b"])
	assert_lt(wa.distance_to(wb), 0.001, "both doors land at the SAME world point (aligned, not sealed)")
	assert_almost_eq(wa.z, 6.0, 0.001, "the door sits at the centre of the 2-cell shared overlap")

func test_shared_symmetric_gate() -> void:
	var a := Rect2i(0, 0, 3, 2)
	var b := Rect2i(3, 0, 2, 3)
	var g1: Vector3 = MissionGeometry.resolve(a, b)["gate"]
	var g2: Vector3 = MissionGeometry.resolve(b, a)["gate"]
	assert_lt(g1.distance_to(g2), 0.001, "the edge gate host point is order-independent")

func test_z_facing_doors_align() -> void:
	var a := Rect2i(0, 0, 2, 2)   # north wall z=12
	var b := Rect2i(0, 2, 3, 2)   # south wall z=12
	var conn := MissionGeometry.resolve(a, b)
	assert_eq(String(conn["kind"]), "shared", "stacked neighbours share a horizontal wall")
	assert_eq(String(conn["door_a"]["side"]), "north", "A opens north toward B")
	var wa := _door_world(a, conn["door_a"])
	var wb := _door_world(b, conn["door_b"])
	assert_lt(wa.distance_to(wb), 0.001, "Z-facing doors line up too")

func test_straight_corridor_across_gap() -> void:
	var a := Rect2i(0, 0, 2, 2)   # east wall x=12
	var b := Rect2i(3, 0, 2, 2)   # west wall x=18, one free column (cell x=2) between
	var conn := MissionGeometry.resolve(a, b)
	assert_eq(String(conn["kind"]), "straight", "a gap between aligned rooms needs a straight corridor")
	assert_eq((conn["runs"] as Array).size(), 1, "one corridor run bridges the gap")
	assert_almost_eq(float(conn["gate"].x), 15.0, 0.001, "the gate sits mid-corridor")
	assert_true(Vector2i(2, 0) in conn["cells"], "the corridor crosses the free gap column")
	# doors still align on the connecting axis
	var wa := _door_world(a, conn["door_a"])
	var wb := _door_world(b, conn["door_b"])
	assert_almost_eq(wa.z, wb.z, 0.001, "both mouths share the corridor centreline Z")

func test_elbow_for_diagonal_neighbours() -> void:
	var a := Rect2i(0, 0, 2, 2)
	var b := Rect2i(3, 3, 2, 2)   # no overlap on either axis
	var conn := MissionGeometry.resolve(a, b)
	assert_eq(String(conn["kind"]), "elbow", "diagonal neighbours need an L corridor")
	assert_eq((conn["runs"] as Array).size(), 2, "an elbow has two legs")

func test_resolve_is_deterministic() -> void:
	var a := Rect2i(0, 0, 3, 2)
	var b := Rect2i(3, 1, 2, 3)
	assert_eq(str(MissionGeometry.resolve(a, b)), str(MissionGeometry.resolve(a, b)), "resolve is pure/deterministic")

# --- 2B: free-cell corridor router (pure) ----------------------------------

func test_route_corridor_contiguous_and_bounded() -> void:
	var path := MissionGeometry.route_corridor(Vector2i(0, 0), Vector2i(3, 2), {})
	assert_eq(path[0], Vector2i(0, 0), "route starts at the start cell")
	assert_eq(path[path.size() - 1], Vector2i(3, 2), "route ends at the end cell")
	for i in range(1, path.size()):
		var step: Vector2i = path[i] - path[i - 1]
		assert_eq(absi(step.x) + absi(step.y), 1, "every step is a single Manhattan move")

func test_route_corridor_avoids_occupied() -> void:
	# The horizontal-first L would cross (2,0); the router should prefer the vertical-first leg instead.
	var occupied := {Vector2i(2, 0): 1}
	var path := MissionGeometry.route_corridor(Vector2i(0, 0), Vector2i(3, 2), occupied)
	assert_false(Vector2i(2, 0) in path, "the router routes around an occupied cell when it can")

# --- 2C: geometry-faithfulness (the headless lock-out proof) ----------------

func test_every_generated_mission_is_physically_reachable() -> void:
	var archetypes := MissionBoard.generatable_archetypes()
	assert_true(archetypes.size() >= 1, "there is at least one generatable archetype")
	for arch in archetypes:
		for s in range(1, 25):
			var layout := MissionGenerator.generate_layout(_contract(s, arch.id, 1 + s % 4))
			if layout.sections.is_empty():
				continue
			var geo := MissionGeometry.faithful(layout)
			assert_true(geo.ok, "%s seed %d: every room is physically reachable (unreachable=%s)"
				% [arch.id, s, str(geo.unreachable)])

## The realize-time proof: a handful of built missions each stay fully reachable (most bank edges are
## flush shared walls the aligned doors connect directly — corridors only appear for gap/diagonal edges).
func test_realized_missions_stay_faithful() -> void:
	for s in [20250702, 4, 11, 19]:
		var controller := MissionGenerator.build(_contract(s, &"bank", 2))
		assert_not_null(controller, "bank seed %d built" % s)
		if controller == null:
			continue
		add_child_autofree(controller)
		assert_true(MissionGeometry.faithful(controller.layout).ok, "bank seed %d realizes a fully-reachable mission" % s)

## The corridor-builder glue: a hand-built layout with a one-cell gap forces a straight corridor, and
## MissionController._build_corridors must construct floored/walled hallway geometry for it.
func test_build_corridors_constructs_hallway_geometry() -> void:
	var d := SectionDef.new()
	d.footprint = Vector2i(2, 2)
	var layout := MissionLayout.new()
	var a := PlacedSection.new(); a.def = d; a.origin = Vector2i(0, 0); layout.add_section(a)
	var b := PlacedSection.new(); b.def = d; b.origin = Vector2i(3, 0); layout.add_section(b)   # free column x=2 between
	layout.edges.append({"a": 0, "b": 1, "gate": -1})
	var controller: MissionController = MissionController.new()
	autofree(controller)                 # never entered the tree → _ready/realize don't run
	controller.layout = layout
	var world := Node3D.new()
	controller.add_child(world)
	controller._build_corridors(world)
	assert_gt(world.find_children("Corridor*", "StaticBody3D", true, false).size(), 0,
		"a gap edge builds real corridor geometry")

func test_faithful_is_not_a_rubber_stamp() -> void:
	# Two rooms, entry at 0, and NO edge between them → room 1 is stranded → not faithful.
	var d := SectionDef.new()
	d.footprint = Vector2i(2, 2)
	var layout := MissionLayout.new()
	var a := PlacedSection.new(); a.def = d; a.origin = Vector2i(0, 0); layout.add_section(a)
	var b := PlacedSection.new(); b.def = d; b.origin = Vector2i(5, 0); layout.add_section(b)
	layout.entry_points = [{"section": 0}]
	assert_false(MissionGeometry.faithful(layout).ok, "a room with no connecting edge is caught as unreachable")
	# Add the edge → now reachable.
	layout.edges.append({"a": 0, "b": 1, "gate": -1})
	assert_true(MissionGeometry.faithful(layout).ok, "connecting the edge makes every room reachable")
