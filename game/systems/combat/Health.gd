extends RefCounted
class_name Health
## The player damage-routing + down/capture brain (task 10, FR-10-6/FR-10-7). A pure-ish RefCounted
## (like Inventory/Weapon/Armor) so it's headless-testable. Damage hits the Armor plate pool first
## (task 09's Armor.absorb) and the overflow bleeds Health; emptying Health drops the player to DOWNED
## with a self-revive window that, if it lapses, becomes CAUGHT. Being surrounded while down triggers
## a Capture, where a one-time Get-Out-of-Jail skill-check can still buy an escape. CAUGHT/CAPTURED are
## both "the Catch" (§8.7) — the resolution flow hands off to task 12. Tunables come from
## PursuitConfigDef (Content.pursuit) — no magic numbers. See docs/tasks/10_going_loud_pursuit.md.

enum State { ALIVE, DOWNED, CAUGHT, CAPTURED, ESCAPED }

## The timing-bar sweet-spot the Get-Out-of-Jail check aims for (0..1). Bar geometry, not a tunable.
const _JAIL_TARGET := 0.5

var config: PursuitConfigDef
var max_health: float = 100.0
var current: float = 100.0
var armor: Armor                       ## optional plate pool; damage routes through it first
var state: int = State.ALIVE

var _revive_timer: float = 0.0         ## counts the DOWNED self-revive window down to CAUGHT

signal state_changed(new_state: int)   ## local readability (HUD is task 15)

func _init(p_max_health: float = 100.0, p_armor: Armor = null, p_config: PursuitConfigDef = null) -> void:
	max_health = p_max_health
	current = p_max_health
	armor = p_armor
	config = p_config
	_resolve_config()

func _resolve_config() -> void:
	if config == null:
		var c := Services.content()
		if c != null and c.pursuit != null:
			config = c.pursuit.get_def(&"default") as PursuitConfigDef
	if config == null:
		config = PursuitConfigDef.new()

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Split `damage` across an armor pool then Health: armor soaks first (Armor.split), the overflow
## bleeds Health. Returns {to_armor, to_health, remaining_armor, remaining_health}. Pure. (FR-10-6)
static func route_damage(damage: float, armor_hp: float, health: float) -> Dictionary:
	var s := Armor.split(damage, armor_hp)
	return {
		"to_armor": s["to_armor"],
		"to_health": s["to_health"],
		"remaining_armor": s["remaining_armor"],
		"remaining_health": maxf(0.0, health - float(s["to_health"])),
	}

## Health is spent when it hits 0. Pure.
static func is_down(health: float) -> bool:
	return health <= 0.0

## The Get-Out-of-Jail timing check: the player stops a bar at `input` (0..1); it passes within
## `tolerance` of the sweet spot. Pure/deterministic so it's headless-testable. (FR-10-7)
static func skill_check_pass(input: float, tolerance: float) -> bool:
	return absf(input - _JAIL_TARGET) <= tolerance

# --- Damage / downs (FR-10-6) ----------------------------------------------
## Apply `damage`: armor absorbs first, the overflow bleeds Health; emptying Health → DOWNED. Returns
## the health damage actually dealt. No-op once already Downed/Caught/Captured.
func take_damage(damage: float) -> float:
	if damage <= 0.0 or state != State.ALIVE:
		return 0.0
	var to_health := damage
	if armor != null:
		to_health = armor.absorb(damage)
	current = maxf(0.0, current - to_health)
	if is_down(current):
		_set_state(State.DOWNED)
		_revive_timer = config.self_revive_window
	return to_health

## Per-frame: bleed the self-revive window (DOWNED → CAUGHT when it lapses) and regen armor while alive.
func tick(delta: float) -> void:
	if state == State.DOWNED:
		_revive_timer = maxf(0.0, _revive_timer - delta)
		if _revive_timer <= 0.0:
			_set_state(State.CAUGHT)
	elif state == State.ALIVE and armor != null:
		armor.regen(delta)

## Self-revive during the DOWNED window (right gear/perk, §8.7). Returns true if it took.
func revive() -> bool:
	if state != State.DOWNED:
		return false
	current = max_health * config.revive_health_fraction
	_set_state(State.ALIVE)
	return true

# --- Capture / Get-Out-of-Jail (FR-10-7) -----------------------------------
## The surrounded/cuffed moment (§8.7). If a Get-Out-of-Jail consumable is held, a one-time timing
## skill-check (`skill_input`, 0..1) can escape it — success consumes the item and frees the player;
## otherwise (or on a miss) the Streak-ending CAPTURED latches. Returns true iff the player escaped.
func capture(loadout, skill_input: float = -1.0) -> bool:
	if loadout != null and loadout.consumable_count(&"get_out_of_jail") > 0 \
			and skill_check_pass(skill_input, config.jail_skill_tolerance):
		loadout.consume(&"get_out_of_jail")
		_set_state(State.ESCAPED)
		return true
	_set_state(State.CAPTURED)
	return false

## Reached an Escape with the run intact (FR-10-8).
func escaped() -> void:
	_set_state(State.ESCAPED)

func is_catch() -> bool:
	return state == State.CAUGHT or state == State.CAPTURED

func _set_state(s: int) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(state)
