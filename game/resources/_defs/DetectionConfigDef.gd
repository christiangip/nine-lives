extends Resource
class_name DetectionConfigDef
## Tunables for the stealth detection meter: fill/decay rates, state thresholds, and
## the distance/light/movement/sound curves. Keeps DetectionSensor free of magic
## numbers (per-actor cone geometry lives in EnemyDef). Instance lives as
## game/resources/detection/default_detection.tres (assigned via DetectionSensor.config).
## See docs/tasks/04_stealth_detection.md and GDD §8.1-§8.3.

@export var id: StringName = &"default"   ## registry key; presets (guard/camera) can coexist

# --- Fill dynamics (meter is 0..1) -----------------------------------------
@export var see_gain_rate: float = 0.9     ## fill/sec at full factors (point-blank, lit, standing, running, clear LoS)
@export var decay_rate: float = 0.35       ## fill/sec recovered while the target is unseen
@export var sound_gain: float = 0.4        ## fill bump from a FULLY LOUD noise at the source
@export var sound_fill_cap: float = 0.6    ## sound alone can't push fill past this (never fully spots)
## How LOUD a noise has to be (its emitted radius, m) to land the full `sound_gain` bump. Quieter noises
## scale down proportionally, so the player's noise levers — stance, Silence, soft-soled gear, floor
## surface — finally govern how fast a guard notices them. Without this the bump depended only on
## DISTANCE: a prone crawl and a standing walk built a guard's meter at exactly the same rate, because a
## footstep's radius never exceeds a guard's hearing radius and so only ever set the (unused) reach.
## Reference 8.0 = a guard's default hearing radius: a standing walk (6.6 m) lands ~0.83 of the bump,
## a crouch-walk (3.3 m) ~0.41, a prone crawl ~0.21, and a sprint/gunshot/drill saturates at 1.0.
@export var sound_reference_radius: float = 8.0

# --- State thresholds (0..1, ascending) ------------------------------------
@export var suspicious_threshold: float = 0.2
@export var searching_threshold: float = 0.5
@export var alerted_threshold: float = 0.85

# --- Post-pursuit awareness (misc-fixes-3 issue 1) --------------------------
## Applied while RunManager.alert_state == ALERTED — i.e. an alarm raised a pursuit, the player shook it
## off, and the level stays on edge for the rest of the mission: every sensor (guards AND cameras) fills
## faster and sees further. Not applied during the pursuit itself (a silent alarm must not tip its hand).
@export var alerted_gain_mult: float = 1.5    ## detection builds this much faster while ALERTED
@export var alerted_range_mult: float = 1.25  ## and the vision cone reaches this much further

# --- Distance ---------------------------------------------------------------
@export var distance_falloff_exp: float = 1.0   ## >1 makes near detection punchier; closer always fills faster

# --- Light ------------------------------------------------------------------
@export var min_light_factor: float = 0.25   ## fill-rate multiplier in full shadow (1.0 = fully lit)

# --- Movement (horizontal speed, m/s) --------------------------------------
@export var walk_speed: float = 1.5    ## below this = "still"; below run_speed = "walking"
@export var run_speed: float = 4.0
@export var still_factor: float = 0.55
@export var walk_factor: float = 0.8
@export var run_factor: float = 1.0

# --- Line-of-sight sampling -------------------------------------------------
## Heights (m, above the target origin) the sensor casts LoS rays to. The fraction of
## clear rays is the visibility: none clear = full cover (blocks), some = partial cover
## (reduces fill), all = full visibility.
@export var los_sample_heights: Array[float] = [1.5, 0.9, 0.2]

# --- AI performance LOD (task 21, FR-21-2 — the deferred 05.5 budget) -------
## The expensive cone/LoS/light sense runs EVERY frame within lod_full_range of the player, every
## lod_mid_interval frames out to lod_mid_range, every lod_far_interval frames out to lod_sleep_range, and
## not at all beyond it (a guard that far can't gain fill anyway — only cheap decay is skipped). Guards at
## equal distance are staggered across frames so their raycasts don't bunch on one frame. Keep lod_full_range
## comfortably past any actor's vision_range so on-screen detection is NEVER throttled (behaviour unchanged).
@export var lod_full_range: float = 22.0
@export var lod_mid_range: float = 40.0
@export var lod_sleep_range: float = 70.0
@export var lod_mid_interval: int = 2
@export var lod_far_interval: int = 4
