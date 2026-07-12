extends Control
## MissionResults — the results / Catch screen (task 15, FR-15-8). GameManager swaps here after a mission
## ends (Escape, or the Catch). It summarizes the outcome + the Legacy payout from GameManager.pending_results
## (set by goto_results): a clean escape reports secured loot + performance and the Streak continues; a Catch
## (caught / captured / committed-abort) reports the Notoriety→Legacy conversion and that the Streak resets
## but Legacy carries forward. One button returns to the Hideout. Built in code with the shared UITheme.
## See docs/tasks/15_ui_hud_menus.md and GDD §15/§5.

const _CATCH_OUTCOMES := ["caught", "captured", "aborted"]

func _ready() -> void:
	theme = UITheme.build()
	# The mission that just ended (escape or Catch) leaves the mouse MOUSE_MODE_CAPTURED for FP look;
	# this is the one screen every ending funnels through (PlayerController never gets a chance to
	# release it itself), so free the cursor here rather than at each trigger site.
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var data := GameManager.pending_results if GameManager != null else {}
	var outcome := String(data.get("outcome", "success"))
	var is_catch := outcome in _CATCH_OUTCOMES
	var is_challenge := bool(data.get("challenge", false))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	# Without growing BOTH ways, PRESET_CENTER puts the box's top-left at screen centre (off-centre summary).
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_title(title, 44)
	if is_challenge:
		title.text = "CHALLENGE FAILED" if is_catch else "CHALLENGE COMPLETE"
		title.add_theme_color_override("font_color", UITheme.WARN if is_catch else UITheme.OK)
	elif is_catch:
		title.text = "CAUGHT" if outcome != "aborted" else "STREAK ENDED"
		title.add_theme_color_override("font_color", UITheme.WARN)
	else:
		title.text = "CONTRACT COMPLETE"
		title.add_theme_color_override("font_color", UITheme.OK)
	box.add_child(title)
	box.add_child(HSeparator.new())

	for line in _summary_lines(data, is_catch):
		var lbl := Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lbl)

	box.add_child(HSeparator.new())
	var cont := Button.new()
	cont.text = "Return to the Hideout"
	cont.custom_minimum_size = Vector2(0, 48)
	cont.pressed.connect(func() -> void: GameManager.goto_hideout())
	box.add_child(cont)
	cont.grab_focus()

## The body lines, tailored to a clean escape vs the Catch (or a standalone Challenge, task 20).
func _summary_lines(data: Dictionary, is_catch: bool) -> Array[String]:
	var lines: Array[String] = []
	var secured := int(data.get("secured_value", 0))
	if bool(data.get("challenge", false)):
		var kind := String(data.get("challenge_kind", "daily")).capitalize()
		if is_catch:
			lines.append("%s Challenge failed — no time recorded." % kind)
			lines.append("Your endless Streak is untouched — try again from the Live Board.")
		else:
			var secs := float(data.get("elapsed_seconds", 0.0))
			lines.append("%s Challenge cleared in %s." % [kind, _fmt_time(secs)])
			lines.append("Your best: %s" % _fmt_time(float(data.get("best_seconds", secs))))
			var reward := int(data.get("reward_legacy", 0))
			if reward > 0:
				lines.append("First-clear bonus: +%d Legacy." % reward)
			lines.append("Your endless Streak is untouched.")
		return lines
	if is_catch:
		lines.append("Loot secured before the Catch: $%d" % secured)
		lines.append("Notoriety banked as permanent Legacy: +%d" % int(data.get("legacy_awarded", 0)))
		lines.append("Your Streak resets — but your Legacy carries forward. Come back sharper.")
	else:
		lines.append("Loot secured this contract: $%d" % secured)
		var perf: Array[String] = []
		if bool(data.get("no_kill", false)): perf.append("No-Kill")
		if bool(data.get("full_clear", false)): perf.append("Full Clear")
		if not perf.is_empty():
			lines.append("Performance: %s" % ", ".join(perf))
		lines.append("Streak continues — pull your next contract from the Job Map.")
	return lines

## m:ss for a Challenge time.
static func _fmt_time(secs: float) -> String:
	var s := int(round(maxf(0.0, secs)))
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]
