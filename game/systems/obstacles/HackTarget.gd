extends Obstacle
class_name HackTarget
## An electronic security target — e-lock, keypad, camera, alarm panel, vault time-lock, or data-loot
## drive (FR-06-5, GDD §9.2). Hacking needs PROXIMITY + TIME: start it, then stay in range while a
## timer fills; step out of range and the hack is ABANDONED — progress resets and you start over
## (misc-fixes-4 issue 2; this supersedes the original pause-and-resume rule, under which a hack
## silently ran to completion behind the player's back the moment they drifted back into range).
## A found code/payload skips the
## minigame entirely, and a camera can be LOOPED (quieter, temporary) instead of DISABLED (offline).
## Also a powered device: cutting its zone's power (FuseBox, FR-06-8) disables it / opens an e-lock.
## The dial/keypad overlay itself is task 07; this owns the proximity+timing+mode logic + the data hook.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-5).

signal hack_completed(device_kind: String)

var hacking: bool = false
var progress: float = 0.0        ## seconds accumulated toward def.time_seconds
var powered: bool = true
var disabled: bool = false       ## camera/keypad taken offline (by hack or power cut)
var looped: bool = false         ## camera feed temporarily looped
var _hacker: Node3D
var _camera_action: String = ""  ## "loop" | "disable"; defaults from params
var _loop_remaining: float = 0.0

func _ready() -> void:
	super._ready()
	if def != null:
		_camera_action = String(def.params.get("camera_action", "disable"))

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Is the hacker close enough to keep the hack live? Pure.
static func in_proximity(distance: float, max_range: float) -> bool:
	return distance <= max_range

## Advance hack progress by `delta` while in range; OUT OF RANGE THE HACK IS ABANDONED and progress
## resets to 0 — walking away costs you the attempt. Clamped to `total`. Pure — the whole proximity
## rule lives here. (FR-06-5, misc-fixes-4 issue 2)
static func step_progress(current: float, delta: float, total: float, in_range: bool) -> float:
	if not in_range:
		return 0.0
	return minf(current + delta, total)

# --- Device identity -------------------------------------------------------
func device_kind() -> String:
	return String(def.params.get("device", "elock")) if def != null else "elock"

func is_disabled() -> bool:
	return disabled or solved

## Proximity-hack fill as 0..1 for the HUD hold ring (this hack is a timed fill, not the tap/hold timer).
func interaction_progress() -> float:
	if not hacking or def == null or def.time_seconds <= 0.0:
		return 0.0
	return clampf(progress / def.time_seconds, 0.0, 1.0)

# --- Hack lifecycle --------------------------------------------------------
## Begin a hack. If the actor holds the found code/payload (def.clue_id), it resolves instantly with no
## minigame. Returns true if already finished (shortcut), false if a timed hack started.
func begin_hack(by: Node) -> bool:
	if solved:
		return true
	if not String(def.clue_id).is_empty() and Obstacle.actor_has_item(by, def.clue_id):
		_complete(&"found_code")
		return true
	_hacker = by as Node3D
	if device_kind() == "keypad":
		# Keypads are a Mastermind deduction overlay (task 07), not an in-world fill timer.
		minigame_requested.emit(&"keypad")   # result → apply_minigame_result
		return false
	hacking = true
	progress = 0.0
	return false

func set_camera_action(action: String) -> void:
	_camera_action = action

## Host callback: a solved keypad deduction takes the panel offline. E-locks / cameras / time-locks use
## the in-world proximity fill (begin_hack + tick) instead, so they never route through here.
func apply_minigame_result(kind: StringName, success: bool) -> void:
	if kind == &"keypad" and success and not solved:
		_complete(&"keypad")

## Tick the in-progress hack given the hacker's current distance. Pure-ish (mutates progress); call it
## from _process or drive it directly in tests. Leaving range abandons the hack outright.
func tick(delta: float, distance: float) -> void:
	if not hacking or def == null:
		return
	var in_range := in_proximity(distance, def.proximity_range)
	progress = step_progress(progress, delta, def.time_seconds, in_range)
	if not in_range:
		cancel_hack()
		return
	if progress >= def.time_seconds and def.time_seconds > 0.0:
		_complete(&"hack")

# --- Interactable channel contract (PlayerController's movement rule, misc-fixes-5) ---------------
## A timed hack is exactly the "stand here and hold still" interaction the movement rule governs, so the
## player either cancels it by moving or is locked in place for its duration (gameplay/interaction_movement).
func is_channeling() -> bool:
	return hacking

func cancel_interaction() -> void:
	cancel_hack()

## Abandon an in-progress hack (the hacker moved, walked out of range, or went away entirely). Idempotent.
## Emits the existing readability signal — EventBus stays frozen. (misc-fixes-4 issue 2)
func cancel_hack() -> void:
	if not hacking:
		return
	hacking = false
	progress = 0.0
	_hacker = null
	state_changed.emit()

func _process(delta: float) -> void:
	# A null _hacker means "no spatial context" (headless test / tick() driven directly) and is left
	# alone, as before. A NON-null but freed one is a dangling reference — cancel rather than read it.
	if hacking and _hacker != null:
		if not is_instance_valid(_hacker):
			cancel_hack()
		else:
			tick(delta, _hacker.global_position.distance_to(global_position))
	if looped:
		_loop_remaining -= delta
		if _loop_remaining <= 0.0:
			looped = false
			state_changed.emit()

func _complete(method: StringName) -> void:
	hacking = false
	var kind := device_kind()
	if kind == "camera" and _camera_action == "loop" and method == &"hack":
		looped = true
		_loop_remaining = float(def.params.get("loop_seconds", 20.0))
	elif kind == "camera" or kind == "keypad" or kind == "alarm_panel":
		disabled = true
	elif kind == "elock" or kind == "time_lock":
		disabled = true   # the barrier opens
	elif kind == "data_loot":
		_deliver_data_loot()
	_mark_solved(method)
	hack_completed.emit(kind)
	if AudioManager != null:
		AudioManager.play_sfx(&"hack_done", global_position)   # device-hacked cue (task 17)

## The download is added to the hacker's carry (↩ from 06, closes TODO[08]). Duck-typed exactly
## like Obstacle.actor_has_item — this class doesn't know Inventory's shape, just that _hacker
## might expose add_loot(LootDef). Resolves the LootDef from def.params.loot_id (data-driven, no
## id branching in code); a missing/misconfigured param is a silent no-op, matching the rest of
## this file's graceful-degradation style.
func _deliver_data_loot() -> void:
	if _hacker == null or not _hacker.has_method("add_loot"):
		return
	var loot_id := StringName(def.params.get("loot_id", ""))
	if String(loot_id).is_empty() or Content == null or Content.loot == null:
		return
	var loot := Content.loot.get_def(loot_id) as LootDef
	if loot != null:
		_hacker.add_loot(loot)

# --- Powered-device contract (FuseBox.cut_power) ---------------------------
func set_powered(on: bool) -> void:
	powered = on
	if not on:
		if device_kind() == "elock" and not solved:
			_mark_solved(&"power_cut")   # cutting power to an e-lock opens it (FR-06-8)
		else:
			disabled = true              # camera/keypad go offline
	elif not solved:
		disabled = false                 # power restored (unless permanently hacked)
	state_changed.emit()

## Instant tap starts the hack; the timed fill runs in _process while the player stays in range.
func interact(by: Node) -> void:
	begin_hack(by)
