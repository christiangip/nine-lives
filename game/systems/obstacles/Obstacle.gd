extends Interactable
class_name Obstacle
## Base for every heist obstacle (GDD §9.1–9.7). Wraps an ObstacleDef: resolves it from
## Content.obstacles, copies its prompt/hold onto the Interactable, tracks solved state, and exposes
## the difficulty + valid-solution query API the generator (11) and Intel (13) read (FR-06-10).
## Subclasses branch on def.category and add the counter-play logic as pure static seams (the
## Body.raises_alarm() style) so they unit-test headlessly. Cross-system effects go through the
## FROZEN EventBus (noise_emitted / alarm_tripped) + groups — no new signals, matching 03/04/05.
## See docs/tasks/06_heist_mechanics_obstacles.md.

signal obstacle_solved(by_method: StringName)   ## local; HUD readout is task 15, world stays EventBus-driven
signal state_changed                             ## solved / powered / revealed flipped — for HUD + debug
signal minigame_requested(kind: StringName)      ## ask the task-07 MinigameHost to mount a skill overlay

## Categories whose devices lose function when their power zone is cut (FR-06-8). Biometric locks are
## deliberately excluded — they gate the most lucrative content and are not trivially power-cut.
const POWERED_CATEGORIES: Array = [
	ObstacleDef.Category.HACK_TARGET,
	ObstacleDef.Category.LASER_GRID,
	ObstacleDef.Category.LIGHT,
	ObstacleDef.Category.MOTION_SENSOR,
	ObstacleDef.Category.SILENT_ALARM,
]

@export var def: ObstacleDef
@export var def_id: StringName = &""   ## when `def` is unset, look this up in Content.obstacles

var solved: bool = false
var power_zone: StringName = &""       ## non-empty on powered devices; matched by FuseBox (FR-06-8)

func _ready() -> void:
	_resolve_def()
	if def != null:
		prompt = def.prompt
		hold_seconds = def.hold_seconds
		power_zone = def.power_zone
		if def.category in POWERED_CATEGORIES and not String(power_zone).is_empty():
			add_to_group(&"powered_device")

func _resolve_def() -> void:
	if def == null and not String(def_id).is_empty() and Content != null and Content.obstacles != null:
		def = Content.obstacles.get_def(def_id) as ObstacleDef

func can_interact(_by: Node) -> bool:
	return not solved

# --- Query API for the generator + Intel (FR-06-10) ------------------------
## The declared counter-play set (a copy). Never minigame-only unless the GDD allows it (LOCK).
func solution_set() -> Array[StringName]:
	var out: Array[StringName] = []
	if def != null:
		out.assign(def.valid_solutions)
	return out

func difficulty() -> int:
	return def.difficulty_tier if def != null else 1

func accepts(method) -> bool:
	return def != null and def.has_solution(method)

# --- Minigame contract (driven by the task-07 MinigameHost) -----------------
## Apply a finished skill overlay's outcome. Default no-op (e.g. the drill/breach owns its own
## completion); Lock/Safe/DisplayCase/HackTarget override to open on success (or roll a pick snap on a
## failed lockpick). Kept a small polymorphic seam so the host never branches on obstacle type/id.
func apply_minigame_result(_kind: StringName, _success: bool) -> void:
	pass

# --- Powered-device contract (driven by FuseBox.cut_power) ------------------
## Default no-op; powered subclasses (HackTarget, LaserGrid, ControllableLight, MotionSensor) override.
func set_powered(_on: bool) -> void:
	pass

# --- Shared effects (frozen EventBus) --------------------------------------
## Emit a noise ring sized by a solution's noise profile (drives guard hearing, task 04/05). 0 = silent.
func _emit_noise_for(method) -> void:
	if def == null:
		return
	var radius: float = def.noise_for(method)
	if radius > 0.0:
		EventBus.noise_emitted.emit(global_position, radius, "obstacle")

func _trip_alarm(kind: String) -> void:
	EventBus.alarm_tripped.emit(kind, global_position)

## Latch the obstacle solved by a method; emits the local signal + any solution noise once.
func _mark_solved(method) -> void:
	if solved:
		return
	solved = true
	_emit_noise_for(method)
	obstacle_solved.emit(StringName(method))
	state_changed.emit()

# --- Duck-typed bridge to not-yet-built systems ----------------------------
## Whether `by` (usually the player) holds an item id — a key, keycard, or found clue. Real inventory
## is task 08; until then this duck-types an optional has_item(id) and is false otherwise. TODO[08].
static func actor_has_item(by: Node, item_id) -> bool:
	if by != null and by.has_method("has_item"):
		return by.has_item(StringName(item_id))
	return false
