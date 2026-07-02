extends CharacterBody3D
class_name GuardAI
## Patrol guard: a lightweight state machine driven by its child DetectionSensor (04).
## Patrols waypoints → investigates the last-known spot on a noise/half-sighting → does a local
## search → resumes; converges/raises when a nearby guard spots the player or finds a body
## (Phase 05.2 coordination). Takedownable: leaves a discoverable Body and arms a RadioCheckin.
## Combat (COMBAT state) is a converge-only placeholder until task 10 wires the cover-shooter.
## Movement/threshold tunables come from AIConfigDef (Content.ai), per-actor senses from EnemyDef
## — no magic numbers. See docs/tasks/05_ai_actors.md and GDD §8.3-§8.5.

enum AIState { PATROL, INVESTIGATE, SEARCH, COMBAT, DOWNED }

const _GRAVITY := 9.8       ## fall accel; keeps the body grounded (not a gameplay tunable)
const _SEARCH_POINTS := 4   ## sweep points visited around the search center (geometry, not a tunable)

@export var def: EnemyDef                ## per-actor archetype (senses/health/speed); FR-05-9
@export var ai_config: AIConfigDef       ## behavior tunables; falls back to Content.ai's &"default"
@export var patrol_path: NodePath        ## a node whose Node3D children are the patrol waypoints
@export var sensor_path: NodePath        ## the DetectionSensor (auto-found among children if unset)

var ai_state: int = AIState.PATROL
var radio: RadioCheckin                  ## armed when this guard is taken down (Phase 05.2)

var _sensor: DetectionSensor
var _waypoints: Array[Vector3] = []
var _patrol_index: int = 0
var _timer: float = 0.0                  ## multipurpose per-state countdown (pause/timeout/search)
var _investigate_target: Vector3 = Vector3.ZERO
var _has_investigate_target: bool = false
var _search_center: Vector3 = Vector3.ZERO   ## anchor for the local SEARCH sweep (the lost-contact spot)
var _search_point_index: int = 0

func _ready() -> void:
	add_to_group(&"guard")
	if def == null and Content != null and Content.enemies != null:
		def = Content.enemies.get_def(&"guard") as EnemyDef
	if def == null:
		def = EnemyDef.new()   # data-driven defaults; avoids magic-number speeds in logic
	if ai_config == null and Content != null and Content.ai != null:
		ai_config = Content.ai.get_def(&"default") as AIConfigDef
	if ai_config == null:
		ai_config = AIConfigDef.new()
	_resolve_sensor()
	_resolve_waypoints()
	if not EventBus.detection_changed.is_connected(_on_detection_changed):
		EventBus.detection_changed.connect(_on_detection_changed)
	if not EventBus.player_spotted.is_connected(_on_player_spotted):
		EventBus.player_spotted.connect(_on_player_spotted)
	if not EventBus.body_discovered.is_connected(_on_body_discovered):
		EventBus.body_discovered.connect(_on_body_discovered)

func _exit_tree() -> void:
	if EventBus.detection_changed.is_connected(_on_detection_changed):
		EventBus.detection_changed.disconnect(_on_detection_changed)
	if EventBus.player_spotted.is_connected(_on_player_spotted):
		EventBus.player_spotted.disconnect(_on_player_spotted)
	if EventBus.body_discovered.is_connected(_on_body_discovered):
		EventBus.body_discovered.disconnect(_on_body_discovered)

func _resolve_sensor() -> void:
	if sensor_path != NodePath() and has_node(sensor_path):
		_sensor = get_node(sensor_path) as DetectionSensor
	if _sensor == null:
		for c in get_children():
			if c is DetectionSensor:
				_sensor = c
				break
	if _sensor != null and def != null and _sensor.enemy_def == null:
		_sensor.enemy_def = def

func _resolve_waypoints() -> void:
	_waypoints.clear()
	if patrol_path == NodePath() or not has_node(patrol_path):
		return
	for c in get_node(patrol_path).get_children():
		if c is Node3D:
			_waypoints.append((c as Node3D).global_position)

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Next waypoint in a looping route.
func next_waypoint_index(current: int, count: int) -> int:
	if count <= 0:
		return 0
	return (current + 1) % count

## Map a DetectionSensor state to the guard's behavior state.
func ai_state_for_detection(det_state: int) -> int:
	match det_state:
		DetectionSensor.DetectionState.SUSPICIOUS:
			return AIState.INVESTIGATE
		DetectionSensor.DetectionState.SEARCHING:
			return AIState.SEARCH
		DetectionSensor.DetectionState.ALERTED, DetectionSensor.DetectionState.PURSUIT:
			return AIState.COMBAT
		_:
			return AIState.PATROL

## Alertness rank of a behavior state (PATROL < INVESTIGATE < SEARCH < COMBAT). Used to gate
## detection reactions to *escalation only* — decay-driven downgrades must not yank the guard
## out of an in-progress search; its own state timers own the wind-down (FR-05-1).
func behavior_severity(s: int) -> int:
	match s:
		AIState.INVESTIGATE: return 1
		AIState.SEARCH: return 2
		AIState.COMBAT: return 3
		_: return 0   # PATROL (DOWNED is handled before this is ever consulted)

## Within `radius` of `target`? (arrival / discovery / propagation test).
func reached(from_pos: Vector3, target: Vector3, radius: float) -> bool:
	return from_pos.distance_to(target) <= radius

## Count a per-state timer down, floored at 0.
func tick_timer(t: float, dt: float) -> float:
	return maxf(t - dt, 0.0)

## Is a teammate (or event) at `other` close enough for this guard to react? (FR-05-2).
func within_propagation_radius(from_pos: Vector3, other: Vector3, radius: float) -> bool:
	return from_pos.distance_to(other) <= radius

## Resolution of an INVESTIGATE: arriving starts a local SEARCH; timing out gives up to PATROL.
func investigate_next(arrived: bool, timed_out: bool) -> int:
	if arrived:
		return AIState.SEARCH
	if timed_out:
		return AIState.PATROL
	return AIState.INVESTIGATE

## Resolution of a SEARCH: resume PATROL once the sweep time is spent.
func search_next(timed_out: bool) -> int:
	return AIState.PATROL if timed_out else AIState.SEARCH

## A local-sweep waypoint offset around the search center: a deterministic ring of points at
## `radius`, so SEARCH actually walks the area (reads AIConfigDef.search_radius) instead of
## freezing in place. `index` advances as each point is reached.
func search_offset(index: int, radius: float) -> Vector3:
	var a := TAU * float(posmod(index, _SEARCH_POINTS)) / float(_SEARCH_POINTS)
	return Vector3(cos(a) * radius, 0.0, sin(a) * radius)

# --- Tick ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if ai_state == AIState.DOWNED:
		return
	_scan_for_bodies()
	match ai_state:
		AIState.PATROL: _tick_patrol(delta)
		AIState.INVESTIGATE: _tick_investigate(delta)
		AIState.SEARCH: _tick_search(delta)
		AIState.COMBAT: _tick_combat(delta)

func _tick_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		_halt(delta)
		return
	var target := _waypoints[_patrol_index]
	if reached(global_position, target, ai_config.arrival_radius):
		_timer = tick_timer(_timer, delta)
		_halt(delta)
		if _timer <= 0.0:
			_patrol_index = next_waypoint_index(_patrol_index, _waypoints.size())
			_timer = ai_config.waypoint_pause
	else:
		_move_toward(target, def.move_speed * ai_config.patrol_speed_mult, delta)

func _tick_investigate(delta: float) -> void:
	var arrived := reached(global_position, _investigate_target, ai_config.arrival_radius)
	_timer = tick_timer(_timer, delta)
	var next := investigate_next(arrived, _timer <= 0.0)
	if next != AIState.INVESTIGATE:
		_set_ai_state(next)
		return
	_move_toward(_investigate_target, def.move_speed * ai_config.investigate_speed_mult, delta)

func _tick_search(delta: float) -> void:
	_timer = tick_timer(_timer, delta)
	if search_next(_timer <= 0.0) == AIState.PATROL:
		_set_ai_state(AIState.PATROL)   # sweep window spent, nothing found → resume patrol
		return
	# Walk a ring of sweep points around the lost-contact spot so "Search" actually searches
	# the area; the cone keeps sensing as it moves.
	var target := _search_center + search_offset(_search_point_index, ai_config.search_radius)
	if reached(global_position, target, ai_config.arrival_radius):
		_search_point_index += 1
		_halt(delta)
	else:
		_move_toward(target, def.move_speed * ai_config.investigate_speed_mult, delta)

func _tick_combat(delta: float) -> void:
	# TODO[10]: cover selection, suppress/peek, flank, advance. For M0 just converge on the
	# last-known position so a spotted player is pressured in the greybox.
	if _sensor != null:
		_move_toward(_sensor.last_seen_position, def.move_speed, delta)
	else:
		_halt(delta)

# --- State entry -----------------------------------------------------------
func _set_ai_state(s: int) -> void:
	if s == ai_state or ai_state == AIState.DOWNED:
		return
	ai_state = s
	match s:
		AIState.INVESTIGATE: _begin_investigate()
		AIState.SEARCH: _begin_search()
		AIState.PATROL: _begin_patrol()
		AIState.COMBAT: pass

## Anchor the sweep at wherever we are now — SEARCH is entered on arriving at the lead
## (via investigate_next) or on discovering a body, so this is the lost-contact spot.
func _begin_search() -> void:
	_search_center = global_position
	_search_point_index = 0
	_timer = ai_config.search_duration

func _begin_investigate() -> void:
	if not _has_investigate_target:
		if _sensor != null and _sensor.has_target:
			_investigate_target = _sensor.last_seen_position
		elif _sensor != null:
			_investigate_target = _sensor.last_heard_position
		else:
			_investigate_target = global_position
	_has_investigate_target = false
	_timer = ai_config.investigate_timeout

func _begin_patrol() -> void:
	_timer = 0.0   # head straight to the current waypoint, then pause on arrival

# --- Takedown / body / radio (FR-05-2, FR-05-3) ----------------------------
## Non-lethal or lethal takedown: stop, drop a discoverable Body, arm the radio check-in. The
## spawned Body is the guard's physical remains from this point on, so the guard actor itself
## (mesh/collision/sensor) is removed rather than left behind frozen in place alongside it.
func take_down(lethal: bool = false) -> void:
	if ai_state == AIState.DOWNED:
		return
	ai_state = AIState.DOWNED
	velocity = Vector3.ZERO
	if _sensor != null:
		_sensor.set_physics_process(false)
	_spawn_body(lethal)
	if ai_config != null:
		radio = RadioCheckin.new(ai_config.max_fakeable_checkins, global_position)
	queue_free()

func _spawn_body(lethal: bool) -> void:
	var body := Body.new()
	body.lethal = lethal
	body.carried_item = def.carried_item if def != null else &""
	var host := get_parent()
	if host != null:
		host.add_child(body)
		body.global_position = global_position

# --- Body discovery scan (FR-05-2) -----------------------------------------
func _scan_for_bodies() -> void:
	if _sensor == null or not is_inside_tree():
		return
	var origin := _sensor.global_position
	var forward := -_sensor.global_transform.basis.z
	var half_angle := deg_to_rad(_sensor.cone_angle_deg() * 0.5)
	var rng := ai_config.body_discovery_range
	for b in get_tree().get_nodes_in_group(&"body"):
		if not (b is Body):
			continue
		var body := b as Body
		if body.discovered or body.concealed:
			continue
		var in_cone := _sensor.is_in_cone(origin, forward, body.global_position, half_angle, rng)
		if not in_cone:
			continue
		if Body.raises_alarm(body.concealed, in_cone, _has_los(origin, body.global_position)):
			body.discover()
			# Head to the body and search there (unless already more alert, e.g. in combat).
			if behavior_severity(AIState.INVESTIGATE) > behavior_severity(ai_state):
				_investigate_target = body.global_position
				_has_investigate_target = true
				_set_ai_state(AIState.INVESTIGATE)

func _has_los(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()

# --- Detection / coordination signals --------------------------------------
func _on_detection_changed(actor_id: int, det_state: int, _fill: float) -> void:
	if ai_state == AIState.DOWNED:
		return
	if _sensor != null and actor_id == _sensor.get_instance_id():
		_react_to_own_detection(det_state)
	elif det_state >= DetectionSensor.DetectionState.SEARCHING:
		_propagate_from(actor_id)

## React to *our own* sensor. Only escalates: a rising meter promotes the guard, but a
## decaying meter (the norm once the player is lost) must NOT interrupt an in-progress
## investigate/search — those wind down on their own timers (investigate_next/search_next),
## which is how "investigate → local search → resume" actually completes (FR-05-1). A spot
## goes straight to COMBAT; any lesser lead routes through INVESTIGATE first so the guard
## walks to the contact before sweeping (rather than searching wherever it happens to stand).
func _react_to_own_detection(det_state: int) -> void:
	var want := ai_state_for_detection(det_state)
	if behavior_severity(want) <= behavior_severity(ai_state):
		return
	if want == AIState.COMBAT:
		_set_ai_state(AIState.COMBAT)
	else:
		_has_investigate_target = false   # investigate the spot our own sensor tracked
		_set_ai_state(AIState.INVESTIGATE)

func _on_player_spotted(by_actor_id: int) -> void:
	if ai_state == AIState.DOWNED:
		return
	if _sensor != null and by_actor_id == _sensor.get_instance_id():
		_set_ai_state(AIState.COMBAT)
	else:
		_propagate_from(by_actor_id)   # ally spotted the player → converge

func _on_body_discovered(position: Vector3) -> void:
	if ai_state == AIState.DOWNED:
		return
	if ai_state == AIState.PATROL and within_propagation_radius(global_position, position, ai_config.alert_propagation_radius):
		_investigate_target = position
		_has_investigate_target = true
		_set_ai_state(AIState.INVESTIGATE)

## A nearby teammate raised the alarm at `actor_id`'s sensor: converge to investigate (FR-05-2).
func _propagate_from(actor_id: int) -> void:
	if ai_state != AIState.PATROL:
		return
	var src := instance_from_id(actor_id)
	if src is Node3D and within_propagation_radius(global_position, (src as Node3D).global_position, ai_config.alert_propagation_radius):
		_investigate_target = (src as Node3D).global_position
		_has_investigate_target = true
		_set_ai_state(AIState.INVESTIGATE)

# --- Movement helpers ------------------------------------------------------
func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.05:
		var dir := to / dist
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		look_at(global_position + dir, Vector3.UP)   # face travel so the cone leads the way
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()

func _halt(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _GRAVITY * delta
