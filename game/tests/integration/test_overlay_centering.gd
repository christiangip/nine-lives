extends GutTest
## Regression (misc-fixes-3 issues 5-7): every code-built overlay must FILL its parent and centre its panel.
##
## The defect this locks out: `set_anchors_preset()` called on a Control that is ALREADY IN THE TREE keeps
## the control's current rect by recomputing its offsets — and a code-built Control starts 0x0. So every
## overlay root that set PRESET_FULL_RECT inside `_ready()` stayed **zero-sized**, which put its centred
## panel's anchor on the screen's top-left pixel (and made its dim invisible). The fix is
## `set_anchors_and_offsets_preset()`, which zeroes the offsets so the root really does fill the screen.
## Panels then need grow BOTH to centre on it. See docs/tasks/15_ui_hud_menus.md.

func _panel_of(root: Control) -> Control:
	for c in root.get_children():
		if c is PanelContainer:
			return c as Control
	return null

## The overlay fills `host`, and its panel is centred on the host — not pinned to a corner.
func _assert_centered(label: String, host: Control, overlay: Control) -> void:
	assert_eq(overlay.size, host.size, "%s: the overlay root must fill its parent (0x0 = the old bug)" % label)
	var panel := _panel_of(overlay)
	assert_not_null(panel, "%s: has a panel" % label)
	var host_center := host.size * 0.5
	var panel_center: Vector2 = panel.position + panel.size * 0.5
	assert_almost_eq(panel_center.x, host_center.x, 1.0, "%s: panel is horizontally centred" % label)
	assert_almost_eq(panel_center.y, host_center.y, 1.0, "%s: panel is vertically centred" % label)

func test_overlays_fill_and_center() -> void:
	var host: Control = load("res://game/scenes/menu/MainMenu.tscn").instantiate()
	get_tree().root.add_child(host)
	await wait_physics_frames(2)
	assert_gt(host.size.x, 0.0, "the host menu itself has a real size")

	var options := OptionsMenu.open(host, false)
	var confirm := ConfirmPopup.open(host, "message", "OK")
	var slots := SlotPopup.open(host, SlotPopup.Mode.NEW)
	await wait_physics_frames(2)
	_assert_centered("Options", host, options)
	_assert_centered("ConfirmPopup", host, confirm)
	_assert_centered("SlotPopup", host, slots)
	host.queue_free()

func test_pause_menu_and_its_submenus_center() -> void:
	var pause: Control = load("res://game/scenes/mission/PauseMenu.tscn").instantiate()
	get_tree().root.add_child(pause)
	await wait_physics_frames(2)
	var content: Control = pause._content
	_assert_centered("PauseMenu", pause, content)

	# A sub-menu HIDES the pause content (so its buttons can't be clicked through the sub-menu's dim).
	pause._open_options()
	await wait_physics_frames(2)
	assert_false(content.visible, "the pause menu is hidden while a sub-menu is open")
	get_tree().paused = false
	pause.queue_free()
