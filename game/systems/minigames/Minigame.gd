extends Control
class_name Minigame
## Base class for diegetic minigame overlays (lockpick, safe, hack, keypad,
## pickpocket). Scaled by attribute/gear. See docs/tasks/07_minigames.md, GDD §9.8.

signal solved
signal failed(reason: String)
signal aborted

@export var difficulty: int = 1
var attribute_level: int = 0
var gear_params: Dictionary = {}

func begin(_ctx: Dictionary) -> void:
	pass # TODO[07]: configure from difficulty + attribute + gear, show overlay

func _finish_solved() -> void: solved.emit()
func _finish_failed(reason: String) -> void: failed.emit(reason)
