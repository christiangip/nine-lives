extends Node3D
## Dev-only F6 feedback for InventoryGreybox — mirrors ObstacleGreyboxDebug.gd's HUD pattern
## (crosshair + live interaction-prompt line) but reads carry-shaped state instead of
## obstacle-shaped state (LootPickup/DropPoint have no progress/solved-category machinery to
## reuse). Adds a running Carry Weight/Volume/Hands/Secured readout (the real HUD is task 15)
## and a debug-only "simulate a Catch" key so FR-08-6 is manually verifiable without task 10's
## real capture system existing yet. Also wires Lock.set_pouch() (task 06's PickPouch stand-in)
## to a real pouch, closing that hook for this greybox. Not shipped; greybox aid only.
## See docs/tasks/08_loot_inventory.md.

const _STARTING_PICKS: int = 3

@export var player_path: NodePath = ^"../Player"

var _player: PlayerController
var _prompt: Label
var _carry_label: Label

func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	_build_hud()
	_wire_pick_pouch()

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
		"drop off.\n[T] throw the carried bag · [G] put down a dragged body · " +
		"[K] simulate a Catch (debug only, not a real game input).") % key

## Closes the task-06 PickPouch stand-in for this greybox: hand a real pouch to any Lock sibling
## so its consumable-pick counter-play (FR-06-1) is exercisable here. General mission-wide
## wiring is task 11's job once MissionGenerator places Locks alongside the player.
func _wire_pick_pouch() -> void:
	var pouch := PickPouch.new(_STARTING_PICKS)
	for node in get_parent().get_children():
		if node is Lock:
			(node as Lock).set_pouch(pouch)

func _process(_delta: float) -> void:
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

## Debug-only "simulate a Catch" (FR-08-6) — a raw key check, not a real game action (mirroring
## PlayerController's own pause-toggle convenience for the greybox playtest), since task 10's
## real Pursuit/capture system doesn't exist yet.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_K:
		if _player != null and _player.inventory != null:
			_player.inventory.lose_in_hand_on_catch()
