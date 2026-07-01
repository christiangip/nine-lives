extends Obstacle
class_name BiometricLock
## A biometric / retinal / magnetic lock (FR-06-6, GDD §9.4). These gate the MOST lucrative content,
## so they are deliberately not power-cuttable or hackable. Get through by bringing a knocked-out
## keyholder (a downed guard/Inspector carried to the reader — Body from task 05 + carry from task 08),
## by spoofing with a rare gadget (task 09), or by finding another route entirely.
## The keyholder + spoof routes are duck-typed until 08/09 land. TODO[08]/[09].
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-6).

## Unlocks iff a valid keyholder is presented or a spoof gadget is used. Pure.
static func unlocks(has_keyholder: bool, has_spoof: bool) -> bool:
	return has_keyholder or has_spoof

func _keyholder_present(by: Node) -> bool:
	# Dragging a downed keyholder to the reader is task 08 carry + task 05 Body. TODO[08].
	return by != null and by.has_method("is_carrying_keyholder") and by.is_carrying_keyholder(def.required_item)

func _has_spoof(by: Node) -> bool:
	return by != null and by.has_method("has_biometric_spoof") and by.has_biometric_spoof()

func can_interact(by: Node) -> bool:
	return not solved and unlocks(_keyholder_present(by), _has_spoof(by))

func interact(by: Node) -> void:
	if solved:
		return
	if _keyholder_present(by):
		_mark_solved(&"keyholder")
	elif _has_spoof(by):
		_mark_solved(&"spoof")
