extends RefCounted
class_name Weapon
## The weapon MODEL (Q2 cover-shooter, FR-09-4): ammo/reload, recoil-driven spread, attachment mods,
## and — the piece that matters for stealth — a noise profile where SUPPRESSED shots emit a much smaller
## ring than loud ones (feeds task-04 detection via the frozen EventBus.noise_emitted). This is the data
## + maths half; the in-world firing, hit resolution, cover and damage routing are task 10's cover-shooter
## (it wraps this model in a viewmodel Node and consumes fire()'s shot dictionary). Built from a GearDef's
## params so weapons ship as data. A pure-ish RefCounted like Inventory/Loadout for headless tests.
## See docs/tasks/09_loadout_gear_gadgets.md (FR-09-4) and GDD §8.6.

var def: GearDef
var config: LoadoutConfigDef

# Resolved from def.params (no magic numbers in logic)
var damage: float = 20.0
var ammo_capacity: int = 12
var suppressed: bool = false
var base_noise_radius: float = 24.0     ## loud-shot noise ring (m)
var spread_base: float = 1.0            ## deg at rest
var recoil_per_shot: float = 1.5        ## deg added to accumulated recoil each shot
var recoil_recovery: float = 6.0        ## deg/sec recoil bleeds off
var fire_interval: float = 0.12         ## seconds between shots
var reload_time: float = 1.5            ## seconds a reload takes (0 = instant); drives the HUD progress bar

var ammo: int = 0
var reserve: int = 0
var is_reloading: bool = false
var _recoil: float = 0.0                ## accumulated recoil (deg), decays over time
var _cooldown: float = 0.0
var _reload_timer: float = 0.0          ## counts a timed reload down to completion
var _mods: Array[StringName] = []       ## attached attachment/mod ids (FR-09-4)

func _init(p_def: GearDef = null, p_config: LoadoutConfigDef = null) -> void:
	def = p_def
	config = p_config
	_resolve_config()
	_read_params()
	ammo = ammo_capacity

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
	damage = float(def.param(&"damage", damage))
	ammo_capacity = int(def.param(&"ammo_capacity", ammo_capacity))
	suppressed = bool(def.param(&"suppressed", suppressed))
	base_noise_radius = float(def.param(&"noise_radius", base_noise_radius))
	spread_base = float(def.param(&"spread_base", spread_base))
	recoil_per_shot = float(def.param(&"recoil_per_shot", recoil_per_shot))
	recoil_recovery = float(def.param(&"recoil_recovery", recoil_recovery))
	fire_interval = float(def.param(&"fire_interval", fire_interval))
	reload_time = float(def.param(&"reload_time", reload_time))
	reserve = int(def.param(&"reserve", reserve))

# --- FR-09-4 noise profile (feeds 04/10) — the pure seam test_weapon_noise_profile calls ----
## Noise ring (m) a shot emits: loud = base, suppressed = base × suppressor_factor (< 1). Pure.
static func shot_noise_radius(base: float, is_suppressed: bool, suppressor_factor: float) -> float:
	return base * suppressor_factor if is_suppressed else base

func noise_radius() -> float:
	return shot_noise_radius(base_noise_radius, suppressed, config.suppressor_noise_factor)

# --- FR-09-4 spread/recoil (Marksmanship eases it; consumed by task-10 combat) --------------
## Spread (deg) = base + accumulated_recoil × spread_per_recoil, reduced by Marksmanship. `marks_effect`
## is 0..1 (level × AttributeDef.effect_per_level, caller-resolved — the Lock.resolve_attempt pattern).
## Pure.
static func spread(base_deg: float, recoil_accum: float, spread_per_recoil: float,
		marks_effect: float, marks_reduction: float) -> float:
	var raw := base_deg + recoil_accum * spread_per_recoil
	return raw * (1.0 - clampf(marks_effect, 0.0, 1.0) * marks_reduction)

func current_spread(marks_effect: float = 0.0) -> float:
	return spread(spread_base, _recoil, config.spread_per_recoil, marks_effect,
		config.marksmanship_spread_reduction)

# --- Attachments / mods (FR-09-4) -------------------------------------------
## Attach an attachment/mod GearDef; its params override this weapon's (e.g. a suppressor sets
## suppressed = true, a compensator lowers recoil_per_shot). Data-driven — branch on params, never id.
func attach(mod: GearDef) -> void:
	if mod == null or mod.id in _mods:
		return
	_mods.append(mod.id)
	for key in mod.params:
		match key:
			"suppressed": suppressed = bool(mod.params[key])
			"noise_radius": base_noise_radius = float(mod.params[key])
			"recoil_per_shot": recoil_per_shot = float(mod.params[key])
			"spread_base": spread_base = float(mod.params[key])
			"ammo_capacity": ammo_capacity = int(mod.params[key])

func mods() -> Array[StringName]:
	return _mods.duplicate()

# --- Firing / ammo (task 10 consumes the returned shot; this owns ammo/recoil) --------------
func can_fire() -> bool:
	return ammo > 0 and _cooldown <= 0.0 and not is_reloading

## Fire one shot: spend a round, add recoil, and return the shot data task-10 combat resolves
## (damage + spread + noise). Emits the noise ring so detection (04) reacts even before combat wiring.
## Returns an empty Dictionary if it can't fire (empty mag / on cooldown).
func fire(origin: Vector3 = Vector3.ZERO, marks_effect: float = 0.0) -> Dictionary:
	if not can_fire():
		return {}
	ammo -= 1
	_recoil += recoil_per_shot
	_cooldown = fire_interval
	var radius := noise_radius()
	if radius > 0.0 and Engine.get_main_loop() is SceneTree:
		EventBus.noise_emitted.emit(origin, radius, "gunshot")
	return {
		"damage": damage,
		"spread": current_spread(marks_effect),
		"noise_radius": radius,
		"suppressed": suppressed,
	}

## Begin a timed reload (completes in `reload_time`s via tick()). No-op if the mag is already full,
## the reserve is empty, or a reload is already running. With reload_time <= 0 it completes instantly.
## Returns true if a reload was started (or instantly completed).
func reload() -> bool:
	if is_reloading or reserve <= 0 or ammo >= ammo_capacity:
		return false
	if reload_time <= 0.0:
		_finish_reload()
		return true
	is_reloading = true
	_reload_timer = reload_time
	return true

## Move rounds from the reserve into the magazine, up to capacity. Returns rounds loaded.
func _finish_reload() -> int:
	is_reloading = false
	_reload_timer = 0.0
	var need := ammo_capacity - ammo
	var loaded := mini(need, reserve)
	ammo += loaded
	reserve -= loaded
	return loaded

## Reload completion 0..1 (1.0 when not reloading), for the HUD progress bar.
func reload_progress() -> float:
	if not is_reloading or reload_time <= 0.0:
		return 1.0
	return clampf(1.0 - _reload_timer / reload_time, 0.0, 1.0)

## Recoil bleed-off + fire-rate cooldown + timed reload. Task 10 calls this each frame; tests drive it directly.
func tick(delta: float) -> void:
	_recoil = maxf(0.0, _recoil - recoil_recovery * delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_reloading:
		_reload_timer = maxf(0.0, _reload_timer - delta)
		if _reload_timer <= 0.0:
			_finish_reload()

func recoil() -> float:
	return _recoil
