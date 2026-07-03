## Free-fly camera for the asset-gallery greyboxes: hold right-mouse to look,
## WASD to move, Q/E down/up, Shift to sprint, wheel to change speed. Dev tool for
## task 18 (phase-1-art) — not shipped gameplay. Uses raw input so it needs no
## InputMap actions (keeps EventBus/InputManager untouched).
extends Camera3D

@export var move_speed: float = 6.0
@export var sprint_mult: float = 3.0
@export var look_sensitivity: float = 0.003

var _looking: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_looking = event.pressed
			if _looking:
				# Continue from the camera's current framing.
				_yaw = rotation.y
				_pitch = rotation.x
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			move_speed = min(move_speed * 1.2, 100.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			move_speed = max(move_speed / 1.2, 0.5)
	elif event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clamp(_pitch - event.relative.y * look_sensitivity, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)

func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += transform.basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	if dir != Vector3.ZERO:
		var speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= sprint_mult
		position += dir.normalized() * speed * delta
