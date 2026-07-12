extends Control
class_name SlotPopup
## The 10-slot save popup (task 15, FR-15-3), shared by New Game (choose/overwrite) and Continue (load).
## Each occupied slot shows the five summary fields (Streak length · total Legacy · playtime · last-played
## date · last contract); empty slots read "Empty." Occupied slots offer Load/Overwrite + Delete (both
## confirmed). It drives SaveManager's seams (scan_slots / slot_summary / delete_slot) + GameManager
## (start_new_game / continue_game). NOTE: the real save I/O is task 16 — until it lands, every slot reads
## "Empty" (the true fresh-profile state) and lights up automatically once 16 fills those seams
## (↩ From 15, see 16_save_system.md). The row-rendering + summary formatting are pure/tested here.
## Built in code with the shared UITheme. See docs/tasks/15_ui_hud_menus.md.

enum Mode { NEW, LOAD }

signal closed

## Build + show the popup over `parent` in the given mode. Returns it.
static func open(parent: Node, mode: int) -> SlotPopup:
	var p := SlotPopup.new()
	p._mode = mode
	parent.add_child(p)
	return p

var _mode: int = Mode.NEW
var _list: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # offsets too: anchors alone keep the 0x0 rect a code-built Control starts with
	theme = UITheme.build()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# Without growing BOTH ways, PRESET_CENTER puts the panel's top-left at screen centre (off-centre panel).
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(720, 560)
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "New Game — choose a slot" if _mode == Mode.NEW else "Continue — load a slot"
	UITheme.style_title(title, 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(_close)
	header.add_child(back)
	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	back.grab_focus()
	_rebuild()

# --- Pure seam (headless-testable) ---------------------------------------------
## Render a slot's summary dict as its display line. An empty dict → "Empty."; otherwise all five fields
## (Streak length · total Legacy · playtime · last-played date · last contract). Pure. (FR-15-3)
static func format_slot(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Empty."
	return "Streak %d      Legacy %d      Played %s      %s      %s" % [
		int(summary.get("streak_len", 0)),
		int(summary.get("legacy", 0)),
		_playtime_text(summary.get("playtime", 0)),
		str(summary.get("last_played", "—")),
		str(summary.get("last_contract", "—")),
	]

static func _playtime_text(playtime) -> String:
	if playtime is int or playtime is float:
		var secs := int(playtime)
		return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]
	return str(playtime)

# --- Rows ----------------------------------------------------------------------
func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var slots: Array = SaveManager.scan_slots()
	for i in slots.size():
		_list.add_child(_slot_row(i, bool(slots[i])))

func _slot_row(slot: int, occupied: bool) -> Control:
	var card := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var idx := Label.new()
	idx.text = "Slot %d" % (slot + 1)
	idx.add_theme_color_override("font_color", UITheme.ACCENT)
	info.add_child(idx)
	var summary := Label.new()
	summary.text = format_slot(SaveManager.slot_summary(slot))
	summary.add_theme_color_override("font_color", UITheme.TEXT if occupied else UITheme.MUTED)
	info.add_child(summary)

	# Primary action: New/Overwrite (NEW mode) or Load (LOAD mode, occupied only).
	if _mode == Mode.NEW:
		var act := Button.new()
		act.text = "Overwrite" if occupied else "New Game"
		act.custom_minimum_size = Vector2(130, 40)
		act.pressed.connect(_on_new.bind(slot, occupied))
		row.add_child(act)
	else:
		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.custom_minimum_size = Vector2(130, 40)
		load_btn.disabled = not occupied
		load_btn.pressed.connect(_on_load.bind(slot))
		row.add_child(load_btn)

	var del := Button.new()
	del.text = "Delete"
	del.custom_minimum_size = Vector2(100, 40)
	del.disabled = not occupied
	del.pressed.connect(_on_delete.bind(slot))
	row.add_child(del)
	return card

# --- Actions -------------------------------------------------------------------
func _on_new(slot: int, occupied: bool) -> void:
	if occupied:
		var c := ConfirmPopup.open(self, "Overwrite Slot %d? This deletes the existing save." % (slot + 1), "Overwrite")
		c.confirmed.connect(func() -> void: _start_new(slot))
	else:
		_start_new(slot)

func _start_new(slot: int) -> void:
	GameManager.start_new_game(slot)   # TODO[16]: SaveManager writes a fresh slot before the hub swap

func _on_load(slot: int) -> void:
	GameManager.continue_game(slot)    # TODO[16]: SaveManager.load_slot rehydrates before the hub swap

func _on_delete(slot: int) -> void:
	var c := ConfirmPopup.open(self, "Delete the save in Slot %d? This can't be undone." % (slot + 1), "Delete")
	c.confirmed.connect(func() -> void:
		SaveManager.delete_slot(slot)  # TODO[16]: real delete; _rebuild reflects it once 16 lands
		_rebuild())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
