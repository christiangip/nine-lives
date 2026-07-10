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

# --- misc-fixes-2 issue 4a: door yaw (pure) ---------------------------------

func test_door_yaw_x_facing_connection_turns_the_leaf() -> void:
	var conn := MissionGeometry.resolve(Rect2i(0, 0, 2, 2), Rect2i(2, 0, 2, 2))   # side-by-side along X
	assert_eq(String(conn["axis"]), "x", "rooms side-by-side along X resolve an X-facing connection")
	assert_almost_eq(MissionGeometry.door_yaw(conn), PI * 0.5, 0.0001,
		"an X-facing doorway turns the leaf 90° so it spans the opening")

func test_door_yaw_z_facing_connection_keeps_default() -> void:
	var conn := MissionGeometry.resolve(Rect2i(0, 0, 2, 2), Rect2i(0, 2, 2, 2))   # stacked along Z
	assert_eq(String(conn["axis"]), "z", "stacked rooms resolve a Z-facing connection")
	assert_almost_eq(MissionGeometry.door_yaw(conn), 0.0, 0.0001,
		"a Z-facing doorway keeps the leaf's default facing (width along X)")

func test_door_yaw_elbow_follows_door_a_side() -> void:
	# Diagonal with X dominant → A leaves east → the elbow gate blocks an X-running leg → 90°.
	var conn_ew := MissionGeometry.resolve(Rect2i(0, 0, 2, 2), Rect2i(4, 3, 2, 2))
	assert_eq(String(conn_ew["kind"]), "elbow", "diagonal neighbours resolve an elbow")
	assert_eq(String(conn_ew["door_a"]["side"]), "east", "X-dominant diagonal leaves A east")
	assert_almost_eq(MissionGeometry.door_yaw(conn_ew), PI * 0.5, 0.0001, "east/west elbow leg → 90°")
	# Diagonal with Z dominant → A leaves north → a Z-running leg → 0°.
	var conn_ns := MissionGeometry.resolve(Rect2i(0, 0, 2, 2), Rect2i(3, 4, 2, 2))
	assert_eq(String(conn_ns["door_a"]["side"]), "north", "Z-dominant diagonal leaves A north")
	assert_almost_eq(MissionGeometry.door_yaw(conn_ns), 0.0, 0.0001, "north/south elbow leg → 0°")

# --- misc-fixes-2 follow-up: spawn anchors pulled inside the walls -----------

func test_inset_into_section_pulls_boundary_anchors_inside() -> void:
	# The greybox regression: bank_entry_lobby authors its entry anchor ON the west boundary — world
	# (0, 0, 9) for the seed-20250702 lobby at rect (0,0,3,2) — which is inside the (now back-to-back)
	# shared wall, embedding the spawned player. The realizer must inset actor spawns off the faces.
	var lobby := Rect2i(0, 0, 3, 2)
	var pulled := MissionController.inset_into_section(Vector3(0, 0, 9), lobby, CELL, 1.2)
	assert_almost_eq(pulled.x, 1.2, 0.001, "a boundary anchor is pulled a margin inside the room")
	assert_almost_eq(pulled.z, 9.0, 0.001, "the already-interior axis is untouched")
	assert_eq(MissionController.inset_into_section(Vector3(9, 0, 6), lobby, CELL, 1.2), Vector3(9, 0, 6),
		"an interior anchor is unchanged")
	var corner := MissionController.inset_into_section(Vector3(0, 0, 0), lobby, CELL, 1.2)
	assert_almost_eq(corner.x, 1.2, 0.001, "a corner anchor clears the wall + pillar on x")
	assert_almost_eq(corner.z, 1.2, 0.001, "a corner anchor clears the wall + pillar on z")
	var tiny := MissionController.inset_into_section(Vector3(0, 0, 0), Rect2i(0, 0, 1, 1), 2.0, 5.0)
	assert_almost_eq(tiny.x, 1.0, 0.001, "an oversized margin caps at the room centre")

func test_realized_player_spawn_is_off_the_shared_wall() -> void:
	# The exact reported repro: MissionGreybox's fixed bank seed put the player at (0, 0.2, 9) — inside
	# the lobby↔office shared wall — and the player couldn't move at all.
	var controller := MissionGenerator.build(_contract(20250702, &"bank", 2))
	assert_not_null(controller, "greybox-seed bank built")
	if controller == null:
		return
	add_child_autofree(controller)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	assert_not_null(player, "the realizer spawned a player")
	if player != null:
		assert_gt(player.position.x, 1.0, "the spawn is pulled off the entry room's west boundary wall")

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
