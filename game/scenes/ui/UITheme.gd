extends RefCounted
class_name UITheme
## Shared UI theme + palette for every task-15 surface (Main Menu, slot popup, Options, Pause, Results,
## HUD, Hideout + station panels). Built in code: body/menu text uses Godot's readable built-in sans
## (the theme's default font is deliberately left unset — misc-fixes-2 issue 1), while the Kenney Future
## display face is reserved for large headings via style_title(). Buttons and every menu widget share the
## flat "understated outline" scheme (issue 2): dark background in every state; keyboard/gamepad focus IS
## the selected look — a bright gold border + white text. This is the house pattern (all menus build their
## chrome in code); centralizing it here keeps the look consistent. Pure presentation — no gameplay logic,
## no autoload deps. See docs/tasks/15_ui_hud_menus.md and misc-fixes-2.md.

const FONT_PATH := "res://game/assets/fonts/KenneyFuture.ttf"

# --- Shared palette (presentation constants, like the greyboxes' inline colors) ----------------
const BG := Color(0.07, 0.08, 0.10)
const PANEL_BG := Color(0.11, 0.13, 0.17, 0.98)
const ACCENT := Color(0.45, 0.72, 1.0)          ## headings / focus
const CURRENCY := Color(1.0, 0.85, 0.4)         ## Legacy/Take/Notoriety readouts
const MUTED := Color(0.62, 0.67, 0.74)          ## sub-labels
const WARN := Color(0.95, 0.45, 0.4)            ## requirements / danger / carry-full
const OK := Color(0.45, 0.85, 0.5)              ## affordable / secured
const TEXT := Color(0.90, 0.92, 0.96)

# Understated-outline widget scheme (misc-fixes-2 issue 2). Dark bg in every state; the focused/selected
# state pops with a bright FOCUS_BORDER edge (reuses the heist gold CURRENCY — no near-duplicate colour).
const HEADING_SIZE := 34                        ## default style_title() size for screen headings
const BTN_BG := Color(0.12, 0.14, 0.18, 0.96)
const BTN_BG_HOVER := Color(0.16, 0.19, 0.24, 0.98)
const BTN_BG_PRESSED := Color(0.10, 0.12, 0.16, 1.0)
const BTN_BG_DISABLED := Color(0.10, 0.11, 0.13, 0.85)
const FOCUS_BORDER := CURRENCY                  ## the distinctive "selected" edge
const EDGE_FAINT := Color(1, 1, 1, 0.10)        ## resting outline on unselected widgets
const TEXT_UNSELECTED := Color(0.74, 0.78, 0.84)  ## brighter than MUTED — unselected still reads

# Detection-state colour band (grey→yellow→orange→red). Indexed by DetectionSensor.DetectionState.
const DETECTION_COLORS := [
	Color(0.60, 0.64, 0.70),   # UNAWARE  — grey
	Color(0.95, 0.85, 0.30),   # SUSPICIOUS — yellow
	Color(0.98, 0.60, 0.20),   # SEARCHING — orange
	Color(0.95, 0.25, 0.22),   # ALERTED  — red
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
]
const DETECTION_COLORS_DEUT := [
	Color(0.55, 0.58, 0.62),   # grey
	Color(0.20, 0.50, 0.95),   # blue
	Color(0.45, 0.72, 0.98),   # light blue
	Color(0.99, 0.80, 0.15),   # yellow
]
const DETECTION_COLORS_TRIT := [
	Color(0.58, 0.60, 0.60),   # grey
	Color(0.20, 0.80, 0.80),   # teal/cyan
	Color(0.95, 0.50, 0.60),   # pink
	Color(0.96, 0.22, 0.26),   # red
]

static var _theme: Theme = null

## The shared Theme (built once, cached). Apply to any Control root: `control.theme = UITheme.build()`.
static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	# No default_font: body/menu text falls back to Godot's clean built-in sans (readability, issue 1).
	# The Kenney display face is applied per-heading via style_title().
	t.default_font_size = 18

	_style_buttonlike(t, "Button")
	_style_buttonlike(t, "OptionButton")   # own theme type — doesn't inherit "Button" entries
	_style_buttonlike(t, "MenuButton")

	# Panels: flat dark + subtle border, cohesive with the outline buttons.
	var panel := _outline(PANEL_BG, EDGE_FAINT, 1)
	panel.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_color("font_color", "Label", TEXT)

	# TabContainer (Options): selected tab = accent border + bright text; unselected = dark + soft.
	var tab_sel := _outline(BTN_BG_HOVER, FOCUS_BORDER, 2)
	tab_sel.set_content_margin_all(8)
	var tab_un := _outline(BTN_BG, EDGE_FAINT, 1)
	tab_un.set_content_margin_all(8)
	var tab_hov := _outline(BTN_BG_HOVER, Color(ACCENT, 0.5), 1)
	tab_hov.set_content_margin_all(8)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_hov)
	t.set_stylebox("tab_disabled", "TabContainer", _outline(BTN_BG_DISABLED, EDGE_FAINT, 1))
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_stylebox("tabbar_background", "TabContainer", _outline(BG, Color(0, 0, 0, 0), 0))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", TEXT_UNSELECTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	# PopupMenu (OptionButton dropdowns): dark list, accent-highlighted hovered item.
	t.set_stylebox("panel", "PopupMenu", _outline(BTN_BG, EDGE_FAINT, 1))
	t.set_stylebox("hover", "PopupMenu", _outline(BTN_BG_HOVER, Color(ACCENT, 0.5), 1))
	t.set_color("font_color", "PopupMenu", TEXT_UNSELECTED)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", MUTED)

	# Toggles + fields: readable text and a visible gold focus ring (styleboxes stay engine-default).
	for toggle_type in ["CheckButton", "CheckBox"]:
		t.set_color("font_color", toggle_type, TEXT_UNSELECTED)
		t.set_color("font_hover_color", toggle_type, TEXT)
		t.set_color("font_focus_color", toggle_type, Color.WHITE)
		t.set_color("font_pressed_color", toggle_type, TEXT)
		t.set_color("font_disabled_color", toggle_type, MUTED)
		t.set_stylebox("focus", toggle_type, _focus_ring())
	t.set_stylebox("normal", "LineEdit", _outline(BTN_BG, EDGE_FAINT, 1))
	t.set_stylebox("focus", "LineEdit", _outline(BTN_BG_HOVER, FOCUS_BORDER, 2))
	t.set_color("font_color", "LineEdit", TEXT)

	_theme = t
	return _theme

static func font() -> Font:
	var f := load(FONT_PATH)
	return f as Font

## Apply the KenneyFuture heading face + size to a title label (issue 1: identity stays on large
## headings; body text is the readable built-in sans). Safe when the font is missing (headless).
static func style_title(label: Label, size: int = HEADING_SIZE) -> void:
	var f := font()
	if f != null:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", size)

# --- StyleBox helpers ----------------------------------------------------------
## The full understated-outline state set + font colors for a Button-like theme type.
static func _style_buttonlike(t: Theme, theme_type: String) -> void:
	t.set_stylebox("normal", theme_type, _outline(BTN_BG, EDGE_FAINT, 1))
	t.set_stylebox("hover", theme_type, _outline(BTN_BG_HOVER, Color(ACCENT, 0.5), 1))
	t.set_stylebox("focus", theme_type, _outline(BTN_BG_HOVER, FOCUS_BORDER, 2))
	t.set_stylebox("pressed", theme_type, _outline(BTN_BG_PRESSED, FOCUS_BORDER, 1))
	t.set_stylebox("disabled", theme_type, _outline(BTN_BG_DISABLED, EDGE_FAINT, 1))
	t.set_color("font_color", theme_type, TEXT_UNSELECTED)
	t.set_color("font_hover_color", theme_type, TEXT)
	t.set_color("font_focus_color", theme_type, Color.WHITE)
	t.set_color("font_pressed_color", theme_type, Color.WHITE)
	t.set_color("font_disabled_color", theme_type, MUTED)

## A flat understated-outline box: dark `bg` behind a `width`-px `border` edge (the issue-2 scheme).
static func _outline(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = border
	sb.set_border_width_all(width)
	return sb

## A border-only gold ring for focus on widgets whose resting look stays engine-default (toggles).
static func _focus_ring() -> StyleBoxFlat:
	var sb := _outline(Color(0, 0, 0, 0), FOCUS_BORDER, 2)
	sb.draw_center = false
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
