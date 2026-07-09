extends Resource
class_name AIConfigDef
## Behavior tunables for rule-driven AI actors (patrol/investigate/search timings, navigation
## arrival, radio check-ins, alert coordination, body discovery). Keeps GuardAI free of magic
## numbers — per-actor senses/health/speed live in EnemyDef, curve/threshold detection tunables
## in DetectionConfigDef. Instance lives as game/resources/ai/default_ai.tres (or per-archetype
## presets), assigned via GuardAI.ai_config; falls back to Content.ai's &"default".
## See docs/tasks/05_ai_actors.md and GDD §8.4.

@export var id: StringName = &"default"   ## registry key; presets can coexist

# --- Navigation / patrol ----------------------------------------------------
@export var arrival_radius: float = 0.6      ## within this of a target = "reached" it (m)
@export var waypoint_pause: float = 1.0      ## seconds to idle/look-around at each patrol waypoint
@export var patrol_speed_mult: float = 0.6   ## fraction of EnemyDef.move_speed while patrolling
@export var investigate_speed_mult: float = 1.0  ## fraction of move_speed while investigating/searching

# --- Investigate / search timing (s) ---------------------------------------
@export var investigate_timeout: float = 6.0    ## give up walking to a stale last-known spot after this
@export var search_duration: float = 5.0        ## local sweep length before resuming patrol
@export var search_radius: float = 4.0          ## radius of the local sweep around the lost contact

# --- Radio check-ins (FR-05-3) ---------------------------------------------
@export var max_fakeable_checkins: int = 2   ## fakeable "all clear" replies before HQ escalates
## checkin_delay/checkin_window feed the on-screen hold-to-fake prompt/timer, which is authored
## in task 15 (HUD); they are intentionally not read by GuardAI yet. See docs/tasks/15_ui_hud_menus.md.
@export var checkin_delay: float = 8.0       ## seconds after a takedown before the radio demands a check-in
@export var checkin_window: float = 4.0      ## window to hold the fake-reply prompt

# --- Coordination / discovery ----------------------------------------------
@export var alert_propagation_radius: float = 12.0   ## nearby guards within this raise on a spotting/search (FR-05-2)
@export var body_discovery_range: float = 8.0        ## a guard notices an unhidden body within this + LoS (FR-05-2)

# --- Combat (task 10) -------------------------------------------------------
@export var combat_aim_height: float = 1.2   ## metres above the player's origin a guard aims its LoS/fire ray at (centre-mass)

# --- Performance budget (task 21, FR-21-2) ----------------------------------
## Hard ceiling on the number of PATROL guards a single mission spawns. Density scaling (Tier/Heat/modifiers)
## can multiply patrols; this caps the instance/AI budget so a dense mission still holds frame rate. Essential
## actors (e.g. a key-carrying Inspector) are placed regardless — this only trims the density overflow.
@export var max_active_guards: int = 24
