extends Node
class_name MinigameHost
## Drives the minigame layer: when an obstacle emits `minigame_requested(kind)`, mount the matching
## Minigame overlay, inject the run context (obstacle difficulty + the relevant attribute + gear), and
## route solved / failed / aborted back to the obstacle via `apply_minigame_result(kind, success)`.
## This is the only new "glue" in task 07 — obstacles keep their task-06 consequence logic + tests.
## EventBus stays frozen (obstacle→host is a LOCAL signal). See docs/tasks/07_minigames.md.

## kind → Minigame script. A data map keyed by the requested kind (branch on the property, never on an
## obstacle id). Overlays build their own UI in code, so no per-overlay .tscn is needed. `preload` (a
## constant expression, unlike a bare class_name) keeps this a const.
const _BUILDERS := {
	&"lockpick": preload("res://game/systems/minigames/LockpickMinigame.gd"),
	&"safe_dial": preload("res://game/systems/minigames/SafeCrackMinigame.gd"),
	&"hack": preload("res://game/systems/minigames/HackMinigame.gd"),
	&"keypad": preload("res://game/systems/minigames/KeypadMinigame.gd"),
	&"pickpocket": preload("res://game/systems/minigames/PickpocketMinigame.gd"),
	&"drill": preload("res://game/systems/minigames/DrillMinigame.gd"),
}

## kind → the attribute whose level eases it (read from ProgressionManager once task 12 lands).
const _KIND_ATTR := {
	&"lockpick": &"lockpicking",
	&"safe_dial": &"hacking",
	&"hack": &"hacking",
	&"keypad": &"hacking",
	&"pickpocket": &"pickpocketing",
}

@export var player_path: NodePath   ## the player, passed as the "hacker" for hack proximity

var _layer: CanvasLayer
var _active: Minigame
var _requester: Node
var _attached: Array[Node] = []

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "OverlayLayer"
	_layer.layer = 50
	add_child(_layer)

## The Minigame script for a kind, or null if unknown. Pure lookup (unit-tested).
static func builder_for(kind: StringName) -> GDScript:
	return _BUILDERS.get(kind)

## The mounted overlay (or null) — for the HUD/debug + tests.
func active() -> Minigame:
	return _active

func is_busy() -> bool:
	return _active != null

# --- Obstacle registration -------------------------------------------------
## Connect one obstacle's minigame_requested to this host. Idempotent.
func attach(obstacle: Node) -> void:
	if obstacle == null or obstacle in _attached or not obstacle.has_signal("minigame_requested"):
		return
	_attached.append(obstacle)
	obstacle.minigame_requested.connect(_on_requested.bind(obstacle))

## Connect every Obstacle under `root` (call once after the level is built).
func attach_all(root: Node) -> void:
	if root == null:
		return
	for n in root.find_children("*", "Obstacle", true, false):
		attach(n)

# --- Mount / route ---------------------------------------------------------
func _on_requested(kind: StringName, obstacle: Node) -> void:
	open(kind, obstacle)

## Mount the overlay for `kind` on behalf of `obstacle`. Returns the instance (or null if a minigame
## is already active or the kind is unknown). `ctx` overrides the auto-built context (hacker/target/breach).
func open(kind: StringName, obstacle: Node, ctx: Dictionary = {}) -> Minigame:
	if _active != null:
		return null
	var builder: GDScript = builder_for(kind)
	if builder == null:
		return null
	_requester = obstacle
	var mg: Minigame = builder.new()
	_active = mg
	var diff := 1
	if obstacle != null and obstacle.has_method("difficulty"):
		diff = obstacle.difficulty()
	mg.configure(diff, _attribute_level_for(kind), _gear_params())
	_layer.add_child(mg)
	mg.solved.connect(_on_solved.bind(kind))
	mg.failed.connect(_on_failed.bind(kind))
	mg.aborted.connect(_on_aborted)
	mg.begin(_build_ctx(obstacle, ctx))
	return mg

func _build_ctx(obstacle: Node, ctx: Dictionary) -> Dictionary:
	var full := ctx.duplicate()
	if not full.has("target") and obstacle is Node3D:
		full["target"] = obstacle
	if not full.has("breach") and obstacle is BreachPoint:
		full["breach"] = obstacle
	if not full.has("hacker"):
		var p := get_node_or_null(player_path)
		if p != null:
			full["hacker"] = p
	# Inject the equipped BREACH tool (method + upgrade params) so the drill overlay uses the loadout's
	# drill/thermite/C4 rather than the default drill (↩ from 06, closes TODO[09]).
	if obstacle is BreachPoint and not full.has("method"):
		var lo := _player_loadout()
		var tool: GearDef = lo.breach_tool() if lo != null else null
		if tool != null:
			full["method"] = tool.param(&"method", &"drill")
			full["breach_gear"] = tool.params
	return full

func _player_loadout() -> Loadout:
	var p := get_node_or_null(player_path)
	if p != null and p.get("loadout") != null:
		return p.loadout as Loadout
	return null

## The trained level of the attribute a minigame kind scales off (Lockpicking/Hacking/…), read from
## ProgressionManager (task 12). 0 headlessly or for an unmapped kind.
func _attribute_level_for(kind: StringName) -> int:
	var attr: StringName = _KIND_ATTR.get(kind, &"")
	if String(attr).is_empty():
		return 0
	if ProgressionManager != null and ProgressionManager.has_method("attribute_level"):
		return int(ProgressionManager.attribute_level(attr))
	return 0

## Gadget flags (stethoscope, hacking rig, drill upgrades …) from the player's equipped Loadout, so
## overlays widen cues / ease difficulty for the right gear (closes TODO[09]). Empty if there's no
## player/loadout (headless). Reads via a duck-typed `loadout` accessor to avoid a hard dependency.
func _gear_params() -> Dictionary:
	var p := get_node_or_null(player_path)
	if p != null and p.get("loadout") != null:
		return p.loadout.gear_flags()
	return {}

func _on_solved(kind: StringName) -> void:
	_apply(kind, true)
	_close()

func _on_failed(_reason: String, kind: StringName) -> void:
	_apply(kind, false)
	_close()

func _on_aborted() -> void:
	_close()

func _apply(kind: StringName, success: bool) -> void:
	if _requester != null and is_instance_valid(_requester) and _requester.has_method("apply_minigame_result"):
		_requester.apply_minigame_result(kind, success)

func _close() -> void:
	if _active != null:
		_active.queue_free()
		_active = null
	_requester = null
