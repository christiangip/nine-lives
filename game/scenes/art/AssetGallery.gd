## Asset-gallery greybox: scans a models folder and lays every model out on a
## labeled grid so art can be browsed and sized in-engine. Task 18 (phase-1-art).
## One gallery scene per asset folder; the grid regenerates from the folder at
## run time, so adding/removing a model needs no scene edit. At play time it also
## builds its own camera/light/environment so the per-folder scenes stay trivial.
## Not shipped content — a dev tool. See phase-1-art.md.
@tool
extends Node3D

## Folder of models to display (res:// path). Set per gallery scene.
@export_dir var models_dir: String = ""
## Grid columns before wrapping to the next row.
@export var columns: int = 8
## Minimum world spacing between grid cells, in metres. When auto_spacing is on,
## the real cell size is max(spacing, biggest model footprint × spacing_margin).
@export var spacing: float = 3.0
## Size the grid cell from the models' real bounding boxes so big buildings and
## small props both lay out cleanly. Off = fixed `spacing`.
@export var auto_spacing: bool = true
## Gap multiplier applied to the largest model footprint when auto_spacing is on.
@export var spacing_margin: float = 1.4
## Rebuild the grid in-editor when toggled (tool convenience).
@export var rebuild_in_editor: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_build()
## Play each model's idle animation at run time (for rigged models e.g. characters).
@export var play_animations: bool = false
## Show a human-scale reference capsule beside every row so sizing is legible.
@export var show_scale_ref: bool = true
## Reference height (m). Matches the player's standing collider (default_player.tres).
@export var human_height: float = 1.8

# Raw meshes (browse galleries) or built prop prefabs (the prefab gallery / shelf).
const MODEL_EXTS := [".glb", ".gltf", ".obj", ".tscn"]
const FLY_CAMERA := preload("res://game/scenes/art/GalleryFlyCamera.gd")
const HUB_PATH := "res://game/scenes/art/gallery_hub.tscn"

# Computed at build time from the placed models, reused for camera framing.
var _cell: float = 3.0
var _max_h: float = 2.0

func _ready() -> void:
	_build()
	if not Engine.is_editor_hint():
		_build_stage()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	if models_dir.is_empty():
		push_warning("AssetGallery: models_dir not set")
		return
	var paths := _scan(models_dir)
	if paths.is_empty():
		push_warning("AssetGallery: no models found in %s" % models_dir)
		return

	# Pass 1: spawn each model, measure it, and sit it centred with base on y=0.
	var holders: Array[Node3D] = []
	var sizes: Array[Vector3] = []
	var footprint := 0.0
	_max_h = human_height
	for path in paths:
		var holder := _spawn_model(path)
		if holder == null:
			continue
		add_child(holder)
		if Engine.is_editor_hint():
			holder.owner = get_tree().edited_scene_root
		elif play_animations:
			_play_idle(holder)
		var aabb := _aabb_of(holder)
		var inst := holder.get_child(0) if holder.get_child_count() > 0 else null
		if inst is Node3D:
			(inst as Node3D).position = -Vector3(
				aabb.position.x + aabb.size.x * 0.5,
				aabb.position.y,
				aabb.position.z + aabb.size.z * 0.5)
		holders.append(holder)
		sizes.append(aabb.size)
		footprint = maxf(footprint, maxf(aabb.size.x, aabb.size.z))
		_max_h = maxf(_max_h, aabb.size.y)

	# Pass 2: derive the cell size, then lay the grid out and label each model.
	_cell = maxf(spacing, footprint * spacing_margin) if auto_spacing else spacing
	for i in holders.size():
		var holder := holders[i]
		holder.position = Vector3(float(i % columns) * _cell, 0.0, float(i / columns) * _cell)
		_add_label(holder, holder.name, sizes[i].y + 0.5)

	if show_scale_ref:
		var rows: int = int(ceil(float(holders.size()) / float(columns)))
		for row in range(rows):
			_place_scale_ref(Vector3(-_cell, 0.0, float(row) * _cell))
	print("AssetGallery: placed %d models from %s (cell %.1f m)" % [holders.size(), models_dir, _cell])

func _scan(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("AssetGallery: cannot open %s" % dir_path)
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower := fname.to_lower()
			for ext in MODEL_EXTS:
				if lower.ends_with(ext):
					out.append(dir_path.path_join(fname))
					break
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out

## Instances one model under a named holder (the model is holder.child(0)). The
## caller adds it to the tree, measures it, and positions it. Null on load failure.
func _spawn_model(path: String) -> Node3D:
	var resource := load(path)
	var model: Node = null
	if resource is PackedScene:
		model = (resource as PackedScene).instantiate()
	elif resource is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = resource
		model = mi
	else:
		push_warning("AssetGallery: could not load %s" % path)
		return null
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	holder.add_child(model)
	return holder

## Merged local-space AABB (metres) of every MeshInstance3D under `root`.
func _aabb_of(root: Node3D) -> AABB:
	var acc := AABB()
	var seeded := false
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var rel: Transform3D = root.global_transform.affine_inverse() * m.global_transform
		var world: AABB = rel * m.mesh.get_aabb()
		if not seeded:
			acc = world
			seeded = true
		else:
			acc = acc.merge(world)
	return acc

## Loops the model's idle animation (falls back to its first clip) if it is rigged.
func _play_idle(root: Node) -> void:
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		var player := ap as AnimationPlayer
		var pick := ""
		for candidate in ["Idle", "Idle_Neutral"]:
			if player.has_animation(candidate):
				pick = candidate
				break
		if pick == "":
			var list := player.get_animation_list()
			if list.size() > 0:
				pick = list[0]
		if pick != "":
			var anim := player.get_animation(pick)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
			player.play(pick)
		return

func _add_label(holder: Node3D, text: String, y: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(0.0, y, 0.0)
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	holder.add_child(label)
	if Engine.is_editor_hint():
		label.owner = get_tree().edited_scene_root

## Translucent human-height capsule (base at y=0) as a scale gauge for each row.
func _place_scale_ref(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "ScaleRef"
	holder.position = pos
	add_child(holder)
	if Engine.is_editor_hint():
		holder.owner = get_tree().edited_scene_root

	var mesh := CapsuleMesh.new()
	mesh.height = human_height
	mesh.radius = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.55, 0.15, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0.0, human_height * 0.5, 0.0)
	holder.add_child(mi)

	var label := Label3D.new()
	label.text = "%.1f m" % human_height
	label.position = Vector3(0.0, human_height + 0.3, 0.0)
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	holder.add_child(label)

## Builds a camera/light/environment framing the whole grid (play-mode only).
func _build_stage() -> void:
	var count := get_child_count()
	var rows: int = int(ceil(float(count) / float(columns)))
	var grid_w := float(columns) * _cell
	var grid_d := float(rows) * _cell
	var center := Vector3(grid_w * 0.5, _max_h * 0.4, grid_d * 0.5)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	cam.set_script(FLY_CAMERA)
	cam.position = Vector3(center.x, maxf(grid_w, grid_d) * 0.45 + _max_h + 6.0, -_max_h - 10.0)
	add_child(cam)
	cam.look_at(center, Vector3.UP)
	cam.current = true

	_build_overlay()

## On-screen greybox UI: back-to-hub button + controls hint (play-mode only).
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var back := Button.new()
	back.text = "← Galleries"
	back.position = Vector2(16, 16)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(HUB_PATH))
	layer.add_child(back)

	var hint := Label.new()
	hint.text = "RMB look · WASD move · Q/E down/up · Shift sprint · wheel speed"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(16, -32)
	layer.add_child(hint)
