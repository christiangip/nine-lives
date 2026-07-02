extends Node
## RunManager — current Streak (per-run) state. Resets on Catch.
## Autoload. Holds Notoriety, Streak Level, Edges, Heat, The Take, Job Map.
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.

var notoriety: int = 0
var streak_level: int = 1
var streak_length: int = 0          ## contracts completed this streak
var heat: float = 0.0               ## 0..1; rises on alarms/going loud
var take: int = 0                   ## per-streak cash currency
var edges: Array[StringName] = []   ## chosen temporary perks
var job_board: Array = []           ## available contracts (+ seeds)
var committed: bool = false         ## true once an alarm is raised (strict saves)
var _loadout: Loadout               ## the Streak's equipped gear (task 09); lazily created

## Going loud raises Heat and commits the Streak (FR-10-3). Heat-per-alarm amounts live in
## PursuitConfigDef (Content.pursuit) so there are no magic numbers here.
func _ready() -> void:
	if not EventBus.alarm_tripped.is_connected(_on_alarm_tripped):
		EventBus.alarm_tripped.connect(_on_alarm_tripped)

## An alarm (silent or loud) commits the Streak — no more mid-mission save-scumming (strict saves) —
## and raises Heat for the remainder of the Streak. Task 10 owns this trigger; task 11/12 own Heat's
## effect on future-contract security + the payout multiplier.
func _on_alarm_tripped(kind: String, _position: Vector3) -> void:
	committed = true
	raise_heat(_heat_for_alarm(kind))

func _heat_for_alarm(kind: String) -> float:
	var cfg: PursuitConfigDef = null
	if Content != null and Content.pursuit != null:
		cfg = Content.pursuit.get_def(&"default") as PursuitConfigDef
	if cfg == null:
		cfg = PursuitConfigDef.new()
	return cfg.heat_per_loud_alarm if kind == "loud" else cfg.heat_per_silent_alarm

## The per-Streak equipped Loadout (FR-09-8). The Armory (task 13) mutates it between missions and
## the save system (task 16) serializes it via loadout.to_dict()/from_dict(); PlayerController reads
## it for gadget queries. Lazily created so a fresh Streak always has a valid (empty) loadout.
func loadout() -> Loadout:
	if _loadout == null:
		_loadout = Loadout.new()
	return _loadout

func start_new_streak() -> void:
	notoriety = 0; streak_level = 1; streak_length = 0
	heat = 0.0; take = 0; edges.clear(); committed = false
	refresh_board()

## (Re)fill the Job Map from MissionGenerator, escalating with Streak length + Heat (FR-11-10). Called
## on a fresh Streak and after each completed contract. The difficulty floor rises with streak_length.
func refresh_board() -> void:
	if MissionGenerator != null:
		job_board = MissionGenerator.refresh_board(1 + streak_length, heat)

func add_notoriety(amount: int) -> void:
	if amount <= 0:
		return
	notoriety += amount
	EventBus.notoriety_gained.emit(amount, notoriety)
	# TODO[12]: apply multipliers, check streak level-up -> offer 3 Edges (wraps/extends this
	# base accumulation — task 08's secured-loot banking needs a real notoriety total now).

## Per-Streak cash from secured loot (task 08). A straight passthrough for now.
func add_take(amount: int) -> void:
	if amount <= 0:
		return
	take += amount
	# TODO[14]: FR-14-2 — Take = a % of secured cash value, not a 1:1 passthrough. This is the
	# real base `take` accrual task 08's banking needs now; 14's "M2 wiring" scales it.

## Raise Heat toward the 0..1 ceiling and announce it (FR-10-3). Going loud / every alarm calls this.
func raise_heat(amount: float) -> void:
	if amount <= 0.0:
		return
	heat = clampf(heat + amount, 0.0, 1.0)
	EventBus.heat_changed.emit(heat)
	# High Heat escalates later contracts' security via refresh_board(streak_len, heat) — task 11 (done).
	# TODO[12]: Heat still owes the Legacy payout multiplier (end_streak conversion).

func end_streak(reason: String) -> int:
	# Returns Legacy awarded. Conversion: notoriety * heat_multiplier.
	return 0 # TODO[12]: ProgressionManager.add_legacy(...), then reset
