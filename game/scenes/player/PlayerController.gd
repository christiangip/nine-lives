extends CharacterBody3D
class_name PlayerController
## First-person player controller: locomotion, three stances, stamina, clamped
## mouse/gamepad look, lean/peek, an interaction raycast, and footstep noise. Also a
## first-person *readability surface* — it exposes stance/noise/lean/interaction data
## (local signals + group "player") for the HUD (task 15) and detection (task 04).
## Tunables live in `config` (PlayerConfigDef) so there are no magic numbers here.
## See docs/tasks/03_player_controller_camera.md and GDD §8.0 (Q1 = first-person).

enum Stance { STAND, CROUCH, PRONE }

## Normalized look-sensitivity (SettingsManager "mouse_sensitivity", ~0..1) -> radians
## per mouse count. A unit conversion, not a gameplay tunable.
const _LOOK_UNIT: float = 0.01

@export var config: PlayerConfigDef   ## all tunables; assign default_player.tres in the scene

@onready var _collider: CollisionShape3D = $Collider
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var _ceiling_cast: ShapeCast3D = $CeilingCast
@onready var _lean_cast_l: RayCast3D = $LeanCastL
@onready var _lean_cast_r: RayCast3D = $LeanCastR
@onready var _hands: Node3D = $Head/Hands

# --- Readable state (HUD/detection read these) -----------------------------
var stance: int = Stance.STAND
var stamina: float = 0.0
var noise_level: float = 0.0          ## last emitted footstep radius (m)
var lean_amount: float = 0.0          ## -1..+1, lerped (left..right)

# --- Carry hooks (task 08 writes these) ------------------------------------
var carry_speed_mult: float = 1.0
var can_climb: bool = true
var can_use_vents: bool = true
var inventory: Inventory   ## task 08 carry state; see game/systems/inventory/Inventory.gd
var loadout: Loadout       ## task 09 equipped gear; the Streak's, or a fresh empty fallback

# --- Combat / survivability hooks (task 10) --------------------------------
var health: Health         ## damage/down/capture brain (built from the loadout's Armor)
var _combat: PlayerCombat  ## FP firing controller, mounted under the Hands node

# --- Internal --------------------------------------------------------------
var _pitch: float = 0.0
var _pitch_min: float = -1.55
var _pitch_max: float = 1.55
var _gravity: float = 9.8
var _eye_height: float = 1.6
var _is_sprinting: bool = false
var _sprint_locked: bool = false      ## true after depletion until regen passes the unlock fraction
var _regen_cooldown: float = 0.0
var _step_accum: float = 0.0
var _current_interactable: Interactable = null
var _last_grounded_pos: Vector3 = Vector3.ZERO   ## fall-backstop anchor (world-gen Phase 1A)
var _has_grounded: bool = false
var _hold_timer: float = 0.0          ## -1.0 = an interaction already fired this press (latched)
var _crouch_toggle_state: bool = false
var _sprint_toggle_state: bool = false
# Cached settings (refreshed on EventBus.settings_changed)
var _sens: float = 0.3
var _invert_y: bool = false
var _crouch_toggle: bool = false
var _sprint_toggle: bool = false
var _camera_shake_on: bool = true       ## video/camera_shake
var _reduce_flashing: bool = false      ## gameplay/reduce_flashing (also suppresses shake)

# --- Camera shake (task 21 juice; gated by the two settings above) ----------
var _cam_shake: CameraShake
var _cam_base_rot: Vector3 = Vector3.ZERO   ## the camera's authored local rotation; shake is added on top

signal stance_changed(new_stance: int)
signal stamina_changed(current: float, maximum: float)
signal interaction_target_changed(interactable: Interactable)
signal shot_landed   ## a fired shot connected with a hostile (HUD hit-marker, task 21)

func _ready() -> void:
	add_to_group(&"player")
	if config == null:
		config = PlayerConfigDef.new()   # never crash on a missing config
	_resolve_gravity()
	_pitch_min = deg_to_rad(config.pitch_min_deg)
	_pitch_max = deg_to_rad(config.pitch_max_deg)
	_refresh_settings()
	if not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)
	if not EventBus.alarm_tripped.is_connected(_on_alarm_tripped):
		EventBus.alarm_tripped.connect(_on_alarm_tripped)
	stamina = _stamina_max()
	inventory = Inventory.new()
	inventory.weight_cap = config.carry_weight_base * (1.0 + attr_effect(&"strength"))
	inventory.volume_cap = config.carry_volume_base * (1.0 + attr_effect(&"strength"))
	loadout = _resolve_loadout()
	_build_health()
	_mount_combat()
	_setup_camera_shake()
	# Don't mutate the shared scene resource — each instance gets its own capsule.
	if _collider != null and _collider.shape != null:
		_collider.shape = _collider.shape.duplicate()
	_eye_height = stance_eye_height(stance)
	if _head != null:
		_head.position.y = _eye_height
	if _interact_ray != null:
		_interact_ray.target_position = Vector3(0.0, 0.0, -config.interact_range)
	# The casts start inside our own capsule — don't let them detect the player.
	for ray in [_interact_ray, _lean_cast_l, _lean_cast_r]:
		if ray != null:
			ray.add_exception(self)
	if _ceiling_cast != null:
		_ceiling_cast.add_exception(self)
	_capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var look := _sens * _LOOK_UNIT
		rotation.y -= mm.relative.x * look
		var inv := -1.0 if _invert_y else 1.0
		_pitch = clampf(_pitch - mm.relative.y * look * inv, _pitch_min, _pitch_max)
		if _head != null:
			_head.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	if config == null:
		return
	# The "pause" action itself is owned entirely by HUD/PauseMenu (task 15), including the mouse-mode
	# toggle — this used to also flip Input.mouse_mode here as a pre-task-15 greybox convenience, which
	# left two systems racing to set the same global on the same keypress.
	if health != null:
		health.tick(delta)
		# Self-revive (§8.7): while Downed, a press of the existing "interact" action within the
		# window revives (Health.revive() already gates on state==DOWNED and always succeeds within
		# it — no separate skill-check, unlike Get-Out-of-Jail's capture()). Reuses the existing
		# action rather than a new bindable one to keep this a minimal wire-up of an already-tested seam.
		if health.state == Health.State.DOWNED and Input.is_action_just_pressed(&"interact"):
			health.revive()
	_apply_gamepad_look(delta)
	_update_toggle_inputs()
	_update_stance_input()
	_update_stance_transition(delta)

	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed(&"jump") and stance == Stance.STAND:
		velocity.y = config.jump_velocity

	var input_2d := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish_dir := (transform.basis * Vector3(input_2d.x, 0.0, input_2d.y))
	wish_dir.y = 0.0
	wish_dir = wish_dir.normalized()
	var moving := input_2d.length() > 0.1

	_is_sprinting = _resolve_sprint(moving and on_floor)
	update_stamina(delta, _is_sprinting)

	var target_speed := stance_speed(stance)
	if _is_sprinting:
		target_speed = config.sprint_speed
	target_speed *= carry_speed_mult
	target_speed *= _armor_speed_mult()   # heavy armor trades agility for protection (task 09/10)

	var accel := config.accel if on_floor else config.accel * config.air_control
	var friction := config.friction if on_floor else config.friction * config.air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if moving:
		horizontal = horizontal.move_toward(wish_dir * target_speed, accel * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	_update_fall_backstop()

	_update_lean(delta)
	_update_footsteps(delta, Vector2(velocity.x, velocity.z).length(), _is_sprinting)
	_update_interaction(delta)
	_update_carry_penalty()
	_update_throw_input()
	_update_drop_input()
	_update_takedown_input()
	_apply_camera_shake(delta)

## Out-of-bounds safety net behind the mission envelope (world-gen Phase 1A): remember the last grounded
## spot, and if the player somehow ends up below the floor plane, snap back instead of falling forever.
## Cheap, scene-agnostic — the real enclosure is the per-room shells + the invisible envelope walls.
func _update_fall_backstop() -> void:
	if is_on_floor():
		_last_grounded_pos = global_position
		_has_grounded = true
	elif config != null and global_position.y < config.fall_reset_y:
		velocity = Vector3.ZERO
		global_position = _last_grounded_pos if _has_grounded else Vector3(global_position.x, 1.0, global_position.z)

# --- Camera shake / feedback (task 21 — FR-21-3 juice + FR-21-1 toggles) ----

## Build the FP camera-shake driver from PlayerConfigDef and remember the camera's authored rotation.
func _setup_camera_shake() -> void:
	_cam_shake = CameraShake.new()
	_cam_shake.max_angle_rad = deg_to_rad(config.shake_max_angle_deg)
	_cam_shake.max_offset = config.shake_max_offset
	_cam_shake.decay_per_sec = config.shake_decay_per_sec
	if _camera != null:
		_cam_base_rot = _camera.rotation

## Apply (or settle) the additive camera shake each frame. Gated OFF by video/camera_shake=false or
## gameplay/reduce_flashing=true (accessibility), in which case the camera returns to its base pose.
func _apply_camera_shake(delta: float) -> void:
	if _cam_shake == null or _camera == null:
		return
	if not _camera_shake_on or _reduce_flashing:
		_cam_shake.trauma = 0.0
		_camera.rotation = _cam_base_rot
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	var s := _cam_shake.tick(delta)
	_camera.rotation = _cam_base_rot + (s["rot"] as Vector3)
	var ofs: Vector2 = s["ofs"]
	_camera.h_offset = ofs.x
	_camera.v_offset = ofs.y

## Add camera trauma (respecting the gate at apply time). Feedback sites call the typed helpers below.
func add_camera_trauma(amount: float) -> void:
	if _cam_shake != null:
		_cam_shake.add_trauma(amount)

## Recoil feedback: PlayerCombat calls this on a successful shot.
func on_weapon_fired() -> void:
	add_camera_trauma(config.shake_trauma_fire)
	Haptics.pulse_fire()

func _on_alarm_tripped(_kind: String, _position: Vector3) -> void:
	add_camera_trauma(config.shake_trauma_alarm)
	Haptics.pulse_alarm()

# --- Stamina (FR-03-1) -----------------------------------------------------

## Max stamina scaled by the player's trained "stamina" attribute (§5.5).
func _stamina_max() -> float:
	return config.stamina_max * (1.0 + attr_effect(&"stamina"))

## Drain while sprinting; after a delay, regen. Depleting locks sprint until regen
## passes `sprint_unlock_fraction` of max. Pure enough to drive directly in tests.
func update_stamina(delta: float, is_sprinting: bool) -> void:
	var smax := _stamina_max()
	if is_sprinting:
		stamina = maxf(0.0, stamina - config.stamina_drain_per_sec * delta)
		_regen_cooldown = config.stamina_regen_delay
		if stamina <= 0.0:
			_sprint_locked = true
	else:
		if _regen_cooldown > 0.0:
			_regen_cooldown = maxf(0.0, _regen_cooldown - delta)
		else:
			stamina = minf(smax, stamina + config.stamina_regen_per_sec * delta)
		if _sprint_locked and stamina >= smax * config.sprint_unlock_fraction:
			_sprint_locked = false
	stamina_changed.emit(stamina, smax)

## Can a *new* sprint start? (A sprint already underway continues until empty.)
func can_sprint() -> bool:
	return not _sprint_locked and stamina >= config.sprint_min_to_start

func _resolve_sprint(can_try: bool) -> bool:
	var wants := _sprint_input() and can_try and stance == Stance.STAND
	if not wants:
		return false
	if _is_sprinting:
		return stamina > 0.0 and not _sprint_locked
	return can_sprint()

func _sprint_input() -> bool:
	return _sprint_toggle_state if _sprint_toggle else Input.is_action_pressed(&"sprint")

# --- Stances (FR-03-2) -----------------------------------------------------

func stance_speed(stance_id: int) -> float:
	match stance_id:
		Stance.CROUCH: return config.crouch_speed
		Stance.PRONE: return config.prone_speed
		_: return config.stand_speed

func stance_eye_height(stance_id: int) -> float:
	match stance_id:
		Stance.CROUCH: return config.crouch_eye_height
		Stance.PRONE: return config.prone_eye_height
		_: return config.stand_eye_height

func stance_collider_height(stance_id: int) -> float:
	match stance_id:
		Stance.CROUCH: return config.crouch_collider_height
		Stance.PRONE: return config.prone_collider_height
		_: return config.stand_collider_height

func stance_noise_mult(stance_id: int) -> float:
	match stance_id:
		Stance.CROUCH: return config.crouch_noise_mult
		Stance.PRONE: return config.prone_noise_mult
		_: return config.stand_noise_mult

## 0..1 visibility the detection system (task 04) samples: stand > crouch > prone.
func detection_profile(stance_id: int = stance) -> float:
	match stance_id:
		Stance.CROUCH: return config.crouch_visibility
		Stance.PRONE: return config.prone_visibility
		_: return config.stand_visibility

## Change stance. Standing up (to a taller stance) fails if a low ceiling blocks it.
func set_stance(stance_id: int) -> bool:
	if stance_id == stance:
		return true
	if stance_id < stance and _ceiling_cast != null:   # lower enum = taller -> standing up
		_ceiling_cast.force_shapecast_update()
		if _ceiling_cast.is_colliding():
			return false
	stance = stance_id
	stance_changed.emit(stance)
	return true

func _update_toggle_inputs() -> void:
	if _crouch_toggle and Input.is_action_just_pressed(&"crouch"):
		_crouch_toggle_state = not _crouch_toggle_state
	if _sprint_toggle and Input.is_action_just_pressed(&"sprint"):
		_sprint_toggle_state = not _sprint_toggle_state

func _update_stance_input() -> void:
	if Input.is_action_just_pressed(&"prone"):
		set_stance(Stance.STAND if stance == Stance.PRONE else Stance.PRONE)
		return
	if _crouch_toggle:
		if Input.is_action_just_pressed(&"crouch"):
			set_stance(Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH)
	else:
		if Input.is_action_pressed(&"crouch"):
			if stance != Stance.PRONE:
				set_stance(Stance.CROUCH)
		elif stance == Stance.CROUCH:
			set_stance(Stance.STAND)

func _update_stance_transition(delta: float) -> void:
	if _collider == null or _head == null:
		return
	var t := clampf(config.stance_lerp_speed * delta, 0.0, 1.0)
	var shape := _collider.shape
	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		cap.height = lerpf(cap.height, stance_collider_height(stance), t)
		_collider.position.y = cap.height * 0.5   # keep feet planted at the body origin
	_eye_height = lerpf(_eye_height, stance_eye_height(stance), t)
	_head.position.y = _eye_height

# --- Look (FR-03-3) --------------------------------------------------------

func _apply_gamepad_look(delta: float) -> void:
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(rx) < config.gamepad_deadzone:
		rx = 0.0
	if absf(ry) < config.gamepad_deadzone:
		ry = 0.0
	if rx == 0.0 and ry == 0.0:
		return
	var speed := deg_to_rad(config.gamepad_look_speed) * delta
	rotation.y -= rx * speed
	var inv := -1.0 if _invert_y else 1.0
	_pitch = clampf(_pitch - ry * speed * inv, _pitch_min, _pitch_max)
	if _head != null:
		_head.rotation.x = _pitch
	# TODO[03]: iterate Input.get_connected_joypads() instead of assuming device 0.

# --- Lean / peek (FR-03-4) -------------------------------------------------

func _update_lean(delta: float) -> void:
	if _head == null:
		return
	var dir := Input.get_action_strength(&"lean_right") - Input.get_action_strength(&"lean_left")
	lean_amount = lerpf(lean_amount, dir, clampf(config.lean_lerp_speed * delta, 0.0, 1.0))
	var target_x := lean_amount * config.lean_offset
	# Shorten the offset so the camera never pokes through a wall.
	var cast := _lean_cast_r if target_x > 0.0 else _lean_cast_l
	if cast != null and cast.is_colliding():
		var clearance := maxf(0.0, cast.global_position.distance_to(cast.get_collision_point()) - config.lean_clear_margin)
		target_x = clampf(target_x, -clearance, clearance)
	_head.position.x = target_x
	_head.rotation.z = -(target_x / maxf(config.lean_offset, 0.001)) * deg_to_rad(config.lean_roll_deg)

# --- Interaction (FR-03-5) -------------------------------------------------

func _update_interaction(delta: float) -> void:
	var hit: Interactable = null
	if _interact_ray != null and _interact_ray.is_colliding():
		hit = _resolve_interactable(_interact_ray.get_collider())
	if hit != _current_interactable:
		_current_interactable = hit
		_hold_timer = 0.0
		interaction_target_changed.emit(_current_interactable)
	if update_hold(delta, Input.is_action_pressed(&"interact")):
		if _current_interactable != null and _current_interactable.can_interact(self):
			_current_interactable.interact(self)

## Walk up from a ray-hit collider to the owning Interactable (or null). Pure.
func _resolve_interactable(collider: Object) -> Interactable:
	var node := collider as Node
	while node != null:
		if node is Interactable:
			return node as Interactable
		node = node.get_parent()
	return null

## Drive tap/hold timing against the current target. Returns true exactly once when an
## interaction completes (instant for hold_seconds==0, else after holding that long).
## Releasing (pressed=false) re-arms it. Pure given `_current_interactable` + `_hold_timer`.
func update_hold(delta: float, pressed: bool) -> bool:
	if _current_interactable == null or not pressed:
		_hold_timer = 0.0
		return false
	if _hold_timer < 0.0:
		return false   # already fired this press; wait for release
	var required := _current_interactable.hold_seconds
	if required <= 0.0:
		_hold_timer = -1.0
		return true
	_hold_timer += delta
	if _hold_timer >= required:
		_hold_timer = -1.0
		return true
	return false

## The current interaction prompt for the HUD ("" when nothing is targetable).
func current_prompt() -> String:
	if _current_interactable != null and _current_interactable.can_interact(self):
		return _current_interactable.prompt
	return ""

## Progress 0..1 of the interaction on the aimed target, for the HUD hold ring. Covers both the tap/hold
## timer (hold_seconds obstacles like a fuse box) AND an in-world timed interaction the target drives
## itself (e.g. a HackTarget's proximity-hack fill) via Interactable.interaction_progress(). 0 when idle.
func interaction_hold_progress() -> float:
	if _current_interactable == null:
		return 0.0
	var p: float = _current_interactable.interaction_progress()   # in-world timed interactions (hacks, …)
	var required: float = _current_interactable.hold_seconds
	if required > 0.0:
		var held := 1.0 if _hold_timer < 0.0 else clampf(_hold_timer / required, 0.0, 1.0)
		p = maxf(p, held)
	return clampf(p, 0.0, 1.0)

# --- Noise (FR-03-6) -------------------------------------------------------

## Footfalls accumulate DISTANCE, not time (misc-fixes-3 issue 8). The old time-based version reset the
## accumulator whenever the player was nearly still, so tapping a move key repeatedly covered ground in
## total silence while a held key could spam the interval. Now: only real travel advances the stride, the
## accumulator is HELD (never reset) while airborne or stopped so taps carry over, and cadence scales with
## speed for free — a crouch-walk is both quieter and slower-footed.
func _update_footsteps(delta: float, horizontal_speed: float, is_running: bool) -> void:
	if not is_on_floor() or horizontal_speed < 0.1:
		return   # hold the accumulator: a stop-start tap must not wipe the ground already covered
	var step := accumulate_step(_step_accum, horizontal_speed * delta, config.step_stride)
	_step_accum = float(step[1])
	if not bool(step[0]):
		return
	# Silence reduction stacks the trained attribute with soft-soled gear (FR-09-7), clamped once.
	var reduction := clampf(attr_effect(&"silence") + _gear_silence_bonus(), 0.0, config.max_silence_reduction)
	noise_level = compute_noise_radius(stance, is_running, _current_surface_tag(), reduction)
	emit_noise(noise_level, "footstep")

## Advance the footfall accumulator by `distance` metres. Returns [emit: bool, remaining: float] — one
## step per `stride` crossed, carrying the remainder so cadence never drifts. Pure.
static func accumulate_step(accum: float, distance: float, stride: float) -> Array:
	var total := accum + maxf(distance, 0.0)
	if stride <= 0.0 or total < stride:
		return [false, total]
	return [true, total - stride]

## Footstep noise radius (m): base × stance × run × surface × (1 − Silence). Pure;
## `silence_reduction` is the already-resolved 0..1 fraction (live code reads it from
## the Silence attribute; tests pass it explicitly).
func compute_noise_radius(stance_id: int, is_running: bool, surface_tag: String, silence_reduction: float) -> float:
	var r := config.base_step_radius
	r *= stance_noise_mult(stance_id)
	if is_running:
		r *= config.run_noise_mult
	r *= surface_mult(surface_tag)
	r *= (1.0 - clampf(silence_reduction, 0.0, config.max_silence_reduction))
	return maxf(0.0, r)

## Extra Silence reduction from equipped soft-soled gear (FR-09-7); 0.0 if none/loadout absent.
func _gear_silence_bonus() -> float:
	if loadout == null:
		return 0.0
	return float(loadout.gadget_param(&"soft_soled_gear", &"silence_bonus", 0.0))

func surface_mult(surface_tag: String) -> float:
	if surface_tag == "":
		return config.surface_noise_default
	return float(config.surface_noise.get(surface_tag, config.surface_noise_default))

func _current_surface_tag() -> String:
	var col := get_last_slide_collision()
	if col == null:
		return ""
	var collider := col.get_collider()
	if collider != null and collider.has_meta("surface"):
		return str(collider.get_meta("surface"))
	return ""

func emit_noise(radius: float, source: String) -> void:
	EventBus.noise_emitted.emit(global_position, radius, source)

# --- Carry hooks (FR-03-7; consumed by task 08) ----------------------------

## Task 08 calls this when bulky/hand-slot loot is carried.
func apply_carry_penalty(speed_mult: float, blocks_climb: bool, blocks_vents: bool) -> void:
	carry_speed_mult = clampf(speed_mult, 0.0, 1.0)
	can_climb = not blocks_climb
	can_use_vents = not blocks_vents
	# TODO[08]: mount the carried viewmodel under _hands; gate vault/climb on can_climb/can_use_vents.

func clear_carry_penalty() -> void:
	carry_speed_mult = 1.0
	can_climb = true
	can_use_vents = true

## Recompute + push the current hand-slot penalty into the FR-03-7 hook every physics tick
## (cheap: Inventory's accounting is O(items held), not a search). Strength is resolved here
## (PlayerController owns attribute reads) and passed down as a float, mirroring
## Lock.resolve_attempt's lockpicking_level pattern — Inventory never touches ProgressionManager.
func _update_carry_penalty() -> void:
	if inventory == null:
		return
	var state := inventory.penalty_state(config.hand_penalty_per_slot, attr_effect(&"strength"))
	apply_carry_penalty(state["speed_mult"], state["blocks_climb"], state["blocks_vents"])

## FR-08-4/FR-08-2: throw the actively-carried bag OR dragged body (Strength-gated distance)
## toward where the camera is looking. Bag and body are already mutually exclusive (hand-slot
## accounting), so there's no ambiguity about which one `throw` acts on.
func _update_throw_input() -> void:
	if inventory == null or not Input.is_action_just_pressed(&"throw"):
		return
	if inventory.can_throw_bag():
		var bag := inventory.release_bag_for_throw()
		if bag != null:
			EventBus.carry_changed.emit(inventory.current_weight(), inventory.current_volume())
			_spawn_thrown_bag(bag)
		return
	if inventory.is_carrying_body():
		var body := inventory.put_down_body()
		if body != null:
			EventBus.carry_changed.emit(inventory.current_weight(), inventory.current_volume())
			_spawn_thrown_body(body)

## Stealth takedown (the `takedown` action, default V): drop the nearest guard we're close to and
## roughly facing → a non-lethal `take_down(false)`, which leaves a concealable Body carrying the
## guard's item (e.g. the Inspector's vault keycard). Range/behind-ness is lenient for the greybox;
## a full sneak-from-behind gate rides with task 05's polish. Closes the unconsumed input action.
func _update_takedown_input() -> void:
	if not Input.is_action_just_pressed(&"takedown"):
		return
	var guard := _takedown_target()
	if guard != null and guard.has_method("take_down"):
		guard.take_down(false)

func _takedown_target() -> Node:
	var forward := -global_transform.basis.z
	var best: Node = null
	var best_d := 2.2   # takedown reach (m); greybox-lenient
	for g in get_tree().get_nodes_in_group(&"guard"):
		if not (g is Node3D):
			continue
		var to: Vector3 = (g as Node3D).global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > best_d or d < 0.05:
			continue
		if forward.dot(to / d) < 0.25:   # roughly in front of us
			continue
		best = g
		best_d = d
	return best

## Where runtime-spawned bags/bodies get parented. Task 11's MissionController joins the
## &"mission_root" group; fall back to the scene tree root for greyboxes/tests (closes TODO[11]).
func _mission_root() -> Node:
	var root := get_tree().get_first_node_in_group(&"mission_root")
	return root if root != null else get_tree().root

func _spawn_thrown_bag(bag: Bag) -> void:
	var thrown := ThrownBag.new()
	thrown.bag = bag
	thrown.thrower_inventory = inventory
	thrown.thrower = self   # excluded from its own collisions — it spawns near our own capsule
	_mission_root().add_child(thrown)
	var dist := Inventory.throw_distance(config.throw_base_distance, attr_effect(&"strength"), config.throw_strength_bonus)
	var dir := -_camera.global_transform.basis.z
	var spawn_pos := _camera.global_position + dir * config.throw_spawn_offset
	thrown.launch(spawn_pos, dir * dist)

func _spawn_thrown_body(body: Body) -> void:
	var thrown := ThrownBody.new()
	thrown.body = body
	thrown.thrower = self   # excluded from its own collisions — it spawns near our own capsule
	_mission_root().add_child(thrown)
	var dist := Inventory.throw_distance(config.body_throw_base_distance, attr_effect(&"strength"), config.body_throw_strength_bonus)
	var dir := -_camera.global_transform.basis.z
	var spawn_pos := _camera.global_position + dir * config.throw_spawn_offset
	thrown.launch(spawn_pos, dir * dist)

## `drop_loot` currently only puts down a dragged Body (FR-05-2's drag/hide half). Dropping
## bagged/pocketed loot back into the world is a nice-to-have beyond any FR-08 requirement.
func _update_drop_input() -> void:
	if inventory == null or not Input.is_action_just_pressed(&"drop_loot"):
		return
	if not inventory.is_carrying_body():
		return
	var body := inventory.put_down_body()
	if body == null:
		return
	_mission_root().add_child(body)
	body.global_position = global_position + (-global_transform.basis.z * 1.0)
	body.set_concealed(false)

# --- Duck-typed bridges consumed by obstacles (↩ from 06, closes TODO[08]) --

## Satisfies Obstacle.actor_has_item(by, id)'s duck-type (keycards/keys/found clues).
func has_item(item_id: StringName) -> bool:
	return inventory != null and inventory.has_item(item_id)

## Satisfies BiometricLock._keyholder_present(by)'s duck-type: is the dragged Body the
## required keyholder?
func is_carrying_keyholder(item_id: StringName) -> bool:
	return inventory != null and inventory.is_carrying_keyholder(item_id)

## Grants a LootDef directly into carry, bypassing the world-pickup Interactable — used by
## HackTarget's data_loot download (↩ from 06).
func add_loot(loot: LootDef) -> void:
	if inventory != null:
		inventory.add_loot(loot)

# --- Gadget queries consumed by obstacles (↩ from 06, closes TODO[09]) ------
# These are the exact duck-types KeycardDoor/DisplayCase/BiometricLock already call — now they
# answer truthfully from the equipped Loadout, so a researched+equipped gadget actually works.

## KeycardDoor._can_clone: the keycard cloner gadget is equipped (clones a nearby legit card).
func can_clone_keycard(_required_item: StringName) -> bool:
	return loadout != null and loadout.has_gadget(&"keycard_cloner")

## DisplayCase._has_glasscutter: the silent glasscutter is equipped.
func has_glasscutter() -> bool:
	return loadout != null and loadout.has_gadget(&"glasscutter")

## BiometricLock._has_spoof: the rare biometric spoof gadget is equipped.
func has_biometric_spoof() -> bool:
	return loadout != null and loadout.has_gadget(&"biometric_spoof")

# --- Loadout resolution ----------------------------------------------------

## Use the Streak's loadout (so gear equipped at the Armory carries into the mission), falling back
## to a fresh empty Loadout headlessly / before a Streak exists.
func _resolve_loadout() -> Loadout:
	var run := Services.run()
	if run != null and run.has_method("loadout"):
		return run.loadout()
	return Loadout.new()

# --- Combat / survivability (task 10) --------------------------------------

## Build the Health pool from the base config (scaled by the Health attribute, §5.5) and the loadout's
## Armor plate pool, if any. Downs/Catches route through Health.state_changed → the resolution flow.
func _build_health() -> void:
	var armor_gear: GearDef = loadout.armor() if loadout != null else null
	var armor: Armor = Armor.new(armor_gear) if armor_gear != null else null
	health = Health.new(config.health_base * (1.0 + attr_effect(&"health")), armor)
	health.state_changed.connect(_on_health_state_changed)

## Mount the FP firing controller under the Hands node so it aims down the look direction (FR-10-4).
func _mount_combat() -> void:
	if _hands == null:
		return
	_combat = PlayerCombat.new()
	_hands.add_child(_combat)
	_combat.shot_hit.connect(func() -> void: shot_landed.emit())   # forward hit-confirm to the HUD (task 21)

## Incoming damage entry point — hostiles (GuardAI combat) call this. Routes armor→health via Health.
func apply_damage(damage: float) -> void:
	if health != null:
		health.take_damage(damage)
	# Juice/accessibility feedback (task 21): a knock of camera trauma + rumble scaled by the hit.
	if damage > 0.0:
		var scale := clampf(damage / maxf(1.0, config.health_base * 0.5), 0.15, 1.0)
		add_camera_trauma(config.shake_trauma_hit * scale)
		Haptics.pulse_hit()

## The Streak's currently-selected weapon (for the HUD loud-block ammo readout, task 15). Null if
## unarmed or combat isn't mounted yet.
func active_weapon() -> Weapon:
	return _combat.active_weapon() if _combat != null else null

## Rebuild the FP combat weapons from the current loadout. Called after the loadout changes mid-mission
## (the debug arm key; a future Armory re-equip). The player's `loadout` is the Streak's shared instance,
## so equipping onto RunManager.loadout() then calling this picks the new weapon up.
func rebuild_weapons() -> void:
	if _combat != null:
		_combat.rebuild_weapons()

## Move-speed multiplier from equipped armor weight (never freezes; Armor.agility_mult floors it).
func _armor_speed_mult() -> float:
	if health != null and health.armor != null:
		return health.armor.speed_mult()
	return 1.0

## A Down that lapses (CAUGHT) or a surround (CAPTURED) is the Catch (§8.7): hand off to task 12 for
## Notoriety→Legacy conversion, then to the results screen (task 11/15). FR-10-6/FR-10-9.
func _on_health_state_changed(new_state: int) -> void:
	if new_state == Health.State.CAUGHT or new_state == Health.State.CAPTURED:
		var secured := inventory.secured_value() if inventory != null else 0
		var awarded := 0
		var run := Services.run()
		if run != null and run.has_method("end_streak"):
			awarded = run.end_streak("caught", secured)   # banks Notoriety × Heat-mult → Legacy + resets the Streak (task 12)
		var gm := Services.game()
		if gm != null and gm.has_method("goto_results"):
			# Feed the Results/Catch screen (task 15, FR-15-8) the real payout + what survived.
			gm.goto_results({"outcome": "caught", "legacy_awarded": awarded, "secured_value": secured})

# --- Attributes / settings / helpers ---------------------------------------

## Trained effect of an attribute: level × effect_per_level. 0.0 if the attribute is
## untrained or its def isn't present (so the controller degrades gracefully).
func attr_effect(attr_id: StringName) -> float:
	var prog := Services.progression()
	if prog == null:
		return 0.0
	var level: int = prog.attribute_level(attr_id)
	if level <= 0:
		return 0.0
	var content := Services.content()
	if content == null or content.attributes == null:
		return 0.0
	var def := content.attributes.get_def(attr_id) as AttributeDef
	if def == null:
		return 0.0
	return float(level) * def.effect_per_level

func _refresh_settings() -> void:
	var s := Services.settings()
	if s == null:
		return
	_sens = float(s.get_value("gameplay", "mouse_sensitivity"))
	_invert_y = bool(s.get_value("gameplay", "invert_y"))
	_crouch_toggle = bool(s.get_value("gameplay", "crouch_toggle"))
	_sprint_toggle = bool(s.get_value("gameplay", "sprint_toggle"))
	_reduce_flashing = bool(s.get_value("gameplay", "reduce_flashing"))
	_camera_shake_on = bool(s.get_value("video", "camera_shake"))
	# Field of view is a graphics option (GDD §15.2) but only the player camera can apply it (task 15).
	if _camera != null:
		_camera.fov = clampf(float(s.get_value("video", "fov")), 50.0, 120.0)

func _on_settings_changed(section: String) -> void:
	if section == "gameplay" or section == "video":
		_refresh_settings()

func _resolve_gravity() -> void:
	if config != null and config.gravity >= 0.0:
		_gravity = config.gravity
	else:
		_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _capture_mouse() -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
