extends GutTest
## Spec: write settings -> reload -> values match defaults/overrides; settings
## persist via ConfigFile independent of save slots (FR-01-4).
## docs/tasks/01_project_setup.md.

const TEST_PATH := "user://test_settings.cfg"
var _orig_path: String

func before_all() -> void:
	# Redirect I/O at a throwaway file so the suite never touches the developer's
	# real user://settings.cfg.
	_orig_path = SettingsManager.config_path
	SettingsManager.config_path = TEST_PATH

func after_all() -> void:
	# Drop the temp file and restore the real path for the rest of the session.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	SettingsManager.config_path = _orig_path

func test_defaults_present_on_fresh_load() -> void:
	SettingsManager.reset_to_defaults()
	SettingsManager.load_config()
	assert_eq(SettingsManager.get_value("audio", "master"),
		SettingsManager.DEFAULTS["audio"]["master"],
		"Fresh load yields the default master volume")

func test_override_survives_reload() -> void:
	SettingsManager.set_value("audio", "music", 0.25)  # applies + writes to disk
	SettingsManager.load_config()                              # rebuild purely from disk
	assert_almost_eq(float(SettingsManager.get_value("audio", "music")), 0.25, 0.0001,
		"An overridden value must persist across a save -> reload cycle")

func test_partial_file_still_yields_complete_set() -> void:
	# Even after overriding one key, untouched keys keep their defaults.
	SettingsManager.set_value("gameplay", "invert_y", true)
	SettingsManager.load_config()
	assert_eq(SettingsManager.get_value("gameplay", "mouse_sensitivity"),
		SettingsManager.DEFAULTS["gameplay"]["mouse_sensitivity"],
		"Untouched keys fall back to defaults after a partial-override reload")

func test_unknown_key_returns_null() -> void:
	assert_null(SettingsManager.get_value("audio", "nonexistent"),
		"Unknown keys return null rather than crashing")
