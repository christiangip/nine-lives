## Bank test greybox (task 18 / phase-1-art): a first-person walkthrough that dresses
## a simple Bank floor plan with the curated prop prefabs so their scale reads in
## context (next to the 1.8 m player, real doorways, real furniture). Greybox shell
## (floor/walls) is built in code; the props are the real `game/prefabs/props/`
## scenes, so tuning a prefab updates this scene too. A dev tool — not a generated
## mission (that's task 11). F6 to walk it.
extends Node3D

const PLAYER := preload("res://game/scenes/player/PlayerController.tscn")
const ENV := preload("res://game/assets/default_env.tres")
const HUB_PATH := "res://game/scenes/art/gallery_hub.tscn"

const DOOR := preload("res://game/prefabs/props/door_interior.tscn")
const DESK := preload("res://game/prefabs/props/desk.tscn")
const CHAIR := preload("res://game/prefabs/props/chair.tscn")
const CABINET := preload("res://game/prefabs/props/cabinet.tscn")
const COMPUTER := preload("res://game/prefabs/props/computer.tscn")
const TELLER := preload("res://game/prefabs/props/teller_counter.tscn")
const SERVER := preload("res://game/prefabs/props/server_rack.tscn")
const SAFE := preload("res://game/prefabs/props/safe_body.tscn")
const VAULT := preload("res://game/prefabs/props/vault_door.tscn")
const CAMERA := preload("res://game/prefabs/props/security_camera.tscn")
const CRATE := preload("res://game/prefabs/props/crate.tscn")
const BARREL := preload("res://game/prefabs/props/barrel.tscn")

const CH_CASUAL := preload("res://game/assets/models/characters/Casual.gltf")
const CH_CASUAL2 := preload("res://game/assets/models/characters/Casual2.gltf")
const CH_FARMER := preload("res://game/assets/models/characters/Farmer.gltf")
const CH_KING := preload("res://game/assets/models/characters/King.gltf")
const CH_PUNK := preload("res://game/assets/models/characters/Punk.gltf")
const CH_SUIT := preload("res://game/assets/models/characters/Suit.gltf")
const CH_SUIT_NOGUN := preload("res://game/assets/models/characters/SuitNoGun.tscn")
const CH_SWAT := preload("res://game/assets/models/characters/Swat.gltf")
const CH_WORKER := preload("res://game/assets/models/characters/Worker.gltf")

const SHOWCASE_INTERVAL := 2.2

const FLOOR_X := 30.0
const FLOOR_Z := 22.0
const WALL_H := 3.0

var _show_ap: AnimationPlayer = null
var _show_label: Label3D = null
var _show_anims: PackedStringArray = PackedStringArray()
var _show_i: int = 0
var _show_t: float = 0.0

func _ready() -> void:
	_build_stage()
	_build_shell()
	_dress()
	_populate()
	_spawn_player()
	_build_overlay()

func _build_stage() -> void:
	var we := WorldEnvironment.new()
	we.environment = ENV
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

func _build_shell() -> void:
	_add_box(Vector3(FLOOR_X * 0.5, -0.2, FLOOR_Z * 0.5), Vector3(FLOOR_X, 0.4, FLOOR_Z), "concrete")
	# Perimeter walls, with a central entrance gap on the south (z = FLOOR_Z).
	_wall(Vector3(FLOOR_X * 0.5, WALL_H * 0.5, 0.0), Vector3(FLOOR_X, WALL_H, 0.3))
	_wall(Vector3(0.0, WALL_H * 0.5, FLOOR_Z * 0.5), Vector3(0.3, WALL_H, FLOOR_Z))
	_wall(Vector3(FLOOR_X, WALL_H * 0.5, FLOOR_Z * 0.5), Vector3(0.3, WALL_H, FLOOR_Z))
	_wall(Vector3(7.0, WALL_H * 0.5, FLOOR_Z), Vector3(14.0, WALL_H, 0.3))
	_wall(Vector3(23.0, WALL_H * 0.5, FLOOR_Z), Vector3(14.0, WALL_H, 0.3))
	# Interior partitions (stubs suggesting rooms, gaps left to walk through).
	_wall(Vector3(9.0, WALL_H * 0.5, 4.0), Vector3(0.3, WALL_H, 8.0))          # office east
	_wall(Vector3(4.5, WALL_H * 0.5, 10.0), Vector3(9.0, WALL_H, 0.3))         # server front
	# Vault entrance: a taller reinforced face (3.8 m) framing the oversized vault
	# door, with a snug door-width gap (1.86 m at z=4.5, door is 1.84 m) and a
	# lintel capping the top.
	var vh := 3.8
	_wall(Vector3(23.0, vh * 0.5, 1.785), Vector3(0.3, vh, 3.57))              # vault west, S of door
	_wall(Vector3(23.0, vh * 0.5, 6.715), Vector3(0.3, vh, 2.57))             # vault west, N of door
	_wall(Vector3(23.0, 3.67, 4.5), Vector3(0.3, 0.26, 1.86))                  # lintel over the door
	_wall(Vector3(26.5, vh * 0.5, 8.0), Vector3(7.0, vh, 0.3))                 # vault back

func _dress() -> void:
	# Entrance
	_place(DOOR, Vector3(15.0, 0.0, FLOOR_Z))
	# Lobby — teller line
	_sign("LOBBY", Vector3(15.0, 2.7, 14.0))
	for x in [10.0, 13.0, 16.0, 19.0]:
		_place(TELLER, Vector3(x, 0.0, 16.0))
	_place(CAMERA, Vector3(1.0, 2.6, 20.0), 45.0)
	_place(CAMERA, Vector3(29.0, 2.6, 20.0), -45.0)
	# Office
	_sign("OFFICE", Vector3(4.5, 2.7, 2.0))
	_place(DESK, Vector3(4.0, 0.0, 4.0))
	_place(CHAIR, Vector3(4.0, 0.0, 5.6), 180.0)
	_place(COMPUTER, Vector3(4.0, 0.78, 4.0))       # on the desk top
	_place(CABINET, Vector3(7.5, 0.0, 3.0))
	# Server room
	_sign("SERVER ROOM", Vector3(4.5, 2.7, 12.5))
	_place(SERVER, Vector3(3.0, 0.0, 14.0), 90.0)
	_place(SERVER, Vector3(5.0, 0.0, 14.0), 90.0)
	# Vault
	_sign("VAULT", Vector3(26.5, 2.7, 2.5))
	_place(VAULT, Vector3(23.0, 0.0, 4.5), 90.0)     # in the vault-west gap
	_place(SAFE, Vector3(27.0, 0.0, 4.0))
	# Loading dock
	_sign("LOADING DOCK", Vector3(26.0, 2.7, 12.5))
	_place(CRATE, Vector3(24.0, 0.0, 15.0))
	_place(CRATE, Vector3(26.0, 0.0, 15.0))
	_place(CRATE, Vector3(25.0, 0.75, 15.0))         # stacked
	_place(BARREL, Vector3(28.0, 0.0, 15.0))
	_place(BARREL, Vector3(28.0, 0.0, 17.0))

## Places all 8 character models in fitting roles, plus one animation showcase.
func _populate() -> void:
	# Lobby — customers and a loiterer
	_place_char(CH_CASUAL, Vector3(11.0, 0.0, 18.0), 0.0, "Idle")
	_place_char(CH_CASUAL2, Vector3(18.0, 0.0, 18.5), 0.0, "Idle")
	_place_char(CH_PUNK, Vector3(21.0, 0.0, 14.0), 200.0, "Idle")
	# Teller line — a suited clerk behind the counter (unarmed civilian variant)
	_place_char(CH_SUIT_NOGUN, Vector3(13.0, 0.0, 17.2), 180.0, "Idle")
	# Guard near the server room
	_place_char(CH_SWAT, Vector3(9.8, 0.0, 12.5), 90.0, "Idle")
	# Loading dock — worker + farmer
	_place_char(CH_WORKER, Vector3(25.0, 0.0, 17.5), 180.0, "Interact")
	_place_char(CH_FARMER, Vector3(27.5, 0.0, 19.0), 200.0, "Idle")
	# Vault — a VIP
	_place_char(CH_KING, Vector3(27.0, 0.0, 4.0), 270.0, "Idle")

	# Animation showcase — a central character cycling its whole clip set.
	var star := _place_char(CH_SUIT, Vector3(15.0, 0.0, 12.0), 180.0, "Idle")
	_show_ap = _find_anim_player(star)
	if _show_ap != null:
		_show_anims = _show_ap.get_animation_list()
		_show_label = Label3D.new()
		_show_label.position = Vector3(15.0, 2.3, 12.0)
		_show_label.pixel_size = 0.008
		_show_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_show_label.outline_size = 8
		_show_label.modulate = Color(0.5, 1.0, 0.7)
		add_child(_show_label)
		_update_showcase()

func _process(delta: float) -> void:
	if _show_ap == null or _show_anims.is_empty():
		return
	_show_t += delta
	if _show_t >= SHOWCASE_INTERVAL:
		_show_t = 0.0
		_show_i = (_show_i + 1) % _show_anims.size()
		_update_showcase()

func _update_showcase() -> void:
	var name := _show_anims[_show_i]
	_play_anim(_show_ap, name)
	if _show_label != null:
		_show_label.text = "ANIMATIONS: %s  (%d/%d)" % [name, _show_i + 1, _show_anims.size()]

func _place_char(scene: PackedScene, pos: Vector3, rot_y_deg: float, anim: String) -> Node3D:
	var inst := scene.instantiate()
	if inst is Node3D:
		(inst as Node3D).position = pos
		(inst as Node3D).rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	add_child(inst)
	_play_anim(_find_anim_player(inst), anim)
	return inst

func _find_anim_player(root: Node) -> AnimationPlayer:
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		return ap
	return null

func _play_anim(ap: AnimationPlayer, name: String) -> void:
	if ap == null:
		return
	if name == "" or not ap.has_animation(name):
		var list := ap.get_animation_list()
		if list.is_empty():
			return
		name = list[0]
	var anim := ap.get_animation(name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(name)

func _spawn_player() -> void:
	var player := PLAYER.instantiate()
	if player is Node3D:
		(player as Node3D).position = Vector3(15.0, 0.3, 19.0)
	add_child(player)

# --- helpers ---------------------------------------------------------------

func _place(scene: PackedScene, pos: Vector3, rot_y_deg: float = 0.0) -> void:
	var inst := scene.instantiate()
	if inst is Node3D:
		(inst as Node3D).position = pos
		(inst as Node3D).rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	add_child(inst)

func _wall(center: Vector3, size: Vector3) -> void:
	_add_box(center, size, "")

func _add_box(center: Vector3, size: Vector3, surface: String) -> void:
	var body := StaticBody3D.new()
	body.position = center
	if surface != "":
		body.set_meta("surface", surface)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _sign(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = Color(1.0, 0.85, 0.4)
	add_child(label)

## Back-to-hub key (Backspace) + controls hint. The player owns the mouse, so this
## uses a key, not a button.
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "Bank test — WASD move · mouse look · Shift sprint · C crouch · F interact · Backspace → galleries    |    green label = live animation showcase"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(16, -32)
	layer.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_BACKSPACE:
		get_tree().change_scene_to_file(HUB_PATH)
