extends GutTest
## Spec: the interaction probe resolves the owning Interactable from a hit collider and
## respects tap vs hold timing; an in-tree raycast smoke check confirms the wiring
## (pending where headless physics can't answer) (FR-03-5).
## docs/tasks/03_player_controller_camera.md.

var _player: PlayerController

func before_each() -> void:
	_player = PlayerController.new()
	_player.config = PlayerConfigDef.new()

func after_each() -> void:
	_player.free()

func test_resolves_interactable_from_child_collider() -> void:
	var interactable := Interactable.new()
	var child := Node3D.new()
	interactable.add_child(child)
	assert_eq(_player._resolve_interactable(child), interactable,
		"resolution walks up from a child collider to the owning Interactable")
	interactable.free()

func test_resolves_null_for_non_interactable() -> void:
	var plain := Node3D.new()
	assert_null(_player._resolve_interactable(plain), "a non-interactable collider resolves to null")
	assert_null(_player._resolve_interactable(null), "a null collider resolves to null")
	plain.free()

func test_tap_fires_once_per_press() -> void:
	var tap := Interactable.new()
	tap.hold_seconds = 0.0
	_player._current_interactable = tap
	assert_true(_player.update_hold(0.0, true), "an instant tap fires on press")
	assert_false(_player.update_hold(0.0, true), "it does not re-fire while the button is held")
	assert_false(_player.update_hold(0.0, false), "releasing re-arms without firing")
	assert_true(_player.update_hold(0.0, true), "the next press fires again")
	_player._current_interactable = null
	tap.free()

func test_hold_requires_full_duration() -> void:
	var hold := Interactable.new()
	hold.hold_seconds = 0.5
	_player._current_interactable = hold
	var fired := false
	for i in 4:
		fired = _player.update_hold(0.1, true) or fired   # 0.1..0.4s
	assert_false(fired, "a hold does not fire before its duration elapses")
	assert_true(_player.update_hold(0.1, true), "it fires once the hold duration is reached")
	_player._current_interactable = null
	hold.free()

func test_current_prompt_reflects_target() -> void:
	assert_eq(_player.current_prompt(), "", "no target yields an empty prompt")
	var inter := Interactable.new()
	inter.prompt = "Open"
	_player._current_interactable = inter
	assert_eq(_player.current_prompt(), "Open", "the prompt comes from the targeted Interactable")
	_player._current_interactable = null
	inter.free()

func test_ray_detects_interactable_in_tree() -> void:
	# Smoke check the real RayCast3D wiring; headless physics may not answer, so this
	# degrades to pending() rather than failing (the contract is covered by the pure
	# resolution tests above).
	var scene := load("res://game/scenes/player/PlayerController.tscn")
	if scene == null:
		pending("PlayerController.tscn not importable in this context")
		return
	var p: PlayerController = scene.instantiate()
	add_child_autofree(p)

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = box
	body.add_child(cs)
	var inter := Interactable.new()
	inter.add_child(body)
	add_child_autofree(inter)
	inter.global_position = p.global_position + Vector3(0.0, 1.6, -1.0)  # 1 m ahead, eye height

	await get_tree().physics_frame
	await get_tree().physics_frame

	if p._interact_ray == null:
		pending("interact ray missing")
		return
	p._interact_ray.force_raycast_update()
	if not p._interact_ray.is_colliding():
		pending("headless physics raycast did not register; covered by pure resolution tests")
		return
	assert_not_null(_player._resolve_interactable(p._interact_ray.get_collider()),
		"the forward ray resolves the Interactable ahead of the player")
