extends Node3D
class_name Interactable
## Base for anything the player can interact with (doors, loot, panels, safes).
## See docs/tasks/06_heist_mechanics_obstacles.md.

@export var prompt: String = "Interact"
@export var hold_seconds: float = 0.0   ## 0 = instant tap

func can_interact(_by: Node) -> bool:
	return true

func interact(_by: Node) -> void:
	pass # TODO[06]: override per subtype

## In-world progress 0..1 of an interaction already under way (e.g. a proximity hack filling), so the HUD
## can draw a hold-to-interact ring for it. 0 for instant taps and idle targets. Override per subtype.
func interaction_progress() -> float:
	return 0.0
