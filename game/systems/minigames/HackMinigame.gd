extends Minigame
class_name HackMinigame
## Hack overlay (FR-07-5, GDD §9.2/§9.8): route a sequence of nodes under a SOFT TIMER while staying
## in PROXIMITY of the target — step out of range and the timer PAUSES (not resets); run the clock out
## and the hack fails. The Hacking attribute adds FAULT TOLERANCE (allowed mis-routes) + eases the tier
## time pressure; distinct visual variants per target type are a skin over the same seams. NON-MODAL
## (pauses_world = false) so the guard AI + pursuit keep running while you work. See docs/tasks/07_minigames.md.

const _DIRECTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
const _GLYPH := {&"ui_left": "◄", &"ui_right": "►", &"ui_up": "▲", &"ui_down": "▼"}

var _time_limit: float = 8.0
var _elapsed: float = 0.0
var _faults_left: int = 0
var _route: Array[StringName] = []
var _index: int = 0
var _hacker: Node3D
var _target: Node3D
var _proximity_range: float = 3.0
var _readout: Label

func _init() -> void:
	pauses_world = false   # the world keeps running; leaving proximity is what pauses the hack

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Is the hacker close enough to keep the hack live? Pure (mirrors HackTarget.in_proximity).
static func in_proximity(distance: float, max_range: float) -> bool:
	return distance <= max_range

## Advance the soft timer by `delta` only while in range; out of range it HOLDS (pause, not reset). Pure.
static func tick_timer(elapsed: float, delta: float, in_range: bool) -> float:
	return elapsed + delta if in_range else elapsed

## Has the soft timer run out? Pure.
static func is_expired(elapsed: float, limit: float) -> bool:
	return elapsed >= limit

## Allowed mis-routes before the hack fails — Hacking adds fault tolerance. Floored at 0. Pure.
static func fault_budget(base: float, hacking_level: float, per_level: float) -> int:
	return int(floor(maxf(0.0, Minigame.scaled(base, hacking_level, per_level))))

## Tier-adjusted soft-timer seconds (tighter per tier, floored). Pure.
static func time_limit_for_tier(base: float, tier: int, tier_penalty: float, min_limit: float) -> float:
	return maxf(min_limit, base - float(maxi(0, tier - 1)) * tier_penalty)

## Routing nodes to connect for a tier. Pure.
static func node_count_for_tier(base: int, tier: int, per_tier: int) -> int:
	return maxi(1, base + maxi(0, tier - 1) * per_tier)

# --- Lifecycle -------------------------------------------------------------
func begin(ctx: Dictionary = {}) -> void:
	super.begin(ctx)
	_hacker = ctx.get("hacker") as Node3D
	_target = ctx.get("target") as Node3D
	_proximity_range = float(ctx.get("proximity_range", config.hack_proximity_range))
	_time_limit = time_limit_for_tier(config.hack_time_limit_base, difficulty,
		config.hack_time_limit_tier_penalty, config.hack_time_limit_min)
	_faults_left = fault_budget(config.hack_fault_base, float(attribute_level), config.hack_fault_per_level)
	var n := node_count_for_tier(config.hack_nodes_base, difficulty, config.hack_nodes_per_tier)
	_route.clear()
	for _i in n:
		_route.append(_DIRECTIONS[randi() % _DIRECTIONS.size()])
	_index = 0
	_elapsed = 0.0
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.position.y = 40.0
	add_child(_readout)
	_refresh()

func _process(delta: float) -> void:
	if _finished:
		return
	var in_range := _current_in_range()
	_elapsed = tick_timer(_elapsed, delta, in_range)
	if is_expired(_elapsed, _time_limit):
		_finish_failed("timeout")
		return
	if in_range:
		for dir in _DIRECTIONS:
			if Input.is_action_just_pressed(dir):
				_route_input(dir)
				break
	_refresh()

func _current_in_range() -> bool:
	if _hacker == null or _target == null:
		return true   # no spatial context (greybox / test) → always live
	return in_proximity(_hacker.global_position.distance_to(_target.global_position), _proximity_range)

func _route_input(dir: StringName) -> void:
	if _index < _route.size() and dir == _route[_index]:
		_index += 1
		if _index >= _route.size():
			_finish_solved()
	else:
		_faults_left -= 1
		if _faults_left < 0:
			_finish_failed("faults")

func _refresh() -> void:
	if _readout == null:
		return
	var seq := ""
	for i in _route.size():
		seq += ("[%s]" if i == _index else " %s ") % _GLYPH[_route[i]]
	_readout.text = "HACK  route the sequence   %.1fs   faults left: %d\n%s%s" % [
		maxf(0.0, _time_limit - _elapsed), _faults_left, seq,
		"" if _current_in_range() else "\n— OUT OF RANGE (paused) —"]
