extends Node3D
class_name DetectionSensor
## Vision-cone + light + distance + sound detection accumulator. Attach to guards/cameras
## at eye height; faces -Z (Node3D forward). Builds a 0..1 detection meter toward the
## player and drives the five detection states, emitting on EventBus for AI (05), HUD (15),
## and audio (17). Core fill math is pure & deterministic (FR-04-7); per-actor cone geometry
## comes from EnemyDef, all curve/threshold tunables from DetectionConfigDef.
## See docs/tasks/04_stealth_detection.md and GDD §8.1-§8.3.

enum DetectionState { UNAWARE, SUSPICIOUS, SEARCHING, ALERTED }

## Curve/threshold tunables. Falls back to Content.detection's default if left unset.
@export var config: DetectionConfigDef
## Per-actor cone/hearing geometry. Falls back to the vision_angle_deg/vision_range below.
@export var enemy_def: EnemyDef
@export var vision_angle_deg: float = 90.0   ## full cone angle (used when enemy_def is unset)
@export var vision_range: float = 14.0
@export var hearing_radius: float = 8.0

var state: int = DetectionState.UNAWARE
var fill: float = 0.0              ## 0..1 detection meter toward the player
var has_target: bool = false       ## true once the player has been seen this life
var last_seen_position: Vector3 = Vector3.ZERO    ## consumed by GuardAI (05)
var last_heard_position: Vector3 = Vector3.ZERO    ## consumed by GuardAI (05)

const _FILL_EMIT_EPSILON := 0.02   ## throttle per-tick detection_changed to meaningful deltas
var _last_emitted_fill: float = 0.0
var _accum_delta: float = 0.0      ## time since the last full sense (LOD staggers senses; step_fill gets the real elapsed)

func _ready() -> void:
	# Content is an autoload; fall back to the registered default config when unassigned.
	if config == null and Content != null and Content.detection != null:
		config = Content.detection.get_def(&"default") as DetectionConfigDef
	# PursuitDirector polls this group's `fill` to decide whether the law still has contact (issue 1).
	add_to_group(&"detection_sensor")
	if not EventBus.noise_emitted.is_connected(_on_noise_emitted):
		EventBus.noise_emitted.connect(_on_noise_emitted)
	if not EventBus.pursuit_phase_changed.is_connected(_on_pursuit_phase_changed):
		EventBus.pursuit_phase_changed.connect(_on_pursuit_phase_changed)

func _exit_tree() -> void:
	if EventBus.noise_emitted.is_connected(_on_noise_emitted):
		EventBus.noise_emitted.disconnect(_on_noise_emitted)
	if EventBus.pursuit_phase_changed.is_connected(_on_pursuit_phase_changed):
		EventBus.pursuit_phase_changed.disconnect(_on_pursuit_phase_changed)
	# Announce we're no longer detecting anything, so the HUD/CompassEye drop this actor. Without this, a
	# taken-down/killed guard's last detection state lingers forever (no more ticks to decay it), leaving
	# the compass "suspicious" with no guard actually aware of the player.
	if Engine.get_main_loop() is SceneTree:
		EventBus.detection_changed.emit(get_instance_id(), DetectionState.UNAWARE, 0.0)

# --- Geometry resolution (per-actor from EnemyDef, else local @exports) -----
func cone_angle_deg() -> float:
	return enemy_def.vision_angle if enemy_def != null else vision_angle_deg

func cone_range() -> float:
	return enemy_def.vision_range if enemy_def != null else vision_range

func hearing() -> float:
	return enemy_def.hearing_radius if enemy_def != null else hearing_radius

# --- Per-tick sensing ------------------------------------------------------
func _physics_process(delta: float) -> void:
	if config == null or not is_inside_tree():
		return
	_accum_delta += delta
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		fill = step_fill(fill, 0.0, delta)
		_accum_delta = 0.0
		_update_state()
		return
	# AI performance LOD (task 21, FR-21-2): the full sense (cone + multi-ray LoS + light) is the hotspot, so
	# throttle it by distance and stagger guards across frames. Near enough to actually see → every frame
	# (behaviour unchanged); far → occasional; beyond sleep range → skipped (can't gain fill out there anyway).
	var dist := global_position.distance_to((player as Node3D).global_position)
	var interval := sense_interval_for_distance(dist, config)
	if interval <= 0:
		_accum_delta = 0.0   # sleeping: fill holds; drop accumulated time so waking doesn't jump
		return
	if not should_sense(Engine.get_physics_frames(), int(get_instance_id()) % interval, interval):
		return
	var elapsed := minf(_accum_delta, 0.5)   # clamp against a physics stall
	_accum_delta = 0.0
	_sense_player(player, elapsed)

## The full per-actor sense: cone test → multi-ray LoS/cover → distance/light/movement → advance the meter.
## `delta` is the real time since the previous sense (LOD may skip frames), so the meter stays framerate-fair.
func _sense_player(player: Node, delta: float) -> void:
	var origin := global_position
	var forward := -global_transform.basis.z
	var target_pos: Vector3 = (player as Node3D).global_position
	var half_angle := deg_to_rad(cone_angle_deg() * 0.5)
	# Heightened awareness once the level is ALERTED (a pursuit happened and was shaken off): the sensor
	# sees FURTHER and fills FASTER for the rest of the mission. Applied here in the node glue only — the
	# pure seams stay untouched, so the task-04 detection tests are unaffected.
	var max_range := cone_range() * _range_mult()

	var gain := 0.0
	if is_in_cone(origin, forward, target_pos, half_angle, max_range):
		var visibility := _visibility_fraction(origin, player)
		if visibility > 0.0:
			var d := origin.distance_to(target_pos)
			var df := distance_factor(d, max_range)
			var light := _sample_light_level(target_pos)
			var stance_profile := _target_stance_profile(player)
			var mf := movement_factor(_target_speed(player))
			gain = compute_fill_rate(df, light, stance_profile, mf, visibility) * _gain_mult()
			has_target = true
			last_seen_position = target_pos

	fill = step_fill(fill, gain, delta)
	_update_state()

# --- Alert-state awareness (misc-fixes-3 issue 1) --------------------------
## Is the mission in the post-pursuit ALERTED state? Deliberately NOT keyed to PURSUIT as well: during a
## pursuit the convergence behaviour IS the response, and a silent alarm arms a pursuit that must stay
## invisible to the player (guards would visibly sharpen). Null-guarded for headless/pure tests.
func _alerted() -> bool:
	return RunManager != null and RunManager.alert_state == RunManager.AlertState.ALERTED

func _gain_mult() -> float:
	return config.alerted_gain_mult if config != null and _alerted() else 1.0

func _range_mult() -> float:
	return config.alerted_range_mult if config != null and _alerted() else 1.0

## The pursuit ended (phase 0): drop the ALERTED latch so this sensor can sense — and be spotted-by —
## afresh. Without this, `state` pins at ALERTED for the life of the sensor (discovery.md #3) and the
## guard never leaves COMBAT. `has_target` must clear with the fill, or the guard's next investigate
## would chase the stale pre-pursuit last_seen_position instead of a fresher heard-noise lead.
func _on_pursuit_phase_changed(phase: int) -> void:
	if phase == 0:
		_deescalate()

func _deescalate() -> void:
	fill = 0.0
	has_target = false
	_last_emitted_fill = 0.0
	if state != DetectionState.UNAWARE:
		_set_state(DetectionState.UNAWARE)   # emits detection_changed so the HUD/compass drop too

## Frames between full senses for a guard `dist` metres from the player (LOD): 1 (every frame) when near
## enough to see, throttled at mid range, 0 (sleep) beyond the sleep range. Pure. (FR-21-2)
static func sense_interval_for_distance(dist: float, cfg: DetectionConfigDef) -> int:
	if cfg == null:
		return 1
	if dist <= cfg.lod_full_range:
		return 1
	if dist <= cfg.lod_mid_range:
		return maxi(1, cfg.lod_mid_interval)
	if dist <= cfg.lod_sleep_range:
		return maxi(1, cfg.lod_far_interval)
	return 0   # sleep — too far to matter this frame

## Round-robin gate: a sensor with stagger `phase` senses on physics `frame` at cadence `interval`. Pure.
static func should_sense(frame: int, phase: int, interval: int) -> bool:
	if interval <= 1:
		return true
	return (frame + phase) % interval == 0

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Is `target` inside the cone defined by `origin`, `forward`, half-angle and range?
func is_in_cone(origin: Vector3, forward: Vector3, target: Vector3, half_angle_rad: float, max_range: float) -> bool:
	var to_target := target - origin
	var dist := to_target.length()
	if dist > max_range or dist <= 0.0001:
		return dist <= 0.0001   # zero distance = on top of the sensor = inside
	var fwd := forward.normalized()
	var ang := fwd.angle_to(to_target / dist)
	return ang <= half_angle_rad

## 1.0 at point blank → 0.0 at max range. Closer always fills faster.
func distance_factor(distance: float, max_range: float) -> float:
	if max_range <= 0.0:
		return 0.0
	var t := clampf(1.0 - distance / max_range, 0.0, 1.0)
	var exp_v := config.distance_falloff_exp if config != null else 1.0
	return pow(t, exp_v)

## Faster movement is more visible: still < walking < running.
func movement_factor(speed: float) -> float:
	if config == null:
		return 1.0
	if speed < config.walk_speed:
		return config.still_factor
	if speed < config.run_speed:
		return config.walk_factor
	return config.run_factor

## Fill rate (fill/sec) from the combined modifiers. All inputs in 0..1 except the rate.
func compute_fill_rate(dist_factor: float, light_level: float, stance_profile: float, move_factor: float, visibility_fraction: float) -> float:
	var base := config.see_gain_rate if config != null else 1.0
	return base * dist_factor * light_level * stance_profile * move_factor * visibility_fraction

## Advance the meter one step: gain while visible (rate > 0), else decay. Clamped 0..1.
func step_fill(current: float, gain_rate: float, delta: float) -> float:
	if gain_rate > 0.0:
		return clampf(current + gain_rate * delta, 0.0, 1.0)
	var decay := config.decay_rate if config != null else 0.0
	return clampf(current - decay * delta, 0.0, 1.0)

## State for a meter value, ignoring history (no latch).
func state_for_fill(f: float) -> int:
	if config == null:
		return DetectionState.UNAWARE
	if f >= config.alerted_threshold:
		return DetectionState.ALERTED
	if f >= config.searching_threshold:
		return DetectionState.SEARCHING
	if f >= config.suspicious_threshold:
		return DetectionState.SUSPICIOUS
	return DetectionState.UNAWARE

## Next state from the current one and the meter. Alerted latches — "full detection commits the location
## to alert" (GDD §8.3); Suspicious/Searching recover as fill decays. The latch is released only by
## _deescalate() when the pursuit ends (issue 1), never by decay.
func step_state(current_state: int, f: float) -> int:
	if current_state == DetectionState.ALERTED:
		return current_state
	return state_for_fill(f)

## Fill bump from an audible noise, scaled by closeness. Audible within the larger of the
## noise's own carry radius and the sensor's hearing radius (keen-eared actors hear quiet
## noises too). Returns 0.0 if out of range.
## NOTE: this is the DISTANCE half only — multiply by loudness_factor() for how loud the noise
## actually was. See _on_noise_emitted.
func hearing_bump(noise_radius: float, noise_pos: Vector3, sensor_pos: Vector3, sensor_hearing: float, gain: float) -> float:
	var reach := maxf(noise_radius, sensor_hearing)
	if reach <= 0.0:
		return 0.0
	var dist := noise_pos.distance_to(sensor_pos)
	if dist > reach:
		return 0.0
	return gain * (1.0 - dist / reach)

## How much of the full bump a noise of this radius lands: 1.0 once it's as loud as `reference`,
## scaling down linearly for quieter ones. This is what makes a crouch-step register less than a
## standing step and a sprint saturate — before it, `hearing_bump` used the radius ONLY to widen the
## reach, so every footstep filled a guard's meter identically regardless of how quiet it was. Pure.
static func loudness_factor(noise_radius: float, reference: float) -> float:
	if reference <= 0.0:
		return 1.0
	return clampf(noise_radius / reference, 0.0, 1.0)

# --- Sound channel (FR-04-4) -----------------------------------------------
func _on_noise_emitted(position: Vector3, radius: float, source: String) -> void:
	if config == null or not is_inside_tree():
		return
	# Distance × LOUDNESS: a quiet noise close by must register less than a loud one at the same spot,
	# or the player's stance/Silence/surface choices buy them nothing against a guard's ears.
	var bump := hearing_bump(radius, position, global_position, hearing(), config.sound_gain) \
		* loudness_factor(radius, config.sound_reference_radius)
	if bump <= 0.0:
		return
	last_heard_position = position
	# Sound raises suspicion toward the source but never fully spots (cap < alerted).
	if fill < config.sound_fill_cap:
		fill = minf(fill + bump, config.sound_fill_cap)
	_update_state()

# --- State application + signals -------------------------------------------
func _update_state() -> void:
	var next := step_state(state, fill)
	if next == DetectionState.ALERTED and state != DetectionState.ALERTED:
		EventBus.player_spotted.emit(get_instance_id())
	_set_state(next)
	_maybe_emit_fill()

func _set_state(s: int) -> void:
	if s != state:
		state = s
		_last_emitted_fill = fill
		EventBus.detection_changed.emit(get_instance_id(), state, fill)

## Emit detection_changed on a meaningful fill delta even without a state change, so the
## HUD cone-fill meter (15) tracks the meter smoothly.
func _maybe_emit_fill() -> void:
	if absf(fill - _last_emitted_fill) >= _FILL_EMIT_EPSILON:
		_last_emitted_fill = fill
		EventBus.detection_changed.emit(get_instance_id(), state, fill)

# --- Node-bound sampling (in-tree only; not unit-tested) -------------------
## Fraction of LoS sample points with a clear ray to the target. 0 = full cover (blocks),
## (0,1) = partial cover (reduces fill), 1 = full visibility. Unifies LoS + cover (FR-04-2).
func _visibility_fraction(origin: Vector3, player: Node) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return 0.0
	var heights: Array[float] = config.los_sample_heights if config != null and not config.los_sample_heights.is_empty() else [1.0]
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude = [(player as CollisionObject3D).get_rid()]
	var clear := 0
	for h in heights:
		var to: Vector3 = (player as Node3D).global_position + Vector3.UP * h
		var q := PhysicsRayQueryParameters3D.create(origin, to)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			clear += 1
	return float(clear) / float(heights.size())

## Sampled light at `pos`: 1.0 lit → config.min_light_factor in shadow. FR-04-5 / world-gen Phase 1C.
##   1. An explicit &"shadow" Area3D always forces shadow (authored dark zones; a shot-out light). Wins.
##   2. Fixture-driven model: a mission scatters LightFixtures (group &"lit") under its ceilings — a point
##      is lit ONLY inside a fixture's pool, shadowed everywhere else. Cutting/shooting a light removes its
##      pool → the area goes dark → detection eases (closes the 06/§9.5 shoot/switch hook for real).
##   3. No fixtures in the scene at all (every pre-existing greybox + unit test) → fully lit, unchanged.
func _sample_light_level(pos: Vector3) -> float:
	if config == null:
		return 1.0
	for node in get_tree().get_nodes_in_group(&"shadow"):
		if node is Area3D and _area_contains(node as Area3D, pos):
			return config.min_light_factor
	var fixtures := get_tree().get_nodes_in_group(&"lit")
	if fixtures.is_empty():
		return 1.0
	for f in fixtures:
		if f is Node3D and f.has_method(&"lights_point") and (f as Object).call(&"lights_point", pos):
			return 1.0
	return config.min_light_factor

func _area_contains(area: Area3D, pos: Vector3) -> bool:
	for body in area.get_overlapping_bodies():
		if body is Node3D and (body as Node3D).global_position.distance_to(pos) < 2.0:
			return true
	return false

# --- Target readouts (degrade gracefully if the player lacks them) ----------
func _target_stance_profile(player: Node) -> float:
	if player.has_method(&"detection_profile"):
		return player.call(&"detection_profile", player.get(&"stance"))
	return 1.0

func _target_speed(player: Node) -> float:
	var v = player.get(&"velocity")
	if v is Vector3:
		return Vector2(v.x, v.z).length()
	return 0.0
