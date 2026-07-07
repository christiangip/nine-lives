extends RefCounted
class_name UITheme
## Shared UI theme + palette for every task-15 surface (Main Menu, slot popup, Options, Pause, Results,
## HUD). Built in code from real imported assets — the Kenney Future font + the Kenney RPG UI kit
## (res://game/assets/ui/kit_rpg) button/panel textures as 9-slice StyleBoxes — with flat fallbacks so it
## never hard-fails if a texture is missing. This is the house pattern (Hideout.gd / StationPanel.gd build
## their chrome in code); centralizing it here keeps the look consistent and "uses the assets" (the F6
## instruction). Pure presentation — no gameplay logic, no autoload deps. See docs/tasks/15_ui_hud_menus.md.

const FONT_PATH := "res://game/assets/fonts/KenneyFuture.ttf"
const KIT_DIR := "res://game/assets/ui/kit_rpg"

# --- Shared palette (presentation constants, like the greyboxes' inline colors) ----------------
const BG := Color(0.07, 0.08, 0.10)
const PANEL_BG := Color(0.11, 0.13, 0.17, 0.98)
const ACCENT := Color(0.45, 0.72, 1.0)          ## headings / focus
const CURRENCY := Color(1.0, 0.85, 0.4)         ## Legacy/Take/Notoriety readouts
const MUTED := Color(0.62, 0.67, 0.74)          ## sub-labels
const WARN := Color(0.95, 0.45, 0.4)            ## requirements / danger / carry-full
const OK := Color(0.45, 0.85, 0.5)              ## affordable / secured
const TEXT := Color(0.90, 0.92, 0.96)

# Detection-state colour band (grey→yellow→orange→red). Indexed by DetectionSensor.DetectionState.
const DETECTION_COLORS := [
	Color(0.60, 0.64, 0.70),   # UNAWARE  — grey
	Color(0.95, 0.85, 0.30),   # SUSPICIOUS — yellow
	Color(0.98, 0.60, 0.20),   # SEARCHING — orange
	Color(0.95, 0.25, 0.22),   # ALERTED  — red
	Color(0.80, 0.10, 0.30),   # PURSUIT  — deep red
]

# Colorblind-adjusted detection bands (task 21, FR-21-1). Keyed by SettingsManager gameplay/colorblind
# (1 protanopia · 2 deuteranopia · 3 tritanopia). Red-green modes escalate along the blue↔yellow axis;
# the blue-yellow mode escalates along the cyan↔red axis. Every ramp keeps luminance rising with the state,
# so it reads even in full colour-blindness — and CompassEye's redundant ?/?!/!/!! symbol is a further cue.
const DETECTION_COLORS_PROT := [
	Color(0.55, 0.58, 0.62),   # grey
	Color(0.30, 0.55, 0.95),   # blue
	Color(0.40, 0.78, 0.98),   # cyan
	Color(0.98, 0.85, 0.20),   # yellow
	Color(1.00, 0.55, 0.05),   # amber
]
const DETECTION_COLORS_DEUT := [
	Color(0.55, 0.58, 0.62),   # grey
	Color(0.20, 0.50, 0.95),   # blue
	Color(0.45, 0.72, 0.98),   # light blue
	Color(0.99, 0.80, 0.15),   # yellow
	Color(1.00, 0.60, 0.10),   # amber
]
const DETECTION_COLORS_TRIT := [
	Color(0.58, 0.60, 0.60),   # grey
	Color(0.20, 0.80, 0.80),   # teal/cyan
	Color(0.95, 0.50, 0.60),   # pink
	Color(0.96, 0.22, 0.26),   # red
	Color(0.70, 0.05, 0.15),   # dark red
]

static var _theme: Theme = null

## The shared Theme (built once, cached). Apply to any Control root: `control.theme = UITheme.build()`.
static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f := font()
	if f != null:
		t.default_font = f
	t.default_font_size = 18

	# Buttons: Kenney "buttonLong" 9-slice, flat fallback. normal/hover/pressed/disabled/focus.
	var normal := _stylebox("%s/buttonLong_grey.png" % KIT_DIR, 8, Color(0.18, 0.22, 0.30, 0.95))
	var hover := _stylebox("%s/buttonLong_blue.png" % KIT_DIR, 8, Color(0.24, 0.34, 0.50, 0.98))
	var pressed := _stylebox("%s/buttonLong_blue_pressed.png" % KIT_DIR, 8, Color(0.20, 0.28, 0.42, 1.0))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", _flat(Color(0.14, 0.15, 0.18, 0.85)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)

	# Panels: Kenney "panel_blue" 9-slice, flat fallback.
	var panel := _stylebox("%s/panel_blue.png" % KIT_DIR, 18, PANEL_BG)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_color("font_color", "Label", TEXT)
	_theme = t
	return _theme

static func font() -> Font:
	var f := load(FONT_PATH)
	return f as Font

# --- StyleBox helpers ----------------------------------------------------------
## A 9-slice StyleBoxTexture from `path` with `margin` px borders + content padding, or a flat box in
## `fallback` if the texture can't load (headless / missing import).
static func _stylebox(path: String, margin: int, fallback: Color) -> StyleBox:
	var tex := load(path) as Texture2D
	if tex == null:
		return _flat(fallback)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = maxi(12, margin)
	sb.content_margin_right = maxi(12, margin)
	sb.content_margin_top = maxi(8, margin - 2)
	sb.content_margin_bottom = maxi(8, margin - 2)
	return sb

static func _flat(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	return sb

## Colour for a detection state (safe-indexed), default palette. Shared by the HUD compass-eye + any readout.
static func detection_color(state: int) -> Color:
	return detection_color_for(state, 0)

## Colour for a detection state under a colorblind `mode` (0 none · 1 protanopia · 2 deuteranopia ·
## 3 tritanopia). Safe-indexed. CompassEye passes the live gameplay/colorblind setting. Pure.
static func detection_color_for(state: int, mode: int) -> Color:
	var band: Array = DETECTION_COLORS
	match mode:
		1: band = DETECTION_COLORS_PROT
		2: band = DETECTION_COLORS_DEUT
		3: band = DETECTION_COLORS_TRIT
	return band[clampi(state, 0, band.size() - 1)]
