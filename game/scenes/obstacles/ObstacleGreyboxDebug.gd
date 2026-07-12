extends Node3D
## Dev-only F6 feedback for ObstacleGreybox — the real HUD is task 15. Adds a screen crosshair + a
## live interaction-prompt line, and floats a state tag over each obstacle (recoloured on change) so
## the otherwise-invisible obstacle logic (solved / powered-off / hacking) is legible while playtesting.
## Not shipped; greybox aid only. See docs/tasks/06_heist_mechanics_obstacles.md.

const COLOR_DONE := Color(0.25, 0.85, 0.35)   ## solved / open
const COLOR_HACK := Color(0.95, 0.85, 0.2)    ## hack in progress
const COLOR_OFF := Color(0.22, 0.22, 0.26)    ## powered off / disabled

## {key} is substituted with the live "interact" binding (see _interact_key_label) so this never
## goes stale if a player rebinds it in Options (task 15).
const HELP_TEXT := """OBSTACLE GREYBOX (F6) — walk up (within ~2.5 m), aim the +, press/HOLD [{key}].
• FUSE BOX (yellow, zone 'wing_a'): HOLD {key} -> e-lock OPENS + camera OFF. Does NOT reach the
   laser (different zone) — power cuts are zone-scoped, not global.
• JUNCTION BOX (orange, zone 'vault'): HOLD {key} -> the red LASER goes dark (its power-cut counter-play).
• E-LOCK (cyan): tap {key} then STAND STILL ~3s -> OPEN. MOVING CANCELS IT (progress is lost) — or, with
   Options > Controls > 'While Interacting' set to Lock, you're rooted until it's done ({key} = cancel).
• LOCK / SAFE / KEYCARD: inert props — need the task-07 minigame / task-08 inventory (labelled)."""

@export var player_path: NodePath = ^"../Player"

var _player: Node
var _prompt: Label
var _entries: Array = []
var _interact_key := "?"

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_interact_key = _interact_key_label()
	_build_hud()
	for node in get_parent().get_children():
		if node is Obstacle:
			_register(node)

## The actual live "interact" key, read from InputMap rather than assumed — project.godot binds it
## to F (E/Q are lean_right/lean_left), but this stays correct if that's ever rebound.
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
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.offset_top = -96.0
	_prompt.offset_bottom = -48.0
	_prompt.add_theme_font_size_override("font_size", 22)
	layer.add_child(_prompt)

func _register(o: Node) -> void:
	var mesh := o.get_node_or_null("Col/Mesh") as MeshInstance3D
	var mat: StandardMaterial3D = null
	var base := Color.WHITE
	if mesh != null:
		var src := mesh.get_surface_override_material(0)
		if src is StandardMaterial3D:
			mat = (src as StandardMaterial3D).duplicate()
			base = mat.albedo_color
		else:
			mat = StandardMaterial3D.new()
		mesh.material_override = mat

	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 40
	tag.outline_size = 12
	tag.pixel_size = 0.005
	tag.position = Vector3(0.0, 1.5, 0.0)
	o.add_child(tag)

	var entry := {"node": o, "mat": mat, "base": base, "tag": tag}
	_entries.append(entry)
	if o.has_signal("state_changed"):
		o.state_changed.connect(_refresh.bind(entry))
	_refresh(entry)

func _process(_delta: float) -> void:
	if _player != null and _prompt != null and _player.has_method("current_prompt"):
		var p: String = _player.current_prompt()
		_prompt.text = "[%s]  %s" % [_interact_key, p] if p != "" else ""
	# Live update while a hack fills (no per-frame signal for progress).
	for e in _entries:
		if e["node"].get("hacking") == true and not e["node"].solved:
			_refresh(e)

func _refresh(e: Dictionary) -> void:
	var o = e["node"]
	var mat: StandardMaterial3D = e["mat"]
	var tag: Label3D = e["tag"]
	tag.text = "%s\n%s" % [_name_of(o), _state_word(o)]
	if o.solved:
		_paint(mat, COLOR_DONE)
		tag.modulate = COLOR_DONE
	elif o.get("hacking") == true:
		_paint(mat, (e["base"] as Color).lerp(COLOR_HACK, _hack_fraction(o)))
		tag.modulate = COLOR_HACK
	elif _is_off(o):
		_paint(mat, COLOR_OFF)
		tag.modulate = Color(0.75, 0.75, 0.8)
	else:
		_paint(mat, e["base"])
		tag.modulate = Color.WHITE

func _paint(mat: StandardMaterial3D, c: Color) -> void:
	if mat != null:
		mat.albedo_color = c

func _name_of(o) -> String:
	if o.def != null and String(o.def.display_name) != "":
		return String(o.def.display_name)
	return String(o.name)

func _hack_fraction(o) -> float:
	if o.def == null or o.def.time_seconds <= 0.0:
		return 0.0
	return clampf(o.progress / o.def.time_seconds, 0.0, 1.0)

func _is_off(o) -> bool:
	return o.get("disabled") == true or o.get("active") == false \
		or o.get("lit") == false or o.get("armed") == false \
		or o.get("powered_cut") == true

func _state_word(o) -> String:
	if o.solved:
		return "OPEN"
	if o.get("hacking") == true:
		return "HACKING %d%%" % int(round(_hack_fraction(o) * 100.0))
	if o.get("powered_cut") == true:
		return "POWER CUT"
	if _is_off(o):
		return "OFF"
	if o.def != null:
		match o.def.category:
			ObstacleDef.Category.LOCK:
				return "LOCKED — lockpick UI = task 07"
			ObstacleDef.Category.SAFE:
				return "LOCKED — dial 07 / clue 08"
			ObstacleDef.Category.KEYCARD_DOOR:
				return "LOCKED — needs keycard (08)"
			ObstacleDef.Category.LASER_GRID:
				return "ARMED — cut its zone power"
	return "READY — press %s" % _interact_key
