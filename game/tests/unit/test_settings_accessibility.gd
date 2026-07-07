extends GutTest
## Task 21 FR-21-1: each accessibility option changes the intended runtime value and persists. Covers the
## colorblind palette swap (UITheme + CompassEye), the language scaffold (locale + tr), reduce-flashing (read
## by the noise ring), controller vibration (Haptics gate), aim-assist persistence, and confirms the dead
## Motion Blur toggle was removed. Mirrors test_settings_roundtrip's temp-file redirect so the developer's
## real settings.cfg is never touched. See docs/tasks/21_release_polish.md.

const TEST_PATH := "user://test_access21.cfg"
var _orig_path: String
var _orig_locale: String

func before_all() -> void:
	_orig_path = SettingsManager.config_path
	SettingsManager.config_path = TEST_PATH
	_orig_locale = TranslationServer.get_locale()

func after_all() -> void:
	# Restore the real config path and reload from it so our in-memory test mutations are dropped WITHOUT
	# writing to the developer's real settings.cfg, then restore the original locale.
	SettingsManager.config_path = _orig_path
	SettingsManager.load_config()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	TranslationServer.set_locale(_orig_locale)

func test_motion_blur_removed_from_schema() -> void:
	assert_false(SettingsManager.DEFAULTS["video"].has("motion_blur"),
		"the non-functional Motion Blur toggle was removed for release (no setting that does nothing)")

func test_colorblind_palette_differs_per_mode() -> void:
	var mid := 1   # SUSPICIOUS band
	var base: Color = UITheme.detection_color_for(mid, 0)
	assert_ne(UITheme.detection_color_for(mid, 1), base, "protanopia remaps the detection band")
	assert_ne(UITheme.detection_color_for(mid, 2), base, "deuteranopia remaps the detection band")
	assert_ne(UITheme.detection_color_for(mid, 3), base, "tritanopia remaps the detection band")
	# The compass-eye visual seam threads the mode through to the colour used on screen.
	assert_eq(CompassEye.detection_visual(3, 0.9, 3)["color"], UITheme.detection_color_for(3, 3),
		"CompassEye uses the colorblind-adjusted colour for the active mode")
	# Mode 0 (and the legacy no-arg call) stays the default band, so existing HUD tests are unaffected.
	assert_eq(UITheme.detection_color_for(mid, 0), UITheme.detection_color(mid),
		"mode 0 is the default palette")

func test_colorblind_persists() -> void:
	SettingsManager.set_value("gameplay", "colorblind", 3)
	SettingsManager.load_config()
	assert_eq(int(SettingsManager.get_value("gameplay", "colorblind")), 3,
		"the colorblind mode persists across save → reload")

func test_language_applies_and_translates() -> void:
	SettingsManager.set_value("gameplay", "language", "es")   # set_value → _apply_gameplay → set_locale
	assert_true(TranslationServer.get_locale().begins_with("es"), "the locale switched to Spanish")
	assert_eq(tr("MENU_NEW_GAME"), "Nuevo Juego", "keyed UI text translates to the active locale")
	SettingsManager.set_value("gameplay", "language", "en")
	assert_eq(tr("MENU_NEW_GAME"), "New Game", "switching back returns the English source string")

func test_language_persists() -> void:
	SettingsManager.set_value("gameplay", "language", "fr")
	SettingsManager.load_config()
	assert_eq(String(SettingsManager.get_value("gameplay", "language")), "fr",
		"the chosen language persists across save → reload")

func test_vibration_gate_reads_setting() -> void:
	SettingsManager.set_value("gameplay", "vibration", false)
	assert_false(Haptics.enabled(), "Haptics is gated OFF when Controller Vibration is disabled")
	SettingsManager.set_value("gameplay", "vibration", true)
	assert_true(Haptics.enabled(), "Haptics is enabled when Controller Vibration is on")

func test_reduce_flashing_read_by_noise_ring() -> void:
	var ring := NoiseRingSpawner.new()
	add_child_autofree(ring)
	SettingsManager.set_value("gameplay", "reduce_flashing", true)
	assert_true(ring.reduce_flashing(), "the on-world noise ring honours Reduce Flashing")
	SettingsManager.set_value("gameplay", "reduce_flashing", false)
	assert_false(ring.reduce_flashing(), "…and clears it when the option is off")

func test_camera_shake_default_on() -> void:
	assert_true(bool(SettingsManager.DEFAULTS["video"]["camera_shake"]),
		"camera shake ships on by default (players opt out)")

func test_aim_assist_persists() -> void:
	SettingsManager.set_value("gameplay", "aim_assist", true)
	SettingsManager.load_config()
	assert_true(bool(SettingsManager.get_value("gameplay", "aim_assist")),
		"the aim-assist option persists across save → reload")
