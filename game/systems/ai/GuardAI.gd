extends CharacterBody3D
class_name GuardAI
## Patrol guard: state machine over NavigationServer. Investigates, searches,
## fights when loud (cover-shooter, Q2). See docs/tasks/05_ai_actors.md, GDD §8.4.

enum AIState { PATROL, INVESTIGATE, SEARCH, COMBAT, DOWNED }

@export var def: EnemyDef
@export var patrol_path: NodePath

var ai_state: int = AIState.PATROL

func _ready() -> void:
	pass # TODO[05]: cache nav agent, patrol points, DetectionSensor

func _physics_process(delta: float) -> void:
	match ai_state:
		AIState.PATROL: _tick_patrol(delta)
		AIState.INVESTIGATE: _tick_investigate(delta)
		AIState.SEARCH: _tick_search(delta)
		AIState.COMBAT: _tick_combat(delta)       # TODO[10]: take cover, suppress, flank
		AIState.DOWNED: pass

func _tick_patrol(_d: float) -> void: pass   # TODO[05]
func _tick_investigate(_d: float) -> void: pass # TODO[05]
func _tick_search(_d: float) -> void: pass   # TODO[05]
func _tick_combat(_d: float) -> void: pass   # TODO[10]
