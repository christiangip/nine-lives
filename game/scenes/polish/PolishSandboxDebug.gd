extends Node3D
## Dev-only Polish & Performance Sandbox (task 21, F6) — a first-person demo of every task-21 surface in one
## furnished room built from REAL Phase-1 art (Quaternius furniture + a heist safe + Swat/Casual characters),
## with the REAL PlayerController + HUD mounted so shake / vignette / compass all bind to live code. It proves:
##   ACCESSIBILITY (FR-21-1): [B] colorblind palettes · [H] reduce flashing · [U] camera-shake toggle ·
##     [I] controller vibration · [Y] language (Menu/Pause tr() strings flip live) · [O] full Options;
##   JUICE (FR-21-3): [J] drive detection (compass palette + escalation pulse) · [K] take damage (camera
##     shake + damage vignette) · [P] go loud (alarm shake + Pursuit) · [N] noise ring · LMB fire (recoil
##     shake + hit-marker);
##   PERFORMANCE (FR-21-2): [L] flood the area with DetectionSensors, [M] toggle the distance-LOD budget; the
##     header shows live FPS + how many sensors are full / throttled / sleeping this frame;
##   RELEASE (FR-21-7): the version stamp (bottom-right) + [9] the Main Menu.
## Mutated settings + locale are snapshot in _ready and restored on exit, so it never perturbs the real
## profile or other tests. NOT shipped. ← returns to the galleries. See docs/tasks/21_release_polish.md.

const GALLERIES := "res://game/scenes/art/gallery_hub.tscn"
const PLAYER_SCENE := preload("res://game/scenes/player/PlayerController.tscn")
const HUD_SCENE := preload("res://game/scenes/ui/hud/HUD.tscn")
const FONT := preload("res://game/assets/fonts/KenneyFuture.ttf")

const SAFE := "res://game/assets/models/props/heist/safe.glb"
const TABLE := "res://game/assets/models/props/furniture_quaternius/Table.obj"
const DESK := "res://game/assets/models/props/furniture_quaternius/Desk.obj"
const BOOKCASE := "res://game/assets/models/props/furniture_quaternius/Bookcase.obj"
const SOFA := "res://game/assets/models/props/furniture_quaternius/Sofa.obj"
const CAMERA_PROP := "res://game/assets/models/props/heist/security_camera.glb"
const THREAT := "res://game/assets/models/characters/Swat.gltf"
const CASUAL := "res://game/assets/models/characters/Casual.gltf"

const _COLORBLIND_NAMES := ["None", "Protanopia", "Deuteranopia", "Tritanopia"]
const _LANG := ["en", "es", "fr", "de"]
const _DEV_GEAR: Array[StringName] = [&"suppressed_pistol", &"emp"]
const PERF_BATCH := 8

## Minimal MissionController stand-in so the HUD objective / secured readout has a source.
class MockMission extends Node:
	var secured_value: int = 2200
	var contract = null
	func loot_total_value() -> int:
		return 8000

var _threat: Node3D
var _det_state: int = 0
var _phase: int = 0
var _ui_layer: CanvasLayer
var _overlay: Control = null
var _header: Label
var _tr_label: Label
var _sensors: Array = []           ## spawned DetectionSensor perf dummies
var _sensor_cfg: DetectionConfigDef
var _budget_on: bool = true
var _lod_full_default: float = 22.0
# Snapshot of mutated settings/locale, restored on exit.
var _saved: Dictionary = {}
var _saved_locale: String = "en"

func _ready() -> void:
	_snapshot_settings()
	_sensor_cfg = _make_sensor_cfg()
	_build_room()
	_spawn_player()
	_equip_dev_loadout()
	add_child(HUD_SCENE.instantiate())
	var m := MockMission.new()
	m.add_to_group(&"mission_root")
	add_child(m)
	add_child(NoiseRingSpawner.new())
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 30
	add_child(_ui_layer)
	_build_ui()

# --- Settings isolation ----------------------------------------------------
func _snapshot_settings() -> void:
	var s := Services.settings()
	if s == null:
		return
	for k in ["colorblind", "reduce_flashing", "vibration", "aim_assist"]:
		_saved[k] = s.get_value("gameplay", k)
	_saved["camera_shake"] = s.get_value("video", "camera_shake")
	_saved["language"] = s.get_value("gameplay", "language")
	_saved_locale = TranslationServer.get_locale()

func _restore_settings() -> void:
	var s := Services.settings()
	if s == null:
		return
	for k in ["colorblind", "reduce_flashing", "vibration", "aim_assist", "language"]:
		if _saved.has(k):
			s.set_value("gameplay", k, _saved[k])
	if _saved.has("camera_shake"):
		s.set_value("video", "camera_shake", _saved["camera_shake"])
	TranslationServer.set_locale(_saved_locale)

## A clone of the registered default detection config, so the perf toggle can flip its LOD without touching
## the shared resource the real game uses.
func _make_sensor_cfg() -> DetectionConfigDef:
	var base := Content.detection.get_def(&"default") as DetectionConfigDef if Content != null and Content.detection != null else null
	var cfg := base.duplicate() as DetectionConfigDef if base != null else DetectionConfigDef.new()
	_lod_full_default = cfg.lod_full_range
	return cfg

# --- World -----------------------------------------------------------------
func _build_room() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.11, 0.15)
	e.ambient_light_color = Color(0.5, 0.55, 0.62)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var floor_body := StaticBody3D.new()
	floor_body.set_meta("surface", "concrete")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(26, 0.5, 26)
	shape.shape = box
	floor_body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(26, 0.5, 26)
	mi.mesh = bm
	mi.material_override = Palette.material(&"floor")
	floor_body.add_child(mi)
	floor_body.position = Vector3(0, -0.25, 0)
	add_child(floor_body)

	_spawn_model(DESK, Vector3(-3, 0, -4), 1.0)
	_spawn_model(TABLE, Vector3(3, 0, -4), 1.0)
	_spawn_model(BOOKCASE, Vector3(-5, 0, 0), 1.0)
	_spawn_model(SOFA, Vector3(5, 0, 1.5), 1.0)
	_spawn_model(SAFE, Vector3(5, 0, -1), 1.0)
	_spawn_model(CAMERA_PROP, Vector3(-6, 2.4, -6), 1.0)
	_spawn_model(CASUAL, Vector3(-2, 0, 3), 1.0)
	_threat = _spawn_model(THREAT, Vector3(6, 0, -6), 1.0)

## .glb/.gltf → instance the PackedScene; .obj → wrap the Mesh in a MeshInstance3D. Returns the root Node3D.
func _spawn_model(path: String, pos: Vector3, model_scale: float) -> Node3D:
	var root: Node3D = null
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		var packed := load(path) as PackedScene
		if packed != null:
			root = packed.instantiate() as Node3D
	else:
		var mesh := load(path) as Mesh
		if mesh != null:
			root = MeshInstance3D.new()
			(root as MeshInstance3D).mesh = mesh
	if root == null:
		root = Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * model_scale
	add_child(root)
	return root

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.2, 4)
	add_child(player)

func _equip_dev_loadout() -> void:
	var lo := RunManager.loadout()
	for gid in _DEV_GEAR:
		if gid not in ProgressionManager.unlocked_gear:
			ProgressionManager.unlocked_gear.append(gid)
		var gd := Content.gear.get_def(gid) as GearDef
		if gd != null:
			lo.equip(gd)
	var p := _player()
	if p != null:
		var combat := p.get_node_or_null("Head/Hands")
		if combat != null and combat.get_child_count() > 0 and combat.get_child(0).has_method("rebuild_weapons"):
			combat.get_child(0).rebuild_weapons()

# --- UI --------------------------------------------------------------------
func _build_ui() -> void:
	var back := Button.new()
	back.text = "← Galleries"
	back.position = Vector2(12, 12)
	back.pressed.connect(_leave)
	_ui_layer.add_child(back)

	_header = _mk_label(Vector2(120, 14), 18, Color(1.0, 0.9, 0.5))
	_header.custom_minimum_size = Vector2(1100, 0)

	var help := _mk_label(Vector2(12, 44), 15, Color(0.8, 0.86, 0.95))
	help.text = "[POLISH & PERFORMANCE SANDBOX — task 21]  WASD/mouse · LMB fire · Esc pause\n" + \
		"ACCESS: B colorblind · H reduce-flashing · U camera-shake · I vibration · Y language · O Options\n" + \
		"JUICE: J detection(compass) · K take damage(shake+vignette) · P go loud · N noise ring\n" + \
		"PERF: L +%d sensors · M toggle LOD budget    |    9 Main Menu · Tab free mouse" % PERF_BATCH

	_tr_label = _mk_label(Vector2(12, 118), 16, Color(0.7, 1.0, 0.8))

	var ver := _mk_label(Vector2.ZERO, 15, Color(0.62, 0.67, 0.74))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_left = -260; ver.offset_top = -30; ver.offset_right = -14; ver.offset_bottom = -8
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.text = Version.string()

	_refresh_readouts()

func _mk_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	_ui_layer.add_child(l)
	return l

func _refresh_readouts() -> void:
	var full := 0; var throttled := 0; var sleeping := 0
	var p := _player()
	var ppos: Vector3 = p.global_position if p != null else Vector3.ZERO
	for s in _sensors:
		if not is_instance_valid(s):
			continue
		var iv := DetectionSensor.sense_interval_for_distance(ppos.distance_to((s as Node3D).global_position), _sensor_cfg)
		if iv <= 0: sleeping += 1
		elif iv == 1: full += 1
		else: throttled += 1
	var s := Services.settings()
	var cb := int(s.get_value("gameplay", "colorblind")) if s != null else 0
	_header.text = "FPS %d  |  sensors %d (full %d · throttled %d · sleeping %d)  |  LOD budget %s  ||  colorblind: %s · flashing: %s · shake: %s · vibration: %s · lang: %s" % [
		Engine.get_frames_per_second(), _sensors.size(), full, throttled, sleeping,
		"ON" if _budget_on else "OFF",
		_COLORBLIND_NAMES[clampi(cb, 0, 3)],
		"reduced" if _flag("gameplay", "reduce_flashing") else "on",
		"on" if _flag("video", "camera_shake") else "off",
		"on" if _flag("gameplay", "vibration") else "off",
		TranslationServer.get_locale()]
	_tr_label.text = "Localized (tr): New Game = '%s'  ·  Pause = '%s'  ·  Abort = '%s'" % [
		tr("MENU_NEW_GAME"), tr("PAUSE_TITLE"), tr("PAUSE_ABORT")]

func _flag(section: String, key: String) -> bool:
	var s := Services.settings()
	return s != null and bool(s.get_value(section, key))

func _process(_delta: float) -> void:
	_refresh_readouts()

# --- Dev keys --------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_J: _cycle_detection()
		KEY_B: _cycle_colorblind()
		KEY_H: _toggle("gameplay", "reduce_flashing")
		KEY_U: _toggle("video", "camera_shake")
		KEY_I: _toggle("gameplay", "vibration")
		KEY_Y: _cycle_language()
		KEY_K: _take_damage()
		KEY_P: _go_loud()
		KEY_N: _spawn_noise()
		KEY_L: _spawn_perf_batch()
		KEY_M: _toggle_budget()
		KEY_O: _open(OptionsMenu.open(_ui_layer))
		KEY_9: GameManager.goto_main_menu()
		KEY_TAB: _toggle_mouse()

func _cycle_detection() -> void:
	_det_state = (_det_state + 1) % 5
	if _threat != null:
		EventBus.detection_changed.emit(_threat.get_instance_id(), _det_state, float(_det_state) / 4.0)

func _cycle_colorblind() -> void:
	var s := Services.settings()
	if s == null:
		return
	s.set_value("gameplay", "colorblind", (int(s.get_value("gameplay", "colorblind")) + 1) % 4)

func _cycle_language() -> void:
	var s := Services.settings()
	if s == null:
		return
	var i := _LANG.find(String(s.get_value("gameplay", "language")))
	s.set_value("gameplay", "language", _LANG[(i + 1) % _LANG.size()])   # → _apply_gameplay → set_locale

func _toggle(section: String, key: String) -> void:
	var s := Services.settings()
	if s != null:
		s.set_value(section, key, not bool(s.get_value(section, key)))

func _take_damage() -> void:
	var p := _player()
	if p != null and p.has_method("apply_damage"):
		p.apply_damage(20.0)   # → Health + camera shake + damage vignette

func _go_loud() -> void:
	var p := _player()
	var pos: Vector3 = p.global_position if p != null else global_position
	EventBus.alarm_tripped.emit("loud", pos)   # → alarm shake + RunManager commit
	_phase = clampi(_phase + 1, 0, 5)
	EventBus.pursuit_phase_changed.emit(_phase)

func _spawn_noise() -> void:
	var p := _player()
	var pos: Vector3 = p.global_position if p != null else global_position
	EventBus.noise_emitted.emit(pos, 6.0, "footstep")

# --- Performance density ---------------------------------------------------
## Add a batch of real DetectionSensors on an expanding ring so the distance-LOD budget has a spread to work
## over (some full, some throttled, some sleeping — see the header).
func _spawn_perf_batch() -> void:
	var p := _player()
	var origin: Vector3 = p.global_position if p != null else Vector3.ZERO
	for i in PERF_BATCH:
		var n := _sensors.size()
		var ring := 6.0 + float(n) * 2.4              # push each new sensor further out
		var ang := float(n) * 2.399963              # golden-angle scatter
		var pos := origin + Vector3(cos(ang) * ring, 1.4, sin(ang) * ring)
		var sensor := DetectionSensor.new()
		sensor.config = _sensor_cfg
		sensor.position = pos
		add_child(sensor)
		sensor.look_at(origin + Vector3.UP * 1.4, Vector3.UP)   # face the player so it actually casts LoS
		var cap := MeshInstance3D.new()
		var cm := CapsuleMesh.new(); cm.height = 1.7; cm.radius = 0.3
		cap.mesh = cm
		cap.material_override = Palette.tinted(Palette.TINT_GUARD)
		sensor.add_child(cap)
		_sensors.append(sensor)

func _toggle_budget() -> void:
	_budget_on = not _budget_on
	# Budget OFF = every sensor senses every frame (huge full-range); ON = the real distance LOD.
	_sensor_cfg.lod_full_range = _lod_full_default if _budget_on else 1_000_000.0

# --- Overlay / mouse -------------------------------------------------------
func _open(node: Control) -> void:
	_overlay = node
	_set_mouse_free(true)
	node.tree_exited.connect(func() -> void:
		_overlay = null
		_set_mouse_free(false))
	if node.get_parent() == null:
		_ui_layer.add_child(node)

func _toggle_mouse() -> void:
	_set_mouse_free(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

func _set_mouse_free(free: bool) -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED

func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D if get_tree() != null else null

func _leave() -> void:
	_restore_settings()   # never perturb the real profile
	get_tree().change_scene_to_file(GALLERIES)
