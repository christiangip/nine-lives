extends Control
class_name PauseMenu
## The in-mission Pause overlay (task 15; Q5 commit messaging). Opened by the HUD on the `pause` action:
## pauses the SceneTree + frees the mouse, and offers Resume · Options · Abort. Per the strict-saves rule
## (Q5, GDD §15): a CLEAN abort (undetected/uncommitted) bugs out to the Hideout keeping secured loot + the
## Streak; once RunManager.committed (an alarm was raised) leaving instead resolves as the **Catch**
## (end_streak → Legacy → Results). Reuses the shared OptionsMenu + ConfirmPopup. Themed via UITheme.
## See docs/tasks/15_ui_hud_menus.md and DESIGN_DECISIONS.md Q5.

## The pause dim + panel, grouped so a sub-menu (Options / Abort confirm) can hide the WHOLE pause menu
## while it's open — a hidden Control isn't drawn, focusable, or clickable, so the pause buttons can't be
## reached through the sub-menu's own dim any more (issue 7). It is a SIBLING of the sub-menu, not a parent.
var _content: Control
var _resume_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # offsets too: anchors alone keep the 0x0 rect a code-built Control starts with
	process_mode = Node.PROCESS_MODE_ALWAYS   # run while the tree is paused
	theme = UITheme.build()
	get_tree().paused = true
	_set_mouse(Input.MOUSE_MODE_VISIBLE)
	Localization.ensure_registered()   # localization scaffold (task 21) — keyed text auto-translates

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# PRESET_CENTER alone pins the panel's TOP-LEFT to screen centre; growing BOTH ways truly centres it.
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(420, 0)
	_content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSE_TITLE"
	UITheme.style_title(title, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Strict-saves status line (Q5): tells the player what leaving will cost right now.
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _committed():
		status.text = "You're committed — an alarm was raised. Leaving now resolves as the Catch."
		status.add_theme_color_override("font_color", UITheme.WARN)
	else:
		status.text = "Undetected — you can bug out cleanly, keeping secured loot and your Streak."
		status.add_theme_color_override("font_color", UITheme.OK)
	box.add_child(status)
	box.add_child(HSeparator.new())

	_resume_btn = _menu_button(box, "PAUSE_RESUME", _resume)
	_menu_button(box, "PAUSE_OPTIONS", _open_options)
	_menu_button(box, "PAUSE_ABORT", _abort)
	_resume_btn.grab_focus()   # every other overlay in the game defaults focus somewhere; this didn't (gamepad/KB-only nav was stuck)

	var ver := Label.new()   # build/version stamp (task 21, FR-21-7)
	ver.text = Version.string()
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override("font_color", UITheme.MUTED)
	box.add_child(ver)

func _menu_button(box: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(cb)
	box.add_child(b)
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()

func _resume() -> void:
	get_tree().paused = false
	_set_mouse(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _open_options() -> void:
	_content.hide()   # the pause menu underneath must be fully out of the way, not just dimmed
	var o := OptionsMenu.open(self, true)
	o.closed.connect(_on_submenu_closed)

func _abort() -> void:
	_content.hide()
	var c: ConfirmPopup
	if _committed():
		c = ConfirmPopup.open(self, "You're committed — aborting now resolves as the Catch. Bank your Notoriety as Legacy and end the Streak?", "Accept the Catch")
		c.confirmed.connect(_abort_as_catch)
	else:
		c = ConfirmPopup.open(self, "Bug out cleanly? You keep secured loot and your Streak stays intact.", "Bug Out")
		c.confirmed.connect(_abort_clean)
	# Only CANCEL comes back to the pause menu — a confirmed abort leaves with the scene swap.
	c.cancelled.connect(_on_submenu_closed)

## A sub-menu closed: bring the pause menu back and re-seat focus (gamepad/KB nav would otherwise be lost).
func _on_submenu_closed() -> void:
	if _content != null:
		_content.show()
	if _resume_btn != null:
		_resume_btn.grab_focus()

func _abort_as_catch() -> void:
	get_tree().paused = false
	var secured := 0
	var awarded := 0
	if RunManager != null:
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null and player.get("inventory") != null:
			secured = int(player.inventory.secured_value())
		awarded = RunManager.end_streak("aborted", secured)
	GameManager.goto_results({"outcome": "aborted", "legacy_awarded": awarded, "secured_value": secured})

func _abort_clean() -> void:
	get_tree().paused = false
	# A standalone Challenge (task 20) has no "Streak" of its own to keep intact — bugging out just
	# abandons the attempt, so restore the real Streak the Challenge snapshotted rather than leaving
	# its zeroed scratch state in place (which goto_hideout's autosave would otherwise persist over
	# the player's real save). No result is recorded: a clean bug-out isn't a completion or a Catch.
	if RunManager != null and RunManager.challenge_mode:
		RunManager.end_challenge()
	# Clean bug-out: Streak + secured loot intact (Q5). Straight back to the hub.
	GameManager.goto_hideout()

func _committed() -> bool:
	return RunManager != null and RunManager.committed

func _set_mouse(mode: int) -> void:
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = mode
