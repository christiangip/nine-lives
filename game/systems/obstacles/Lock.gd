extends Obstacle
class_name Lock
## Pin-tumbler lock on a door/drawer/chest (FR-06-1, GDD §9.1). Opened by the lockpick minigame
## (task 07); picks are consumable and can SNAP on a failed attempt, and the Lockpicking attribute
## (task 12) widens the sweet spot + lowers snap odds. Per GDD §9.1 a pin-tumbler has no alternate —
## it is the one documented minigame-only obstacle (test_solution_set's exception).
## This class owns the consequence logic (snap → consume a pick); the dial/tension overlay is task 07.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-1).

signal pick_snapped   ## a pick broke on a failed attempt (HUD/audio feedback = tasks 15/17)

## The player's picks. Injected by the carrier; real inventory storage is task 08. TODO[08].
var pouch: PickPouch

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Snap probability for a failed attempt: the def's base chance, lowered by Lockpicking level.
## `reduction_per_level` is the attribute's effect_per_level (AttributeDef). Clamped to [0,1]. Pure.
static func snap_chance(base: float, lockpicking_level: float, reduction_per_level: float) -> float:
	return clampf(base - lockpicking_level * reduction_per_level, 0.0, 1.0)

## Does this failed attempt snap the pick? `roll` is a uniform draw in [0,1). Pure.
static func should_snap(roll: float, chance: float) -> bool:
	return roll < chance

# --- Interaction / consequence --------------------------------------------
func set_pouch(p: PickPouch) -> void:
	pouch = p

## Resolve one lockpick attempt. `success` is the minigame outcome (task 07 produces it; here it is an
## input so the consequence is deterministically testable). A failure may snap a pick. `roll` overrides
## the RNG for tests (leave as NAN to draw randf()). `lockpicking_level` comes from ProgressionManager
## (task 12); 0 until then. TODO[12].
func resolve_attempt(success: bool, roll: float = NAN, lockpicking_level: float = 0.0, reduction_per_level: float = 0.0) -> void:
	if solved:
		return
	if success:
		_mark_solved(&"lockpick")
		return
	var base: float = def.snap_base_chance if def != null else 0.25
	var chance: float = snap_chance(base, lockpicking_level, reduction_per_level)
	var r: float = roll if not is_nan(roll) else randf()
	if should_snap(r, chance):
		if pouch != null:
			pouch.consume()
		pick_snapped.emit()

## Instant tap requests the lockpick overlay (task 07). The MinigameHost mounts it and feeds the
## outcome back through apply_minigame_result → resolve_attempt.
func interact(_by: Node) -> void:
	if solved:
		return
	minigame_requested.emit(&"lockpick")

## Host callback: a solved overlay opens the lock; a failed one may snap a pick. Attribute-scaled snap
## odds arrive once ProgressionManager lands (TODO[12]); resolve_attempt defaults them to 0 for now.
func apply_minigame_result(kind: StringName, success: bool) -> void:
	if kind == &"lockpick":
		resolve_attempt(success)
