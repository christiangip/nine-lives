extends Resource
class_name PlayerConfigDef
## Tunables for the first-person player controller (locomotion, stances, stamina,
## look, lean, interaction, footstep noise). Keeps PlayerController free of magic
## numbers. Instance lives as game/resources/player/default_player.tres (assigned via
## PlayerController.config). See docs/tasks/03_player_controller_camera.md and GDD §8.0.

# --- Locomotion ------------------------------------------------------------
@export var sprint_speed: float = 5.6        ## m/s while sprinting (standing only)
@export var accel: float = 12.0              ## ground acceleration toward target velocity
@export var friction: float = 14.0           ## ground deceleration when no input
@export var air_control: float = 0.3         ## 0..1 fraction of accel applied airborne
@export var jump_velocity: float = 4.5       ## upward m/s on jump
@export var gravity: float = -1.0            ## < 0 -> use ProjectSettings default_gravity
@export var fall_reset_y: float = -8.0       ## below this world-Y, snap back to the last grounded spot (out-of-bounds safety net, world-gen Phase 1A)

# --- Stances (flat per-stance fields, indexed by PlayerController.Stance) ---
@export var stand_speed: float = 3.2         ## m/s walking while standing
@export var crouch_speed: float = 1.5        ## m/s while crouched
@export var prone_speed: float = 0.8         ## m/s while prone
@export var stand_eye_height: float = 1.6    ## camera/Head local y when standing
@export var crouch_eye_height: float = 0.9
@export var prone_eye_height: float = 0.4
@export var stand_collider_height: float = 1.8   ## capsule total height standing (>= 2*radius)
@export var crouch_collider_height: float = 1.0
@export var prone_collider_height: float = 0.8
@export var stand_visibility: float = 1.0    ## 0..1 detection profile fed to task 04 (stand>crouch>prone)
@export var crouch_visibility: float = 0.6
@export var prone_visibility: float = 0.35
@export var stand_noise_mult: float = 1.0    ## footstep-radius multiplier per stance
@export var crouch_noise_mult: float = 0.5
@export var prone_noise_mult: float = 0.25
@export var stance_lerp_speed: float = 10.0  ## per-second lerp rate for height/eye transitions

# --- Stamina (sprint budget; max scaled by the "stamina" attribute) --------
@export var stamina_max: float = 100.0
@export var stamina_drain_per_sec: float = 25.0
@export var stamina_regen_per_sec: float = 18.0
@export var stamina_regen_delay: float = 0.6     ## seconds after sprinting before regen starts
@export var sprint_unlock_fraction: float = 0.25 ## after depletion, regen to this fraction of max to sprint again
@export var sprint_min_to_start: float = 5.0     ## need at least this much stamina to begin a sprint

# --- Look (mouse + gamepad) ------------------------------------------------
@export var mouse_sensitivity: float = 0.3   ## fallback when SettingsManager is unavailable
@export var pitch_min_deg: float = -89.0     ## clamp looking down
@export var pitch_max_deg: float = 89.0      ## clamp looking up
@export var gamepad_look_speed: float = 180.0    ## deg/sec at full right-stick deflection
@export var gamepad_deadzone: float = 0.15

# --- Lean / peek (camera offset only; collider never moves) ----------------
@export var lean_offset: float = 0.6         ## metres the Head shifts sideways at full lean
@export var lean_roll_deg: float = 8.0       ## camera roll at full lean
@export var lean_lerp_speed: float = 10.0
@export var lean_clear_margin: float = 0.25  ## keep the camera at least this far off a wall

# --- Interaction -----------------------------------------------------------
@export var interact_range: float = 2.5      ## ray length for the interaction probe (m)

# --- Footstep noise --------------------------------------------------------
## Footfalls are DISTANCE-based, not time-based: a step is emitted every `step_stride` metres travelled.
## So a tap of the move key still makes noise once you've actually covered ground (it can't be dodged by
## stutter-stepping), faster movement naturally steps more often, and a crouch-walk is quiet AND slow-
## cadenced. ~1.6 m reproduces the old cadences (walk 3.2 m/s → ~0.5 s; sprint 5.6 m/s → ~0.29 s).
@export var step_stride: float = 1.6             ## metres travelled between footfalls
## Noise radius (m) of a standing walk step on a default surface. This is the AUDIBILITY/ring size; how
## strongly a step registers on a guard's detection meter is DetectionConfigDef.sound_reference_radius.
@export var base_step_radius: float = 6.0
@export var run_noise_mult: float = 1.7          ## extra multiplier when running/sprinting
@export var max_silence_reduction: float = 0.85  ## cap on the Silence-attribute noise cut (avoid 0-radius)
## Floor-surface tag -> footstep-radius multiplier. Tags come from a floor collider's
## "surface" meta (see PlayerController). Unlisted tags fall back to surface_noise_default.
@export var surface_noise: Dictionary = {
	"metal": 1.5,
	"concrete": 1.1,
	"wood": 1.0,
	"grass": 0.7,
	"carpet": 0.45,
}
@export var surface_noise_default: float = 1.0

# --- Combat / survivability (task 10; max scaled by the "health" attribute) --
@export var health_base: float = 100.0           ## base Health pool before the Health attribute scales it (§5.5)

# --- Camera shake (task 21 juice; gated by video/camera_shake + gameplay/reduce_flashing) --
@export var shake_max_angle_deg: float = 2.5     ## peak additive camera rotation at full trauma (deg)
@export var shake_max_offset: float = 0.08       ## peak additive camera projection offset at full trauma
@export var shake_decay_per_sec: float = 1.6     ## trauma bled off per second
@export var shake_trauma_fire: float = 0.32      ## trauma added per shot fired
@export var shake_trauma_hit: float = 0.55       ## trauma added when the player takes damage
@export var shake_trauma_alarm: float = 0.25     ## trauma added when an alarm trips

# --- Carry (task 08; scaled by the "strength" attribute) -------------------
@export var carry_weight_base: float = 40.0      ## kg, before Strength scaling
@export var carry_volume_base: float = 20.0      ## L/slots, before Strength scaling
@export var hand_penalty_per_slot: float = 0.25  ## FR-08-2 speed reduction per occupied hand slot
@export var throw_base_distance: float = 6.0     ## m, before Strength scaling
@export var throw_strength_bonus: float = 4.0    ## m added per full Strength effect unit
@export var throw_spawn_offset: float = 1.0      ## m in front of the camera a thrown object spawns (clears the player's own collider)
@export var body_throw_base_distance: float = 3.0   ## m, before Strength scaling — a body is heavier/bulkier than a bag
@export var body_throw_strength_bonus: float = 2.0  ## m added per full Strength effect unit
