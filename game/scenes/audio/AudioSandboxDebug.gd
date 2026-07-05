extends Node3D
## AudioSandboxDebug — the task-17 demo/greybox (F6). A first-person room built from REAL imported
## assets (Quaternius furniture + a heist safe + a patrolling Swat guard) that exercises the whole audio
## layer: cycle the detection state to hear the music crossfade Calm→Tense→Combat, bump Pursuit, fire each
## diegetic SFX cue, walk near the patrolling guard to locate it by 3D footsteps, toggle Subtitles (the
## real caption path), and mute/unmute a bus. Uses the same _spawn_model / _unhandled_input pattern as
## EconomyGreyboxDebug / UISandboxDebug. See docs/tasks/17_audio.md.

const EYE_HEIGHT := 1.6
const ROOM := 9.0

const DESK := "res://game/assets/models/props/furniture_quaternius/Desk.obj"
const TABLE := "res://game/assets/models/props/furniture_quaternius/Table.obj"
const BOOKCASE := "res://game/assets/models/props/furniture_quaternius/Bookcase.obj"
const SAFE := "res://game/assets/models/props/heist/safe.glb"
const GUARD := "res://game/assets/models/characters/Swat.gltf"

var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _threat: Node3D           ## dummy node whose id keys the detection music aggregator
var _patroller: Node3D        ## the walking guard model (3D footsteps)
var _patrol_t := 0.0
var _step_accum := 0.0
var _det := 0
var _phase := 0
var _header: Label
var _caption: Label

func _ready() -> void:
	_build_environment()
	_build_room()
	_spawn_model(DESK, Vector3(-3, 0, -4), 1.0)
	_spawn_model(TABLE, Vector3(3, 0, -4), 1.0)
	_spawn_model(BOOKCASE, Vector3(-5, 0, 0), 1.0)
	_spawn_model(SAFE, Vector3(5, 0, 0), 1.0)
	_patroller = _spawn_model(GUARD, Vector3(0, 0, -6), 1.0)
	_threat = Node3D.new()
	add_child(_threat)
	_build_hud()
	if AudioManager != null and not AudioManager.caption_requested.is_connected(_on_caption):
		AudioManager.caption_requested.connect(_on_caption)
	_set_mouse(true)

# --- World -------------------------------------------------------------------
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.10, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, EYE_HEIGHT, 4)
	_cam.current = true
	add_child(_cam)

func _build_room() -> void:
	var floor := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(ROOM * 2.0, ROOM * 2.0)
	floor.mesh = fm
	floor.material_override = _mat(Color(0.18, 0.19, 0.22))
	add_child(floor)
	for side in 4:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(ROOM * 2.0, 3.0, 0.2)
		wall.mesh = wm
		wall.material_override = _mat(Color(0.14, 0.15, 0.18))
		match side:
			0: wall.position = Vector3(0, 1.5, -ROOM)
			1: wall.position = Vector3(0, 1.5, ROOM)
			2:
				wall.position = Vector3(-ROOM, 1.5, 0); wall.rotation.y = PI / 2
			3:
				wall.position = Vector3(ROOM, 1.5, 0); wall.rotation.y = PI / 2
		add_child(wall)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

## .glb/.gltf → PackedScene.instantiate(); .obj → MeshInstance3D(Mesh). Returns the root Node3D.
func _spawn_model(path: String, pos: Vector3, scale: float) -> Node3D:
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
	root.scale = Vector3.ONE * scale
	add_child(root)
	return root

# --- Per-frame: patrol + footsteps + readout ---------------------------------
func _process(delta: float) -> void:
	_move_player(delta)
	_patrol(delta)
	_refresh_header()

func _patrol(delta: float) -> void:
	if _patroller == null:
		return
	_patrol_t += delta * 0.6
	var x := sin(_patrol_t) * 6.0
	var prev := _patroller.global_position
	_patroller.global_position = Vector3(x, 0, -6)
	# 3D footsteps as it walks (locatable by ear, FR-17-3).
	if AudioManager != null and prev.distance_to(_patroller.global_position) > 0.001:
		_step_accum += delta
		if _step_accum >= 0.5:
			_step_accum = 0.0
			AudioManager.play_footstep(_patroller.global_position, "demo_guard")

func _move_player(delta: float) -> void:
	if _cam == null:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += _cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= _cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += _cam.global_transform.basis.x
	dir.y = 0.0
	if dir.length() > 0.0:
		_cam.global_position += dir.normalized() * 5.0 * delta

# --- HUD ---------------------------------------------------------------------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_header = Label.new()
	_header.position = Vector2(16, 14)
	_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	layer.add_child(_header)
	var help := Label.new()
	help.position = Vector2(16, 60)
	help.add_theme_color_override("font_color", Color(0.78, 0.83, 0.92))
	help.text = "WASD + mouse look · [J] cycle detection (music) · [P] pursuit+ · [K] reset calm\n" + \
		"[1] spotted · [2] alarm · [3] takedown · [4] lockpick snap · [5] hack done · [6] loot secured · [7] drill\n" + \
		"[U] toggle subtitles · [B] mute/unmute Music · [Esc] free mouse"
	layer.add_child(help)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.position = Vector2(-200, -60)
	_caption.custom_minimum_size = Vector2(400, 0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	layer.add_child(_caption)

func _refresh_header() -> void:
	if _header == null or AudioManager == null:
		return
	var names := ["CALM", "TENSE", "COMBAT", "RESOLVE"]
	var subs := Services.settings() != null and bool(Services.settings().get_value("audio", "subtitles"))
	_header.text = "AUDIO SANDBOX — music: %s   detection: %d   pursuit: %d   subtitles: %s   last SFX: %s" % [
		names[clampi(AudioManager.music_state, 0, 3)], _det, _phase,
		"ON" if subs else "off", String(AudioManager._last_sfx_id)]

# --- Dev keys ----------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.4, 1.4)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_set_mouse(false)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key((event as InputEventKey).keycode)

func _on_key(code: int) -> void:
	match code:
		KEY_J:
			_det = (_det + 1) % 5
			EventBus.detection_changed.emit(_threat.get_instance_id(), _det, float(_det) / 4.0)
		KEY_P:
			_phase = clampi(_phase + 1, 0, 5)
			EventBus.pursuit_phase_changed.emit(_phase)
		KEY_K:
			_det = 0
			_phase = 0
			EventBus.game_state_changed.emit(0, 0)
		KEY_1: AudioManager.play_sfx(&"spotted")
		KEY_2: AudioManager.play_sfx(&"alarm_loud", _cam.global_position)
		KEY_3: AudioManager.play_sfx(&"takedown", _cam.global_position)
		KEY_4: AudioManager.play_sfx(&"lockpick_snap", _cam.global_position)
		KEY_5: AudioManager.play_sfx(&"hack_done", _cam.global_position)
		KEY_6: AudioManager.play_sfx(&"loot_secured")
		KEY_7: AudioManager.play_sfx(&"drill_run", _cam.global_position)
		KEY_U: _toggle_subtitles()
		KEY_B: _toggle_music_mute()
		KEY_ESCAPE: _set_mouse(true)

func _toggle_subtitles() -> void:
	var s := Services.settings()
	if s != null:
		s.set_value("audio", "subtitles", not bool(s.get_value("audio", "subtitles")))

func _toggle_music_mute() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, not AudioServer.is_bus_mute(idx))

func _on_caption(text: String) -> void:
	if _caption == null:
		return
	if Services.settings() != null and bool(Services.settings().get_value("audio", "subtitles")):
		_caption.text = text
		var t := get_tree().create_timer(3.0)
		t.timeout.connect(func() -> void:
			if _caption != null:
				_caption.text = "")

func _set_mouse(free: bool) -> void:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED
