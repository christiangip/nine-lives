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
## World spacing between grid cells, in metres.
@export var spacing: float = 3.0
## Rebuild the grid in-editor when toggled (tool convenience).
@export var rebuild_in_editor: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_build()

# Raw meshes (browse galleries) or built prop prefabs (the prefab gallery / shelf).
const MODEL_EXTS := [".glb", ".gltf", ".obj", ".tscn"]
const FLY_CAMERA := preload("res://game/scenes/art/GalleryFlyCamera.gd")

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
	var i := 0
	for path in paths:
		var cell := Vector3(
			float(i % columns) * spacing,
			0.0,
			float(i / columns) * spacing)
		_place_model(path, cell)
		i += 1
	print("AssetGallery: placed %d models from %s" % [paths.size(), models_dir])

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

func _place_model(path: String, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	holder.position = pos
	add_child(holder)
	if Engine.is_editor_hint():
		holder.owner = get_tree().edited_scene_root

	var resource := load(path)
	if resource is PackedScene:
		holder.add_child((resource as PackedScene).instantiate())
	elif resource is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = resource
		holder.add_child(mi)
	else:
		push_warning("AssetGallery: could not load %s" % path)

	var label := Label3D.new()
	label.text = holder.name
	label.position = Vector3(0.0, 2.2, 0.0)
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	holder.add_child(label)

## Builds a camera/light/environment framing the whole grid (play-mode only).
func _build_stage() -> void:
	var count := get_child_count()
	var rows: int = int(ceil(float(count) / float(columns)))
	var grid_w := float(columns) * spacing
	var grid_d := float(rows) * spacing
	var center := Vector3(grid_w * 0.5, 1.0, grid_d * 0.5)

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
	cam.position = Vector3(center.x, maxf(grid_w, grid_d) * 0.55 + 6.0, -10.0)
	add_child(cam)
	cam.look_at(center, Vector3.UP)
	cam.current = true
