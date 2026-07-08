extends Control
class_name PauseMenu
## The in-mission Pause overlay (task 15; Q5 commit messaging). Opened by the HUD on the `pause` action:
## pauses the SceneTree + frees the mouse, and offers Resume · Options · Abort. Per the strict-saves rule
## (Q5, GDD §15): a CLEAN abort (undetected/uncommitted) bugs out to the Hideout keeping secured loot + the
## Streak; once RunManager.committed (an alarm was raised) leaving instead resolves as the **Catch**
## (end_streak → Legacy → Results). Reuses the shared OptionsMenu + ConfirmPopup. Themed via UITheme.
## See docs/tasks/15_ui_hud_menus.md and DESIGN_DECISIONS.md Q5.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS   # run while the tree is paused
	theme = UITheme.build()
	get_tree().paused = true
	_set_mouse(Input.MOUSE_MODE_VISIBLE)
	Localization.ensure_registered()   # localization scaffold (task 21) — keyed text auto-translates

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSE_TITLE"
	title.add_theme_font_size_override("font_size", 32)
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

	var resume_btn := _menu_button(box, "PAUSE_RESUME", _resume)
	_menu_button(box, "PAUSE_OPTIONS", _open_options)
	_menu_button(box, "PAUSE_ABORT", _abort)
	resume_btn.grab_focus()   # every other overlay in the game defaults focus somewhere; this didn't (gamepad/KB-only nav was stuck)

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
	OptionsMenu.open(self, true)

func _abort() -> void:
	if _committed():
		var c := ConfirmPopup.open(self, "You're committed — aborting now resolves as the Catch. Bank your Notoriety as Legacy and end the Streak?", "Accept the Catch")
		c.confirmed.connect(_abort_as_catch)
	else:
		var c := ConfirmPopup.open(self, "Bug out cleanly? You keep secured loot and your Streak stays intact.", "Bug Out")
		c.confirmed.connect(_abort_clean)

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
