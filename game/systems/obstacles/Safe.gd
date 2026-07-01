extends Obstacle
class_name Safe
## A dial-combination safe (FR-06-2, GDD §9.1). Cracked by the safe-dial minigame (task 07; more
## wheels/tighter tolerance at higher tiers, and a stethoscope gadget widens the audio cue) — but a
## COMBO CLUE found in the level trivialises it: hold the clue and the safe opens with no minigame.
## This class owns the clue-skip routing; the dial overlay + stethoscope bonus are task 07.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-2).

# minigame_requested is declared on Obstacle (the base) — task 07 mounts the dial overlay on it.

# --- Pure seam (deterministic; unit-tested headless) -----------------------
## Does holding `held_clues` let us skip the dial? True iff the required clue id is present. Pure.
static func can_skip(held_clues: Array, clue_id) -> bool:
	var want := StringName(clue_id)
	if String(want).is_empty():
		return false
	return want in held_clues

# --- Interaction -----------------------------------------------------------
func interact(by: Node) -> void:
	if solved or def == null:
		return
	if not String(def.clue_id).is_empty() and Obstacle.actor_has_item(by, def.clue_id):
		_mark_solved(&"found_combo")            # clue trivialises it — no minigame (GDD §9.1)
	else:
		minigame_requested.emit(&"safe_dial")   # MinigameHost mounts the dial; result → apply_minigame_result

## Host callback: cracking the dial opens the safe (a failed/aborted dial just leaves it shut).
func apply_minigame_result(kind: StringName, success: bool) -> void:
	if kind == &"safe_dial" and success:
		_mark_solved(&"safe_dial")
