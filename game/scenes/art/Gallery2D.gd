## 2D asset browser greybox: scans a folder of PNGs and lays them on a scrollable,
## labeled grid — the 2D analogue of AssetGallery for icons / UI sprites. Rebuilds
## from the folder each run. Dev tool (task 18 / phase-1-art). Not shipped.
@tool
extends Control

## Folder of PNG images to display (res:// path). Set per gallery scene.
@export_dir var images_dir: String = ""
## Grid columns before wrapping.
@export var columns: int = 10
## Cell size (px) for each image tile.
@export var tile: int = 96
## Dark backdrop (white/tintable icons read best on dark).
@export var dark_bg: bool = true

const HUB_PATH := "res://game/scenes/art/gallery_hub.tscn"

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.16) if dark_bg else Color(0.82, 0.82, 0.84)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var paths := _scan(images_dir)
	for path in paths:
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var cell := VBoxContainer.new()
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(tile, tile)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(rect)
		var label := Label.new()
		label.text = path.get_file().get_basename()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 10)
		label.custom_minimum_size = Vector2(tile, 0)
		cell.add_child(label)
		grid.add_child(cell)

	if not Engine.is_editor_hint():
		var layer := CanvasLayer.new()
		add_child(layer)
		var back := Button.new()
		back.text = "← Galleries"
		back.position = Vector2(12, 12)
		back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(HUB_PATH))
		layer.add_child(back)
		var count := Label.new()
		count.text = "%d images · %s" % [paths.size(), images_dir]
		count.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		count.position = Vector2(12, -28)
		layer.add_child(count)

func _scan(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	if dir_path.is_empty():
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Gallery2D: cannot open %s" % dir_path)
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.to_lower().ends_with(".png"):
			out.append(dir_path.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
