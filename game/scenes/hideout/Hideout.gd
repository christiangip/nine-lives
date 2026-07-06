extends Control
## The Hideout — the between-mission hub and first sight on New Game / Continue / post-Catch
## (FR-13-11). Manifest-driven (FR-13-1): the station grid is built entirely from HideoutManifest
## (Content.stations + ProgressionManager unlock state) — dropping a StationDef .tres + panel scene
## adds a station with NO edit here. Unlocked stations open their panel overlay (StationDef.scene_path);
## locked stations show their requirement + an Unlock button (Legacy / delivered special loot).
## This is the 2D functional hub; HideoutGreybox.tscn demos the diegetic 3D safehouse. Scene swaps stay
## GameManager's job. See docs/tasks/13_hideout_stations.md and GDD §6.

const FONT := preload("res://game/assets/fonts/KenneyFuture.ttf")

var _grid: GridContainer
var _currency_label: Label
var _active_panel: StationPanel

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 16
	self.theme = theme
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 30
	root.offset_right = -40
	root.offset_bottom = -30
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "THE HIDEOUT"
	title.add_theme_font_size_override("font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_currency_label = Label.new()
	_currency_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_currency_label)

	var sub := Label.new()
	sub.text = "Between-mission safehouse — spend Legacy & The Take, then pull your next contract."
	sub.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	root.add_child(sub)
	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	# Grant + announce any milestone arcs newly reached since last visit (task 20, FR-20-1). Idempotent —
	# most fire at the Catch (end_streak) and surface here as the safehouse visibly grows.
	if ProgressionManager != null:
		ProgressionManager.check_milestones()

	_rebuild()
	_show_milestone_toasts()

## Pop a brief toast per milestone reached since the last drain (task 20). The unlock itself is already
## persisted + reflected in the station grid; this is just the "new content!" flourish.
func _show_milestone_toasts() -> void:
	if ProgressionManager == null:
		return
	var index := 0
	for mid in ProgressionManager.drain_milestone_toasts():
		var def := Content.milestones.get_def(mid) as MilestoneDef if Content != null and Content.milestones != null else null
		_toast("★ Milestone reached: %s" % (def.display_name if def != null else String(mid)), index)
		index += 1

func _toast(text: String, index: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.position = Vector2(50, 92 + index * 34)
	add_child(lbl)
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free())

## (Re)build the station grid from the manifest. Called on open + whenever an unlock changes the
## Hideout ("the safehouse visibly grows").
func _rebuild() -> void:
	_update_currencies()
	for c in _grid.get_children():
		c.queue_free()
	var entries := HideoutManifest.build_live()
	entries.sort_custom(_by_order)
	for entry in entries:
		_grid.add_child(_station_card(entry))

func _by_order(a: Dictionary, b: Dictionary) -> bool:
	return _order(a["def"]) < _order(b["def"])

func _order(def: StationDef) -> int:
	return int(def.ui_hooks.get("order", 999))

## A card per station: name + blurb, and either an Enter button (unlocked) or the requirement + an
## Unlock button (locked, enabled iff currently affordable / its loot is delivered).
func _station_card(entry: Dictionary) -> Control:
	var def: StationDef = entry["def"]
	var unlocked: bool = entry["unlocked"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 150)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var name_lbl := Label.new()
	name_lbl.text = def.display_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	box.add_child(name_lbl)

	var blurb := Label.new()
	blurb.text = String(def.ui_hooks.get("blurb", ""))
	blurb.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(blurb)

	if unlocked:
		var enter := Button.new()
		enter.text = "Enter"
		enter.pressed.connect(_open_station.bind(def))
		box.add_child(enter)
	else:
		var req := Label.new()
		req.text = HideoutManifest.requirement_text(def)
		req.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4))
		box.add_child(req)
		var can := ProgressionManager.can_unlock_station(def, ProgressionManager.legacy, ProgressionManager.stash)
		var unlock := Button.new()
		unlock.text = "Unlock"
		unlock.disabled = not can
		unlock.pressed.connect(_unlock_station.bind(def))
		box.add_child(unlock)
	return card

func _open_station(def: StationDef) -> void:
	if _active_panel != null:
		return
	var packed := load(def.scene_path) as PackedScene
	if packed == null:
		push_warning("Hideout: station '%s' has no scene at %s" % [def.id, def.scene_path])
		return
	var panel := packed.instantiate()
	if panel is StationPanel:
		_active_panel = panel
		panel.closed.connect(_on_panel_closed)
		add_child(panel)

func _on_panel_closed() -> void:
	_active_panel = null
	_rebuild()   # currencies / new unlocks may have changed
	# Persist spends made at the station so a purchase can't be lost to a quit (task 16, FR-16-4).
	if SaveManager != null:
		SaveManager.autosave()

func _unlock_station(def: StationDef) -> void:
	if ProgressionManager.try_unlock_station(def):
		_rebuild()
		if SaveManager != null:
			SaveManager.autosave()

func _update_currencies() -> void:
	var take := RunManager.take if RunManager != null else 0
	var noto := RunManager.notoriety if RunManager != null else 0
	var legacy := ProgressionManager.legacy if ProgressionManager != null else 0
	_currency_label.text = "Legacy %d      Take $%d      Notoriety %d" % [legacy, take, noto]
