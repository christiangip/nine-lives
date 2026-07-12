extends Node
class_name PursuitDirector
## The Going-Loud Pursuit timeline (task 10, FR-10-1/FR-10-2). A mission-scoped node that listens
## for EventBus.alarm_tripped and escalates the police response through phases 0..5 (GDD §8.6):
## 0 Calm · 1 Local guards · 2 Alarm confirmed · 3 Responders · 4 Police flood · 5 Tactical. Each
## step re-emits the frozen EventBus.pursuit_phase_changed and computes a spawn budget + reinforcement
## tier; the actual spawn PLACEMENT into a nav-meshed level is task 11 (this exposes a local
## `reinforcements_requested` seam a greybox / MissionGenerator wires to real sockets — no new signals).
## It also owns the LOST-CONTACT timer (misc-fixes-3 issue 1): pursuit_lost_timeout seconds with no sensor
## anywhere holding any detection fill ends the pursuit — RunManager.enter_alerted() then a phase-0
## broadcast, which sensors de-latch on and guards stand down on. Heat + committed are owned by
## RunManager's own alarm listener. Tunables come from PursuitConfigDef (Content.pursuit) — no magic
## numbers. See docs/tasks/10_going_loud_pursuit.md and GDD §8.6.

@export var config: PursuitConfigDef   ## falls back to Content.pursuit's &"default"

var phase: int = 0            ## current Pursuit phase (0 = calm/pre-alarm)
var active: bool = false      ## true once the first alarm has fired
var _elapsed: float = 0.0     ## seconds spent in the current phase
var _lost_timer: float = 0.0  ## seconds since ANY sensor last held contact; ends the pursuit at pursuit_lost_timeout

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

## Is anyone currently holding contact? True when ANY sensor's meter is off zero — a glimpse, a partial
## sighting, a heard footstep all count ("even partially found" keeps the hunt alive). Pure. (issue 1)
static func has_contact(fills: Array) -> bool:
	for f in fills:
		if float(f) > 0.0:
			return true
	return false

## Advance the lost-contact timer: reset to 0 while any sensor holds contact, else accumulate. Pure.
static func step_lost_timer(current: float, delta: float, contact: bool) -> float:
	return 0.0 if contact else current + delta

# --- Timeline glue ---------------------------------------------------------
func _process(delta: float) -> void:
	if not active:
		return
	# The lost-contact timer runs whenever the pursuit is active — INCLUDING at the terminal phase, which
	# the escalation branch below skips. Contact is POLLED from sensor fill rather than driven by
	# detection_changed: that signal is throttled by a fill epsilon and its ALERTED state latches, so a
	# sensor staring at the player at fill 1.0 emits nothing at all (see discovery.md #4) and an
	# event-driven timer would "end" the pursuit mid-firefight.
	_lost_timer = step_lost_timer(_lost_timer, delta, _any_sensor_has_contact())
	if _lost_timer >= config.pursuit_lost_timeout:
		_end_pursuit()
		return
	if phase >= config.max_phase():
		return
	_elapsed += delta
	var nxt := next_phase(phase, _elapsed, config.phase_durations)
	if nxt != phase:
		_set_phase(nxt)

## Scan the &"detection_sensor" group (guards AND cameras) for any live meter. The group is capped by
## AIConfigDef.max_active_guards, so this is a handful of property reads — negligible next to the
## sensors' own LoS raycasts, and the only correct source given the throttled signal above.
func _any_sensor_has_contact() -> bool:
	if not is_inside_tree():
		return false
	var fills: Array = []
	for s in get_tree().get_nodes_in_group(&"detection_sensor"):
		fills.append(s.get(&"fill"))
	return has_contact(fills)

## No contact for pursuit_lost_timeout seconds → call off the hunt. RunManager flips to ALERTED FIRST:
## pursuit_phase_changed(0) is the mission-wide "pursuit ended" broadcast that sensors de-latch on and
## guards stand down on, and signal delivery is synchronous — alert_state must already read ALERTED when
## those handlers run. Phase 0 requests no reinforcements (spawn_budget[0] == 0); the music de-escalates
## and the HUD banner drops to phase 0, while Heat + committed persist (truthful — the run is still hot).
func _end_pursuit() -> void:
	active = false
	_lost_timer = 0.0
	if RunManager != null:
		RunManager.enter_alerted()
	_set_phase(0)

## First alarm arms the timeline; a later silent alarm can still skip it ahead. Loud never regresses.
## A fresh alarm also re-arms the lost-contact timer (and RunManager's own listener flips alert_state back
## to PURSUIT), so an ALERTED level re-escalates into a full pursuit.
func _on_alarm_tripped(kind: String, _position: Vector3) -> void:
	_lost_timer = 0.0
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
