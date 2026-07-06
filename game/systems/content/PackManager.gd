extends RefCounted
class_name PackManager
## Content-pack loader (task 19, FR-19-4). Pure static — discovers `res://game/packs/<id>/pack.json`
## bundles, tracks their enable state in `user://packs.json` (deliberately *outside* the save slots so a
## disabled pack can never brick a slot and the state survives save deletion), and hands
## `Content._make()` each enabled pack's category folders so its content flows into the same registries
## by id with **zero core code change**. Packs are **add-only** — the core folder is scanned first, so
## first-writer-wins (ContentRegistry) means a pack can never silently override a base id (override is
## deferred). Reached as the global `PackManager` (like Services/HideoutManifest); no 11th autoload.
## See docs/CONTENT_PACKS.md and docs/tasks/19_expansion_framework.md. TODO[19].

const DEFAULT_PACK_ROOT := "res://game/packs"
const DEFAULT_STATE_PATH := "user://packs.json"

# Roots + state path are swappable for tests (configure/reset) so CI never touches a dev's real packs.
static var _roots: Array[String] = [DEFAULT_PACK_ROOT]
static var _state_path: String = DEFAULT_STATE_PATH
static var _manifests: Array = []        ## Array[Dictionary] — discovered pack.json + injected "_dir"
static var _enabled: Dictionary = {}     ## pack_id (String) -> bool
static var _scanned: bool = false

# --- Discovery -------------------------------------------------------------
static func _ensure_scanned() -> void:
	if not _scanned:
		_scan()

## Force a fresh disk scan (e.g. after dropping a pack folder in while the editor is open).
static func rescan() -> void:
	_scanned = false
	_ensure_scanned()

static func _scan() -> void:
	_manifests.clear()
	for root in _roots:
		_scan_root(root)
	_load_state()
	_scanned = true

static func _scan_root(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return # no packs/ folder yet is fine
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var m := _read_manifest(root.path_join(entry).path_join("pack.json"))
			if not m.is_empty():
				m["_dir"] = root.path_join(entry)
				_manifests.append(m)
		entry = dir.get_next()
	dir.list_dir_end()

static func _read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and String(data.get("id", "")) != "":
		return data
	if data != null:
		push_warning("PackManager: invalid pack manifest (missing id) at %s" % path)
	return {}

# --- Enable state (user://packs.json) --------------------------------------
static func _load_state() -> void:
	_enabled.clear()
	if FileAccess.file_exists(_state_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_state_path))
		if data is Dictionary and data.get("enabled") is Dictionary:
			for k in data["enabled"]:
				_enabled[String(k)] = bool(data["enabled"][k])
	# Any installed pack with no saved preference defaults to its manifest's default_enabled (true).
	for m in _manifests:
		var id := String(m.get("id", ""))
		if id != "" and not _enabled.has(id):
			_enabled[id] = bool(m.get("default_enabled", true))

static func _save_state() -> void:
	var f := FileAccess.open(_state_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"enabled": _enabled}, "\t"))
		f.close()

# --- Public API ------------------------------------------------------------
## All discovered pack manifests (each a Dictionary with its "_dir"). A copy — safe to iterate.
static func installed() -> Array:
	_ensure_scanned()
	return _manifests.duplicate()

static func is_enabled(id) -> bool:
	_ensure_scanned()
	return bool(_enabled.get(String(id), false))

## Toggle a pack, persist the choice, and rebuild the registries live so the change is visible at once.
static func set_enabled(id, on: bool) -> void:
	_ensure_scanned()
	_enabled[String(id)] = on
	_save_state()
	if Content != null:
		Content.reload()

## The enabled packs' root folders (used by the demo sandbox for a manifest readout).
static func enabled_pack_dirs() -> Array[String]:
	_ensure_scanned()
	var out: Array[String] = []
	for m in _manifests:
		if bool(_enabled.get(String(m.get("id", "")), false)):
			out.append(String(m.get("_dir", "")))
	return out

## Scan-hook for Content._make(): every enabled pack's <key>/ subfolder that exists on disk. The pack
## subfolder is named by the registry key (loot/, gear/, sections/, …) — author-intuitive.
static func tres_dirs_for(key: StringName) -> Array[String]:
	_ensure_scanned()
	var out: Array[String] = []
	var sub := String(key)
	for m in _manifests:
		if bool(_enabled.get(String(m.get("id", "")), false)):
			var d: String = String(m.get("_dir", "")).path_join(sub)
			if DirAccess.dir_exists_absolute(d):
				out.append(d)
	return out

## Scan-hook for Content._make(): every enabled pack's <key>.json bulk file (parity with core JSON).
static func json_files_for(key: StringName) -> Array[String]:
	_ensure_scanned()
	var out: Array[String] = []
	var fname := String(key) + ".json"
	for m in _manifests:
		if bool(_enabled.get(String(m.get("id", "")), false)):
			var f: String = String(m.get("_dir", "")).path_join(fname)
			if FileAccess.file_exists(f):
				out.append(f)
	return out

# --- Test seam -------------------------------------------------------------
## Point discovery at temp roots + a temp state file so tests never touch the real user://packs.json.
static func configure(pack_roots: Array, state_path: String) -> void:
	_roots = []
	for r in pack_roots:
		_roots.append(String(r))
	_state_path = state_path
	_scanned = false
	_manifests.clear()
	_enabled.clear()

## Restore production defaults (real packs/ root + user://packs.json).
static func reset() -> void:
	_roots = [DEFAULT_PACK_ROOT]
	_state_path = DEFAULT_STATE_PATH
	_scanned = false
	_manifests.clear()
	_enabled.clear()
