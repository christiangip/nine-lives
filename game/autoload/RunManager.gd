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

func start_new_streak() -> void:
	notoriety = 0; streak_level = 1; streak_length = 0
	heat = 0.0; take = 0; edges.clear(); committed = false
	# TODO[11]: MissionGenerator.refresh_board(difficulty_floor=1)

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

func raise_heat(amount: float) -> void:
	pass # TODO[12]: clamp, EventBus.heat_changed, escalate future contracts

func end_streak(reason: String) -> int:
	# Returns Legacy awarded. Conversion: notoriety * heat_multiplier.
	return 0 # TODO[12]: ProgressionManager.add_legacy(...), then reset
