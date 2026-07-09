extends Node3D
class_name PlayerCombat
## The first-person firing controller (task 10, FR-10-4): the in-world half that wraps task 09's pure
## Weapon model. Mounts under PlayerController/$Head/Hands so it aims down the look direction; builds live
## Weapon instances from the Streak Loadout's WEAPON slot, ticks recoil/cooldown, fires on input, and
## hit-scans the shot against hostiles (group &"guard") applying Weapon.fire()'s damage. Marksmanship
## eases spread (Weapon.current_spread already reads it); cover/lean come from PlayerController (task 03).
## Weapon.fire() already emits the frozen EventBus.noise_emitted("gunshot") ring, so detection (04)
## reacts. Tunables live on the Weapon/GearDef + PursuitConfigDef — no magic numbers. See GDD §8.6.

@export var player_path: NodePath   ## the PlayerController (auto-found among ancestors if unset)

var player: PlayerController
var weapons: Array[Weapon] = []
var active_index: int = 0
var suppression: float = 0.0        ## 0..1, raised by incoming near-misses; widens spread while it lasts

signal shot_hit                     ## a fired shot connected with a hostile (HUD hit-marker, task 21)

func _ready() -> void:
	_resolve_player()
	rebuild_weapons()

func _resolve_player() -> void:
	if player_path != NodePath() and has_node(player_path):
		player = get_node(player_path) as PlayerController
	if player == null:
		var n := get_parent()
		while n != null and not (n is PlayerController):
			n = n.get_parent()
		player = n as PlayerController

## (Re)build Weapon models from the equipped WEAPON gear. Called on spawn and whenever the loadout
## changes (Armory between missions — task 13 will re-arm it).
func rebuild_weapons() -> void:
	weapons.clear()
	active_index = 0
	if player == null or player.loadout == null:
		return
	for gear in player.loadout.weapons():
		weapons.append(Weapon.new(gear))

func active_weapon() -> Weapon:
	return weapons[active_index] if active_index >= 0 and active_index < weapons.size() else null

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Blindfiring from cover (not peeking) trades accuracy for safety: widen spread. Pure. (FR-10-4)
static func blindfire_spread(spread: float, blindfiring: bool, mult: float) -> float:
	return spread * mult if blindfiring else spread

## Suppression from incoming fire widens the shooter's effective spread (0..1 → up to `mult`). Pure.
static func suppressed_spread(spread: float, suppression_amount: float, mult: float) -> float:
	return spread * (1.0 + clampf(suppression_amount, 0.0, 1.0) * mult)

## Loud aim-assist (FR-21-1): nudge `aim_dir` toward `target_dir` by at most `max_deg`. If the target is
## already within the cap it snaps to it, otherwise it rotates the cap amount toward it — never a hard lock,
## and only ever applied while firing (stealth is untouched). Both inputs need not be normalized. Pure.
static func assist_aim(aim_dir: Vector3, target_dir: Vector3, max_deg: float) -> Vector3:
	if aim_dir.length() < 0.0001 or target_dir.length() < 0.0001:
		return aim_dir
	var a := aim_dir.normalized()
	var t := target_dir.normalized()
	var ang := a.angle_to(t)
	if ang <= 0.0001:
		return a
	var frac := clampf(deg_to_rad(max_deg) / ang, 0.0, 1.0)
	return a.slerp(t, frac)

# --- Firing glue -----------------------------------------------------------
func _physics_process(delta: float) -> void:
	var w := active_weapon()
	if w != null:
		w.tick(delta)
	suppression = maxf(0.0, suppression - delta)   # bleeds off over ~1s
	if player == null:
		return
	if Input.is_action_just_pressed(&"fire"):
		fire()
	elif Input.is_action_just_pressed(&"reload"):
		reload()
	elif Input.is_action_just_pressed(&"weapon_next"):
		next_weapon()

## Cycle to the next equipped weapon (FR-10-4 weapon handling).
func next_weapon() -> void:
	if weapons.size() > 1:
		active_index = (active_index + 1) % weapons.size()

## Fire the active weapon and resolve the hit. Returns the shot dict (empty if it couldn't fire).
func fire() -> Dictionary:
	var w := active_weapon()
	if w == null:
		return {}
	var marks := player.attr_effect(&"marksmanship") if player != null else 0.0
	var shot := w.fire(global_position, marks)
	if shot.is_empty():
		return shot
	if player != null:
		player.on_weapon_fired()   # recoil camera shake + rumble (task 21)
	_resolve_hit(float(shot["damage"]))
	return shot

func reload() -> bool:
	var w := active_weapon()
	return w.reload() if w != null else false

## Raycast down the aim direction; deal the shot's damage to whatever hostile it strikes. Hostiles
## expose apply_damage(float) (GuardAI); a killed guard drops to a discoverable Body via its own logic.
func _resolve_hit(damage: float) -> void:
	if not is_inside_tree() or damage <= 0.0:
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := global_position
	var to := from + _aim_direction() * _aim_range()
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if player != null:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var target = hit.get("collider")
	while target != null and not target.has_method("apply_damage"):
		target = target.get_parent() if target is Node else null
	if target != null and target.has_method("apply_damage"):
		target.apply_damage(damage)
		shot_hit.emit()   # hit confirmation (HUD marker, task 21)

## The firing direction: the raw aim, nudged by loud aim-assist toward a nearby hostile when the option is on
## (FR-21-1). Off/stealth → the raw camera forward.
func _aim_direction() -> Vector3:
	var base := -global_transform.basis.z
	if not _aim_assist_on():
		return base
	var cfg := _pursuit_cfg()
	if cfg == null:
		return base
	var target := _nearest_target_in_cone(base, cfg.aim_assist_cone_deg)
	if target == null:
		return base
	var to := ((target as Node3D).global_position + Vector3.UP * 1.0) - global_position
	return assist_aim(base, to, cfg.aim_assist_max_deg)

## Nearest hostile (group &"guard") within `cone_deg` of `dir` and inside aim range, or null.
func _nearest_target_in_cone(dir: Vector3, cone_deg: float) -> Node:
	var best: Node = null
	var best_d := INF
	var half := deg_to_rad(cone_deg)
	var d := dir.normalized()
	for g in get_tree().get_nodes_in_group(&"guard"):
		if not (g is Node3D):
			continue
		var to := (g as Node3D).global_position - global_position
		var dist := to.length()
		if dist < 0.05 or dist > _aim_range():
			continue
		if d.angle_to(to / dist) > half:
			continue
		if dist < best_d:
			best_d = dist
			best = g
	return best

func _aim_assist_on() -> bool:
	var s := Services.settings()
	return s != null and bool(s.get_value("gameplay", "aim_assist"))

func _pursuit_cfg() -> PursuitConfigDef:
	if Content != null and Content.pursuit != null:
		return Content.pursuit.get_def(&"default") as PursuitConfigDef
	return null

func _aim_range() -> float:
	var cfg := _pursuit_cfg()
	return cfg.guard_engage_range * 4.0 if cfg != null else 60.0
