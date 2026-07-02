extends Node
class_name PursuitDirector
## The Going-Loud Pursuit timeline (task 10, FR-10-1/FR-10-2). A mission-scoped node that listens
## for EventBus.alarm_tripped and escalates the police response through phases 0..5 (GDD §8.6):
## 0 Calm · 1 Local guards · 2 Alarm confirmed · 3 Responders · 4 Police flood · 5 Tactical. Each
## step re-emits the frozen EventBus.pursuit_phase_changed and computes a spawn budget + reinforcement
## tier; the actual spawn PLACEMENT into a nav-meshed level is task 11 (this exposes a local
## `reinforcements_requested` seam a greybox / MissionGenerator wires to real sockets — no new signals).
## Heat + committed are owned by RunManager's own alarm listener. Tunables come from PursuitConfigDef
## (Content.pursuit) — no magic numbers. See docs/tasks/10_going_loud_pursuit.md and GDD §8.6.

@export var config: PursuitConfigDef   ## falls back to Content.pursuit's &"default"

var phase: int = 0            ## current Pursuit phase (0 = calm/pre-alarm)
var active: bool = false      ## true once the first alarm has fired
var _elapsed: float = 0.0     ## seconds spent in the current phase

## Emitted when the director wants `count` hostiles of `tier` (an EnemyDef id) placed. Task 11 /
## the greybox listens and spawns them at level sockets. Local (not a cross-system EventBus signal).
signal reinforcements_requested(tier: StringName, count: int)

func _ready() -> void:
	if config == null and Content != null and Content.pursuit != null:
		config = Content.pursuit.get_def(&"default") as PursuitConfigDef
	if config == null:
		config = PursuitConfigDef.new()
	if not EventBus.alarm_tripped.is_connected(_on_alarm_tripped):
		EventBus.alarm_tripped.connect(_on_alarm_tripped)

func _exit_tree() -> void:
	if EventBus.alarm_tripped.is_connected(_on_alarm_tripped):
		EventBus.alarm_tripped.disconnect(_on_alarm_tripped)

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## The phase an alarm starts the timeline at: loud → 1 (local guards), silent → skip ahead
## (police quietly enroute, no on-screen warning). Pure. (FR-10-2)
static func start_phase(kind: String, silent_skip: int) -> int:
	return maxi(1, silent_skip) if kind == "silent" else 1

## Given the current phase, seconds elapsed in it, and the per-phase durations, return the next
## phase. Advances by one when the dwell time is spent; a duration <= 0 marks a terminal phase
## (the timeline tops out at tactical). Pure. (FR-10-1)
static func next_phase(current: int, elapsed: float, durations: Array) -> int:
	if current < 1 or current >= durations.size() - 1:
		return current
	var dur := float(durations[current])
	if dur > 0.0 and elapsed >= dur:
		return current + 1
	return current

## The spawn budget (active-hostile target) for a phase. Pure. (FR-10-5)
static func spawn_budget_for(phase_i: int, budgets: Array) -> int:
	return int(budgets[phase_i]) if phase_i >= 0 and phase_i < budgets.size() else 0

## The reinforcement EnemyDef id for a phase (the tier ladder). Pure. (FR-10-5)
static func tier_for(phase_i: int, ladder: Array) -> StringName:
	return StringName(ladder[phase_i]) if phase_i >= 0 and phase_i < ladder.size() else &""

# --- Timeline glue ---------------------------------------------------------
func _process(delta: float) -> void:
	if not active or phase >= config.max_phase():
		return
	_elapsed += delta
	var nxt := next_phase(phase, _elapsed, config.phase_durations)
	if nxt != phase:
		_set_phase(nxt)

## First alarm arms the timeline; a later silent alarm can still skip it ahead. Loud never regresses.
func _on_alarm_tripped(kind: String, _position: Vector3) -> void:
	var target := start_phase(kind, config.silent_skip_phase)
	if not active:
		active = true
		_set_phase(target)
	elif target > phase:
		_set_phase(target)

func _set_phase(p: int) -> void:
	phase = clampi(p, 0, config.max_phase())
	_elapsed = 0.0
	EventBus.pursuit_phase_changed.emit(phase)
	_request_reinforcements()

func _request_reinforcements() -> void:
	var count := spawn_budget_for(phase, config.spawn_budget)
	var tier := tier_for(phase, config.tier_ladder)
	if count > 0 and tier != &"":
		reinforcements_requested.emit(tier, count)
