extends Obstacle
class_name KeycardDoor
## A key/keycard-gated door or restricted-zone gate (FR-06-3, GDD §9.1). Opens with the matching card
## (held after pickpocket/takedown of a carrier — e.g. the Inspector's must-have card — or found
## stashed), or with a cloned copy (keycard cloner gadget, task 09). There is always a non-card route
## in the level (alt_route), so a card is never the sole solution.
## Card storage/pickpocket is task 08; the cloner gadget is task 09 — both duck-typed here. TODO[08]/[09].
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-3).

# --- Pure seam (deterministic; unit-tested headless) -----------------------
## Opens iff the actor holds the card or can clone one. Pure.
static func opens_with(has_card: bool, can_clone: bool) -> bool:
	return has_card or can_clone

func _can_clone(by: Node) -> bool:
	# Keycard cloner is task 09; duck-type an optional gadget until then. TODO[09].
	return by != null and by.has_method("can_clone_keycard") and by.can_clone_keycard(def.required_item)

func can_interact(by: Node) -> bool:
	if solved:
		return false
	return opens_with(Obstacle.actor_has_item(by, def.required_item), _can_clone(by))

func interact(by: Node) -> void:
	if solved or def == null:
		return
	if Obstacle.actor_has_item(by, def.required_item):
		_mark_solved(&"keycard")
	elif _can_clone(by):
		_mark_solved(&"clone")
