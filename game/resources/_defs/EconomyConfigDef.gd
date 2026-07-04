extends Resource
class_name EconomyConfigDef
## The central, hot-editable balance table for the three-currency economy (task 14, GDD §12).
## Owns every dial the economy is *tuned* on: The Take's cash cut (FR-14-2), the Notoriety
## performance multipliers (FR-14-3), the Heat→Legacy payout slope, the anti-frustration floor
## (FR-14-5), plus the balancing-harness catch model + target bands (FR-14-5/6). Authored ONLY as
## game/data/economy.json (no .tres) so designers/modders tune the numbers without the editor — the
## flagship "cost/value tables live in data/*.json" deliverable (FR-14-4). Registered as
## Content.economy; resolve() falls back to these schema defaults so headless seams never crash
## (mirrors RunManager._cfg()). The per-item cost tables (loot/gear/attr/perk/intel) stay in their
## .tres and are range-checked by EconomyValidator rather than migrated here.
## See docs/tasks/14_economy_balancing.md.
##
## NOTE: task 14 took over the economy dials from ProgressionConfigDef (the `↩ From 12` handoff).
## ProgressionConfigDef keeps the streak *structure* (level thresholds, Edge draw weights); the
## bonus_*/heat_*/legacy_floor fields there remain (schema defaults) but are no longer the runtime
## source — RunManager reads them here via _econ().

@export var id: StringName = &"default"   ## registry key; balance presets can coexist (task 20)

# --- The Take (FR-14-1/2) --------------------------------------------------
## Fraction of a secured loot's cash value that becomes spendable Take (the launder/fence cut). The
## full value still feeds Notoriety — Take is the smaller, spendable slice. 0..1.
@export var take_fraction: float = 0.35
## Fraction of a fenced *special* trophy's value paid out as Take at the Fence station. 0..1
## (default 1.0 = fencing is the dedicated sale, no skim).
@export var fence_fraction: float = 1.0

# --- Notoriety accrual + performance stack (FR-14-3) -----------------------
@export var objective_notoriety: int = 1000        ## base NP for completing a contract objective
## Performance bonuses (additive fractions on the ×1.0 base). Stealth-favored: a clean run stacks a
## large multiplier; going loud forfeits all of these. (RunManager.stack_multiplier reads these.)
@export var bonus_stealth: float = 0.60            ## never spotted this mission
@export var bonus_no_alarm: float = 0.40           ## no alarm tripped this mission
@export var bonus_no_kill: float = 0.40            ## no lethal takedowns
@export var bonus_speed: float = 0.25              ## finished under par time
@export var bonus_full_clear: float = 0.50         ## every objective completed

# --- Heat → Legacy payout multiplier (FR-14-3/5) ---------------------------
## Legacy payout multiplier = base + heat*slope. Kept a MODEST slope on purpose: going loud raises
## Heat for a small payout bump, but the catch model punishes it far more — loud is a last resort,
## not a strategy (stealth-favored tuning).
@export var heat_multiplier_base: float = 1.0
@export var heat_multiplier_slope: float = 0.5

# --- Anti-frustration floor (FR-14-5) --------------------------------------
## Every Catch pays at least this much Legacy so the player can always afford *something*. Keep it
## ≥ min_first_buy_legacy (the cheapest first Training/Perk buy) — the validator asserts this.
@export var legacy_floor: int = 150

# --- Balancing harness: catch model (FR-14-6) ------------------------------
## Per-contract Catch probability in the simulator = clamp(base + per_tier*tier + per_heat*heat).
## per_heat is deliberately steep so a hot (loud) Streak dies fast — the risk half of push-your-luck.
@export var base_catch_chance: float = 0.06
@export var catch_per_tier: float = 0.05
@export var catch_per_heat: float = 0.55
@export var max_contracts_per_streak: int = 12     ## safety cap so a sim run always terminates
## Heat added per contract in the loud cohort (a balancing abstraction of "going loud raises Heat").
@export var sim_heat_per_loud_contract: float = 0.25
## Representative secured cash per contract (feeds the Take side of the sim). A balancing abstraction.
@export var sim_cash_per_contract: int = 5000

# --- Tuning-target bands (FR-14-5 invariants) ------------------------------
## A Streak should average "several missions". test_tuning_invariants asserts the sim's mean falls in
## [min, max] for the clean cohort.
@export var target_streak_len_min: float = 3.0
@export var target_streak_len_max: float = 7.0
## The cheapest first Legacy purchase (cheapest attribute's first cost_curve entry). legacy_floor must
## cover it so every Catch affords an impactful first buy. The validator cross-checks it against data.
@export var min_first_buy_legacy: int = 100

# --- Pure static seams (headless-testable) ---------------------------------
## The spendable Take a secured cash value yields (FR-14-2). Notoriety takes the full value; Take
## takes this cut. Pure — DropPoint.bank() and tests call it identically.
static func take_cut(cash_value: int, fraction: float) -> int:
	if cash_value <= 0:
		return 0
	return int(round(float(cash_value) * clampf(fraction, 0.0, 1.0)))

## The Take a fenced special trophy pays (FR-14-1). Pure.
static func fence_payout(value: int, fraction: float) -> int:
	if value <= 0:
		return 0
	return int(round(float(value) * clampf(fraction, 0.0, 1.0)))

## Per-contract Catch probability from the catch model (FR-14-6). Pure; clamped to a sane ceiling so a
## Streak can always, in principle, continue. tier ≥ 0, heat 0..1.
static func catch_chance(base: float, per_tier: float, tier: int, per_heat: float, heat: float) -> float:
	var p := base + per_tier * float(maxi(tier, 0)) + per_heat * clampf(heat, 0.0, 1.0)
	return clampf(p, 0.0, 0.95)

## The economy config in effect: Content.economy's &"default", or a schema-default fallback so headless
## seams (tests, the simulator) never crash. Mirrors the _cfg() idiom via the Services locator.
static func resolve() -> EconomyConfigDef:
	var c := Services.content()
	if c != null and c.economy != null:
		var d := c.economy.get_def(&"default") as EconomyConfigDef
		if d != null:
			return d
	return EconomyConfigDef.new()
