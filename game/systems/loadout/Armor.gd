extends RefCounted
class_name Armor
## The armor LAYER model (Q2, FR-09-5): a plate/segment pool on top of Health that absorbs damage first
## and regenerates after a lull, and whose weight trades off against agility (move speed). This is the
## data + maths half; WHICH pool takes damage first and the Downed/Capture flow are task-10's damage
## routing (FR-10-6) — it drives this model. Built from a GearDef's params so armor ships as data.
## A pure-ish RefCounted like Inventory/Loadout/Weapon for headless tests.
## See docs/tasks/09_loadout_gear_gadgets.md (FR-09-5) and GDD §5.5 / §8.7.

var def: GearDef
var config: LoadoutConfigDef

var plate_hp: float = 50.0     ## HP per plate/segment
var plates: int = 2            ## number of segments
var weight_kg: float = 6.0     ## mass driving the agility tradeoff

var current: float = 0.0       ## current armor HP (starts full)
var _regen_timer: float = 0.0  ## counts down the post-hit delay before regen resumes

func _init(p_def: GearDef = null, p_config: LoadoutConfigDef = null) -> void:
	def = p_def
	config = p_config
	_resolve_config()
	_read_params()
	current = maximum()

func _resolve_config() -> void:
	if config == null:
		var c := Services.content()
		if c != null and c.loadout != null:
			config = c.loadout.get_def(&"default") as LoadoutConfigDef
	if config == null:
		config = LoadoutConfigDef.new()

func _read_params() -> void:
	if def == null:
		return
	plate_hp = float(def.param(&"plate_hp", plate_hp))
	plates = int(def.param(&"plates", plates))
	weight_kg = float(def.param(&"weight_kg", weight_kg))

func maximum() -> float:
	return plate_hp * float(plates)

# --- FR-09-5 absorb (the pure seam task-10 damage routing calls) ------------
## Split `damage` against `armor_hp`: armor soaks what it can, the rest overflows to Health. Returns
## {to_armor, to_health, remaining_armor}. Pure — task 10 decides ordering; this is the plate maths.
static func split(damage: float, armor_hp: float) -> Dictionary:
	var soaked := clampf(damage, 0.0, maxf(0.0, armor_hp))
	return {
		"to_armor": soaked,
		"to_health": maxf(0.0, damage - soaked),
		"remaining_armor": maxf(0.0, armor_hp - soaked),
	}

## Apply `damage` to this armor pool, returning the overflow that should hit Health. Resets the
## regen delay (a fresh hit interrupts regeneration).
func absorb(damage: float) -> float:
	var r := split(damage, current)
	current = r["remaining_armor"]
	_regen_timer = config.armor_regen_delay
	return r["to_health"]

# --- Regen (segments recover after a lull) ----------------------------------
func regen(delta: float) -> void:
	if current >= maximum():
		return
	# Burn down the post-hit delay first; if this tick outlasts it, spend the leftover on regen so a
	# large delta doesn't silently skip a regen frame.
	if _regen_timer > 0.0:
		if _regen_timer >= delta:
			_regen_timer -= delta
			return
		delta -= _regen_timer
		_regen_timer = 0.0
	current = minf(maximum(), current + config.armor_regen_per_sec * delta)

# --- FR-09-5 weight/agility tradeoff ----------------------------------------
## Move-speed multiplier from armor weight: 1 − weight × penalty_per_kg, floored so heavy armor slows
## but never freezes you. Pure.
static func agility_mult(weight: float, penalty_per_kg: float) -> float:
	return clampf(1.0 - weight * penalty_per_kg, 0.4, 1.0)

func speed_mult() -> float:
	return agility_mult(weight_kg, config.armor_speed_penalty_per_kg)
