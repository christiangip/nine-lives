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

## Called by MissionGenerator.build() before this node enters the tree.
func setup(p_layout: MissionLayout, p_contract: Contract) -> void:
	layout = p_layout
	contract = p_contract

func _ready() -> void:
	add_to_group(&"mission_root")
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
	_build_floor(world)
	_build_sections(world)
	_build_actors(world)
	_build_obstacles(world)
	_build_loot(world)
	_build_banking(world)
	_collect_reinforce_points()
	_build_pursuit()
	_build_minigame_host(world)
	_spawn_player(world)

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
	floor_body.add_child(mesh)
	world.add_child(floor_body)

func _build_sections(world: Node3D) -> void:
	for ps in layout.sections:
		var tile := MeshInstance3D.new()
		tile.name = "Section_%d_%s" % [ps.index, ps.def.id]
		var bm := BoxMesh.new()
		bm.size = Vector3(float(ps.size().x) * CELL - 0.6, 0.1, float(ps.size().y) * CELL - 0.6)
		tile.mesh = bm
		tile.position = ps.center_world(CELL) + Vector3(0, 0.06, 0)
		var mat := StandardMaterial3D.new()
		var t := clampf(float(ps.def.security_tier) / 3.0, 0.0, 1.0)
		mat.albedo_color = Color(0.25 + t * 0.5, 0.35 - t * 0.2, 0.4 - t * 0.25, 1.0)
		tile.material_override = mat
		world.add_child(tile)

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
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35; cm.height = 1.8
	mesh.mesh = cm
	guard.add_child(mesh)
	# detection sensor child (auto-found by GuardAI)
	var sensor := Node3D.new()
	sensor.name = "Sensor"
	sensor.set_script(load("res://game/systems/stealth/DetectionSensor.gd"))
	sensor.position = Vector3(0, 0.7, 0)
	sensor.set("enemy_def", edef)
	var det_cfg := _detection_config()
	if det_cfg != null:
		sensor.set("config", det_cfg)
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
		_spawn_obstacle(world, StringName(g.get("obstacle_id", &"")), pos)
	for h in layout.hazards:
		_spawn_obstacle(world, StringName(h.get("obstacle_id", &"")), h.get("pos", Vector3.ZERO))

func _spawn_obstacle(world: Node3D, obstacle_id: StringName, pos: Vector3) -> void:
	var odef := _obstacle_def(obstacle_id)
	if odef == null:
		return
	var script: GDScript = _OBSTACLE_SCRIPTS.get(odef.category, load("res://game/systems/obstacles/Obstacle.gd"))
	var node := Node3D.new()
	node.set_script(script)
	node.name = "Obstacle_%s" % obstacle_id
	node.set("def_id", obstacle_id)
	node.position = pos + Vector3(0, 1.0, 0)
	_add_marker_body(node, Vector3(0.8, 2.0, 0.3), Color(0.7, 0.5, 0.2))
	world.add_child(node)

func _build_loot(world: Node3D) -> void:
	for l in layout.loot:
		var node := Node3D.new()
		node.set_script(load("res://game/systems/inventory/LootPickup.gd"))
		node.name = "Loot_%s" % l.get("loot_id", &"")
		node.set("def_id", StringName(l.get("loot_id", &"")))
		node.position = l.get("pos", Vector3.ZERO) + Vector3(0, 0.5, 0)
		var col := Color(0.9, 0.8, 0.2) if bool(l.get("is_mark", false)) else Color(0.8, 0.75, 0.4)
		_add_marker_body(node, Vector3(0.5, 0.5, 0.5), col)
		world.add_child(node)
	for c in layout.consumables:
		_add_labeled_marker(world, "Consumable_%s" % c.get("gear_id", &""), c.get("pos", Vector3.ZERO),
			Vector3(0.35, 0.35, 0.35), Color(0.4, 0.8, 0.9))
	for civ in layout.civilians:
		var m := _add_labeled_marker(world, "Civilian", civ.get("pos", Vector3.ZERO),
			Vector3(0.4, 1.7, 0.4), Color(0.85, 0.85, 0.85))
		m.add_to_group(&"civilian")
		m.set_meta("carried_item", civ.get("carried_item", &""))

func _build_banking(world: Node3D) -> void:
	for dp in layout.drop_points:
		var node := Node3D.new()
		node.set_script(load("res://game/systems/inventory/DropPoint.gd"))
		node.name = "DropPoint"
		node.position = dp.get("pos", Vector3.ZERO) + Vector3(0, 0.5, 0)
		_add_marker_body(node, Vector3(1.0, 1.0, 1.0), Color(0.2, 0.7, 0.3))
		world.add_child(node)
	if layout.escape_index >= 0:
		var e := Node3D.new()
		e.set_script(load("res://game/systems/inventory/Escape.gd"))
		e.name = "Escape"
		e.position = layout.sections[layout.escape_index].center_world(CELL) + Vector3(0, 1.0, 0)
		_add_marker_body(e, Vector3(1.5, 2.2, 0.4), Color(0.9, 0.3, 0.3))
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
	var summary := {"outcome": outcome, "secured_value": secured_value,
		"objective_id": String(contract.objective_id) if contract != null else ""}
	EventBus.mission_completed.emit(summary)
	var gm := Services.game()
	if gm != null and gm.has_method("goto_results"):
		gm.goto_results(summary)

# --- Small build helpers ---------------------------------------------------
func _add_marker_body(parent: Node3D, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	parent.add_child(body)

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
