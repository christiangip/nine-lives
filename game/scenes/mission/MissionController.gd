extends Node3D
class_name MissionController
## The scene-local root of a generated mission (task 11) — what MissionGenerator.build() returns and
## GameManager swaps in. Owns per-mission state (objective progress, secured value) and the runtime
## wiring the downstream tasks deferred here:
##   • escape objective → GameManager.goto_results (closes Escape.gd TODO[11], ↩ From 10)
##   • PursuitDirector.reinforcements_requested → spawn EnemyDefs at reinforcement sockets (↩ From 10)
##   • MinigameHost.attach_all over the built obstacles (↩ From 07)
##   • the &"mission_root" group so PlayerController parents thrown bags/bodies here (closes its TODO[11])
## Realizes the abstract MissionLayout into a walkable greybox (procedural floors + spawned guards/
## obstacles/loot/drops/escape); real art is task 18. See docs/tasks/11_mission_generation.md + ARCHITECTURE.md.

const CELL := MissionLayout.CELL_SIZE
const _PLAYER_SCENE := preload("res://game/scenes/player/PlayerController.tscn")
const _HUD_SCENE := preload("res://game/scenes/ui/hud/HUD.tscn")   ## the real in-mission HUD (task 15)
const _INTERIOR_ENV := preload("res://game/assets/interior_env.tres")  ## dim ambient so fixtures read (world-gen 1C)
const _CIVILIAN_MODEL := preload("res://game/assets/models/characters/Casual.gltf")  ## civilian art (task 18)

# --- Greybox geometry tunables (world-gen Phase 1; realization consts, mirrors SectionShell's local set) --
const _ENVELOPE_MARGIN := 3.0     ## metres the boundary walls sit beyond the section bounding box (inside the floor slab)
const _ENVELOPE_HEIGHT := 8.0     ## boundary wall height (m) — well over the 3.4 m room walls
const _ENVELOPE_THICK := 1.0      ## boundary wall/cap thickness (m)
const _CAMERA_MOUNT_HEIGHT := 2.6 ## camera mount height (m) when the def doesn't override it
const _CAMERA_FOV := 60.0
const _CAMERA_RANGE := 12.0
const _CAMERA_PITCH_DEG := 22.0   ## downward tilt so a ceiling camera watches the floor
const _CAMERA_SWEEP_PERIOD := 6.0

## Category → Obstacle subclass. Branch on the def property, never on id (const via preload, per house rule).
const _OBSTACLE_SCRIPTS := {
	ObstacleDef.Category.LOCK: preload("res://game/systems/obstacles/Lock.gd"),
	ObstacleDef.Category.KEYCARD_DOOR: preload("res://game/systems/obstacles/KeycardDoor.gd"),
	ObstacleDef.Category.SAFE: preload("res://game/systems/obstacles/Safe.gd"),
	ObstacleDef.Category.DISPLAY_CASE: preload("res://game/systems/obstacles/DisplayCase.gd"),
	ObstacleDef.Category.HACK_TARGET: preload("res://game/systems/obstacles/HackTarget.gd"),
	ObstacleDef.Category.LASER_GRID: preload("res://game/systems/obstacles/LaserGrid.gd"),
	ObstacleDef.Category.MOTION_SENSOR: preload("res://game/systems/obstacles/MotionSensor.gd"),
	ObstacleDef.Category.PRESSURE_PLATE: preload("res://game/systems/obstacles/PressurePlate.gd"),
	ObstacleDef.Category.BIOMETRIC_LOCK: preload("res://game/systems/obstacles/BiometricLock.gd"),
	ObstacleDef.Category.SILENT_ALARM: preload("res://game/systems/obstacles/SilentAlarm.gd"),
	ObstacleDef.Category.FUSE_BOX: preload("res://game/systems/obstacles/FuseBox.gd"),
	ObstacleDef.Category.LIGHT: preload("res://game/systems/obstacles/ControllableLight.gd"),
	ObstacleDef.Category.BREACH_POINT: preload("res://game/systems/obstacles/BreachPoint.gd"),
}

var layout: MissionLayout
var contract: Contract
var secured_value: int = 0
var objectives_done: Dictionary = {}     ## objective_id -> true
var _director: PursuitDirector
var _host: MinigameHost
var _reinforce_points: Array = []        ## world Vector3s
var _reinforce_cursor: int = 0
var _realized := false
var _finished := false
var _start_msec: int = 0                 ## Time.get_ticks_msec() at mission start (feeds the speed bonus)

## Debug/QA self-damage chunk (Part C) — ~3 hits down a 100 HP player, enough to exercise down → revive → Catch.
const _DEBUG_SELF_DAMAGE := 34.0
## Dev loadout equipped by the debug arm key so firing/gadgets are testable in a real mission (a fresh
## player is intentionally unarmed — weapons are Armory-researched). Mirrors MissionGreyboxDebug._DEV_GEAR.
const _DEBUG_GEAR: Array[StringName] = [&"suppressed_pistol", &"keycard_cloner", &"lockpick_set", &"emp", &"smoke"]

## Called by MissionGenerator.build() before this node enters the tree.
func setup(p_layout: MissionLayout, p_contract: Contract) -> void:
	layout = p_layout
	contract = p_contract

func _ready() -> void:
	add_to_group(&"mission_root")
	_start_msec = Time.get_ticks_msec()
	if not EventBus.objective_updated.is_connected(_on_objective_updated):
		EventBus.objective_updated.connect(_on_objective_updated)
	if not EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.connect(_on_loot_secured)
	if layout != null:
		realize()

# --- Realization (node glue; F6-verified, not unit-tested) -----------------
func realize() -> void:
	if _realized or layout == null:
		return
	_realized = true
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	_build_stage(world)
	_build_floor(world)
	_build_envelope(world)
	_build_sections(world)
	_build_fixtures(world)
	_build_actors(world)
	_build_obstacles(world)
	_build_loot(world)
	_build_banking(world)
	_collect_reinforce_points()
	_build_pursuit()
	_build_minigame_host(world)
	_spawn_player(world)
	_build_hud(world)
	if _debug_enabled():
		_build_debug_hint()

## Mount the real task-15 HUD (compass-eye / carry / objective / pursuit / loud) + the on-world noise-ring
## spawner. Replaces the MissionGreyboxDebug stand-in label. A greybox that already added its own HUD is
## left alone (avoid a double overlay).
func _build_hud(world: Node3D) -> void:
	if get_tree() != null and not get_tree().get_nodes_in_group(&"mission_hud").is_empty():
		return
	var hud := _HUD_SCENE.instantiate()
	hud.add_to_group(&"mission_hud")
	add_child(hud)
	var rings := NoiseRingSpawner.new()
	rings.name = "NoiseRings"
	world.add_child(rings)

## Total street value of all loot placed in this mission — the denominator for the HUD's
## secured-vs-remaining readout (task 15, FR-15-5).
func loot_total_value() -> int:
	var total := 0
	if layout == null or Content == null or Content.loot == null:
		return total
	for l in layout.loot:
		var def := Content.loot.get_def(StringName(l.get("loot_id", &""))) as LootDef
		if def != null:
			total += def.value
	return total

## WorldEnvironment + key/fill lighting for the generated mission (task 18, FR-18-7). Tuned so cast
## shadows stay dark enough to hide in but the scene reads (the stealth readability pass). Skipped when
## the scene already supplies its own environment (MissionGreybox.tscn ships a WorldEnvironment + Sun),
## so we never double up.
func _build_stage(_world: Node3D) -> void:
	if _has_world_environment():
		return
	var we := WorldEnvironment.new()
	we.name = "MissionEnv"
	we.environment = _INTERIOR_ENV   # dim ambient — ceilings + fixtures now do the interior lighting (world-gen 1C)
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_energy = 0.15
	add_child(fill)

func _has_world_environment() -> bool:
	if get_tree() == null:
		return false
	return not get_tree().root.find_children("*", "WorldEnvironment", true, false).is_empty()

func _build_floor(world: Node3D) -> void:
	if layout.sections.is_empty():
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for ps in layout.sections:
		var r := ps.rect()
		lo.x = mini(lo.x, r.position.x); lo.y = mini(lo.y, r.position.y)
		hi.x = maxi(hi.x, r.end.x); hi.y = maxi(hi.y, r.end.y)
	var size := Vector3(float(hi.x - lo.x) * CELL + 8.0, 0.5, float(hi.y - lo.y) * CELL + 8.0)
	var center := Vector3(float(lo.x + hi.x) * 0.5 * CELL, -0.25, float(lo.y + hi.y) * 0.5 * CELL)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = center
	floor_body.set_meta("surface", "concrete")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = Palette.material(&"floor")
	floor_body.add_child(mesh)
	world.add_child(floor_body)

## Invisible boundary so the player can't walk off the connective floor slab into the void, or get
## launched out the (open) top (world-gen Phase 1A). Four perimeter walls + a high cap around the section
## bounding box + a margin. Collision-only — the visible enclosure is the per-room shells; this is the
## guaranteed backstop behind them (paired with PlayerController's fall reset).
func _build_envelope(world: Node3D) -> void:
	if layout.sections.is_empty():
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for ps in layout.sections:
		var r := ps.rect()
		lo.x = mini(lo.x, r.position.x); lo.y = mini(lo.y, r.position.y)
		hi.x = maxi(hi.x, r.end.x); hi.y = maxi(hi.y, r.end.y)
	var min_x := float(lo.x) * CELL - _ENVELOPE_MARGIN
	var min_z := float(lo.y) * CELL - _ENVELOPE_MARGIN
	var max_x := float(hi.x) * CELL + _ENVELOPE_MARGIN
	var max_z := float(hi.y) * CELL + _ENVELOPE_MARGIN
	var span_x := max_x - min_x
	var span_z := max_z - min_z
	var cx := (min_x + max_x) * 0.5
	var cz := (min_z + max_z) * 0.5
	var h := _ENVELOPE_HEIGHT
	var t := _ENVELOPE_THICK
	_add_collider(world, Vector3(cx, h * 0.5, min_z), Vector3(span_x + t, h, t))   # south (-Z)
	_add_collider(world, Vector3(cx, h * 0.5, max_z), Vector3(span_x + t, h, t))   # north (+Z)
	_add_collider(world, Vector3(min_x, h * 0.5, cz), Vector3(t, h, span_z + t))   # west (-X)
	_add_collider(world, Vector3(max_x, h * 0.5, cz), Vector3(t, h, span_z + t))   # east (+X)
	_add_collider(world, Vector3(cx, h + t, cz), Vector3(span_x + t, t, span_z + t))  # cap

## An invisible collision-only box (boundary wall / cap). No mesh — it just stops movement.
func _add_collider(world: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Bound"
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)

func _build_sections(world: Node3D) -> void:
	for ps in layout.sections:
		# Edge-aware enclosure (world-gen Phase 1B): open a doorway only on the walls facing a graph-neighbour
		# so the room seals on its outward faces. The shell falls back to all-open if handed no sides.
		var open_sides := _open_sides_for(ps.index)
		# Real art (task 18, FR-18-7): a SectionDef.scene shell is instanced at the section centre; its
		# footprint + open sides are synced from the layout so it grid-snaps and seals correctly.
		if ps.def.scene != null:
			var section: Node3D = ps.def.scene.instantiate()
			section.name = "Section_%d_%s" % [ps.index, ps.def.id]
			if "footprint" in section:
				section.set("footprint", ps.def.footprint)
			if "open_sides" in section:
				section.set("open_sides", open_sides)
			section.position = ps.center_world(CELL)
			world.add_child(section)
			continue
		# No authored scene: build a sealed procedural room (walls + ceiling + doors) via SectionShell rather
		# than a flat tile, so un-dressed archetypes (estate pack, museum/warehouse) are enclosed + lit too.
		var shell := SectionShell.new()
		shell.name = "Section_%d_%s" % [ps.index, ps.def.id]
		shell.footprint = ps.def.footprint
		shell.open_sides = open_sides
		shell.dressing = _dressing_for(ps.def)
		shell.position = ps.center_world(CELL)
		world.add_child(shell)

## Ceiling light fixtures per room (world-gen Phase 1C): honour authored &"light" anchors, else auto-scatter
## by footprint. Each fixture pools light + joins group &"lit" so detection reads exposed-vs-shadow.
func _build_fixtures(world: Node3D) -> void:
	for ps in layout.sections:
		var lights := ps.def.anchors_of(&"light")
		if not lights.is_empty():
			for a in lights:
				_add_fixture(world, ps.anchor_world(a.get("pos", Vector3.ZERO), CELL))
			continue
		var s := ps.size()
		var count := clampi(int(round(float(s.x * s.y) / 4.0)), 1, 4)
		var center := ps.center_world(CELL)
		if count <= 1:
			_add_fixture(world, center)
			continue
		var long_x := s.x >= s.y
		for i in count:
			var frac := (float(i) + 0.5) / float(count) - 0.5   # -0.5 .. 0.5 along the long axis
			var off := Vector3(float(s.x) * CELL * frac, 0, 0) if long_x else Vector3(0, 0, float(s.y) * CELL * frac)
			_add_fixture(world, center + off)

func _add_fixture(world: Node3D, pos: Vector3) -> void:
	var f := LightFixture.new()
	f.name = "Fixture"
	f.position = pos
	world.add_child(f)

## Pure seam (unit-tested): the cardinal side of `from_center` that faces `to_center` — used to open a
## room's wall toward each graph-neighbour so sealed rooms stay traversable (world-gen Phase 1B).
static func dominant_side(from_center: Vector3, to_center: Vector3) -> StringName:
	var dx := to_center.x - from_center.x
	var dz := to_center.z - from_center.z
	if absf(dx) >= absf(dz):
		return &"east" if dx >= 0.0 else &"west"
	return &"north" if dz >= 0.0 else &"south"

## Which of this section's walls face a connected neighbour (so the shell opens a doorway there).
func _open_sides_for(index: int) -> Array[StringName]:
	var sides: Array[StringName] = []
	var c0 := layout.sections[index].center_world(CELL)
	for e in layout.edges:
		var other := -1
		if int(e.get("a", -1)) == index:
			other = int(e.get("b", -1))
		elif int(e.get("b", -1)) == index:
			other = int(e.get("a", -1))
		if other < 0 or other >= layout.sections.size():
			continue
		var side := dominant_side(c0, layout.sections[other].center_world(CELL))
		if side not in sides:
			sides.append(side)
	if sides.is_empty():
		sides.append(&"north")   # isolated safety (a connected graph never hits this)
	return sides

## Dressing preset for a procedurally-shelled (scene-less) room, by section kind.
func _dressing_for(def: SectionDef) -> StringName:
	match def.kind:
		SectionDef.Kind.ENTRY:
			return &"lobby"
		SectionDef.Kind.OBJECTIVE, SectionDef.Kind.SETPIECE:
			return &"vault"
		_:
			return &"generic"

func _build_actors(world: Node3D) -> void:
	for a in layout.actors:
		_spawn_guard(world, StringName(a.get("enemy_id", &"guard")), a.get("pos", Vector3.ZERO),
			float(a.get("skill_mult", 1.0)), StringName(a.get("carried_item", &"")))

func _spawn_guard(world: Node3D, enemy_id: StringName, pos: Vector3, skill_mult: float, carried_item: StringName) -> void:
	var base := _enemy_def(enemy_id)
	if base == null:
		return
	var edef := base.scaled(maxf(0.1, skill_mult))
	if carried_item != &"":
		edef.carried_item = carried_item
	var guard := CharacterBody3D.new()
	guard.set_script(GuardAI)
	guard.name = "Guard_%s" % enemy_id
	guard.position = pos + Vector3(0, 0.9, 0)
	guard.def = edef
	var ai_cfg := _ai_config()
	if ai_cfg != null:
		guard.ai_config = ai_cfg
	# collider + mesh
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35; cap.height = 1.8
	shape.shape = cap
	guard.add_child(shape)
	# Visual: the real character model (task 18) over the kept capsule collider, with a tinted feet-ring so
	# the threat read survives (gold = keycard carrier / the Inspector, blue = a regular guard). The cone
	# wedge below keeps detection legible. Capsule mesh is the fallback when a def has no model.
	var role: Color = Palette.TINT_KEYCARRIER if carried_item != &"" else Palette.TINT_GUARD
	if edef.model != null:
		_add_model(guard, edef.model, Vector3(0, -0.9, 0))
		guard.add_child(_role_ring(role, Vector3(0, -0.88, 0)))
	else:
		var mesh := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.35; cm.height = 1.8
		mesh.mesh = cm
		mesh.material_override = Palette.tinted(role)
		guard.add_child(mesh)
	# detection sensor child (auto-found by GuardAI) + a debug cone wedge so the player can read it
	var sensor := Node3D.new()
	sensor.name = "Sensor"
	sensor.set_script(load("res://game/systems/stealth/DetectionSensor.gd"))
	sensor.position = Vector3(0, 0.7, 0)
	sensor.set("enemy_def", edef)
	var det_cfg := _detection_config()
	if det_cfg != null:
		sensor.set("config", det_cfg)
	var cone := MeshInstance3D.new()
	cone.name = "ConeDebug"
	cone.set_script(load("res://game/systems/stealth/DetectionConeDebug.gd"))
	sensor.add_child(cone)
	guard.add_child(sensor)
	guard.sensor_path = NodePath("Sensor")
	# a short local patrol so the guard actually walks (greybox; real routes via anchors is task 18)
	var patrol := Node3D.new()
	patrol.name = "Patrol_%s" % enemy_id
	patrol.position = pos
	for off in [Vector3(2, 0, 0), Vector3(-2, 0, 1.5)]:
		var wp := Marker3D.new()
		wp.position = off
		patrol.add_child(wp)
	world.add_child(patrol)
	# Set the patrol path BEFORE the guard enters the tree, so GuardAI._ready() resolves its waypoints.
	guard.patrol_path = patrol.get_path()
	world.add_child(guard)

func _build_obstacles(world: Node3D) -> void:
	for g in layout.gates:
		var pos := _edge_midpoint(int(g.get("edge", -1)))
		_spawn_obstacle(world, StringName(g.get("obstacle_id", &"")), pos, pos)
	for h in layout.hazards:
		var hp: Vector3 = h.get("pos", Vector3.ZERO)
		var sec := int(h.get("section", -1))
		var center := layout.sections[sec].center_world(CELL) if sec >= 0 and sec < layout.sections.size() else hp
		_spawn_obstacle(world, StringName(h.get("obstacle_id", &"")), hp, center)

func _spawn_obstacle(world: Node3D, obstacle_id: StringName, pos: Vector3, watch_center: Vector3) -> void:
	var odef := _obstacle_def(obstacle_id)
	if odef == null:
		return
	var script: GDScript = _OBSTACLE_SCRIPTS.get(odef.category, load("res://game/systems/obstacles/Obstacle.gd"))
	var node := Node3D.new()
	node.set_script(script)
	node.name = "Obstacle_%s" % obstacle_id
	node.set("def_id", obstacle_id)
	# A camera mounts high and aims down at the floor it guards (world-gen Phase 1D); everything else sits at
	# floor level like before. mount_height/vision live in the def's params (data-driven, no id branching).
	var is_cam := _is_camera(odef)
	var mount_y: float = float(odef.params.get("mount_height", _CAMERA_MOUNT_HEIGHT)) if is_cam else 1.0
	node.position = pos + Vector3(0, mount_y, 0)
	# Real art (task 18): the ObstacleDef.scene prop prefab brings its own collider, so the interaction ray
	# resolves up to this Interactable exactly as it did for the marker body. Fallback: the colored marker.
	if odef.scene != null:
		_add_model(node, odef.scene, Vector3.ZERO if is_cam else Vector3(0, -1.0, 0))
	elif is_cam:
		_add_marker_body(node, Vector3(0.4, 0.3, 0.6), Palette.TINT_KEYCARRIER)
	else:
		_add_marker_body(node, Vector3(0.8, 2.0, 0.3), Color(0.7, 0.5, 0.2))
	if is_cam:
		_attach_camera_eye(node, odef, pos, watch_center)
	world.add_child(node)

func _is_camera(odef: ObstacleDef) -> bool:
	return odef.category == ObstacleDef.Category.HACK_TARGET and String(odef.params.get("device", "")) == "camera"

## Give a camera a real detection cone: a CameraEye child (the full DetectionSensor vision core) pitched
## down and yawed toward the room, with a debug wedge, gated on the HackTarget's defeated state. Reuses
## the guard sensor template — a camera now sees like a guard and alerts the same way (world-gen Phase 1D).
func _attach_camera_eye(node: Node3D, odef: ObstacleDef, floor_pos: Vector3, watch_center: Vector3) -> void:
	var eye := CameraEye.new()
	eye.name = "Sensor"
	eye.vision_angle_deg = float(odef.params.get("vision_angle", _CAMERA_FOV))
	eye.vision_range = float(odef.params.get("vision_range", _CAMERA_RANGE))
	eye.sweep_deg = float(odef.params.get("ptz_sweep_deg", 0.0))
	eye.sweep_period = float(odef.params.get("ptz_period", _CAMERA_SWEEP_PERIOD))
	eye.host = node
	var det_cfg := _detection_config()
	if det_cfg != null:
		eye.config = det_cfg
	var pitch := deg_to_rad(float(odef.params.get("pitch_deg", _CAMERA_PITCH_DEG)))
	var dx := watch_center.x - floor_pos.x
	var dz := watch_center.z - floor_pos.z
	var yaw := atan2(-dx, -dz) if (dx * dx + dz * dz) > 1.0 else 0.0
	eye.rotation = Vector3(-pitch, yaw, 0.0)   # -Z forward: negative X-rot looks down, yaw faces the room
	var cone := MeshInstance3D.new()
	cone.name = "ConeDebug"
	cone.set_script(load("res://game/systems/stealth/DetectionConeDebug.gd"))
	eye.add_child(cone)
	node.add_child(eye)

func _build_loot(world: Node3D) -> void:
	for l in layout.loot:
		var node := Node3D.new()
		node.set_script(load("res://game/systems/inventory/LootPickup.gd"))
		node.name = "Loot_%s" % l.get("loot_id", &"")
		var lid := StringName(l.get("loot_id", &""))
		node.set("def_id", lid)
		node.position = l.get("pos", Vector3.ZERO) + Vector3(0, 0.5, 0)
		var col := Color(0.9, 0.8, 0.2) if bool(l.get("is_mark", false)) else Color(0.8, 0.75, 0.4)
		# Real art (task 18): a LootDef.mesh is shown over an invisible collider (the raw .glb has none, so
		# the interaction ray still needs one). Fallback: the colored marker box.
		var ldef := (Content.loot.get_def(lid) as LootDef) if Content != null and Content.loot != null else null
		if ldef != null and ldef.mesh != null:
			_add_marker_body(node, Vector3(0.5, 0.5, 0.5), col, false)
			_add_model(node, ldef.mesh, Vector3(0, -0.5, 0))
		else:
			_add_marker_body(node, Vector3(0.5, 0.5, 0.5), col)
		world.add_child(node)
	for c in layout.consumables:
		_add_labeled_marker(world, "Consumable_%s" % c.get("gear_id", &""), c.get("pos", Vector3.ZERO),
			Vector3(0.35, 0.35, 0.35), Color(0.4, 0.8, 0.9))
	for civ in layout.civilians:
		# Real art (task 18): a civilian model over an invisible collider (a pickpocket target), tinted cyan
		# by a feet-ring so it reads as clearly not-a-guard / not-the-gold-Inspector.
		var m := Node3D.new()
		m.name = "Civilian"
		m.position = civ.get("pos", Vector3.ZERO) + Vector3(0, 0.85, 0)
		_add_marker_body(m, Vector3(0.4, 1.7, 0.4), Palette.TINT_CIVILIAN, false)
		_add_model(m, _CIVILIAN_MODEL, Vector3(0, -0.85, 0))
		m.add_child(_role_ring(Palette.TINT_CIVILIAN, Vector3(0, -0.83, 0)))
		m.add_to_group(&"civilian")
		m.set_meta("carried_item", civ.get("carried_item", &""))
		world.add_child(m)

func _build_banking(world: Node3D) -> void:
	for dp in layout.drop_points:
		var node := Node3D.new()
		node.set_script(load("res://game/systems/inventory/DropPoint.gd"))
		node.name = "DropPoint"
		node.position = dp.get("pos", Vector3.ZERO) + Vector3(0, 0.5, 0)
		_add_marker_body(node, Vector3(1.0, 1.0, 1.0), Palette.SIGNAL_OK)
		world.add_child(node)
	if layout.escape_index >= 0:
		var e := Node3D.new()
		e.set_script(load("res://game/systems/inventory/Escape.gd"))
		e.name = "Escape"
		e.position = layout.sections[layout.escape_index].center_world(CELL) + Vector3(0, 1.0, 0)
		_add_marker_body(e, Vector3(1.5, 2.2, 0.4), Palette.SIGNAL_DANGER)
		world.add_child(e)

# --- Pursuit + minigame wiring (closes ↩ From 10 / ↩ From 07) --------------
func _collect_reinforce_points() -> void:
	for rp in layout.reinforce_points:
		_reinforce_points.append(rp.get("pos", Vector3.ZERO))
	if _reinforce_points.is_empty() and layout.entry_index >= 0:
		_reinforce_points.append(layout.sections[layout.entry_index].center_world(CELL))

func _build_pursuit() -> void:
	_director = PursuitDirector.new()
	_director.name = "PursuitDirector"
	add_child(_director)
	_director.reinforcements_requested.connect(_on_reinforcements)

func _build_minigame_host(world: Node3D) -> void:
	_host = MinigameHost.new()
	_host.name = "MinigameHost"
	add_child(_host)
	_host.attach_all(world)

func _on_reinforcements(tier: StringName, count: int) -> void:
	if _reinforce_points.is_empty():
		return
	var world := get_node_or_null("World")
	if world == null:
		return
	for i in count:
		var pos: Vector3 = _reinforce_points[_reinforce_cursor % _reinforce_points.size()]
		_reinforce_cursor += 1
		_spawn_guard(world, tier, pos, 1.0 + 0.15 * float(maxi(0, contract.tier - 1)), &"")

# --- Debug / QA affordances (Part C; gated OFF in release builds) ----------
## Port the greybox's testing keys into a *realized* mission so the going-loud / down → self-revive →
## Catch loop is reproducible from the real New Game flow (not only the F6 greybox). Inert unless
## GameManager.debug_mode (defaults to OS.is_debug_build()), so an exported release never sees these.
func _debug_enabled() -> bool:
	return GameManager != null and GameManager.debug_mode

func _unhandled_input(event: InputEvent) -> void:
	if not _debug_enabled():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_L:   # force go-loud (no scripted alarm exists yet) — drives RunManager + PursuitDirector
			var p := _debug_player()
			EventBus.alarm_tripped.emit("loud", p.global_position if p != null else global_position)
		KEY_K:   # self-damage — exercise down / self-revive / Catch without relying on AI aim
			var p := _debug_player()
			if p != null and p.has_method("apply_damage"):
				p.apply_damage(_DEBUG_SELF_DAMAGE)
		KEY_J:   # spawn a responder at a reinforcement anchor via the real pursuit spawn path
			_on_reinforcements(&"responder", 1)
		KEY_H:   # arm the player with a dev loadout (a fresh player is unarmed by design) so firing is testable
			_debug_arm_player()

func _debug_player() -> Node3D:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"player") as Node3D

## Dev-unlock + equip the dev gear onto the Streak loadout, then rebuild the player's weapons so `fire`
## works immediately (a real mission's player is otherwise unarmed until the Armory).
func _debug_arm_player() -> void:
	if RunManager == null or ProgressionManager == null or Content == null:
		return
	var lo := RunManager.loadout()
	for gid in _DEBUG_GEAR:
		if gid not in ProgressionManager.unlocked_gear:
			ProgressionManager.unlocked_gear.append(gid)
		var gd := Content.gear.get_def(gid) as GearDef
		if gd != null:
			lo.equip(gd)
	var p := _debug_player()
	if p != null and p.has_method("rebuild_weapons"):
		p.rebuild_weapons()

func _build_debug_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugHint"
	layer.layer = 45
	add_child(layer)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lbl.position = Vector2(16, 16)
	lbl.text = "[DEBUG]  L go-loud · K self-damage · J spawn responder · H arm weapon"
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)

func _spawn_player(world: Node3D) -> void:
	if get_tree() != null and not get_tree().get_nodes_in_group(&"player").is_empty():
		return   # a scene (greybox) already placed a player
	var player := _PLAYER_SCENE.instantiate()
	var spawn := _primary_entry_point()
	player.position = spawn + Vector3(0, 0.2, 0)
	world.add_child(player)
	if _host != null:
		_host.player_path = _host.get_path_to(player)

func _primary_entry_point() -> Vector3:
	if not layout.entry_points.is_empty():
		return layout.entry_points[0].get("pos", Vector3.ZERO)
	if layout.entry_index >= 0:
		return layout.sections[layout.entry_index].center_world(CELL)
	return Vector3.ZERO

# --- Mission state / end (closes Escape.gd TODO[11]) -----------------------
func _on_objective_updated(objective_id: String, complete: bool) -> void:
	objectives_done[objective_id] = complete
	if complete and objective_id == "escape":
		_finish("success")

func _on_loot_secured(_loot_id: String, value: int) -> void:
	secured_value += value

func _finish(outcome: String) -> void:
	if _finished:
		return
	_finished = true
	# Performance flags for the Notoriety multiplier stack (task 12, FR-12-1): time vs par, whether
	# any lethal takedown happened, and whether the bonus objective was cleared. RunManager derives
	# no_alarm / stealth from its own per-mission tracking.
	var summary := {"outcome": outcome, "secured_value": secured_value,
		"objective_id": String(contract.objective_id) if contract != null else "",
		"elapsed_seconds": float(Time.get_ticks_msec() - _start_msec) / 1000.0,
		"no_kill": _lethal_body_count() == 0,
		"full_clear": _bonus_objective_cleared()}
	EventBus.mission_completed.emit(summary)
	var gm := Services.game()
	if gm != null and gm.has_method("goto_results"):
		gm.goto_results(summary)

## Number of lethal Bodies left in the world (guards killed rather than choked out) — 0 earns the
## no-kill bonus. Reads the frozen &"body" group + Body.lethal (no new signal needed).
func _lethal_body_count() -> int:
	var count := 0
	for b in get_tree().get_nodes_in_group(&"body"):
		if b is Body and b.lethal:
			count += 1
	return count

## The optional bonus objective (if the contract has one) was completed — the "full clear". With no
## bonus objective there is nothing extra to miss, so it counts as a full clear.
func _bonus_objective_cleared() -> bool:
	if contract == null or contract.bonus_objective_id == &"":
		return true
	return bool(objectives_done.get(String(contract.bonus_objective_id), false))

# --- Small build helpers ---------------------------------------------------
## A box collider (+ optional visible tinted mesh) under `parent`. `visible == false` gives an invisible
## collider — used when real art (task 18) supplies the look but the raw mesh has no collider of its own.
func _add_marker_body(parent: Node3D, size: Vector3, color: Color, visible := true) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	if visible:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.material_override = mat
		body.add_child(mesh)
	parent.add_child(body)

## Instances an art scene (character / loot / prop prefab) as a visual child at a local offset, playing an
## idle clip if it has one so characters don't T-pose. Task 18. Returns the instance.
func _add_model(parent: Node3D, scene: PackedScene, local_pos: Vector3) -> Node3D:
	var inst := scene.instantiate()
	if inst is Node3D:
		(inst as Node3D).position = local_pos
	parent.add_child(inst)
	_play_idle(inst)
	return inst as Node3D

func _play_idle(root: Node) -> void:
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		var player := ap as AnimationPlayer
		var list := player.get_animation_list()
		if list.is_empty():
			return
		var anim_name: String = "Idle" if player.has_animation("Idle") else String(list[0])
		var a := player.get_animation(anim_name)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
		player.play(anim_name)
		return

## A thin emissive feet-ring marking an actor's role (blue guard / gold keycard-carrier / cyan civilian) —
## keeps the threat read legible even in shadow now the body is a full character model. Task 18.
func _role_ring(color: Color, local_pos: Vector3) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.55
	ring.mesh = tm
	ring.position = local_pos
	var mat := Palette.tinted(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	ring.material_override = mat
	return ring

func _add_labeled_marker(world: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos + Vector3(0, size.y * 0.5, 0)
	_add_marker_body(n, size, color)
	world.add_child(n)
	return n

func _edge_midpoint(edge_index: int) -> Vector3:
	if edge_index < 0 or edge_index >= layout.edges.size():
		return Vector3.ZERO
	var e := layout.edges[edge_index]
	var a: PlacedSection = layout.sections[int(e.a)]
	var b: PlacedSection = layout.sections[int(e.b)]
	return (a.center_world(CELL) + b.center_world(CELL)) * 0.5

# --- Content resolution ----------------------------------------------------
func _enemy_def(id: StringName) -> EnemyDef:
	return Content.enemies.get_def(id) as EnemyDef if Content != null and Content.enemies != null else null

func _obstacle_def(id: StringName) -> ObstacleDef:
	return Content.obstacles.get_def(id) as ObstacleDef if Content != null and Content.obstacles != null else null

func _ai_config() -> AIConfigDef:
	return Content.ai.get_def(&"default") as AIConfigDef if Content != null and Content.ai != null else null

func _detection_config() -> DetectionConfigDef:
	return Content.detection.get_def(&"default") as DetectionConfigDef if Content != null and Content.detection != null else null
