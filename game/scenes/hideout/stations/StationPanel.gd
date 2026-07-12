extends Control
class_name StationPanel
## Shared base for a Hideout station's UI panel (task 13). The Hideout hub instantiates a station's
## scene (StationDef.scene_path) as a full-screen overlay; the base draws the chrome (title, currency
## strip, Back button) and hands the subclass a body container to fill in code — the house pattern for
## dev/greybox UI (Phase567Demo / MissionGreyboxDebug). Subclasses override _station_title() and
## _populate(body); after a purchase they call refresh() to rebuild the body + currency readout.
## Stations drive already-tested manager methods; EventBus stays FROZEN — this is a local overlay.
## See docs/tasks/13_hideout_stations.md and GDD §6.

signal closed   ## local; the hub re-shows itself + refreshes currencies when a panel closes

var _body: VBoxContainer
var _currency_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # offsets too: anchors alone keep the 0x0 rect a code-built Control starts with
	theme = UITheme.build()   # shared readable body font + understated-outline widgets (misc-fixes-2)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.13, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP   # eat clicks so the hub behind doesn't get them
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 28
	root.offset_top = 22
	root.offset_right = -28
	root.offset_bottom = -22
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# Header: Back · title · currencies.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(_close)
	header.add_child(back)
	var title := Label.new()
	title.text = _station_title()
	UITheme.style_title(title, 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_currency_label = Label.new()
	_currency_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_currency_label)

	root.add_child(HSeparator.new())

	# Scrollable body the subclass fills.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)

	back.grab_focus()
	refresh()

## Rebuild the currency readout + body. Call after any purchase so the panel reflects new state.
func refresh() -> void:
	_update_currencies()
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	_populate(_body)

func _update_currencies() -> void:
	if _currency_label == null:
		return
	var legacy := 0
	if ProgressionManager != null:
		legacy = ProgressionManager.legacy
	var take := 0
	var notoriety := 0
	if RunManager != null:
		take = RunManager.take
		notoriety = RunManager.notoriety
	_currency_label.text = "Legacy %d    Take $%d    Notoriety %d" % [legacy, take, notoriety]

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

# --- Subclass hooks --------------------------------------------------------
## The panel's heading. Override.
func _station_title() -> String:
	return "Station"

## Fill `body` with the station's controls. Override. Called on open + after every refresh().
func _populate(_body_container: VBoxContainer) -> void:
	pass

# --- Small shared UI helpers -----------------------------------------------
## A titled row: a left-aligned label + a right-aligned action Button (disabled/greyed when `enabled`
## is false). Returns the button so the caller can wire `pressed`. The common station widget.
func _action_row(text: String, button_text: String, enabled: bool) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = button_text
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(150, 0)
	row.add_child(btn)
	return btn

func _heading(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 20)
	h.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_body.add_child(h)

func _note(text: String) -> void:
	var n := Label.new()
	n.text = text
	n.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(n)

# --- Content name resolution (shared by Job Map + Planning Table) -----------
func _archetype_name(id: StringName) -> String:
	var def := Content.archetypes.get_def(id) as ArchetypeDef if Content != null and Content.archetypes != null else null
	return def.display_name if def != null else String(id)

func _objective_name(id: StringName) -> String:
	var def := Content.objectives.get_def(id) as ObjectiveDef if Content != null and Content.objectives != null else null
	return def.display_name if def != null else String(id)

func _modifier_name(id: StringName) -> String:
	var def := Content.modifiers.get_def(id) as ModifierDef if Content != null and Content.modifiers != null else null
	return def.display_name if def != null else String(id)

## One-line headline for a Job Map pin: archetype · tier · objective. (§7.1)
func _contract_headline(c: Contract) -> String:
	return "%s   ·   Tier %d   ·   %s" % [_archetype_name(c.archetype_id), c.tier, _objective_name(c.objective_id)]

## The loot manifest an Intel purchase reveals — the archetype's loot pool (names). Empty if no data.
func _contract_manifest(c: Contract) -> Array:
	var out: Array = []
	var arch := Content.archetypes.get_def(c.archetype_id) as ArchetypeDef if Content != null and Content.archetypes != null else null
	if arch == null:
		return out
	for lid in arch.loot_ids:
		var loot := Content.loot.get_def(lid) as LootDef
		out.append(loot.display_name if loot != null else String(lid))
	return out
