extends GutTest
## Task 15 FR-15-4: changing an Options value writes config and survives a reload (live-apply + ConfigFile
## persistence, independent of save slots). Covers a task-15-added key too. Mirrors test_settings_roundtrip's
## temp-file redirect so the developer's real settings.cfg is never touched. docs/tasks/15_ui_hud_menus.md.

const TEST_PATH := "user://test_options15.cfg"
var _orig_path: String

func before_all() -> void:
	_orig_path = SettingsManager.config_path
	SettingsManager.config_path = TEST_PATH

func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	SettingsManager.config_path = _orig_path

func test_accessibility_key_persists() -> void:
	SettingsManager.set_value("gameplay", "colorblind", 2)   # applies + writes to disk
	SettingsManager.load_config()                             # rebuild purely from disk
	assert_eq(int(SettingsManager.get_value("gameplay", "colorblind")), 2,
		"a newly-added accessibility key persists across save → reload")

func test_graphics_key_persists() -> void:
	SettingsManager.set_value("video", "render_scale", 0.75)
	SettingsManager.load_config()
	assert_almost_eq(float(SettingsManager.get_value("video", "render_scale")), 0.75, 0.0001,
		"a graphics option persists across save → reload")

func test_new_defaults_present() -> void:
	SettingsManager.reset_to_defaults()
	assert_eq(SettingsManager.get_value("gameplay", "reduce_flashing"),
		SettingsManager.DEFAULTS["gameplay"]["reduce_flashing"],
		"the added accessibility keys ship with schema defaults")
