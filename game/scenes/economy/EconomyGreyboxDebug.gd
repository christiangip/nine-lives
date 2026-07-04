## Dev-only 3D Economy Sandbox (task 14 / FR-14) — a first-person demo of the whole three-currency
## loop in one room, using the Phase-1 art. Walk (WASD + mouselook) up to a prop and press [F]:
##   • the Vault (heist safe model) SECURES a cash haul → watch Notoriety take the FULL value but The
##     Take take only its launderable fraction (FR-14-2, the split made visible);
##   • the five spend-station props (real Quaternius furniture) open the SAME station panels the hub
##     uses — spend The Take at the Fence/Planning Table, spend Legacy at Training/Workshop/Legacy Board;
##   • the Analyst desk opens the balancing-harness readout (EconomySimulator: Streak-length
##     distribution + Legacy/run, clean-vs-loud — FR-14-6).
## Dev keys drive the run-flow: [H] silent alarm (Heat↑), [C] complete a clean contract (objective NP ×
## performance), [K] get Caught (Notoriety→Legacy conversion + reset). The header tracks all three
## currencies + Heat + Streak live. NOT shipped — the real hub is Hideout.tscn; the real HUD is task 15.
## F6 to run; ← returns to the galleries. See docs/tasks/14_economy_balancing.md.
extends Node3D

const GALLERIES := "res://game/scenes/art/gallery_hub.tscn"
const FONT := preload("res://game/assets/fonts/KenneyFuture.ttf")
const VAULT_MODEL := "res://game/assets/models/props/heist/safe.glb"
const CASH_MODEL := "res://game/assets/models/props/heist/cash_stack.glb"

const EYE_HEIGHT := 1.6
const MOVE_SPEED := 4.0
const INTERACT_RANGE := 2.6
const ROOM := 9.0

# Economy spend stations — real Quaternius furniture, opening the real station panels.
const STATIONS := [
	{"id": &"fence",          "pos": Vector3(-6, 0, -6), "mesh": "res://game/assets/models/props/furniture_quaternius/NightStand.obj", "label": "Fence Terminal"},
	{"id": &"planning_table", "pos": Vector3(0, 0, -7),  "mesh": "res://game/assets/models/props/furniture_quaternius/Table.obj",      "label": "Planning Table"},
	{"id": &"training",       "pos": Vector3(6, 0, -6),  "mesh": "res://game/assets/models/props/furniture_quaternius/Stool.obj",      "label": "Training Area"},
	{"id": &"workshop",       "pos": Vector3(7, 0, 1),   "mesh": "res://game/assets/models/props/furniture_quaternius/Table2.obj",     "label": "Workshop"},
	{"id": &"legacy_board",   "pos": Vector3(6, 0, 6),   "mesh": "res://game/assets/models/props/furniture_quaternius/Bookcase.obj",   "label": "Legacy Board"},
]

var _cam: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _props: Array = []          # { kind, id, pos, marker, mesh }
var _prompt: Label
var _header: Label
var _toast: Label
var _toast_time: float = 0.0
var _ui_layer: CanvasLayer
var _active_panel: StationPanel = null
var _balance_panel: Control = null
var _nearest: Dictionary = {}

func _ready() -> void:
	# Seed a fresh Streak with some starter currency so both earning AND spending are demoable.
	if RunManager != null:
		RunManager.start_new_streak()
		RunManager.take = maxi(RunManager.take, 2000)
	if ProgressionManager != null:
		ProgressionManager.legacy = maxi(ProgressionManager.legacy, 1500)
		# Open the economy stations so their panels are reachable in the demo.
		for s in STATIONS:
			if s["id"] not in ProgressionManager.stations_unlocked:
				ProgressionManager.stations_unlocked.append(s["id"])

	_build_environment()
	_build_room()
	for s in STATIONS:
		_build_station(s)
	_build_special_prop(&"loot", "Vault  —  Secure Cash", Vector3(-7, 0, 1), VAULT_MODEL, Color(0.95, 0.8, 0.35))
	_build_special_prop(&"balance", "Analyst  —  Balance Report", Vector3(-6, 0, 6),
		"res://game/assets/models/props/furniture_quaternius/Desk.obj", Color(0.55, 0.8, 1.0))
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

## A spend-station prop (Quaternius .obj Mesh). Tinted red/green by unlock state like the hideout demo.
func _build_station(s: Dictionary) -> void:
	var holder := Node3D.new()
	holder.position = s["pos"]
	add_child(holder)
	var mi := MeshInstance3D.new()
	var mesh_res := load(s["mesh"]) as Mesh
	if mesh_res != null:
		mi.mesh = mesh_res
	else:
		mi.mesh = BoxMesh.new()
	holder.add_child(mi)
	var marker := _label3d(String(s["label"]), holder)
	_props.append({"kind": &"station", "id": s["id"], "pos": s["pos"], "marker": marker, "mesh": mi})
	_refresh_lock_state(_props.back())

## A special prop (loot Vault / Analyst). glb → instanced scene, .obj → Mesh. Always usable (no lock).
func _build_special_prop(kind: StringName, label: String, pos: Vector3, model_path: String, tint: Color) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	_spawn_model(model_path, holder)
	var marker := _label3d(label, holder)
	marker.modulate = tint
	_props.append({"kind": kind, "id": kind, "pos": pos, "marker": marker, "mesh": null})

## Instance a model as a child: .glb/.gltf → PackedScene.instantiate(), .obj → MeshInstance3D(Mesh).
func _spawn_model(path: String, parent: Node3D) -> void:
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		var packed := load(path) as PackedScene
		if packed != null:
			parent.add_child(packed.instantiate())
			return
	var mi := MeshInstance3D.new()
	var mesh_res := load(path) as Mesh
	mi.mesh = mesh_res if mesh_res != null else BoxMesh.new()
	parent.add_child(mi)

func _label3d(text: String, parent: Node3D) -> Label3D:
	var marker := Label3D.new()
	marker.text = text
	marker.font = FONT
	marker.font_size = 48
	marker.pixel_size = 0.004
	marker.position = Vector3(0, 2.0, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(marker)
	return marker

func _refresh_lock_state(prop: Dictionary) -> void:
	if prop["kind"] != &"station":
		return
	var def := _station_def(prop["id"])
	var unlocked := def != null and ProgressionManager.is_station_unlocked(def)
	var col := Color(0.5, 0.9, 0.6) if unlocked else Color(0.9, 0.45, 0.4)
	(prop["marker"] as Label3D).modulate = col
	if prop["mesh"] != null:
		(prop["mesh"] as MeshInstance3D).material_override = null if unlocked else _mat(col.darkened(0.4))

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

	_header = Label.new()
	_header.add_theme_font_override("font", FONT)
	_header.add_theme_font_size_override("font_size", 22)
	_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_header.position = Vector2(120, 14)
	_ui_layer.add_child(_header)

	var help := Label.new()
	help.text = "WASD move · mouse look · [F] use prop\n[H] silent alarm (Heat↑) · [C] complete clean contract · [K] get Caught → convert · [B] balance report · [Esc] mouse"
	help.add_theme_font_override("font", FONT)
	help.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	help.position = Vector2(12, 48)
	_ui_layer.add_child(help)

	_toast = Label.new()
	_toast.add_theme_font_override("font", FONT)
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-320, 96)
	_toast.custom_minimum_size = Vector2(640, 0)
	_ui_layer.add_child(_toast)

	_prompt = Label.new()
	_prompt.add_theme_font_override("font", FONT)
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-200, -120)
	_prompt.custom_minimum_size = Vector2(400, 0)
	_ui_layer.add_child(_prompt)
	_update_header()

func _update_header() -> void:
	var econ := EconomyConfigDef.resolve()
	_header.text = "Legacy %d    Take $%d    Notoriety %d    Heat %d%%    Streak %d contracts    (Take = %d%% of cash)" % [
		ProgressionManager.legacy, RunManager.take, RunManager.notoriety,
		int(round(RunManager.heat * 100.0)), RunManager.streak_length, int(round(econ.take_fraction * 100.0))]

func _toast_msg(text: String) -> void:
	_toast.text = text
	_toast_time = 4.0

# --- Input / movement ------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _active_panel != null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.4, 1.4)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.keycode)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and _balance_panel == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_key(keycode: int) -> void:
	match keycode:
		KEY_F:
			if not _nearest.is_empty():
				_use(_nearest)
		KEY_H:
			# A silent alarm — the stealth-appropriate way to raise Heat (commits the Streak, GDD §5.3).
			EventBus.alarm_tripped.emit("silent", _cam.position)
			_toast_msg("Silent alarm tripped — Heat is now %d%%. A hotter Streak converts more Legacy but dies faster." % int(round(RunManager.heat * 100.0)))
			_update_header()
		KEY_C:
			_complete_contract()
		KEY_K:
			_get_caught()
		KEY_B:
			_toggle_balance()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	for prop in _props:
		_refresh_lock_state(prop)
	_update_header()
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.text = ""
	if _active_panel != null or _balance_panel != null:
		return
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
	_nearest = {}
	var best := INTERACT_RANGE
	for prop in _props:
		var d := _cam.position.distance_to(prop["pos"])
		if d < best:
			best = d
			_nearest = prop
	if _nearest.is_empty():
		_prompt.text = ""
		return
	match _nearest["kind"]:
		&"loot":
			_prompt.text = "[F]  Crack the vault & secure a cash haul"
		&"balance":
			_prompt.text = "[F]  Run the balancing harness"
		_:
			var def := _station_def(_nearest["id"])
			if def != null and ProgressionManager.is_station_unlocked(def):
				_prompt.text = "[F]  %s" % def.display_name
			else:
				_prompt.text = "%s — locked" % (def.display_name if def != null else String(_nearest["id"]))

# --- Prop actions ----------------------------------------------------------
func _use(prop: Dictionary) -> void:
	match prop["kind"]:
		&"loot": _secure_loot()
		&"balance": _toggle_balance()
		&"station": _open_station(prop["id"])

## Secure a cash haul at the Vault: Notoriety banks the FULL street value, The Take banks only the
## launderable fraction (FR-14-2). The split is the whole point of the demo.
func _secure_loot() -> void:
	var loot := Content.loot.get_def(&"cash_bundle") as LootDef
	var value := loot.value if loot != null else 2500
	var before_take := RunManager.take
	DropPoint.bank(value, "vault_cash")
	var take_gain := RunManager.take - before_take
	_toast_msg("Secured $%d loot  →  +%d Notoriety (full)   +%d Take (%d%% cut)" % [
		value, value, take_gain, int(round(100.0 * float(take_gain) / float(maxi(value, 1))))])

## Complete a clean contract: objective Notoriety × the performance stack (stealth/no-alarm bonuses if
## this mission stayed clean). The single biggest earner on a stealth run.
func _complete_contract() -> void:
	var before := RunManager.notoriety
	EventBus.mission_completed.emit({"no_kill": true, "full_clear": true, "elapsed_seconds": 120.0})
	var gain := RunManager.notoriety - before
	_toast_msg("Contract complete  →  +%d Notoriety (objective × performance). Play clean to stack the bonuses." % gain)

## Get Caught: convert accrued Notoriety × Heat-multiplier → permanent Legacy, then reset the Streak.
func _get_caught() -> void:
	var noto := RunManager.notoriety
	var awarded := RunManager.end_streak("caught")
	_toast_msg("CAUGHT.  %d Notoriety × Heat → %d Legacy banked (permanent). The Take was lost; the Streak resets." % [noto, awarded])
	_update_header()

# --- Station panel overlay -------------------------------------------------
func _open_station(id: StringName) -> void:
	if _active_panel != null:
		return
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

# --- Balancing-harness readout (FR-14-6) -----------------------------------
func _toggle_balance() -> void:
	if _balance_panel != null:
		_balance_panel.queue_free()
		_balance_panel = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if _active_panel != null:
		return
	var econ := EconomyConfigDef.resolve()
	var cmp := EconomySimulator.compare(econ, 3000, 20260704)
	_balance_panel = _build_balance_overlay(EconomySimulator.format_compare(cmp), cmp)
	_ui_layer.add_child(_balance_panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_balance_overlay(report: String, cmp: Dictionary) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40; box.offset_top = 30; box.offset_right = -40; box.offset_bottom = -30
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)

	var title := Label.new()
	title.text = "Balancing Harness — Monte-Carlo run simulation (FR-14-6)"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	box.add_child(title)

	var body := Label.new()
	body.text = report + "\n\n" + _histogram_text(cmp)
	body.add_theme_font_override("font", FONT)
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	box.add_child(body)

	var close := Button.new()
	close.text = "Close  [B]"
	close.pressed.connect(_toggle_balance)
	box.add_child(close)
	return root

## An ASCII histogram of the clean cohort's Streak-length distribution — "a Streak averages several missions".
func _histogram_text(cmp: Dictionary) -> String:
	var clean: Dictionary = cmp["clean"]
	var max_len := int(clean.get("max_streak_len", 0))
	var bins := EconomySimulator.histogram(clean.get("lengths", []), max_len)
	var peak := 1
	for b in bins:
		peak = maxi(peak, int(b))
	var lines: Array = ["Clean-run Streak-length distribution (each █ ≈ %d runs):" % maxi(peak / 30, 1)]
	for i in bins.size():
		var bars := int(round(30.0 * float(bins[i]) / float(peak)))
		lines.append("  %2d contracts | %s %d" % [i, "█".repeat(bars), int(bins[i])])
	return "\n".join(lines)

# --- Helpers ---------------------------------------------------------------
func _station_def(id: StringName) -> StationDef:
	if Content != null and Content.stations != null:
		return Content.stations.get_def(id) as StationDef
	return null
