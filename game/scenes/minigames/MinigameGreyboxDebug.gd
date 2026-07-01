extends Node3D
## Dev-only F6 harness for MinigameGreybox — wires the MinigameHost to every obstacle in the scene and
## draws a crosshair + a live interaction-prompt line so the task-07 overlays are exercisable by hand
## (the real HUD is task 15). Not shipped. See docs/tasks/07_minigames.md.

## {key} is substituted with the live "interact" binding so it never goes stale on a rebind (task 15).
const HELP_TEXT := """MINIGAME GREYBOX (F6) — walk up (aim the +), press [{key}] to open each overlay.
Overlays: ◄►/▲▼ + [Enter] to act, [Esc] to cancel. Keyboard OR gamepad (ui_* actions).
• LOCK (grey): lockpick — spin ◄► to the give, [Enter] to set (a miss can snap a pick).
• SAFE (dark): dial — ◄► to each click number, [Enter]; listen for *click* (Hacking/stethoscope widen it).
• KEYPAD (cyan): Mastermind — ◄► pick a digit, ▲▼ change, [Enter] to submit; deduce from exact/partial.
• DISPLAY CASE (green): e-lock hack — route the ◄►▲▼ sequence before the soft timer runs out (non-modal).
• VAULT (red): drill — a tension gauge; [Enter] to clear a JAM. Non-modal: it grinds while you watch."""

@export var host_path: NodePath = ^"../MinigameHost"
@export var player_path: NodePath = ^"../Player"

var _player: Node
var _prompt: Label
var _interact_key := "?"

func _ready() -> void:
	_player = get_node_or_null(player_path)
	var host := get_node_or_null(host_path) as MinigameHost
	if host != null:
		host.attach_all(get_parent())
	_interact_key = _interact_key_label()
	_build_hud()

func _interact_key_label() -> String:
	for ev in InputMap.action_get_events(&"interact"):
		if ev is InputEventKey:
			return (ev as InputEventKey).as_text_physical_keycode().replace(" (Physical)", "")
	return "?"

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
	help.text = HELP_TEXT.format({"key": _interact_key})
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(16, 12)
	layer.add_child(help)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_top = -96.0
	_prompt.offset_bottom = -48.0
	_prompt.add_theme_font_size_override("font_size", 22)
	layer.add_child(_prompt)

func _process(_delta: float) -> void:
	if _player != null and _prompt != null and _player.has_method("current_prompt"):
		var p: String = _player.current_prompt()
		_prompt.text = "[%s]  %s" % [_interact_key, p] if p != "" else ""
