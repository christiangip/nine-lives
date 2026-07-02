extends Node3D
## Dev-only greybox driver for the task-10 "going loud" manual playtest (F6). Not wired into
## GameManager — mission flow is task 11. Press the "gadget_use" action to trip a LOUD alarm: the
## PursuitDirector arms and escalates phases 1..5 (printed to the output), RunManager Heat rises and
## the Streak commits, and reinforcement requests are logged (actual spawn PLACEMENT is task 11).
## Walk into a guard's cone to pull it into COMBAT — it holds a standoff and shoots back; fire with
## the "fire" action. See docs/tasks/10_going_loud_pursuit.md.

@export var director_path: NodePath

var _director: PursuitDirector

func _ready() -> void:
	_director = get_node_or_null(director_path) as PursuitDirector
	if _director != null:
		_director.reinforcements_requested.connect(_on_reinforcements)
	EventBus.pursuit_phase_changed.connect(_on_phase)
	EventBus.heat_changed.connect(_on_heat)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"gadget_use"):
		EventBus.alarm_tripped.emit("loud", global_position)

func _on_phase(phase: int) -> void:
	print("[Pursuit] phase -> ", phase)

func _on_heat(new_heat: float) -> void:
	print("[Pursuit] heat -> ", new_heat)

func _on_reinforcements(tier: StringName, count: int) -> void:
	print("[Pursuit] reinforcements requested: ", count, " x ", tier, " (placement -> task 11)")
