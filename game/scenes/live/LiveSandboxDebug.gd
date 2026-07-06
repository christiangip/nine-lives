## Dev-only 3D Live Sandbox (task 20 / FR-20) — a first-person demo of the "living game" surface in one
## room, using the Phase-1 art. It proves the live-content promise interactively:
##   • [L] (or the Ledger) banks lifetime Legacy → a MILESTONE arc crosses its threshold and AUTO-UNLOCKS
##     content for free (station/gear/archetype), announced by a toast — the safehouse grows (FR-20-1);
##   • [T] (or the Calendar) advances the simulated date → the week's ROTATING event modifier changes and
##     the daily/weekly seed shifts (FR-20-3);
##   • [D] rolls today's DAILY Challenge and shows its date-derived seed + contract — identical for everyone
##     on the same day (FR-20-2);
##   • [P] (or the Content Drop) toggles the shipped "live_season" pack → its Casino archetype lands on the
##     generatable board with NO code change (FR-20-5), registry counts jump live;
##   • [S] completes + claims a SEASON goal → Legacy + a (dormant) title (FR-20-4);
##   • the Wire prop opens the real "The Wire" station panel (milestones / event / challenges / season).
## Isolates its pack toggles to user://packs_sandbox_live.json and restores clean state on exit. NOT shipped.
## F6 to run; ← returns to the galleries. See docs/tasks/20_progression_milestones.md and docs/LIVE_OPS.md.
extends Node3D

const GALLERIES := "res://game/scenes/art/gallery_hub.tscn"
const FONT := preload("res://game/assets/fonts/KenneyFuture.ttf")
const PACK_ID := &"live_season"
const SANDBOX_STATE := "user://packs_sandbox_live.json"

const EYE_HEIGHT := 1.6
const MOVE_SPEED := 4.0
const INTERACT_RANGE := 2.6
const ROOM := 9.0
const LEGACY_STEP := 1500   # lifetime Legacy banked per [L]

const PROPS := [
	{"kind": &"wire",     "pos": Vector3(-6, 0, -6), "mesh": "res://game/assets/models/props/furniture_quaternius/Table.obj",     "label": "The Wire  [F]"},
	{"kind": &"ledger",   "pos": Vector3(6, 0, -6),  "mesh": "res://game/assets/models/props/furniture_quaternius/Bookcase.obj",  "label": "Ledger — bank Legacy  [F]"},
	{"kind": &"calendar", "pos": Vector3(-6, 0, 6),  "mesh": "res://game/assets/models/props/furniture_quaternius/NightStand.obj","label": "Calendar — advance a week  [F]"},
	{"kind": &"pack",     "pos": Vector3(6, 0, 6),   "mesh": "res://game/assets/models/props/furniture_quaternius/Table2.obj",    "label": "Content Drop  [F]"},
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
var _base_now: int = 0
var _sim_days: int = 0

func _ready() -> void:
	# Isolate pack toggles to a sandbox state file (never the real user://packs.json); start pack-off.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SANDBOX_STATE))
	PackManager.configure([PackManager.DEFAULT_PACK_ROOT], SANDBOX_STATE)
	Content.reload()
	LiveChallenges.configure("user://challenge_results_sandbox.json")
	_base_now = LiveOps.now_unix()

	if RunManager != null:
		RunManager.start_new_streak()
		RunManager.take = maxi(RunManager.take, 2000)
	if ProgressionManager != null:
		ProgressionManager.legacy = maxi(ProgressionManager.legacy, 500)

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

func _build_dressing() -> void:
	_spawn_at("res://game/assets/models/props/heist/safe.glb", Vector3(0, 0, -8.2))
	_spawn_at("res://game/assets/models/props/heist/cash_stack.glb", Vector3(-2.5, 0.4, -8.2))
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
	_header.add_theme_font_size_override("font_size", 19)
	_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_header.position = Vector2(120, 14)
	_ui_layer.add_child(_header)

	var help := Label.new()
	help.text = "WASD move · mouse look · [F] use prop\n[L] bank Legacy (milestones) · [T] advance a week (event/seed) · [D] roll Daily · [P] toggle content pack · [S] claim season goal · [Esc] mouse"
	help.add_theme_font_override("font", FONT)
	help.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	help.position = Vector2(12, 44)
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

func _now() -> int:
	return _base_now + _sim_days * LiveOps.SECONDS_PER_DAY

func _update_header() -> void:
	var earned := int(ProgressionManager.stats.get(&"legacy_earned", 0)) if ProgressionManager != null else 0
	var mods := LiveOps.active_modifiers(LiveOps.config(), _now())
	var event := "calm week" if mods.is_empty() else _mod_name(mods[0])
	var maps := MissionBoard.generatable_archetypes(ProgressionManager.unlocked_archetypes).size() if ProgressionManager != null else 0
	_header.text = "Legacy %d (lifetime earned %d)  |  This week: %s  |  date +%dd  |  pack '%s': %s  |  maps on board: %d" % [
		ProgressionManager.legacy, earned, event, _sim_days,
		PACK_ID, "ON" if PackManager.is_enabled(PACK_ID) else "off", maps]

func _toast_msg(text: String) -> void:
	_toast.text = text
	_toast_time = 6.0

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
		KEY_L: _bank_legacy()
		KEY_T: _advance_week()
		KEY_D: _roll_daily()
		KEY_P: _toggle_pack()
		KEY_S: _claim_season()
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
		&"wire":     _prompt.text = "[F]  Open The Wire (live board)"
		&"ledger":   _prompt.text = "[F]  Bank +%d lifetime Legacy" % LEGACY_STEP
		&"calendar": _prompt.text = "[F]  Advance the date one week"
		&"pack":     _prompt.text = "[F]  %s the 'Casino Nights' content pack" % ("Disable" if PackManager.is_enabled(PACK_ID) else "Enable")

# --- Prop / key actions ----------------------------------------------------
func _use(prop: Dictionary) -> void:
	match prop["kind"]:
		&"wire": _open_wire()
		&"ledger": _bank_legacy()
		&"calendar": _advance_week()
		&"pack": _toggle_pack()

## Bank lifetime Legacy and evaluate milestones — the "earn over many runs → the safehouse grows" beat.
func _bank_legacy() -> void:
	if ProgressionManager == null:
		return
	ProgressionManager.stats[&"legacy_earned"] = int(ProgressionManager.stats.get(&"legacy_earned", 0)) + LEGACY_STEP
	var granted := ProgressionManager.check_milestones()
	var names: Array = []
	for mid in ProgressionManager.drain_milestone_toasts():
		var def := Content.milestones.get_def(mid) as MilestoneDef
		names.append(def.display_name if def != null else String(mid))
	if not granted.is_empty():
		_toast_msg("★ Milestone reached: %s — content auto-unlocked for FREE. Check the header's map count / open The Wire." % ", ".join(names))
	else:
		var next := _next_milestone_threshold()
		var earned := int(ProgressionManager.stats.get(&"legacy_earned", 0))
		_toast_msg("Banked lifetime Legacy (earned now %d). %s" % [earned, ("Next arc at %d." % next) if next > 0 else "All Legacy arcs reached."])

func _next_milestone_threshold() -> int:
	var earned := int(ProgressionManager.stats.get(&"legacy_earned", 0))
	var best := 0
	for res in Content.milestones.all():
		var m := res as MilestoneDef
		if m == null or m.id in ProgressionManager.milestones_reached or m.threshold_legacy <= earned:
			continue
		if best == 0 or m.threshold_legacy < best:
			best = m.threshold_legacy
	return best

func _advance_week() -> void:
	_sim_days += 7
	var mods := LiveOps.active_modifiers(LiveOps.config(), _now())
	var event := "a calm week (no global event)" if mods.is_empty() else "'%s' board-wide" % _mod_name(mods[0])
	_toast_msg("Date advanced to %s (+%d days). This week's event: %s. The daily/weekly seed shifts too — roll [D]." % [LiveOps.day_label(_now()), _sim_days, event])

func _roll_daily() -> void:
	var cfg := LiveOps.config()
	var ts := _now()
	var seed := LiveOps.daily_seed(ts)
	var cands := LiveOps.challenge_candidates(cfg, "daily")
	var c := LiveOps.challenge_contract(seed, cands, "daily", int(cfg.get("challenge_tier", 3)))
	var lines: Array = [
		"Date: %s   (simulated +%d days)" % [LiveOps.day_label(ts), _sim_days],
		"",
		"Daily seed:  %d" % seed,
		"Weekly seed: %d" % LiveOps.weekly_seed(ts),
		"→ the same seed for EVERY player on this UTC day (self-rolled stable hash, not Godot's hash()).",
		"",
		"Today's Daily Challenge:",
		"   %s" % (_headline(c) if c.archetype_id != &"" else "unavailable (no eligible map)"),
		"",
		"Launch it from The Wire — it runs standalone, so your endless Streak is never at risk.",
	]
	_show_overlay("Daily / Weekly Challenge — date→seed (FR-20-2)", "\n".join(lines), Color(0.7, 0.9, 1.0))

func _toggle_pack() -> void:
	var before := MissionBoard.generatable_archetypes(ProgressionManager.unlocked_archetypes).size()
	var now_on := not PackManager.is_enabled(PACK_ID)
	PackManager.set_enabled(PACK_ID, now_on)   # persists (sandbox state) + Content.reload()
	var after := MissionBoard.generatable_archetypes(ProgressionManager.unlocked_archetypes).size()
	if now_on:
		_toast_msg("Enabled 'Casino Nights' — the Casino archetype landed on the board (maps %d → %d), plus a milestone + event modifier, all as DATA. No code change." % [before, after])
	else:
		_toast_msg("Disabled 'Casino Nights' — its Casino/milestone/modifier are gone from the registries (maps %d → %d)." % [before, after])

func _claim_season() -> void:
	var cfg := LiveOps.config()
	var season := LiveOps.active_season(cfg, _now())
	if season.is_empty():
		_toast_msg("No active season right now.")
		return
	ProgressionManager.ensure_season(season)
	# For the demo, fast-forward every tracked lifetime metric so a goal completes, then claim the first.
	for key in [&"contracts_completed", &"loot_value_secured", &"special_delivered", &"legacy_earned"]:
		ProgressionManager.stats[key] = int(ProgressionManager.stats.get(key, 0)) + 100000
	for g in season.get("goals", []):
		if ProgressionManager.claim_season_reward(season, g):
			_toast_msg("Season goal '%s' claimed: +%d Legacy and the title '%s' (recorded for later)." % [
				String(g.get("display", "goal")), int(g.get("reward_legacy", 0)), String(g.get("reward_title", ""))])
			return
	_toast_msg("Every goal in '%s' is already claimed." % String(season.get("title", "the season")))

func _open_wire() -> void:
	if _active_panel != null:
		return
	var def := Content.stations.get_def(&"live_board") as StationDef
	if def == null:
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
func _mod_name(id) -> String:
	var def := Content.modifiers.get_def(id) as ModifierDef if Content != null and Content.modifiers != null else null
	return def.display_name if def != null else String(id)

func _headline(c: Contract) -> String:
	var arch := Content.archetypes.get_def(c.archetype_id) as ArchetypeDef
	var obj := Content.objectives.get_def(c.objective_id) as ObjectiveDef
	var an := arch.display_name if arch != null else String(c.archetype_id)
	var on := obj.display_name if obj != null else String(c.objective_id)
	return "%s · Tier %d · %s" % [an, c.tier, on]

func _leave() -> void:
	# Restore clean global state so returning to the galleries doesn't perturb the real game/tests.
	PackManager.reset()
	Content.reload()
	LiveChallenges.reset()
	get_tree().change_scene_to_file(GALLERIES)
