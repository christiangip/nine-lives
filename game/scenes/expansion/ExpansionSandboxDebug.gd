## Dev-only 3D Expansion Sandbox (task 19 / FR-19) — a first-person demo of the "content pack" loop in one
## room, using the Phase-1 art. It proves the whole expansion promise live:
##   • [P] (or the Pack Console prop) toggles the shipped "The Estate Job" pack — watch the registry counts
##     (archetypes / edges / gear / stations / sections) jump with ZERO code change (FR-19-1/4);
##   • [V] (or the Validator Terminal) runs ContentValidator over the base game + enabled packs and shows
##     the report — clean, or the exact violations (FR-19-3);
##   • [G] grants the pack's unlocks (as a save would hold them); toggling the pack OFF keeps them dormant
##     (preserve-but-dormant, FR-19-6) — the header's "dormant save ids" count reflects SaveReconcile;
##   • the Locksmith prop opens the pack's OWN station panel (StationDef + scene only, FR-19-7) when enabled.
## The sandbox isolates its toggles to user://packs_sandbox.json and restores clean state on exit, so it
## never perturbs the real game or the tests. NOT shipped. F6 to run; ← returns to the galleries.
## See docs/tasks/19_expansion_framework.md and docs/CONTENT_PACKS.md.
extends Node3D

const GALLERIES := "res://game/scenes/art/gallery_hub.tscn"
const FONT := preload("res://game/assets/fonts/KenneyFuture.ttf")
const PACK_ID := &"estate_job"
const SANDBOX_STATE := "user://packs_sandbox.json"

const EYE_HEIGHT := 1.6
const MOVE_SPEED := 4.0
const INTERACT_RANGE := 2.6
const ROOM := 9.0

# Interactive props — real Quaternius furniture. Each drives one facet of the expansion loop.
const PROPS := [
	{"kind": &"pack",      "pos": Vector3(-6, 0, -6), "mesh": "res://game/assets/models/props/furniture_quaternius/Desk.obj",      "label": "Pack Console  [F]"},
	{"kind": &"validate",  "pos": Vector3(6, 0, -6),  "mesh": "res://game/assets/models/props/furniture_quaternius/Bookcase.obj",  "label": "Validator Terminal  [F]"},
	{"kind": &"board",     "pos": Vector3(-6, 0, 6),  "mesh": "res://game/assets/models/props/furniture_quaternius/Table.obj",     "label": "Estate Job Board  [F]"},
	{"kind": &"locksmith", "pos": Vector3(6, 0, 6),   "mesh": "res://game/assets/models/props/furniture_quaternius/Table2.obj",    "label": "Locksmith  [F]"},
]

var _cam: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _props: Array = []
var _prompt: Label
var _header: Label
var _toast: Label
var _toast_time: float = 0.0
var _ui_layer: CanvasLayer
var _active_panel: StationPanel = null
var _overlay: Control = null
var _nearest: Dictionary = {}

func _ready() -> void:
	# Isolate this sandbox's pack toggles to its own state file (never the real user://packs.json), and
	# start from a clean, pack-disabled slate every run.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SANDBOX_STATE))
	PackManager.configure([PackManager.DEFAULT_PACK_ROOT], SANDBOX_STATE)
	Content.reload()

	# A Streak so RunManager.loadout()/edges exist and the Locksmith has The Take to spend.
	if RunManager != null:
		RunManager.start_new_streak()
		RunManager.take = maxi(RunManager.take, 2000)
	if ProgressionManager != null:
		ProgressionManager.legacy = maxi(ProgressionManager.legacy, 1000)

	_build_environment()
	_build_room()
	for p in PROPS:
		_build_prop(p)
	_build_dressing()
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
	var floor_mi := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(ROOM * 2.0, ROOM * 2.0)
	floor_mi.mesh = fm
	floor_mi.material_override = _mat(Color(0.18, 0.19, 0.22))
	add_child(floor_mi)
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

func _build_prop(p: Dictionary) -> void:
	var holder := Node3D.new()
	holder.position = p["pos"]
	add_child(holder)
	var mi := MeshInstance3D.new()
	var mesh_res := load(p["mesh"]) as Mesh
	mi.mesh = mesh_res if mesh_res != null else BoxMesh.new()
	holder.add_child(mi)
	var marker := _label3d(String(p["label"]), holder)
	_props.append({"kind": p["kind"], "pos": p["pos"], "marker": marker})

## Estate-flavoured dressing (real heist props + an NPC) — non-interactive, just sets the scene.
func _build_dressing() -> void:
	_spawn_at("res://game/assets/models/props/heist/safe.glb", Vector3(0, 0, -8.2))
	_spawn_at("res://game/assets/models/props/heist/display_case.glb", Vector3(-2.5, 0, -8.2))
	_spawn_at("res://game/assets/models/props/heist/painting.glb", Vector3(2.5, 0.6, -8.6))
	_spawn_at("res://game/assets/models/characters/Casual.gltf", Vector3(0, 0, 4.5))

func _spawn_at(path: String, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		var packed := load(path) as PackedScene
		if packed != null:
			holder.add_child(packed.instantiate())
			return
	var mi := MeshInstance3D.new()
	var mesh_res := load(path) as Mesh
	mi.mesh = mesh_res if mesh_res != null else BoxMesh.new()
	holder.add_child(mi)

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
	back.pressed.connect(_leave)
	_ui_layer.add_child(back)

	_header = Label.new()
	_header.add_theme_font_override("font", FONT)
	_header.add_theme_font_size_override("font_size", 20)
	_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_header.position = Vector2(120, 14)
	_ui_layer.add_child(_header)

	var help := Label.new()
	help.text = "WASD move · mouse look · [F] use prop\n[P] toggle 'The Estate Job' pack · [V] validate content · [G] grant pack unlocks (as a save) · [Esc] mouse"
	help.add_theme_font_override("font", FONT)
	help.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	help.position = Vector2(12, 46)
	_ui_layer.add_child(help)

	_toast = Label.new()
	_toast.add_theme_font_override("font", FONT)
	_toast.add_theme_font_size_override("font_size", 21)
	_toast.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-360, 92)
	_toast.custom_minimum_size = Vector2(720, 0)
	_ui_layer.add_child(_toast)

	_prompt = Label.new()
	_prompt.add_theme_font_override("font", FONT)
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-260, -120)
	_prompt.custom_minimum_size = Vector2(520, 0)
	_ui_layer.add_child(_prompt)
	_update_header()

func _update_header() -> void:
	var on := PackManager.is_enabled(PACK_ID)
	_header.text = "Pack 'The Estate Job': %s    |    archetypes %d · edges %d · gear %d · stations %d · sections %d    |    dormant save ids: %d" % [
		"ENABLED" if on else "disabled",
		Content.archetypes.size(), Content.edges.size(), Content.gear.size(),
		Content.stations.size(), Content.sections.size(), SaveReconcile.unknown_count()]

func _toast_msg(text: String) -> void:
	_toast.text = text
	_toast_time = 5.0

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
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and _overlay == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_key(keycode: int) -> void:
	match keycode:
		KEY_F:
			if not _nearest.is_empty():
				_use(_nearest)
		KEY_P:
			_toggle_pack()
		KEY_V:
			_run_validator()
		KEY_G:
			_grant_unlocks()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	_update_header()
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.text = ""
	if _active_panel != null or _overlay != null:
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
		&"pack":      _prompt.text = "[F]  %s 'The Estate Job' pack" % ("Disable" if PackManager.is_enabled(PACK_ID) else "Enable")
		&"validate":  _prompt.text = "[F]  Run the content validator"
		&"board":     _prompt.text = "[F]  Inspect the Estate archetype"
		&"locksmith": _prompt.text = "[F]  Open the Locksmith (pack station)"

# --- Prop / key actions ----------------------------------------------------
func _use(prop: Dictionary) -> void:
	match prop["kind"]:
		&"pack": _toggle_pack()
		&"validate": _run_validator()
		&"board": _show_board()
		&"locksmith": _open_locksmith()

func _toggle_pack() -> void:
	var before := _counts()
	var now_on := not PackManager.is_enabled(PACK_ID)
	PackManager.set_enabled(PACK_ID, now_on)   # persists (to the sandbox state) + Content.reload()
	var after := _counts()
	if now_on:
		_toast_msg("Enabled 'The Estate Job' — registries grew with NO code change:  archetypes +%d · edges +%d · gear +%d · stations +%d · sections +%d." % [
			after["archetypes"] - before["archetypes"], after["edges"] - before["edges"],
			after["gear"] - before["gear"], after["stations"] - before["stations"], after["sections"] - before["sections"]])
	else:
		_toast_msg("Disabled 'The Estate Job' — its content is gone from the registries. Any earned unlocks stay DORMANT (preserve-but-dormant) and revive on re-enable.")

func _grant_unlocks() -> void:
	if not PackManager.is_enabled(PACK_ID):
		_toast_msg("Enable the pack first [P], then grant its unlocks.")
		return
	if &"estate_snips" not in ProgressionManager.unlocked_gear:
		ProgressionManager.unlocked_gear.append(&"estate_snips")
	if &"locksmith" not in ProgressionManager.stations_unlocked:
		ProgressionManager.stations_unlocked.append(&"locksmith")
	if RunManager != null and &"rooftop_entry" not in RunManager.edges:
		RunManager.edges.append(&"rooftop_entry")
	_toast_msg("Granted pack unlocks (Diamond Snips gear, Locksmith station, Rooftop Entry edge) — as a save would hold them. Now toggle the pack OFF [P] and watch them go dormant, not lost.")

func _run_validator() -> void:
	var errors := ContentValidator.validate()
	var report: String
	if errors.is_empty():
		report = "✔ 0 violations.\n\nValidated the base game + every enabled pack: id present / unique / lowercase_snake, required fields, dangling cross-references, and economy value/cost/curve ranges.\n\n(The same sweep runs headlessly via tools/scripts/validate_content.sh — the CI content gate. test_content_validator proves it catches a missing field, a duplicate id, a dangling ref, and a bad id.)"
	else:
		report = "✘ %d violation(s):\n\n%s" % [errors.size(), "\n".join(errors)]
	_show_overlay("Content Validator (FR-19-3)", report, Color(0.6, 0.85, 1.0) if errors.is_empty() else Color(1.0, 0.6, 0.5))

func _show_board() -> void:
	var a := Content.archetypes.get_def(&"estate") as ArchetypeDef
	if a == null:
		_show_overlay("Estate Job Board", "The Estate Job pack is disabled — press [P] (or use the Pack Console) to enable it, then the 'estate' archetype and its sections/loot appear here, resolved live from the registries.", Color(0.9, 0.7, 0.5))
		return
	var lines: Array = ["Archetype: %s   (id: %s)" % [a.display_name, a.id], ""]
	lines.append("Sections (resolved from Content.sections):")
	for sid in (a.section_ids + a.setpiece_ids):
		var s := Content.sections.get_def(sid) as SectionDef
		lines.append("   • %s" % (s.display_name if s != null else String(sid) + "  (UNRESOLVED)"))
	lines.append("")
	lines.append("Loot (resolved from Content.loot):")
	for lid in a.loot_ids:
		var l := Content.loot.get_def(lid) as LootDef
		lines.append("   • %s" % (l.display_name if l != null else String(lid) + "  (UNRESOLVED)"))
	lines.append("")
	lines.append("Pack Edges present: %s" % _present([&"rooftop_entry", &"silent_landing", &"art_fence"], Content.edges))
	lines.append("Pack Gear present:  %s" % _present([&"estate_snips"], Content.gear))
	lines.append("Pack Station present: %s" % _present([&"locksmith"], Content.stations))
	lines.append("")
	lines.append("Every reference above resolved through the registries — no core code knows the word 'estate'.")
	_show_overlay("Estate Job Board — live content", "\n".join(lines), Color(0.7, 0.9, 0.7))

func _open_locksmith() -> void:
	if _active_panel != null:
		return
	var def := Content.stations.get_def(&"locksmith") as StationDef
	if def == null:
		_toast_msg("The Locksmith belongs to 'The Estate Job' — enable the pack [P] first.")
		return
	if not ProgressionManager.is_station_unlocked(def):
		_toast_msg("Locksmith is locked — press [G] to grant the pack's unlocks, then try again.")
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

# --- Overlay ---------------------------------------------------------------
func _show_overlay(title: String, body_text: String, tint: Color) -> void:
	if _overlay != null:
		_overlay.queue_free()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40; box.offset_top = 30; box.offset_right = -40; box.offset_bottom = -30
	box.add_theme_constant_override("separation", 10)
	_overlay.add_child(box)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", FONT)
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", tint)
	box.add_child(t)
	var body := Label.new()
	body.text = body_text
	body.add_theme_font_override("font", FONT)
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close_overlay)
	box.add_child(close)
	_ui_layer.add_child(_overlay)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- Helpers ---------------------------------------------------------------
func _counts() -> Dictionary:
	return {
		"archetypes": Content.archetypes.size(), "edges": Content.edges.size(),
		"gear": Content.gear.size(), "stations": Content.stations.size(), "sections": Content.sections.size(),
	}

func _present(ids: Array, reg) -> String:
	var out: Array = []
	for id in ids:
		out.append("%s ✔" % id if reg.has(id) else "%s ✘" % id)
	return ", ".join(out)

func _leave() -> void:
	# Restore the real pack state so returning to the galleries leaves a clean global.
	PackManager.reset()
	Content.reload()
	get_tree().change_scene_to_file(GALLERIES)
