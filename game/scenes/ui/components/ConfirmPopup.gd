extends Control
class_name ConfirmPopup
## A small reusable confirm overlay (task 15) — used by Exit, slot overwrite, and slot Delete, i.e. every
## irreversible menu action (FR-15-1/3). Dims the screen, shows a message + Cancel/Confirm, and emits
## `confirmed` (or `cancelled`) then frees itself. Built in code with the shared UITheme; embedded (a plain
## Control, not a native Window) so it renders consistently in-game and headlessly. See docs/tasks/15_ui_hud_menus.md.

signal confirmed
signal cancelled

## Build + show a confirm over `parent`. Returns the popup so the caller can also connect signals inline.
static func open(parent: Node, message: String, confirm_text: String = "Confirm") -> ConfirmPopup:
	var p := ConfirmPopup.new()
	p._message = message
	p._confirm_text = confirm_text
	parent.add_child(p)
	return p

var _message: String = ""
var _confirm_text: String = "Confirm"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable while the tree is paused (Pause → Abort confirm)
	theme = UITheme.build()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var msg := Label.new()
	msg.text = _message
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size = Vector2(420, 0)
	box.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(150, 44)
	cancel.pressed.connect(_on_cancel)
	row.add_child(cancel)
	var confirm := Button.new()
	confirm.text = _confirm_text
	confirm.custom_minimum_size = Vector2(150, 44)
	confirm.pressed.connect(_on_confirm)
	row.add_child(confirm)
	confirm.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()

func _on_confirm() -> void:
	confirmed.emit()
	queue_free()

func _on_cancel() -> void:
	cancelled.emit()
	queue_free()
