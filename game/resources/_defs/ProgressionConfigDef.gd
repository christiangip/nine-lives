extends Resource
class_name ProgressionConfigDef
## Tunables for the roguelite progression engine (task 12): Streak-Level thresholds, the
## performance-multiplier stack, the Heat→payout curve, the Catch conversion floor, and Edge
## draw weighting. Keeps RunManager/ProgressionManager free of magic numbers. The instance
## lives as game/resources/progression/default_progression.tres (registered as
## Content.progression); RunManager falls back to Content.progression's &"default".
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.

@export var id: StringName = &"default"   ## registry key; balance presets can coexist

# --- Streak Levels + Edges (FR-12-2, FR-12-8) ------------------------------
## Cumulative Notoriety needed to reach level 2, 3, 4, … (index i → level i+2). Streak Level is
## 1 + the count of thresholds the current Notoriety has passed.
@export var streak_level_thresholds: Array[int] = [
	1000, 2500, 4500, 7000, 10000, 13500, 17500, 22000, 27000,
]
@export var edge_choices_per_level: int = 3        ## a level-up offers a choice of 1 of N Edges
## Draw weight per EdgeDef.rarity (0 common .. 3 legendary). Rare Edges surface less often.
@export var edge_rarity_weights: Array[float] = [1.0, 0.5, 0.2, 0.05]

# --- Notoriety accrual + performance stack (FR-12-1) -----------------------
@export var objective_notoriety: int = 1000        ## base NP for completing a contract objective
## Performance bonuses (additive fractions on the ×1.0 base). A flawless run stacks them all.
@export var bonus_stealth: float = 0.50            ## never spotted this mission
@export var bonus_no_alarm: float = 0.30           ## no alarm tripped this mission
@export var bonus_no_kill: float = 0.30            ## no lethal takedowns
@export var bonus_speed: float = 0.25              ## finished under par time
@export var bonus_full_clear: float = 0.50         ## every objective completed

# --- Heat → payout multiplier (FR-12-3, FR-12-4) ---------------------------
## Legacy payout multiplier = base + heat*slope. Heat 0..1 → 1.0..(base+slope).
@export var heat_multiplier_base: float = 1.0
@export var heat_multiplier_slope: float = 1.0

# --- Catch conversion floor (FR-12-9) --------------------------------------
## Anti-frustration: every Catch pays at least this much Legacy, so the player can always
## afford *something*. Keep it ≥ the cheapest Training/Perk purchase.
@export var legacy_floor: int = 150

# --- Par time (feeds the speed bonus; MissionController may override per-contract) ----------
@export var default_par_seconds: float = 300.0
