extends RefCounted
class_name Palette
## Master world material set + locked palette (task 18 / FR-18-2). The single place the mission
## realizer (MissionController), the section/prop prefabs and the Bank showcase read their surface +
## actor role-tint materials, so the mixed CC0 kits share one grounded, stealth-readable look and a
## recolor is a single edit. The authored master StandardMaterial3D set lives as .tres in
## game/assets/materials/ (per docs/ASSET_PIPELINE.md); this is the code accessor with a flat fallback
## so it never hard-fails when a .tres is missing (the UITheme philosophy). Pure presentation — no
## gameplay logic, no autoload deps. See docs/tasks/18_art_asset_pipeline.md.

# --- Locked palette (grounded, low-saturation; tuned so cast shadows stay dark + readable for stealth) --
const FLOOR := Color(0.62, 0.63, 0.66)
const WALL := Color(0.55, 0.53, 0.50)
const TRIM := Color(0.30, 0.31, 0.34)
const METAL := Color(0.28, 0.30, 0.33)
const WOOD := Color(0.34, 0.21, 0.12)
const GLASS := Color(0.55, 0.72, 0.82, 0.30)
const ACCENT := Color(0.72, 0.56, 0.20)          ## brass / gold trim + objective
const SHADOW := Color(0.06, 0.07, 0.09)          ## deep-shadow surfaces
const SIGNAL_OK := Color(0.20, 0.70, 0.32)       ## drop point
const SIGNAL_DANGER := Color(0.85, 0.28, 0.28)   ## escape

# --- Actor role tints — mirror the MissionController reads so threats stay legible (FR-15-7 / stealth) --
const TINT_GUARD := Color(0.20, 0.35, 0.78)      ## regular guard — blue
const TINT_KEYCARRIER := Color(0.90, 0.72, 0.12) ## keycard/key holder (the Inspector) — gold
const TINT_CIVILIAN := Color(0.10, 0.75, 0.80)   ## non-hostile — cyan

## Named master material → authored .tres path (the master set kept in game/assets/materials/).
const _PATHS := {
	&"floor": "res://game/assets/materials/floor.tres",
	&"wall": "res://game/assets/materials/wall.tres",
	&"trim": "res://game/assets/materials/trim.tres",
	&"metal": "res://game/assets/materials/metal.tres",
	&"wood": "res://game/assets/materials/wood.tres",
	&"glass": "res://game/assets/materials/glass.tres",
	&"accent": "res://game/assets/materials/accent.tres",
	&"shadow": "res://game/assets/materials/shadow.tres",
	&"drop": "res://game/assets/materials/drop.tres",
	&"escape": "res://game/assets/materials/escape.tres",
}
## Flat fallback colour per name — used only if the .tres fails to load, so material() never returns null.
const _FALLBACK := {
	&"floor": FLOOR, &"wall": WALL, &"trim": TRIM, &"metal": METAL, &"wood": WOOD,
	&"glass": GLASS, &"accent": ACCENT, &"shadow": SHADOW, &"drop": SIGNAL_OK, &"escape": SIGNAL_DANGER,
}

static var _cache: Dictionary = {}

## The shared master material for `name` (built/loaded once, cached). Loads the authored .tres; on any
## miss returns a flat palette-coloured material so callers never hard-fail. Treat the result as
## read-only + shared (assign to material_override, don't mutate).
static func material(name: StringName) -> StandardMaterial3D:
	if _cache.has(name):
		return _cache[name]
	var m: StandardMaterial3D = null
	var path: String = _PATHS.get(name, "")
	if path != "" and ResourceLoader.exists(path):
		m = load(path) as StandardMaterial3D
	if m == null:
		m = _flat(_FALLBACK.get(name, WALL))
	_cache[name] = m
	return m

## A fresh flat palette-coloured material for an arbitrary tint (actor role tints, ad-hoc markers).
## Not cached — the caller owns it and may keep it per-instance.
static func tinted(color: Color) -> StandardMaterial3D:
	return _flat(color)

## Every registered master-material name — lets a smoke test assert the whole set resolves.
static func names() -> Array:
	return _PATHS.keys()

static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
