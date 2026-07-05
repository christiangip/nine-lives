extends Control
## SaveSandboxDebug — the task-16 demo/greybox (F6). A menu-flow save sandbox (the user's chosen form:
## exercise the REAL SaveManager + the REAL MainMenu → SlotPopup → Hideout loop rather than a bespoke 3D
## room). It shows a live readout of all 10 slots via the real SaveManager.slot_summary /
## SlotPopup.format_slot seams, and dev keys drive every save path: save/load/delete the active slot,
## simulate a hot-quit-while-committed → Catch, and a v1→v2 migration round-trip. Opens the real
## MainMenu / 10-slot SlotPopup so the whole flow is walkable end to end. See docs/tasks/16_save_system.md.

var _readout: Label
var _toast: Label
var _active: int = 0
var _overlay: Control = null

func _ready() -> void:
	# Give the sandbox a mission-ish demo state so a save has something to show off.
	_seed_demo_state()
	GameManager.active_slot = _active
	_build_ui()
	_refresh()

func _seed_demo_state() -> void:
	if ProgressionManager != null and ProgressionManager.legacy < 100:
		ProgressionManager.legacy = 4200
		ProgressionManager.attributes[&"lockpicking"] = 3
	if RunManager != null:
		if RunManager.notoriety == 0:
			RunManager.notoriety = 1800
		if RunManager.streak_length == 0:
			RunManager.streak_length = 2
		if RunManager.last_contract == "":
			RunManager.last_contract = "First National Bank"

# --- UI ----------------------------------------------------------------------
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.08, 0.11)
	add_child(bg)

	var title := Label.new()
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 22)
	title.text = "SAVE SANDBOX — task 16   (schema v%d)" % SaveManager.SCHEMA_VERSION
	add_child(title)

	_readout = Label.new()
	_readout.position = Vector2(24, 60)
	_readout.custom_minimum_size = Vector2(940, 0)
	add_child(_readout)

	var help := Label.new()
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(24, -132)
	help.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	help.text = "0-9 select active slot   ·   S save   ·   L load   ·   D delete\n" + \
		"C simulate hot-quit-while-committed → Catch on reload\n" + \
		"G v1→v2 migration round-trip demo\n" + \
		"N open Main Menu (New)   ·   O open Slot popup (Load)   ·   H go to Hideout"
	add_child(help)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.position = Vector2(0, 34)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	add_child(_toast)

func _refresh() -> void:
	var lines: Array[String] = []
	lines.append("Active slot: %d    Legacy: %d    Notoriety: %d    Streak: %d" % [
		_active, ProgressionManager.legacy, RunManager.notoriety, RunManager.streak_length])
	lines.append("Continue would be: %s" % ("ENABLED" if SaveManager.populated_count() > 0 else "greyed"))
	lines.append("")
	for i in SaveManager.SLOT_COUNT:
		var marker := ">" if i == _active else " "
		lines.append("%s slot %d:  %s" % [marker, i, SlotPopup.format_slot(SaveManager.slot_summary(i))])
	_readout.text = "\n".join(lines)

func _flash(msg: String) -> void:
	_toast.text = msg
	_refresh()

# --- Dev keys ----------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var code := (event as InputEventKey).keycode
	if code >= KEY_0 and code <= KEY_9:
		_active = code - KEY_0
		GameManager.active_slot = _active
		_flash("Active slot → %d" % _active)
		return
	match code:
		KEY_S:
			_flash("save_slot(%d) → %s" % [_active, SaveManager.save_slot(_active)])
		KEY_L:
			_flash("load_slot(%d) → %s" % [_active, SaveManager.load_slot(_active)])
		KEY_D:
			_flash("delete_slot(%d) → %s" % [_active, SaveManager.delete_slot(_active)])
		KEY_C:
			_demo_hot_quit()
		KEY_G:
			_demo_migration()
		KEY_N:
			GameManager.goto_main_menu()
		KEY_O:
			_open(SlotPopup.open(self, SlotPopup.Mode.LOAD))
		KEY_H:
			GameManager.goto_hideout()

## Save the slot, flip its on-disk commit flag (as an alarm would mid-mission), then reload — the strict
## policy resolves it as the Catch (Legacy banked, Streak reset) instead of a free continue (FR-16-5).
func _demo_hot_quit() -> void:
	SaveManager.save_slot(_active)
	var legacy_before := ProgressionManager.legacy
	SaveManager.mark_committed()
	SaveManager.load_slot(_active)
	_flash("Hot-quit demo: committed reload → Catch. Legacy %d → %d, Streak reset to %d." % [
		legacy_before, ProgressionManager.legacy, RunManager.streak_length])

## Write a hand-rolled v1 save (no checkpoint flag / playtime), then migrate() it and show the upgrade.
func _demo_migration() -> void:
	var v1 := {
		"schema_version": 1,
		"meta": {"streak_len": 1, "legacy": 999, "playtime": 0, "last_played": "2026-01-01", "last_contract": "Old Save"},
		"permanent": {"legacy": 999, "attributes": {}, "unlocked_gear": [], "research_done": [],
			"meta_perks": [], "stations_unlocked": [], "stash": [], "stats": {}},
		"streak": {"notoriety": 0, "streak_level": 1, "streak_length": 1, "heat": 0.0, "take": 0,
			"edges": [], "committed": false, "loadout": {}, "job_board": [], "intel_by_seed": {}},
	}
	var upgraded := SaveManager.migrate(v1.duplicate(true))
	_flash("Migration v1→v%d: added active_mission_committed=%s, playtime_seconds=%s." % [
		upgraded["schema_version"], upgraded.get("active_mission_committed"),
		upgraded["permanent"].get("playtime_seconds")])

func _open(node: Control) -> void:
	_overlay = node
	if node.get_parent() == null:
		add_child(node)
	node.tree_exited.connect(func() -> void:
		_overlay = null
		_refresh())
