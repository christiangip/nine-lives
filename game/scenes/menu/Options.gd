extends Control
class_name OptionsMenu
## The full Options menu (task 15, FR-15-4; GDD §15.2): Graphics · Audio · Controls (live KB+M/gamepad
## remap) · Gameplay/Accessibility · System. Every control reads/writes SettingsManager.get_value/set_value
## — which already live-applies + persists to user://settings.cfg + emits settings_changed — and the remap
## rows drive InputManager.rebind_action. Reused as an overlay from both the Main Menu and the Pause menu.
## Built in code with the shared UITheme; EventBus stays FROZEN. See docs/tasks/15_ui_hud_menus.md.

signal closed

const _COLORBLIND := ["None", "Protanopia", "Deuteranopia", "Tritanopia"]
const _MSAA := ["Off", "2×", "4×", "8×"]
const _SHADOWS := ["Off", "Low", "Medium", "High"]
const _LANG_CODES := ["en", "es", "fr", "de"]
const _LANG_NAMES := ["English", "Español", "Français", "Deutsch"]

## Pretty labels for the remappable actions (falls back to a titled id).
const _ACTION_LABELS := {
	&"move_forward": "Move Forward", &"move_back": "Move Back", &"move_left": "Move Left",
	&"move_right": "Move Right", &"sprint": "Sprint", &"crouch": "Crouch", &"prone": "Prone",
	&"jump": "Jump", &"lean_left": "Lean Left", &"lean_right": "Lean Right", &"interact": "Interact",
	&"takedown": "Takedown", &"casing_vision": "Casing Vision", &"drop_loot": "Drop Loot",
	&"throw": "Throw", &"aim": "Aim", &"fire": "Fire", &"reload": "Reload",
	&"weapon_next": "Next Weapon", &"gadget_use": "Use Gadget", &"pause": "Pause",
}

static func open(parent: Node, pause_aware: bool = false) -> OptionsMenu:
	var o := OptionsMenu.new()
	o._pause_aware = pause_aware
	parent.add_child(o)
	return o

var _pause_aware: bool = false            ## keep processing while the tree is paused (opened from Pause)
var _tabs: TabContainer
var _listening_action: StringName = &""
var _listening_button: Button = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _pause_aware:
		process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.build()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(820, 620)
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(_close)
	header.add_child(back)
	root.add_child(HSeparator.new())

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_populate()
	back.grab_focus()

func _populate() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	_build_graphics(_tab("Graphics"))
	_build_audio(_tab("Audio"))
	_build_controls(_tab("Controls"))
	_build_accessibility(_tab("Accessibility"))
	_build_system(_tab("System"))

# --- Tab bodies ----------------------------------------------------------------
func _build_graphics(body: VBoxContainer) -> void:
	_check(body, "Fullscreen", "video", "fullscreen")
	_check(body, "V-Sync", "video", "vsync")
	_spin(body, "Max FPS (0 = uncapped)", "video", "max_fps", 0, 360, 5)
	_option_int(body, "Anti-Aliasing (MSAA)", "video", "msaa", _MSAA)
	_slider(body, "Render Scale", "video", "render_scale", 0.5, 1.0, 0.05)
	_option_int(body, "Shadows", "video", "shadows", _SHADOWS)
	_slider(body, "Field of View", "video", "fov", 50.0, 120.0, 1.0)
	_slider(body, "Gamma", "video", "gamma", 0.5, 2.0, 0.05)
	_check(body, "Motion Blur", "video", "motion_blur")
	_check(body, "Camera Shake", "video", "camera_shake")

func _build_audio(body: VBoxContainer) -> void:
	_slider(body, "Master Volume", "audio", "master", 0.0, 1.0, 0.05)
	_slider(body, "Music", "audio", "music", 0.0, 1.0, 0.05)
	_slider(body, "SFX", "audio", "sfx", 0.0, 1.0, 0.05)
	_slider(body, "UI", "audio", "ui", 0.0, 1.0, 0.05)
	_slider(body, "Ambience", "audio", "ambience", 0.0, 1.0, 0.05)
	_check(body, "Subtitles", "audio", "subtitles")

func _build_controls(body: VBoxContainer) -> void:
	_slider(body, "Mouse Sensitivity", "gameplay", "mouse_sensitivity", 0.05, 1.0, 0.01)
	_check(body, "Invert Y", "gameplay", "invert_y")
	_check(body, "Hold-to-Crouch (off = toggle)", "gameplay", "crouch_toggle")
	_check(body, "Hold-to-Sprint (off = toggle)", "gameplay", "sprint_toggle")
	_check(body, "Controller Vibration", "gameplay", "vibration")
	_note(body, "Rebind — click a binding, then press a key, mouse button, or gamepad button. Esc cancels.")
	for action in InputManager.ACTIONS:
		_remap_row(body, action)

func _build_accessibility(body: VBoxContainer) -> void:
	_slider(body, "UI Scale", "gameplay", "ui_scale", 0.75, 1.5, 0.05)
	_option_int(body, "Colorblind Mode", "gameplay", "colorblind", _COLORBLIND)
	_check(body, "Reduce Flashing", "gameplay", "reduce_flashing")
	_check(body, "Aim Assist", "gameplay", "aim_assist")
	_option_str(body, "Language", "gameplay", "language", _LANG_CODES, _LANG_NAMES)

func _build_system(body: VBoxContainer) -> void:
	_note(body, "Settings are saved to user://settings.cfg, independent of your save slots.")
	var reset := Button.new()
	reset.text = "Reset all settings to defaults"
	reset.custom_minimum_size = Vector2(320, 44)
	reset.pressed.connect(_on_reset_pressed)
	body.add_child(reset)

func _on_reset_pressed() -> void:
	var c := ConfirmPopup.open(self, "Reset ALL options to their defaults?", "Reset")
	c.confirmed.connect(func() -> void:
		SettingsManager.reset_to_defaults()
		_populate())

# --- Control builders ----------------------------------------------------------
func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	_tabs.add_child(scroll)
	return box

func _row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row

func _check(parent: VBoxContainer, label_text: String, section: String, key: String) -> void:
	var row := _row(parent, label_text)
	var cb := CheckButton.new()
	cb.button_pressed = bool(SettingsManager.get_value(section, key))
	cb.toggled.connect(func(on: bool) -> void: SettingsManager.set_value(section, key, on))
	row.add_child(cb)

func _slider(parent: VBoxContainer, label_text: String, section: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := _row(parent, label_text)
	var val := Label.new()
	val.custom_minimum_size = Vector2(60, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = step
	s.custom_minimum_size = Vector2(260, 0)
	s.value = float(SettingsManager.get_value(section, key))
	val.text = _fmt_num(s.value, step)
	s.value_changed.connect(func(v: float) -> void:
		val.text = _fmt_num(v, step)
		SettingsManager.set_value(section, key, v))
	row.add_child(s)
	row.add_child(val)

func _spin(parent: VBoxContainer, label_text: String, section: String, key: String, lo: int, hi: int, step: int) -> void:
	var row := _row(parent, label_text)
	var sp := SpinBox.new()
	sp.min_value = lo; sp.max_value = hi; sp.step = step
	sp.value = int(SettingsManager.get_value(section, key))
	sp.value_changed.connect(func(v: float) -> void: SettingsManager.set_value(section, key, int(v)))
	row.add_child(sp)

func _option_int(parent: VBoxContainer, label_text: String, section: String, key: String, items: Array) -> void:
	var row := _row(parent, label_text)
	var ob := OptionButton.new()
	for i in items.size():
		ob.add_item(String(items[i]), i)
	ob.selected = clampi(int(SettingsManager.get_value(section, key)), 0, items.size() - 1)
	ob.item_selected.connect(func(idx: int) -> void: SettingsManager.set_value(section, key, idx))
	row.add_child(ob)

func _option_str(parent: VBoxContainer, label_text: String, section: String, key: String, codes: Array, names: Array) -> void:
	var row := _row(parent, label_text)
	var ob := OptionButton.new()
	for i in names.size():
		ob.add_item(String(names[i]), i)
	var cur := String(SettingsManager.get_value(section, key))
	ob.selected = maxi(0, codes.find(cur))
	ob.item_selected.connect(func(idx: int) -> void: SettingsManager.set_value(section, key, String(codes[idx])))
	row.add_child(ob)

func _note(parent: VBoxContainer, text: String) -> void:
	var n := Label.new()
	n.text = text
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_color_override("font_color", UITheme.MUTED)
	parent.add_child(n)

# --- Remap ---------------------------------------------------------------------
func _remap_row(parent: VBoxContainer, action: StringName) -> void:
	var row := _row(parent, String(_ACTION_LABELS.get(action, String(action).capitalize())))
	var btn := Button.new()
	btn.text = _binding_text(action)
	btn.custom_minimum_size = Vector2(240, 36)
	btn.pressed.connect(func() -> void: _begin_listen(action, btn))
	row.add_child(btn)

func _binding_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var parts: Array[String] = []
	for ev in InputMap.action_get_events(action):
		parts.append(ev.as_text())
		if parts.size() >= 2:
			break
	return " / ".join(parts) if not parts.is_empty() else "Unbound"

func _begin_listen(action: StringName, btn: Button) -> void:
	_listening_action = action
	_listening_button = btn
	btn.text = "Press input…"

func _input(event: InputEvent) -> void:
	if _listening_action == &"":
		return
	if event.is_action_pressed("ui_cancel"):
		_end_listen()
		get_viewport().set_input_as_handled()
		return
	var capture := _capturable(event)
	if capture != null:
		InputManager.rebind_action(_listening_action, capture)
		_end_listen()
		get_viewport().set_input_as_handled()

## A fresh, storable event from a raw input, or null if this input isn't a rebind target.
func _capturable(event: InputEvent) -> InputEvent:
	if event is InputEventKey and event.pressed and not event.echo:
		return event
	if event is InputEventMouseButton and event.pressed:
		return event
	if event is InputEventJoypadButton and event.pressed:
		return event
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		return event
	return null

func _end_listen() -> void:
	if _listening_button != null:
		_listening_button.text = _binding_text(_listening_action)
	_listening_action = &""
	_listening_button = null

# --- helpers -------------------------------------------------------------------
func _fmt_num(v: float, step: float) -> String:
	return str(int(round(v))) if step >= 1.0 else "%.2f" % v

func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == &"":
		if event.is_action_pressed("ui_cancel"):
			_close()
			get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
