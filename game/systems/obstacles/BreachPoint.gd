extends Obstacle
class_name BreachPoint
## A breachable barrier — vault door, reinforced wall (FR-06-9, GDD §9.6). Three loud/semi-loud tools:
## DRILL (timed, noisy, can JAM and need a repair, upgradeable), THERMITE (timed burn, very loud, no
## jam), or C4 (instant breach, max alarm). This is a tension manager, not a puzzle: a timer + jam
## events + noise. Tool params (time/noise/jam, upgrades) come from the def / gear (task 09).
## The on-screen drill gauge/repair prompt is task 07 (FR-07-8); the logic lives here.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-9).

signal breach_progress(fraction: float)
signal jammed
signal breached(method: StringName)

var running: bool = false
var is_jammed: bool = false
var method: StringName = &"drill"
var progress: float = 0.0
var _speed_mult: float = 1.0   ## breach-gear upgrade: >1 drills faster (task 09, FR-09-3)
var _jam_mult: float = 1.0     ## breach-gear upgrade: <1 jams less often (task 09, FR-09-3)
var _drill_sfx: AudioStreamPlayer3D   ## running-drill loop (task 17); stopped on jam/finish

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Does the drill jam this tick? `roll` is a uniform draw in [0,1); `chance` already folds in delta. Pure.
static func jam_check(roll: float, chance: float) -> bool:
	return roll < chance

## Fraction complete for a timer. Pure.
static func fraction(progress_s: float, total_s: float) -> float:
	if total_s <= 0.0:
		return 1.0
	return clampf(progress_s / total_s, 0.0, 1.0)

# --- Breach lifecycle ------------------------------------------------------
## Instant tap requests the drill/thermite tension overlay (task 07). The DrillMinigame drives
## begin_breach + repair and mirrors progress; C4/thermite tool choice is a loadout concern (task 09),
## so the default request is the drill. Nothing to apply back — the breach owns its own completion.
func interact(_by: Node) -> void:
	if solved or running:
		return
	minigame_requested.emit(&"drill")

## Apply the equipped breach tool's upgrade params (↩ from 06, closes the FR-06-9 "gear/upgrades → 09"
## note): a faster drill (`speed_mult`) and/or reduced jam chance (`jam_mult`). Identity (1.0) when no
## gear is equipped, so the base tuning and every existing task-06 test are unchanged.
func equip_tool(gear_params: Dictionary) -> void:
	_speed_mult = maxf(0.0, float(gear_params.get("speed_mult", 1.0)))
	_jam_mult = maxf(0.0, float(gear_params.get("jam_mult", 1.0)))

func begin_breach(p_method: StringName, _by: Node = null) -> void:
	if solved or def == null or not def.has_solution(p_method):
		return
	method = p_method
	if method == &"c4":
		_trip_alarm("loud")            # instant + max alarm
		_finish()
		return
	running = true
	is_jammed = false
	progress = 0.0
	_emit_noise_for(method)            # the tool draws guards while it works
	_start_drill_sfx()                 # running-drill loop (task 17)

func repair() -> void:
	if is_jammed:
		is_jammed = false
		if running:
			_start_drill_sfx()   # resume the running-drill loop after a repair (task 17)

func _process(delta: float) -> void:
	if not running or is_jammed:
		return
	if method == &"drill" and _jam_chance() > 0.0 and jam_check(randf(), _jam_chance() * delta):
		is_jammed = true
		jammed.emit()
		_stop_drill_sfx()
		if AudioManager != null:
			AudioManager.play_sfx(&"drill_jam", global_position)
		return
	progress = minf(progress + delta * _speed_mult, def.time_seconds)
	breach_progress.emit(fraction(progress, def.time_seconds))
	if progress >= def.time_seconds and def.time_seconds > 0.0:
		_finish()

func _jam_chance() -> float:
	return (float(def.params.get("jam_chance_per_sec", 0.0)) if def != null else 0.0) * _jam_mult

func _finish() -> void:
	running = false
	_stop_drill_sfx()
	if AudioManager != null and method != &"c4":
		AudioManager.play_sfx(&"drill_done", global_position)   # thermite/drill completion (task 17)
	_mark_solved(method)
	breached.emit(method)

# --- Running-drill loop SFX (task 17) --------------------------------------
func _start_drill_sfx() -> void:
	if AudioManager == null or method == &"c4":
		return
	_stop_drill_sfx()
	_drill_sfx = AudioManager.play_loop(&"drill_run", global_position)

func _stop_drill_sfx() -> void:
	if is_instance_valid(_drill_sfx):
		_drill_sfx.queue_free()
	_drill_sfx = null
