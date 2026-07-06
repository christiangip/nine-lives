## Asset-gallery hub: a launcher greybox that opens each per-kit gallery so all
## imported art can be reviewed for size/scale from one place. Every gallery shows
## a 1.8 m human-scale reference capsule beside its rows. Task 18 (phase-1-art) —
## a dev tool, not shipped content. See phase-1-art.md.
extends Control

# title · model count · gallery scene. Counts mirror the imported kit folders.
const GALLERIES := [
	{"title": "★ Bank Test (walkthrough)", "count": 12, "path": "res://game/scenes/art/bank_test.tscn"},
	{"title": "★ Phase 5-7 Demo (weapons/audio/UI)", "count": 3, "path": "res://game/scenes/art/phase567_demo.tscn"},
	{"title": "★ Expansion Sandbox (content packs)", "count": 1, "path": "res://game/scenes/expansion/ExpansionSandbox.tscn"},
	{"title": "★ Prefabs — Bank set", "count": 12, "path": "res://game/scenes/art/gallery_prefabs.tscn"},
	{"title": "★ Characters", "count": 8, "path": "res://game/scenes/art/gallery_characters.tscn"},
	{"title": "★ Heist Props (loot/security)", "count": 18, "path": "res://game/scenes/art/gallery_heist_props.tscn"},
	{"title": "★ Weapons", "count": 11, "path": "res://game/scenes/art/gallery_weapons.tscn"},
	{"title": "★ Icons (Kenney, 2D)", "count": 105, "path": "res://game/scenes/art/gallery_icons.tscn"},
	{"title": "★ UI Kit (Kenney, 2D)", "count": 82, "path": "res://game/scenes/art/gallery_ui_kit.tscn"},
	{"title": "Modular Buildings", "count": 108, "path": "res://game/scenes/art/gallery_modular_buildings.tscn"},
	{"title": "City Commercial", "count": 41, "path": "res://game/scenes/art/gallery_city_commercial.tscn"},
	{"title": "Factory", "count": 143, "path": "res://game/scenes/art/gallery_factory.tscn"},
	{"title": "Survival", "count": 80, "path": "res://game/scenes/art/gallery_survival.tscn"},
	{"title": "SciFi MegaKit", "count": 186, "path": "res://game/scenes/art/gallery_scifi_megakit.tscn"},
	{"title": "Furniture — Kenney", "count": 140, "path": "res://game/scenes/art/gallery_furniture_kenney.tscn"},
	{"title": "Furniture — Quaternius", "count": 20, "path": "res://game/scenes/art/gallery_furniture_quaternius.tscn"},
	{"title": "Server Rack", "count": 1, "path": "res://game/scenes/art/gallery_server_rack.tscn"},
]

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Nine Lives — Asset Galleries"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Each gallery shows a 1.8 m human capsule beside every row for scale."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)

	var first: Button = null
	for entry in GALLERIES:
		var btn := Button.new()
		btn.text = "%s  (%d)" % [entry["title"], entry["count"]]
		btn.custom_minimum_size = Vector2(320, 0)
		var path: String = entry["path"]
		btn.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(path))
		box.add_child(btn)
		if first == null:
			first = btn

	if first != null:
		first.grab_focus()
