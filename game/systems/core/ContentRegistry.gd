extends RefCounted
class_name ContentRegistry
## Generic content index. Scans folders of a given `*Def` type (`.tres`) plus any
## bulk `data/*.json`, and indexes instances by their `id`. Systems look content up
## by id, so a new file appears automatically with zero code edits.
## See docs/tasks/02_core_architecture.md (FR-02-3..5).

var def_script: GDScript                     ## the *Def class scanned/hydrated (e.g. LootDef)
var tres_dirs: Array[String] = []            ## res://.../<category>/ folders of .tres
var json_files: Array[String] = []           ## explicit data/*.json sources (type-unambiguous)

var _by_id: Dictionary = {}                  ## StringName -> Resource (Def instance)
var duplicate_ids: Array[StringName] = []    ## ids seen more than once (first writer wins)

func _init(p_def_script: GDScript, p_tres_dirs: Array = [], p_json_files: Array = []) -> void:
	def_script = p_def_script
	for d in p_tres_dirs:
		tres_dirs.append(String(d))
	for f in p_json_files:
		json_files.append(String(f))

## (Re)build the index from disk. Safe to call repeatedly.
func scan() -> void:
	_by_id.clear()
	duplicate_ids.clear()
	for dir_path in tres_dirs:
		_scan_tres_dir(dir_path)
	for file_path in json_files:
		_scan_json_file(file_path)

# --- Lookups -------------------------------------------------------------
## Named `get_def` (not `get`) to avoid shadowing the native Object.get().
func get_def(id) -> Resource:
	return _by_id.get(StringName(id))

func has(id) -> bool:
	return _by_id.has(StringName(id))

func all() -> Array:
	return _by_id.values()

func ids() -> Array:
	return _by_id.keys()

func size() -> int:
	return _by_id.size()

## Defs that declare a `tags` array containing `tag`. Property-based — never branches
## on id; returns empty for def types without a `tags` field.
func filter(tag) -> Array:
	var want := StringName(tag)
	var out: Array = []
	for res in _by_id.values():
		var tags = res.get("tags")
		if tags is Array and want in tags:
			out.append(res)
	return out

# --- Scanning ------------------------------------------------------------
func _scan_tres_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return # a missing/empty category folder (only .gitkeep yet) is fine
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and (entry.ends_with(".tres") or entry.ends_with(".res")):
			var res := ResourceLoader.load(dir_path.path_join(entry))
			if res is Resource:
				_index(res)
		entry = dir.get_next()
	dir.list_dir_end()

func _scan_json_file(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if data is Array:
		for obj in data:
			if obj is Dictionary:
				_index(_hydrate(obj))
	elif data is Dictionary:
		_index(_hydrate(data))
	else:
		push_warning("ContentRegistry: could not parse JSON %s" % file_path)

func _index(res: Resource) -> void:
	if res == null:
		return
	var id: StringName = StringName(res.get("id"))
	if String(id).is_empty():
		push_warning("ContentRegistry: def missing 'id' in %s" % def_script.resource_path)
		return
	if _by_id.has(id):
		if not duplicate_ids.has(id):
			duplicate_ids.append(id)
		push_warning("ContentRegistry: duplicate id '%s' ignored (first writer wins)" % id)
		return
	_by_id[id] = res

# --- JSON hydration ------------------------------------------------------
## Build a Def from a JSON object: assign declared properties, coercing enum-name
## strings ("SMALL" -> Tier.SMALL) to ints. Id-reference arrays (e.g. ArchetypeDef
## .loot_table, an Array[LootDef]) are left empty for consumers to resolve (task 11).
func _hydrate(obj: Dictionary) -> Resource:
	var res: Resource = def_script.new()
	var prop_types := {}
	for p in res.get_property_list():
		prop_types[p.name] = p.type
	for key in obj:
		if not prop_types.has(key):
			continue # unknown JSON key (e.g. authoring "notes") — ignore
		var prop_type: int = prop_types[key]
		var value: Variant = obj[key]
		if prop_type == TYPE_ARRAY:
			var current = res.get(key)
			if current is Array and current.get_typed_builtin() == TYPE_OBJECT:
				continue # typed resource array referenced by id — resolved later
		elif value is String and prop_type == TYPE_INT:
			value = _resolve_enum(value)
		res.set(key, value)
	return res

## Map an enum member name to its int by searching the def script's enum constant
## maps. Returns the original string if unmatched (set() then surfaces the mismatch).
func _resolve_enum(member: String) -> Variant:
	var consts := def_script.get_script_constant_map()
	for const_name in consts:
		var c = consts[const_name]
		if c is Dictionary and c.has(member):
			return c[member]
	return member
