extends Resource
class_name PursuitConfigDef
## Tunables for the Going-Loud Pursuit timeline + combat resolution (task 10). Keeps
## PursuitDirector / Health / GuardAI combat free of magic numbers. The Pursuit phases follow
## GDD §8.6: 0 Calm · 1 Local guards · 2 Alarm confirmed · 3 Responders · 4 Police flood ·
## 5 Tactical/special units. Instance lives as game/resources/pursuit/default_pursuit.tres
## (registered as Content.pursuit); PursuitDirector falls back to Content.pursuit's &"default".
## See docs/tasks/10_going_loud_pursuit.md and GDD §8.6-§8.7.

@export var id: StringName = &"default"   ## registry key; presets can coexist

# --- Pursuit timeline (FR-10-1/FR-10-2) ------------------------------------
## Seconds to remain at phase i before escalating to i+1. Indexed by phase (0..5); a value <= 0
## marks a terminal phase (5 = tactical, the timeline tops out — enemies keep coming, you escape).
@export var phase_durations: Array[float] = [0.0, 18.0, 22.0, 30.0, 40.0, 0.0]
## A silent alarm starts the timeline further along than a loud one (police are quietly enroute,
## no on-screen warning — Intel reveals them). Loud always starts at phase 1. (FR-10-2)
@export var silent_skip_phase: int = 2
## Seconds of ZERO detection contact (no sensor anywhere holding any fill) before the pursuit is called
## off. The level then drops to phase 0 but stays ALERTED for the rest of the mission — guards resume
## patrol with heightened senses, and a fresh alarm re-escalates to a full pursuit. (misc-fixes-3 issue 1)
@export var pursuit_lost_timeout: float = 60.0

# --- Heat on going loud (FR-10-3) ------------------------------------------
@export var heat_per_loud_alarm: float = 0.25    ## Heat added (0..1) when a loud alarm fires
@export var heat_per_silent_alarm: float = 0.12  ## silent alarms raise Heat less

# --- Enemy escalation (FR-10-5) --------------------------------------------
## How many hostiles the director wants active at each phase (spawn budget). Indexed by phase.
@export var spawn_budget: Array[int] = [0, 1, 2, 3, 4, 5]
## Which EnemyDef id reinforces at each phase (the tier ladder: beat cops → SWAT → specialists).
## Indexed by phase; the actual spawn PLACEMENT into a level is task 11 (needs nav-meshed sockets).
@export var tier_ladder: Array[StringName] = [
	&"", &"guard", &"responder", &"responder", &"swat", &"specialist_shield",
]

# --- Combat geometry / firing (FR-10-4/FR-10-5) ----------------------------
@export var guard_engage_range: float = 18.0     ## a guard opens fire within this of a visible player
@export var guard_desired_range: float = 8.0     ## the standoff distance combat AI steers toward
@export var guard_range_band: float = 0.25       ## +/- fraction around desired range that reads as "hold"
@export var guard_advance_speed_mult: float = 1.0  ## fraction of move_speed while advancing under Pursuit

# --- Aim assist (task 21, FR-21-1; loud only, deliberately light) -----------
@export var aim_assist_cone_deg: float = 12.0    ## only a target within this half-cone of the aim is assisted
@export var aim_assist_max_deg: float = 6.0      ## the aim is nudged toward it by at most this (never a full snap-lock)

# --- Downs / capture / Get-Out-of-Jail (FR-10-6/FR-10-7) --------------------
@export var self_revive_window: float = 8.0      ## seconds Downed before it becomes Caught
@export var revive_health_fraction: float = 0.5  ## Health restored (fraction of max) on a self-revive
@export var capture_radius: float = 2.5          ## hostiles within this of a Downed player can cuff
@export var capture_count: int = 2               ## this many surrounding hostiles = Captured
@export var jail_skill_tolerance: float = 0.15   ## Get-Out-of-Jail timing-check half-width (0..1)

func max_phase() -> int:
	return maxi(0, phase_durations.size() - 1)
