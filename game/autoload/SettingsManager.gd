extends Node
## SettingsManager — graphics/audio/gameplay options + ConfigFile persistence.
## Autoload (9th). Independent of save slots; reads/writes user://settings.cfg.
## Input rebinds live in the same file's [controls] section, owned by InputManager.
## See docs/tasks/01_project_setup.md (FR-01-3/4) and 15_ui_hud_menus.md.

## Default config path; a plain var (not const) so tests can redirect I/O at a
## throwaway user://test_*.cfg instead of clobbering the player's real settings.
var config_path := "user://settings.cfg"

## The schema and its defaults, grouped by ConfigFile section. The keys here ARE
## the contract — Options UI and gameplay read through get_value()/set_value().
const DEFAULTS := {
	"video": {
		"fullscreen": false,
		"vsync": true,
		"max_fps": 0,        # 0 = uncapped
		"msaa": 2,           # matches project.godot anti_aliasing/quality/msaa_3d
		"render_scale": 1.0, # 3D resolution scale (0.5..1.0), applied to the viewport
		"shadows": 2,        # 0 off · 1 low · 2 medium · 3 high (read on demand by the renderer)
		"fov": 75.0,         # camera field of view (deg); PlayerController reads it on settings_changed
		"gamma": 1.0,        # display gamma (read on demand)
		"camera_shake": true,  # FP camera shake on fire/damage/alarm (task 21; also gated by reduce_flashing)
	},
	"audio": {
		"master": 1.0,       # linear 0..1, applied as bus volume
		"music": 0.8,
		"sfx": 0.9,
		"ui": 0.9,           # UI SFX bus (falls back gracefully if the bus is absent)
		"ambience": 0.7,
		"subtitles": false,
	},
	"gameplay": {
		"mouse_sensitivity": 0.3,
		"invert_y": false,
		"ui_scale": 1.0,
		"crouch_toggle": false,  # false = hold to crouch; true = press to toggle (task 03)
		"sprint_toggle": false,  # false = hold to sprint; true = press to toggle (task 03)
		# Accessibility (GDD §15.2). Read on demand by the HUD / camera / input.
		"colorblind": 0,         # 0 none · 1 protanopia · 2 deuteranopia · 3 tritanopia
		"reduce_flashing": false,# HUD honours this (no flashing cues) — FR-15-7
		"aim_assist": false,
		"vibration": true,
		"language": "en",
	},
}

var _values: Dictionary = {}

func _ready() -> void:
	load_config()
	apply_all()

# --- public API ------------------------------------------------------------

func get_value(section: String, key: String) -> Variant:
	return _values.get(section, {}).get(key, _default(section, key))

## Set, apply immediately, persist, and announce — apply-on-change.
func set_value(section: String, key: String, value: Variant) -> void:
	if not _values.has(section):
		_values[section] = {}
	_values[section][key] = value
	_apply_section(section)
	save()
	EventBus.settings_changed.emit(section)

func reset_to_defaults() -> void:
	_values = _deep_copy(DEFAULTS)
	apply_all()
	save()

# --- persistence -----------------------------------------------------------

## Start from defaults, then overlay any values present in the config file so a
## partial or older file still yields a complete, valid set. Named `load_config`
## (not `load`) so it never collides with Godot's global `load()` utility.
func load_config() -> void:
	_values = _deep_copy(DEFAULTS)
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			if cfg.has_section_key(section, key):
				_values[section][key] = cfg.get_value(section, key)

## Persist all settings, preserving the [controls] section InputManager writes.
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(config_path)  # ignore error: missing file just means a fresh write
	for section in _values:
		for key in _values[section]:
			cfg.set_value(section, key, _values[section][key])
	cfg.save(config_path)

# --- apply -----------------------------------------------------------------

func apply_all() -> void:
	for section in _values:
		_apply_section(section)

func _apply_section(section: String) -> void:
	match section:
		"video":
			_apply_video()
		"audio":
			_apply_audio()
		"gameplay":
			_apply_gameplay()

func _apply_video() -> void:
	var fullscreen: bool = get_value("video", "fullscreen")
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var vsync: bool = get_value("video", "vsync")
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(get_value("video", "max_fps"))
	var vp := get_viewport()
	if vp != null:
		vp.msaa_3d = int(get_value("video", "msaa"))
		# Live-apply the 3D render scale where possible (FR-15-4). Shadows/gamma/motion-blur are
		# read on demand by the renderer/camera; fov is pushed to the player via settings_changed.
		vp.scaling_3d_scale = clampf(float(get_value("video", "render_scale")), 0.5, 1.0)

func _apply_audio() -> void:
	_set_bus_linear("Master", get_value("audio", "master"))
	_set_bus_linear("Music", get_value("audio", "music"))
	_set_bus_linear("SFX", get_value("audio", "sfx"))
	_set_bus_linear("UI", get_value("audio", "ui"))            # no-op if the bus doesn't exist
	_set_bus_linear("Ambience", get_value("audio", "ambience"))

func _set_bus_linear(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))

## Gameplay settings are mostly read on demand (camera/UI/input), but the UI language is a global side
## effect: push it to the TranslationServer via the localization scaffold (task 21, FR-21-1).
func _apply_gameplay() -> void:
	Localization.apply_locale(String(get_value("gameplay", "language")))

# --- helpers ---------------------------------------------------------------

func _default(section: String, key: String) -> Variant:
	return DEFAULTS.get(section, {}).get(key, null)

func _deep_copy(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[k] = (d[k].duplicate() if d[k] is Dictionary else d[k])
	return out
