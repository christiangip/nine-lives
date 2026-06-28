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
