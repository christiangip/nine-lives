extends Node3D
## Dev-only F6 feedback for InventoryGreybox — mirrors ObstacleGreyboxDebug.gd's HUD pattern
## (crosshair + live interaction-prompt line) but reads carry-shaped state instead of
## obstacle-shaped state (LootPickup/DropPoint have no progress/solved-category machinery to
## reuse). Adds a running Carry Weight/Volume/Hands/Secured readout (the real HUD is task 15)
## and an on-screen flash when an objective (the Escape) completes. Two debug-only keys: [K]
## "simulate a Catch" (FR-08-6, since task 10's real capture system doesn't exist yet) and [L]
## takedown-the-Guard (task 10 owns the real takedown *input*; this greybox needs some way to
## reach task 08's drag/keycard-pickup half interactively). Also wires Lock.set_pouch() (task
## 06's PickPouch stand-in) to a real pouch, and attaches the sibling MinigameHost to every
## Obstacle in the scene (task 07's pattern — see MinigameGreyboxDebug.gd) so the Lock's
## lockpick overlay actually mounts on interact. Not shipped; greybox aid only.
## See docs/tasks/08_loot_inventory.md.

const _STARTING_PICKS: int = 3
const _MESSAGE_SECONDS: float = 3.0

@export var player_path: NodePath = ^"../Player"
@export var host_path: NodePath = ^"../MinigameHost"
@export var guard_path: NodePath = ^"../Guard"

var _player: PlayerController
var _guard: GuardAI
var _prompt: Label
var _carry_label: Label
var _message_label: Label
var _message_timer: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_guard = get_node_or_null(guard_path) as GuardAI
	var host := get_node_or_null(host_path) as MinigameHost
	if host != null:
		host.attach_all(get_parent())
	_build_hud()
	_wire_pick_pouch()
	if not EventBus.objective_updated.is_connected(_on_objective_updated):
		EventBus.objective_updated.connect(_on_objective_updated)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cross)

	var help := Label.new()
	help.text = _help_text()
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(16, 12)
	layer.add_child(help)

	_carry_label = Label.new()
	_carry_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_carry_label.position = Vector2(16, 150)
	layer.add_child(_carry_label)

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.position = Vector2(-200, 40)
	_message_label.custom_minimum_size = Vector2(400, 40)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 28)
	_message_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	layer.add_child(_message_label)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.offset_top = -96.0
	_prompt.offset_bottom = -48.0
	_prompt.add_theme_font_size_override("font_size", 22)
	layer.add_child(_prompt)

## {key} is substituted with the live "interact" binding so this never goes stale if a player
## rebinds it in Options (task 15) — same trick as ObstacleGreyboxDebug.
func _help_text() -> String:
	var key := "?"
	for ev in InputMap.action_get_events(&"interact"):
		if ev is InputEventKey:
			key = (ev as InputEventKey).as_text_physical_keycode().replace(" (Physical)", "")
			break
	return ("INVENTORY GREYBOX (F6) — walk up, aim the +, press [%s] to pick up / bag / drag / " +
		"drop off / escape.\n[T] throw the carried bag OR dragged body · [G] gently put down a " +
		"dragged body ·\n[K] simulate a Catch · [L] take down the Guard (both debug only, not " +
		"real game input).") % key

## Closes the task-06 PickPouch stand-in for this greybox: hand a real pouch to any Lock sibling
## so its consumable-pick counter-play (FR-06-1) is exercisable here. General mission-wide
## wiring is task 11's job once MissionGenerator places Locks alongside the player.
func _wire_pick_pouch() -> void:
	var pouch := PickPouch.new(_STARTING_PICKS)
	for node in get_parent().get_children():
		if node is Lock:
			(node as Lock).set_pouch(pouch)

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0 and _message_label != null:
			_message_label.text = ""
	if _player == null:
		return
	if _prompt != null:
		_prompt.text = _player.current_prompt()
	if _carry_label != null and _player.inventory != null:
		var inv := _player.inventory
		_carry_label.text = "Weight %.1f / %.1f\nVolume %.1f / %.1f\nHands %d / 2\nIn-hand $%d\nSecured $%d" % [
			inv.current_weight(), inv.weight_cap,
			inv.current_volume(), inv.volume_cap,
			inv.hand_slots_used(), inv.in_hand_value(), inv.secured_value(),
		]

## Flash a message when an objective completes (the Escape) — the only feedback FR-08-5's
## objective_updated emission gets until the real HUD (task 15) exists.
func _on_objective_updated(objective_id: String, complete: bool) -> void:
	if not complete or _message_label == null:
		return
	_message_label.text = "OBJECTIVE COMPLETE: %s (secured $%d)" % [objective_id, _player.inventory.secured_value() if _player != null and _player.inventory != null else 0]
	_message_timer = _MESSAGE_SECONDS

## Debug-only keys, not real game actions (mirroring PlayerController's own pause-toggle
## convenience for the greybox playtest): [K] "simulate a Catch" (FR-08-6), since task 10's real
## Pursuit/capture system doesn't exist yet; [L] takes down the Guard, since task 10 also owns
## the real takedown *input* — without this there's no way to reach task 08's drag/keycard-pickup
## half interactively at all.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_K:
		if _player != null and _player.inventory != null:
			_player.inventory.lose_in_hand_on_catch()
	elif key == KEY_L:
		if _guard != null:
			_guard.take_down(false)
