extends Node
## Main — the boot scene (project.godot run/main_scene).
## Does nothing itself: hands off to the Main Menu via GameManager so all scene
## transitions stay funneled through one place. See docs/tasks/01_project_setup.md.

func _ready() -> void:
	# Defer: the scene tree is still finishing setup during _ready; swapping the
	# current scene synchronously here is unsafe.
	GameManager.call_deferred("goto_main_menu")
