extends Interactable
class_name Escape
## Extraction point: leaving via here successfully ends the mission and continues the Streak
## (GDD §10.4). Reuses DropPoint's banking arithmetic for "reaching it secures carried value"
## (FR-08-5) — composition, not inheritance, since Escape's one extra effect
## (EventBus.objective_updated) must never leak onto a mid-level DropPoint, and the two don't
## share a Def/solved state machine to justify a base class.
## See docs/tasks/08_loot_inventory.md (FR-08-5).

@export var objective_id: StringName = &"escape"

func _ready() -> void:
	prompt = "Escape"

func can_interact(by: Node) -> bool:
	return by != null and by.get("inventory") != null

## Banks whatever's carried (same arithmetic as DropPoint), then marks the escape objective
## complete. TODO[11]: MissionController (task 11) is what actually ends the mission/transitions
## the scene on this signal — task 08 only fires it + banks value, per the ARCHITECTURE.md
## handoff (MissionGenerator-built levels own mission flow).
func interact(by: Node) -> void:
	var inv = by.get("inventory") if by != null else null
	if inv != null:
		var result: Dictionary = inv.secure_all_carried()
		var amount: int = result.get("value", 0)
		if amount > 0:
			DropPoint.bank(amount, "carried_haul")
		for hook in result.get("special_hooks", []):
			ProgressionManager.add_to_stash(hook)
	EventBus.objective_updated.emit(String(objective_id), true)
