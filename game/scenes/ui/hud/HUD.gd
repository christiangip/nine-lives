extends CanvasLayer
class_name MissionHUD
## The in-mission HUD (task 15, FR-15-5/6/7) — the minimal, trustable, FP-readability overlay. Assembles:
## a crosshair + interaction prompt, the combined CompassEye detection indicator, a carry readout
## (W/V vs caps + FULL warning), an objective + secured-vs-remaining tracker, a Pursuit/Heat strip, and a
## loud block (health/armor/ammo) that only appears once committed/loud. Reads live state each frame from
## the player (&"player" group), the mission (&"mission_root" → MissionController) and RunManager, and binds
## the frozen EventBus (pursuit_phase_changed / heat_changed). Honours gameplay/ui_scale + reduce_flashing.
## Also owns the Pause overlay (the `pause` action). Minigame overlays are the diegetic FR-15-6 half, already
## shipped by task 07's MinigameHost. Built in code (house pattern). See docs/tasks/15_ui_hud_menus.md.

const PAUSE_SCENE := "res://game/scenes/mission/PauseMenu.tscn"
const _OUTLINE := 5

var _root: Control
var _crosshair: Control
var _prompt_label: Label
var _compass: CompassEye
var _carry_label: Label
var _carry_full: Label
var _objective_label: Label
var _secured_label: Label
var _pursuit_label: Label
var _loud_box: Control
var _hp_fill: ColorRect
var _armor_fill: ColorRect
var _ammo_label: Label
var _bar_w: float = 180.0

var _phase: int = 0
var _pause_menu: Control = null
var _ui_scale: float = 1.0

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep drawing + catch the resume key while the tree is paused
	_ui_scale = _read_ui_scale()
	_build()
	if not EventBus.pursuit_phase_changed.is_connected(_on_pursuit_phase):
		EventBus.pursuit_phase_changed.connect(_on_pursuit_phase)
	if not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)

# --- Pure seams (headless-testable) --------------------------------------------
## Carry is "full" (show the warning) once within a whisker of either cap. Pure. (FR-15-5)
static func carry_warning(w: float, v: float, wcap: float, vcap: float) -> bool:
	return (wcap > 0.0 and w >= wcap * 0.98) or (vcap > 0.0 and v >= vcap * 0.98)

## The loud block (health/armor/ammo) is shown only when the run has gone loud/committed, Pursuit is
## active, or the player has actually taken damage. Pure. (FR-15-5)
static func loud_visible(committed: bool, phase: int, health_frac: float) -> bool:
	return committed or phase > 0 or health_frac < 0.999

# --- Build ---------------------------------------------------------------------
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.build()
	add_child(_root)

	_build_crosshair()
	_compass = CompassEye.new()
	_compass.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_compass.position = Vector2(-60, -170) * _ui_scale
	_compass.scale = Vector2.ONE * _ui_scale
	_root.add_child(_compass)

	# Top-left: carry readout + FULL warning.
	var tl := _corner_box(Control.PRESET_TOP_LEFT, Vector2(20, 18))
	_carry_label = _mk_label(tl, "", 20, UITheme.TEXT)
	_carry_full = _mk_label(tl, "", 18, UITheme.WARN)

	# Top-right: objective + secured/remaining.
	var tr := _corner_box(Control.PRESET_TOP_RIGHT, Vector2(-20, 18))
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_label = _mk_label(tr, "", 20, UITheme.ACCENT)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_secured_label = _mk_label(tr, "", 18, UITheme.OK)
	_secured_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Bottom-left: Pursuit/Heat strip.
	var bl := _corner_box(Control.PRESET_BOTTOM_LEFT, Vector2(20, -18))
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pursuit_label = _mk_label(bl, "", 20, UITheme.WARN)

	_build_loud_block()

func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.custom_minimum_size = Vector2(1, 1)
	_root.add_child(_crosshair)
	var dot := Label.new()
	dot.text = "+"
	dot.add_theme_font_size_override("font_size", int(22 * _ui_scale))
	dot.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	dot.position = Vector2(-8, -16)
	_crosshair.add_child(dot)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	_prompt_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("outline_size", _OUTLINE)
	_prompt_label.position = Vector2(-70, 22)
	_prompt_label.custom_minimum_size = Vector2(140, 0)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.add_child(_prompt_label)

func _build_loud_block() -> void:
	_loud_box = VBoxContainer.new()
	_loud_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_loud_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_loud_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loud_box.position = Vector2(-20, -18)
	_loud_box.add_theme_constant_override("separation", 4)
	_loud_box.visible = false
	_root.add_child(_loud_box)
	_bar_w = 180.0 * _ui_scale
	_hp_fill = _mk_bar(_loud_box, "HEALTH", Color(0.85, 0.25, 0.25))
	_armor_fill = _mk_bar(_loud_box, "ARMOR", Color(0.35, 0.6, 0.95))
	_ammo_label = _mk_label(_loud_box, "", 20, UITheme.TEXT)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

## A labelled bar: returns the fill ColorRect (its width is set each frame to value/max × _bar_w).
func _mk_bar(parent: Control, caption: String, fill_color: Color) -> ColorRect:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(row)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", int(14 * _ui_scale))
	cap.add_theme_color_override("font_color", UITheme.MUTED)
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	cap.add_theme_constant_override("outline_size", _OUTLINE)
	row.add_child(cap)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(_bar_w, 16 * _ui_scale)
	row.add_child(frame)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(bg)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.position = Vector2.ZERO
	fill.size = Vector2(_bar_w, 16 * _ui_scale)
	frame.add_child(fill)
	return fill

# --- Per-frame update ----------------------------------------------------------
func _process(_delta: float) -> void:
	var player := _player()
	_update_carry(player)
	_update_prompt(player)
	_update_objective()
	_update_pursuit()
	_update_loud(player)

func _update_carry(player: Node) -> void:
	if player == null or player.get("inventory") == null:
		_carry_label.text = ""
		_carry_full.text = ""
		return
	var inv = player.inventory
	var w: float = inv.current_weight()
	var v: float = inv.current_volume()
	var wc: float = inv.weight_cap
	var vc: float = inv.volume_cap
	_carry_label.text = "Weight %.1f / %.0f kg     Volume %.1f / %.0f L     In-hand $%d" % [w, wc, v, vc, inv.in_hand_value()]
	_carry_full.text = "◆ CARRY FULL — drop or bag at a Drop Point" if carry_warning(w, v, wc, vc) else ""

func _update_prompt(player: Node) -> void:
	if player != null and player.has_method("current_prompt"):
		_prompt_label.text = player.current_prompt()
	else:
		_prompt_label.text = ""

func _update_objective() -> void:
	var mission := _mission()
	if mission == null:
		_objective_label.text = ""
		_secured_label.text = ""
		return
	_objective_label.text = "Objective: %s" % _objective_name(mission)
	var secured := int(mission.secured_value)
	var total := int(mission.loot_total_value()) if mission.has_method("loot_total_value") else secured
	var remaining := maxi(0, total - secured)
	_secured_label.text = "Secured $%d / $%d      Remaining $%d" % [secured, total, remaining]

func _update_pursuit() -> void:
	var heat := RunManager.heat if RunManager != null else 0.0
	var committed := RunManager != null and RunManager.committed
	if not committed and _phase <= 0 and heat <= 0.0:
		_pursuit_label.text = ""
		return
	_pursuit_label.text = "HEAT %.0f%%      PURSUIT phase %d" % [heat * 100.0, _phase]

func _update_loud(player: Node) -> void:
	var committed := RunManager != null and RunManager.committed
	var health = player.get("health") if player != null else null
	var health_frac := 1.0
	if health != null and float(health.max_health) > 0.0:
		health_frac = float(health.current) / float(health.max_health)
	_loud_box.visible = loud_visible(committed, _phase, health_frac)
	if not _loud_box.visible:
		return
	_hp_fill.size.x = _bar_w * clampf(health_frac, 0.0, 1.0)
	var armor_frac := 0.0
	if health != null and health.armor != null and float(health.armor.maximum()) > 0.0:
		armor_frac = float(health.armor.current) / float(health.armor.maximum())
	_armor_fill.size.x = _bar_w * clampf(armor_frac, 0.0, 1.0)
	var weapon = player.active_weapon() if player != null and player.has_method("active_weapon") else null
	_ammo_label.text = ("AMMO %d / %d" % [int(weapon.ammo), int(weapon.reserve)]) if weapon != null else "UNARMED"

# --- Pause (owns the `pause` action) -------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and _pause_menu == null and _player() != null:
		_open_pause()
		get_viewport().set_input_as_handled()

func _open_pause() -> void:
	var packed := load(PAUSE_SCENE) as PackedScene
	if packed == null:
		return
	_pause_menu = packed.instantiate()
	_pause_menu.tree_exited.connect(func() -> void: _pause_menu = null)
	add_child(_pause_menu)

# --- Signals / settings --------------------------------------------------------
func _on_pursuit_phase(phase: int) -> void:
	_phase = phase

func _on_settings_changed(section: String) -> void:
	if section == "gameplay":
		var s := _read_ui_scale()
		if not is_equal_approx(s, _ui_scale):
			# UI scale changed — rebuild the HUD at the new scale (cheap; happens only on an Options change).
			_ui_scale = s
			for c in _root.get_children():
				c.queue_free()
			_compass = null
			_build()

# --- Lookups -------------------------------------------------------------------
func _player() -> Node:
	return get_tree().get_first_node_in_group(&"player") if get_tree() != null else null

func _mission() -> Node:
	return get_tree().get_first_node_in_group(&"mission_root") if get_tree() != null else null

func _objective_name(mission: Node) -> String:
	var c = mission.get("contract")
	if c == null:
		return "Reach the objective"
	var def := Content.objectives.get_def(c.objective_id) as ObjectiveDef if Content != null and Content.objectives != null else null
	return def.display_name if def != null else String(c.objective_id)

func _read_ui_scale() -> float:
	var s := Services.settings()
	return clampf(float(s.get_value("gameplay", "ui_scale")), 0.75, 1.5) if s != null else 1.0

# --- Small UI helpers ----------------------------------------------------------
func _corner_box(preset: int, offset: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(preset)
	box.position = offset
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	return box

func _mk_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(font_size * _ui_scale))
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", _OUTLINE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl
