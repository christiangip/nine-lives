extends Control
class_name Minigame
## Base for the diegetic minigame overlays (lockpick, safe, hack, keypad, pickpocket, drill).
## Lifecycle: configure(...) injects the run context → begin(ctx) resolves tunables + (optionally)
## pauses the world and takes input → the play loop emits `solved` / `failed(reason)` / `aborted`
## EXACTLY ONCE (a `_finished` latch), tears the pause down, and the MinigameHost frees the node.
## Each subclass adds its scalable maths as PURE STATIC SEAMS so it unit-tests headlessly; the
## Control glue is thin. EventBus stays FROZEN — outcomes are LOCAL signals the host routes back to
## the requesting obstacle. See docs/tasks/07_minigames.md, GDD §9.8.

signal solved
signal failed(reason: String)
signal aborted

## Whether entering this minigame pauses the game world. Focused close-ups (lockpick / safe / keypad
## / pickpocket) pause; the hack and drill are NON-MODAL so proximity + pursuit stay live while you
## work (GDD §9.2 the hack overlay's soft timer pauses out of range, §9.6 the vault drill draws guards
## — and walking away ABANDONS the drill outright, which closes this overlay; see BreachPoint).
@export var pauses_world: bool = true

@export var difficulty: int = 1
var config: MinigameConfigDef
var attribute_level: int = 0        ## the relevant attribute's level (Lockpicking / Hacking / …); fed by ProgressionManager (task 12)
var gear_params: Dictionary = {}    ## gadget bonuses (stethoscope, hacking rig, …); fed by task 09 loadout

var _finished: bool = false         ## latches on the first outcome so each signal fires once
var _did_pause: bool = false        ## only unpause if this instance actually paused

func _ready() -> void:
	_resolve_config()

func _resolve_config() -> void:
	if config == null and Content != null and Content.minigames != null:
		config = Content.minigames.get_def(&"default") as MinigameConfigDef
	if config == null:
		config = MinigameConfigDef.new()   # headless / no-registry fallback: schema defaults

## Inject the run context before begin(): the obstacle's difficulty tier, the player's relevant
## attribute level (from ProgressionManager, task 12), and any gear bonuses (task 09 loadout).
func configure(p_difficulty: int, p_attribute_level: int = 0, p_gear: Dictionary = {}) -> void:
	difficulty = maxi(1, p_difficulty)
	attribute_level = maxi(0, p_attribute_level)
	gear_params = p_gear

## Enter the minigame. Subclasses override to build + seed their overlay, calling super() first to
## resolve tunables + apply the world pause. `ctx` carries optional per-run nodes (e.g. hacker/target).
func begin(_ctx: Dictionary = {}) -> void:
	_resolve_config()
	if pauses_world and is_inside_tree():
		_did_pause = true
		get_tree().paused = true
		process_mode = Node.PROCESS_MODE_ALWAYS   # keep ticking + taking input while the world is frozen

## Linear difficulty/attribute widen: base + level * per_level. The shared scaling primitive the
## subclass seams build on. Pure.
static func scaled(base: float, level: float, per_level: float) -> float:
	return base + level * per_level

## Does the loadout carry a gadget flag (e.g. &"stethoscope")? Fed by task 09's Loadout.gear_flags(). Pure.
func has_gear(flag: StringName) -> bool:
	return bool(gear_params.get(String(flag), false))

# --- Input: Esc / gamepad-B aborts any overlay (subclasses handle their own play actions) --------
func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed(&"ui_cancel"):
		abort()
		if is_inside_tree():
			get_viewport().set_input_as_handled()

# --- Outcomes (each fires exactly once, then releases the pause) -----------
## TODO[17]: play the success/fail/abort diegetic sting + haptics here (AudioManager) — the outcome
## methods below are the single seam the audio+juice pass hooks. Kept signal-only for now.
func _finish_solved() -> void:
	if _finished:
		return
	_finished = true
	_teardown()
	solved.emit()

func _finish_failed(reason: String = "") -> void:
	if _finished:
		return
	_finished = true
	_teardown()
	failed.emit(reason)

func abort() -> void:
	if _finished:
		return
	_finished = true
	_teardown()
	aborted.emit()

## Release the world pause + stop taking input. The host frees the node on any outcome. Guarded so
## it's a no-op headlessly (tests drive the seams / outcomes without a running world).
func _teardown() -> void:
	set_process_input(false)
	if _did_pause and is_inside_tree():
		get_tree().paused = false
		_did_pause = false
