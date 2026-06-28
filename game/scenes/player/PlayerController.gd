extends CharacterBody3D
class_name PlayerController
## First-person player controller. Movement, stances, stamina, lean/peek.
## See docs/tasks/03_player_controller_camera.md and GDD §8.0 (Q1 = first-person).

enum Stance { STAND, CROUCH, PRONE }

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.6
@export var mouse_sensitivity: float = 0.0025

var stance: int = Stance.STAND
var stamina: float = 100.0
var noise_level: float = 0.0     ## current footstep/action noise radius (m)

func _physics_process(delta: float) -> void:
	pass # TODO[03]: gravity, move_and_slide, stance height, stamina drain

func _unhandled_input(event: InputEvent) -> void:
	pass # TODO[03]: mouselook (clamped pitch), lean, stance toggles

func emit_noise(radius: float, source: String) -> void:
	EventBus.noise_emitted.emit(global_position, radius, source)
