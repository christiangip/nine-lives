## Dev-only 3D demo of the diegetic Hideout (task 13 / phase-1-art) — NOT the shipped hub (that is the
## 2D Hideout.tscn the game loads). A furnished first-person safehouse: walk the room (WASD + mouselook),
## look at a station prop and press [F] to open that station's real panel overlay (the same
## stations/*.tscn the 2D hub uses). Locked stations show a red placard; unlocking one at the 2D hub
## makes its prop light up here ("the safehouse visibly grows"). Uses the Phase-1 furniture/character
## art. F6 to run; ← button returns to the galleries. See docs/tasks/13_hideout_stations.md.
extends Node3D

const HUB_2D := "res://game/scenes/hideout/Hideout.tscn"
const GALLERIES := "res://game/scenes/art/gallery_hub.tscn"
const FONT := preload("res://game/assets/fonts/KenneyFuture.ttf")
const MANNEQUIN := "res://game/assets/models/characters/Casual.gltf"

const EYE_HEIGHT := 1.6
const MOVE_SPEED := 4.0
const INTERACT_RANGE := 2.4
const ROOM := 9.0   # half-extent of the walkable floor

# id -> { pos, mesh_path, label }. Props are placed around the room; meshes are Quaternius furniture.
const STATIONS := [
	{"id": &"job_map",        "pos": Vector3(-6, 0, -6), "mesh": "res://game/assets/models/props/furniture_quaternius/Desk.obj",       "label": "The Job Map"},
	{"id": &"training",       "pos": Vector3(0, 0, -7),  "mesh": "res://game/assets/models/props/furniture_quaternius/Stool.obj",      "label": "Training Area"},
	{"id": &"workshop",       "pos": Vector3(6, 0, -6),  "mesh": "res://game/assets/models/props/furniture_quaternius/Table2.obj",     "label": "Workshop"},
	{"id": &"armory",         "pos": Vector3(-7, 0, 0),  "mesh": "res://game/assets/models/props/furniture_quaternius/Closet.obj",     "label": "Armory"},
	{"id": &"legacy_board",   "pos": Vector3(7, 0, 0),   "mesh": "res://game/assets/models/props/furniture_quaternius/Bookcase.obj",   "label": "Legacy Board"},
	{"id": &"planning_table", "pos": Vector3(-6, 0, 6),  "mesh": "res://game/assets/models/props/furniture_quaternius/Table.obj",      "label": "Planning Table"},
	{"id": &"stash",          "pos": Vector3(0, 0, 7),   "mesh": "res://game/assets/models/props/furniture_quaternius/ShortCloset.obj","label": "The Stash"},
	{"id": &"fence",          "pos": Vector3(6, 0, 6),   "mesh": "res://game/assets/models/props/furniture_quaternius/NightStand.obj", "label": "Fence Terminal"},
]

var _cam: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _props: Array = []          # { id, pos, marker: Label3D }
var _prompt: Label
var _ui_layer: CanvasLayer
var _active_panel: StationPanel = null
var _nearest_id: StringName = &""

func _ready() -> void:
	# Give the player a fresh Streak so the Job Map has a board + some Legacy/Take to spend in the demo.
	if RunManager != null:
		RunManager.start_new_streak()
	if ProgressionManager != null:
		ProgressionManager.legacy = max(ProgressionManager.legacy, 2000)
		RunManager.take = max(RunManager.take, 10000)

	_build_environment()
	_build_room()
	for s in STATIONS:
		_build_station(s)
	_build_mannequin()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- World -----------------------------------------------------------------
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	add_child(sun)

	_cam = Camera3D.new()
	_cam.position = Vector3(0, EYE_HEIGHT, 0)
	_cam.current = true
	add_child(_cam)

func _build_room() -> void:
	var floor := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(ROOM * 2.0, ROOM * 2.0)
	floor.mesh = fm
	floor.material_override = _mat(Color(0.18, 0.19, 0.22))
	add_child(floor)
	# Four low walls for enclosure (visual only; the walker is clamped to ROOM).
	var h := 3.0
	for side in 4:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(ROOM * 2.0, h, 0.2)
		wall.mesh = wm
		wall.material_override = _mat(Color(0.14, 0.15, 0.18))
		var d := ROOM
		match side:
			0: wall.position = Vector3(0, h * 0.5, -d)
			1: wall.position = Vector3(0, h * 0.5, d)
			2: wall.position = Vector3(-d, h * 0.5, 0); wall.rotation_degrees.y = 90
			3: wall.position = Vector3(d, h * 0.5, 0); wall.rotation_degrees.y = 90
		add_child(wall)

func _build_station(s: Dictionary) -> void:
	var pos: Vector3 = s["pos"]
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)

	var mesh_res := load(s["mesh"]) as Mesh
	var mi := MeshInstance3D.new()
	if mesh_res != null:
		mi.mesh = mesh_res
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 1, 1)
		mi.mesh = bm
	holder.add_child(mi)

	var marker := Label3D.new()
	marker.text = String(s["label"])
	marker.font = FONT
	marker.font_size = 48
	marker.pixel_size = 0.004
	marker.position = Vector3(0, 2.0, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holder.add_child(marker)

	_props.append({"id": s["id"], "pos": pos, "marker": marker, "mesh": mi})
	_refresh_lock_state(_props.back())

## Tint the prop + placard by unlock state (green = open, red = locked). Re-checked each frame so an
## unlock made at the 2D hub is reflected live ("safehouse grows").
func _refresh_lock_state(prop: Dictionary) -> void:
	var def := _station_def(prop["id"])
	var unlocked := def != null and ProgressionManager.is_station_unlocked(def)
	var col := Color(0.5, 0.9, 0.6) if unlocked else Color(0.9, 0.45, 0.4)
	(prop["marker"] as Label3D).modulate = col
	(prop["mesh"] as MeshInstance3D).material_override = _mat(col.darkened(0.4)) if not unlocked else null

func _build_mannequin() -> void:
	var packed := load(MANNEQUIN) as PackedScene
	if packed == null:
		return
	var m := packed.instantiate()
	if m is Node3D:
		m.position = Vector3(2.5, 0, 2.5)
		add_child(m)

func _mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	return mat

# --- HUD -------------------------------------------------------------------
func _build_hud() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	var back := Button.new()
	back.text = "← Galleries"
	back.position = Vector2(12, 12)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(GALLERIES))
	_ui_layer.add_child(back)

	var help := Label.new()
	help.text = "WASD move · mouse look · [F] use station · [Esc] release mouse\nDev demo — the shipped hub is the 2D Hideout.tscn"
	help.position = Vector2(12, 48)
	help.add_theme_font_override("font", FONT)
	help.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	_ui_layer.add_child(help)

	_prompt = Label.new()
	_prompt.add_theme_font_override("font", FONT)
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-140, -120)
	_prompt.custom_minimum_size = Vector2(280, 0)
	_ui_layer.add_child(_prompt)

# --- Input / movement ------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _active_panel != null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.4, 1.4)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if _nearest_id != &"":
			_open(_nearest_id)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	for prop in _props:
		_refresh_lock_state(prop)
	if _active_panel != null:
		return
	# Walk on the XZ plane, clamped inside the room.
	var dir := Vector3.ZERO
	var basis := _cam.global_transform.basis
	if Input.is_key_pressed(KEY_W): dir -= basis.z
	if Input.is_key_pressed(KEY_S): dir += basis.z
	if Input.is_key_pressed(KEY_A): dir -= basis.x
	if Input.is_key_pressed(KEY_D): dir += basis.x
	dir.y = 0.0
	if dir != Vector3.ZERO:
		_cam.position += dir.normalized() * MOVE_SPEED * delta
	_cam.position.x = clampf(_cam.position.x, -ROOM + 0.5, ROOM - 0.5)
	_cam.position.z = clampf(_cam.position.z, -ROOM + 0.5, ROOM - 0.5)
	_cam.position.y = EYE_HEIGHT
	_update_prompt()

func _update_prompt() -> void:
	_nearest_id = &""
	var best := INTERACT_RANGE
	for prop in _props:
		var d := _cam.position.distance_to(prop["pos"])
		if d < best:
			best = d
			_nearest_id = prop["id"]
	if _nearest_id == &"":
		_prompt.text = ""
		return
	var def := _station_def(_nearest_id)
	if def != null and ProgressionManager.is_station_unlocked(def):
		_prompt.text = "[F]  %s" % def.display_name
	else:
		_prompt.text = "%s — %s" % [def.display_name if def != null else String(_nearest_id),
			HideoutManifest.requirement_text(def) if def != null else "locked"]

# --- Station panel overlay -------------------------------------------------
func _open(id: StringName) -> void:
	var def := _station_def(id)
	if def == null or not ProgressionManager.is_station_unlocked(def):
		return
	var packed := load(def.scene_path) as PackedScene
	if packed == null:
		return
	var panel := packed.instantiate()
	if panel is StationPanel:
		_active_panel = panel
		panel.closed.connect(_on_panel_closed)
		_ui_layer.add_child(panel)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_panel_closed() -> void:
	_active_panel = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _station_def(id: StringName) -> StationDef:
	if Content != null and Content.stations != null:
		return Content.stations.get_def(id) as StationDef
	return null
