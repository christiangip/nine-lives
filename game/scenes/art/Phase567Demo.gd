## Phase 5-7 demo greybox: shows off what the weapons/audio/UI import produced —
## a rotating suppressed pistol (3D, in a SubViewport), a click-to-play audio
## soundboard grouped by sound family, and the Kenney font + icons in use. Dev
## tool (task 18 / phase-1-art). F6 to run; click any sound button to hear it.
extends Control

const HUB_PATH := "res://game/scenes/art/gallery_hub.tscn"
const FONT := preload("res://game/assets/fonts/KenneyFuture.ttf")
const PISTOL := preload("res://game/assets/models/weapons/Pistol_1.obj")
const SILENCER := preload("res://game/assets/models/weapons/Silencer_long.obj")

const INTERFACE_DIR := "res://game/assets/audio/sfx/interface"
const IMPACT_DIR := "res://game/assets/audio/sfx/impact"
const ICONS_DIR := "res://game/assets/ui/icons"

var _audio: AudioStreamPlayer
var _pivots: Array[Node3D] = []

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 16
	self.theme = theme

	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.12, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 20
	root.offset_right = -24
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "NINE LIVES — PHASE 5-7 DEMO"
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "Weapons (3D) · Audio (click to play) · UI icons + font — all CC0"
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	root.add_child(sub)

	# Top row: 3D weapon viewports (with / without suppressor) + icon strip.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	top.add_child(_build_weapon_viewport(false, "pistol (Pistol_1)"))
	top.add_child(_build_weapon_viewport(true, "suppressed_pistol (+ silencer)"))
	top.add_child(_build_icon_strip())

	# Soundboard.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var board := VBoxContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(board)
	board.add_child(_section("§6  INTERFACE SFX (UI)", INTERFACE_DIR))
	board.add_child(_section("§6  IMPACTS & FOOTSTEPS (per surface)", IMPACT_DIR))

	# Back to hub.
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := Button.new()
	back.text = "← Galleries"
	back.position = Vector2(12, 12)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(HUB_PATH))
	layer.add_child(back)

func _process(delta: float) -> void:
	for pivot in _pivots:
		pivot.rotate_y(delta * 0.8)

## A lit SubViewport showing the pistol, optionally with the silencer mated to the
## muzzle (placement derived from mesh geometry, not a blind offset).
func _build_weapon_viewport(with_suppressor: bool, title: String) -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(300, 210)
	var vp := SubViewport.new()
	vp.size = Vector2i(300, 210)
	vp.transparent_bg = true
	container.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -40, 0)
	vp.add_child(sun)

	var pivot := Node3D.new()
	vp.add_child(pivot)
	_pivots.append(pivot)
	# Centre the whole assembly on the pivot for tidy rotation.
	var centerer := Node3D.new()
	centerer.position = -PISTOL.get_aabb().get_center()
	pivot.add_child(centerer)
	var gun := MeshInstance3D.new()
	gun.mesh = PISTOL
	centerer.add_child(gun)
	if with_suppressor:
		var sil := MeshInstance3D.new()
		sil.mesh = SILENCER
		sil.position = _suppressor_offset()
		centerer.add_child(sil)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.12, 0.5)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	vp.add_child(cam)
	cam.current = true

	var lbl := Label.new()
	lbl.text = title
	container.add_child(lbl)
	return container

## Local offset that butts the silencer's rear against the pistol muzzle, centred
## on the barrel axis. Reads mesh vertices to find the muzzle (works headless).
func _suppressor_offset() -> Vector3:
	var m := _muzzle(_verts(PISTOL))
	var sab := SILENCER.get_aabb()
	# rear_x: the silencer end that should touch the muzzle (facing the gun body).
	var rear_x: float = sab.position.x if m.dir > 0.0 else sab.position.x + sab.size.x
	var sc := sab.get_center()
	return Vector3(m.x - rear_x, m.y - sc.y, m.z - sc.z)

## Merged vertex list of every surface in `mesh`.
func _verts(mesh: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out

## Finds the barrel/muzzle: barrel axis = X; the muzzle end is the X-extreme whose
## slice has the *higher* min-Y (no grip hanging down). Returns muzzle point + dir.
func _muzzle(verts: PackedVector3Array) -> Dictionary:
	var minx := INF
	var maxx := -INF
	for v in verts:
		minx = minf(minx, v.x)
		maxx = maxf(maxx, v.x)
	var span := maxx - minx
	var front_miny := INF   # near maxx
	var back_miny := INF    # near minx
	for v in verts:
		if v.x >= maxx - span * 0.2:
			front_miny = minf(front_miny, v.y)
		elif v.x <= minx + span * 0.2:
			back_miny = minf(back_miny, v.y)
	var dir := 1.0 if front_miny > back_miny else -1.0
	var muzzle_x := maxx if dir > 0.0 else minx
	# Barrel height/depth = mean of the vertices right at the muzzle tip.
	var sy := 0.0
	var sz := 0.0
	var n := 0
	for v in verts:
		if absf(v.x - muzzle_x) <= span * 0.08:
			sy += v.y
			sz += v.z
			n += 1
	var by := sy / float(n) if n > 0 else 0.0
	var bz := sz / float(n) if n > 0 else 0.0
	return {"x": muzzle_x, "y": by, "z": bz, "dir": dir}

func _build_icon_strip() -> Control:
	var box := VBoxContainer.new()
	var cap := Label.new()
	cap.text = "§7  Kenney icons (tintable)"
	box.add_child(cap)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var n := 0
	for path in _list_pngs(ICONS_DIR):
		if n >= 24:
			break
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(34, 34)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = Color(0.85, 0.9, 1.0)
		grid.add_child(tr)
		n += 1
	return box

## A titled block of buttons — one per sound family in `dir` (plays a sample).
func _section(title: String, dir: String) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for group in _sound_groups(dir):
		var btn := Button.new()
		btn.text = group["label"]
		btn.custom_minimum_size = Vector2(150, 34)
		var path: String = group["path"]
		btn.pressed.connect(func() -> void:
			_audio.stream = load(path)
			_audio.play())
		grid.add_child(btn)
	return box

## Unique sound families in `dir` (strip trailing digits), one sample path each.
func _sound_groups(dir_path: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var l := f.to_lower()
		if l.ends_with(".ogg") or l.ends_with(".wav"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for file in files:
		var key := file.get_basename().rstrip("0123456789").rstrip("_")
		if not seen.has(key):
			seen[key] = true
			out.append({"label": key, "path": dir_path.path_join(file)})
	return out

func _list_pngs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.to_lower().ends_with(".png"):
			out.append(dir_path.path_join(f))
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
