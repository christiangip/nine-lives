extends Resource
class_name MinigameConfigDef
## Tunables for the six diegetic minigame frameworks (lockpick, hack, safe-crack, keypad,
## pickpocket, drill/thermite). Keeps every Minigame subclass free of magic numbers — the
## per-obstacle difficulty tier + the player's attribute/gear widen these at runtime through the
## pure seams. Instance lives as game/resources/minigames/default_minigame.tres (per-difficulty
## presets can coexist), resolved via Content.minigames.get_def(&"default").
## See docs/tasks/07_minigames.md and GDD §9.8.

@export var id: StringName = &"default"   ## registry key; presets (e.g. per-archetype) can coexist

# --- Lockpick (FR-07-3): rotate to a sweet-spot arc; Lockpicking widens it, tier narrows it -----
## Sweet-spot half-width in DEGREES. Snap odds themselves come from the obstacle (Lock.snap_base_chance)
## + the Lockpicking AttributeDef, via Lock.snap_chance — this def only governs the arc geometry.
@export var lockpick_arc_base_deg: float = 25.0        ## tier-1 half-width of the "give" arc
@export var lockpick_arc_tier_penalty_deg: float = 4.0 ## each tier above 1 narrows the arc
@export var lockpick_arc_per_level_deg: float = 2.0    ## each Lockpicking level widens the arc
@export var lockpick_arc_min_deg: float = 6.0          ## floor so high tiers never become impossible

# --- Hack (FR-07-5): node-routing under a soft timer with proximity pause; Hacking adds tolerance --
@export var hack_time_limit_base: float = 8.0          ## tier-1 soft-timer seconds to finish routing
@export var hack_time_limit_tier_penalty: float = 1.5  ## each tier above 1 shortens the limit
@export var hack_time_limit_min: float = 2.5           ## floor on the soft timer
@export var hack_nodes_base: int = 4                   ## routing nodes to connect at tier 1
@export var hack_nodes_per_tier: int = 1               ## +nodes per tier
@export var hack_fault_base: float = 0.0               ## allowed mis-routes at Hacking 0
@export var hack_fault_per_level: float = 0.34         ## Hacking adds fault tolerance (~1 per 3 levels)
@export var hack_proximity_range: float = 3.0          ## fallback range if the obstacle declares none

# --- Safe-crack (FR-07-4): chain dial clicks; stethoscope + Hacking widen the audio cue window ---
@export var safe_wheels_base: int = 3                  ## click numbers to chain at tier 1
@export var safe_wheels_per_tier: int = 1              ## +wheels per tier
@export var safe_tolerance_base_deg: float = 6.0       ## tier-1 half-width where a click "reads" (degrees)
@export var safe_tolerance_tier_penalty_deg: float = 1.0   ## each tier above 1 tightens it
@export var safe_tolerance_per_level_deg: float = 0.5  ## each Hacking level widens the cue
@export var safe_stethoscope_bonus_deg: float = 4.0    ## stethoscope gadget widens the cue (task 09)
@export var safe_tolerance_min_deg: float = 1.5        ## floor so a maxed tier is still fair

# --- Keypad (FR-07-6): Mastermind-style deduction; a found code skips it (obstacle-side) ---------
@export var keypad_symbol_count: int = 6               ## distinct symbols available per position
@export var keypad_length_base: int = 3                ## code length at tier 1
@export var keypad_length_per_tier: int = 1            ## +length per tier
@export var keypad_max_guesses: int = 8                ## deduction attempts before it fails

# --- Pickpocket (FR-07-7): moving timing meter; Pickpocketing widens the safe zone --------------
@export var pickpocket_window_base: float = 0.18       ## safe-zone half-width as a fraction of the meter [0,1]
@export var pickpocket_window_per_level: float = 0.02  ## each Pickpocketing level widens it
@export var pickpocket_window_tier_penalty: float = 0.02   ## each tier above 1 narrows it
@export var pickpocket_window_min: float = 0.04        ## floor so a high tier is still catchable
@export var pickpocket_meter_speed: float = 1.2        ## meter sweeps per second (presentation glue)

# --- Drill / Thermite (FR-07-8): a tension manager, not a puzzle. The timer/jam/noise live on the
# BreachPoint obstacle (ObstacleDef.time_seconds + params.jam_chance_per_sec); the overlay mirrors
# progress and offers the repair prompt — which you must be AT THE DRILL to hit. The drill itself
# keeps running while you walk away (that IS the tension); only the repair needs you back. ---------
## Clearing a jam requires standing this close to the breach point — i.e. back where you had to be to
## START it. Mirrors PlayerConfigDef.interact_range (2.5 m, the interaction ray) with a small tolerance,
## so a breach you could reach to begin is always a breach you can reach to repair.
@export var drill_proximity_range: float = 3.0
