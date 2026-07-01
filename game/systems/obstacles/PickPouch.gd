extends RefCounted
class_name PickPouch
## A small holder for the player's consumable lockpicks (FR-06-1). A failed pick attempt can snap a
## pick, draining the pouch; run out and pin-tumbler locks become impassable without a key. This is a
## minimal seam — the real inventory/economy of picks (restock, cost, capacity) is task 08. TODO[08].
## See docs/tasks/06_heist_mechanics_obstacles.md.

var count: int = 3

func _init(p_count: int = 3) -> void:
	count = p_count

func has_pick() -> bool:
	return count > 0

## Consume one pick (on a snap). Returns true if one was available to break.
func consume() -> bool:
	if count <= 0:
		return false
	count -= 1
	return true
