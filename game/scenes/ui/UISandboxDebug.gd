extends Node3D
## UISandboxDebug — the task-15 demo/greybox (F6). A furnished first-person room built from REAL imported
## assets (Quaternius furniture + a heist safe + Swat/Casual characters) with the REAL task-15 HUD mounted
## over it and a REAL PlayerController, so every HUD readout binds to live state. Dev keys drive every
## surface: cycle the compass-eye off a positioned "threat" character, climb Pursuit/Heat, take damage
## (loud block), fill carry, spawn a noise ring, and open the Main Menu / 10-slot popup / Options / Results.
## Uses the same .glb→instantiate / .obj→MeshInstance pattern as EconomyGreyboxDebug. See docs/tasks/15_ui_hud_menus.md.

const PLAYER_SCENE := preload("res://game/scenes/player/PlayerController.tscn")
const HUD_SCENE := preload("res://game/scenes/ui/hud/HUD.tscn")

const SAFE := "res://game/assets/models/props/heist/safe.glb"
const TABLE := "res://game/assets/models/props/furniture_quaternius/Table.obj"
const DESK := "res://game/assets/models/props/furniture_quaternius/Desk.obj"
const BOOKCASE := "res://game/assets/models/props/furniture_quaternius/Bookcase.obj"
const THREAT := "res://game/assets/models/characters/Swat.gltf"
const CASUAL := "res://game/assets/models/characters/Casual.gltf"

## Equipped so the loud-block ammo readout has a weapon (research-gated → dev-unlock first).
const _DEV_GEAR: Array[StringName] = [&"suppressed_pistol", &"emp"]

## A minimal stand-in for MissionController so the HUD's objective + secured/remaining readout has a source.
class MockMission extends Node:
	var secured_value: int = 1500
	var contract = null            ## null → HUD shows the generic objective label
	func loot_total_value() -> int:
		return 6000

var _threat: Node3D
var _det_state: int = 0
var _phase: int = 0
var _ui_layer: CanvasLayer
var _overlay: Control = null

func _ready() -> void:
	_build_room()
	_spawn_player()
	_equip_dev_loadout()
	add_child(HUD_SCENE.instantiate())
	var m := MockMission.new()
	m.add_to_group(&"mission_root")
	add_child(m)
	# NoiseRingSpawner so [N] shows an on-world ring.
	var rings := NoiseRingSpawner.new()
	add_child(rings)
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 30
	add_child(_ui_layer)
	_build_help()

# --- World ---------------------------------------------------------------------
func _build_room() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.12, 0.16)
	e.ambient_light_color = Color(0.5, 0.55, 0.62)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var floor_body := StaticBody3D.new()
	floor_body.set_meta("surface", "concrete")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 0.5, 24)
	shape.shape = box
	floor_body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(24, 0.5, 24)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.19, 0.22)
	mi.material_override = mat
	floor_body.add_child(mi)
	floor_body.position = Vector3(0, -0.25, 0)
	add_child(floor_body)

	_spawn_model(DESK, Vector3(-3, 0, -4), 1.0)
	_spawn_model(TABLE, Vector3(3, 0, -4), 1.0)
	_spawn_model(BOOKCASE, Vector3(-5, 0, 0), 1.0)
	_spawn_model(SAFE, Vector3(5, 0, 0), 1.0)
	_spawn_model(CASUAL, Vector3(-2, 0, 2), 1.0)
	# The "threat" the compass-eye points at (a positioned character we drive detection from).
	_threat = _spawn_model(THREAT, Vector3(6, 0, -6), 1.0)

## .glb/.gltf → instance the PackedScene; .obj → wrap the Mesh in a MeshInstance3D. Returns the root Node3D.
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
		root = Node3D.new()   # never crash if an asset is missing
	root.position = pos
	root.scale = Vector3.ONE * scale
	add_child(root)
	return root

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.2, 3)
	add_child(player)

func _equip_dev_loadout() -> void:
	var lo := RunManager.loadout()
	for gid in _DEV_GEAR:
		if gid not in ProgressionManager.unlocked_gear:
			ProgressionManager.unlocked_gear.append(gid)
		var gd := Content.gear.get_def(gid) as GearDef
		if gd != null:
			lo.equip(gd)
	# Rebuild the player's weapons now the loadout is populated.
	var p := _player()
	if p != null and p.has_method("active_weapon"):
		var combat := p.get_node_or_null("Head/Hands")
		if combat != null and combat.get_child_count() > 0 and combat.get_child(0).has_method("rebuild_weapons"):
			combat.get_child(0).rebuild_weapons()

# --- Dev keys ------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Dev keys chosen to avoid the player's bindings (WASD/Shift/C/Z/Space/Q/E/F/V/X/G/T/R/1/4/Esc).
	match (event as InputEventKey).keycode:
		KEY_J: _cycle_detection()
		KEY_B: _add_carry()
		KEY_H: _go_loud()
		KEY_P: _bump_pursuit()
		KEY_N: _spawn_noise()
		KEY_K: _take_damage()
		KEY_O: _open(OptionsMenu.open(_ui_layer))
		KEY_U: _open(SlotPopup.open(_ui_layer, SlotPopup.Mode.NEW))
		KEY_I: _open(SlotPopup.open(_ui_layer, SlotPopup.Mode.LOAD))
		KEY_Y: _preview_results(false)
		KEY_L: _preview_results(true)
		KEY_M: GameManager.goto_main_menu()
		KEY_TAB: _toggle_mouse()

func _cycle_detection() -> void:
	_det_state = (_det_state + 1) % 5
	var fill := float(_det_state) / 4.0
	if _threat != null:
		EventBus.detection_changed.emit(_threat.get_instance_id(), _det_state, fill)

func _add_carry() -> void:
	var p := _player()
	if p == null or p.get("inventory") == null:
		return
	var loot := LootDef.new()
	loot.id = &"demo_bar"
	loot.display_name = "Gold Bar"
	loot.value = 900
	loot.weight = 6.0
	loot.volume = 3.0
	p.inventory.add_loot(loot)

func _go_loud() -> void:
	var p := _player()
	var pos: Vector3 = p.global_position if p != null else global_position
	EventBus.alarm_tripped.emit("loud", pos)   # RunManager: committed + Heat
	_bump_pursuit()

func _bump_pursuit() -> void:
	_phase = clampi(_phase + 1, 0, 5)
	EventBus.pursuit_phase_changed.emit(_phase)

func _spawn_noise() -> void:
	var p := _player()
	var pos: Vector3 = p.global_position if p != null else global_position
	EventBus.noise_emitted.emit(pos, 6.0, "footstep")

func _take_damage() -> void:
	var p := _player()
	if p != null and p.has_method("apply_damage"):
		p.apply_damage(18.0)

func _preview_results(is_catch: bool) -> void:
	GameManager.pending_results = {"outcome": "caught" if is_catch else "success",
		"secured_value": 3200, "legacy_awarded": 4800, "no_kill": true, "full_clear": true}
	var packed := load("res://game/scenes/mission/MissionResults.tscn") as PackedScene
	if packed != null:
		_open(packed.instantiate())

# --- Overlay + mouse plumbing --------------------------------------------------
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

# --- Help --------------------------------------------------------------------
func _build_help() -> void:
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.position = Vector2(-360, 8)
	lbl.custom_minimum_size = Vector2(720, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.text = "[UI SANDBOX — task 15]  WASD/mouse move · Esc pause\n" + \
		"J detection · B add loot · H go loud · P pursuit+ · K take damage · N noise ring\n" + \
		"O Options · U New-slot popup · I Load-slot popup · Y results · L caught-results · M Main Menu · Tab free mouse"
	_ui_layer.add_child(lbl)
