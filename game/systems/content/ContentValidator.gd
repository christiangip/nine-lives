extends RefCounted
class_name ContentValidator
## Content-sanity sweep for the expansion framework (task 19, FR-19-3). A pure static, headless-safe
## superset of EconomyValidator: on top of the economy value/cost/curve range checks it verifies every
## def has a present, lowercase_snake, unique id, that required fields are filled, and that its
## cross-reference fields point at real content (no dangling ids). Returns human-readable violation
## strings (empty = everything sane). test_content_validator asserts empty on the base game + proves it
## is not a rubber stamp; the CLI (tools/scripts/validate_content.sh), an EditorScript, and CI all call
## it. Data-driven: it branches on a def's *field* + target registry via the REQUIRED/REFERENCES tables,
## never on a content id. See docs/tasks/19_expansion_framework.md and docs/AUTHORING.md. TODO[19].

const SN := 0   ## a StringName id field
const ARR := 1  ## an Array[StringName] id field

## Every registry key (mirrors Content._build). Used for the universal id / uniqueness sweep.
const REGISTRY_KEYS: Array[StringName] = [
	&"loot", &"gear", &"edges", &"perks", &"archetypes", &"objectives", &"modifiers",
	&"enemies", &"attributes", &"stations", &"intel", &"detection", &"ai", &"obstacles",
	&"minigames", &"loadout", &"pursuit", &"sections", &"progression", &"economy", &"audio",
	&"milestones",
]

## registry key -> String fields that must be non-empty (id is checked on every def separately). Kept
## deliberately small + true; extend a row here to require more (that extensibility is the whole point).
const REQUIRED := {
	&"stations": [&"scene_path"],
}

## registry key -> id-reference fields to resolve. Only fields that are genuine registry-id references
## live here. Deliberately excluded (would false-positive): EnemyDef.carried_item / ObstacleDef
## .required_item (free-form *key-item* ids with no registry — matched by Inventory.has_item),
## ObstacleDef.valid_solutions (solution-kind ids), PerkDef.prerequisites (already checked by
## EconomyValidator), StationDef.unlock_special_loot (a LootDef *special_hook*, not an id). Empty ids in
## an array are "none" sentinels (e.g. PursuitConfigDef.tier_ladder phase 0) and are skipped.
const REFERENCES := {
	&"archetypes": [
		{"field": &"section_ids", "kind": ARR, "target": &"sections"},
		{"field": &"setpiece_ids", "kind": ARR, "target": &"sections"},
		{"field": &"objective_ids", "kind": ARR, "target": &"objectives"},
		{"field": &"modifier_pool", "kind": ARR, "target": &"modifiers"},
		{"field": &"enemy_roster", "kind": ARR, "target": &"enemies"},
		{"field": &"loot_ids", "kind": ARR, "target": &"loot"},
		{"field": &"unlock_milestone", "kind": SN, "target": &"milestones"},   # task 20: milestone gate (empty = ungated)
	],
	&"enemies": [
		{"field": &"loadout", "kind": ARR, "target": &"gear"},
	],
	&"pursuit": [
		{"field": &"tier_ladder", "kind": ARR, "target": &"enemies"},
	],
	# task 20 milestone arcs: the grant fields are genuine registry-id references. require_special_loot is
	# a LootDef *special_hook* (like StationDef.unlock_special_loot) so it's deliberately NOT listed here.
	&"milestones": [
		{"field": &"grant_stations", "kind": ARR, "target": &"stations"},
		{"field": &"grant_gear", "kind": ARR, "target": &"gear"},
		{"field": &"grant_archetypes", "kind": ARR, "target": &"archetypes"},
	],
}

static var _snake_re: RegEx = null

## Every content violation across the base game + any enabled packs (via the live Content autoload).
## Empty Array means everything passes. This is what the CLI + CI call.
static func validate() -> Array:
	var errors: Array = []
	errors.append_array(EconomyValidator.validate())   # reuse the value/cost/curve/perk-prereq half
	errors.append_array(validate_content(Services.content()))
	return errors

## The structural half (id present/format/unique, required fields, dangling references) over ANY Content
## node — not just the global. The editor tool (ValidateContentEditor) builds a transient Content and
## calls this so designers get in-editor feedback without the game's runtime autoloads. Economy-range
## checks (EconomyValidator) need the resolved economy config and stay CLI/CI-only.
static func validate_content(c) -> Array:
	var errors: Array = []
	if c == null:
		errors.append("Content autoload unavailable — cannot validate content tables")
		return errors
	_check_ids_and_required(c, errors)
	_check_duplicates(c, errors)
	_check_references(c, errors)
	return errors

# --- Sweeps ----------------------------------------------------------------
static func _check_ids_and_required(c, errors: Array) -> void:
	for key in REGISTRY_KEYS:
		var reg = c.registry(key)
		if reg == null:
			continue
		var required: Array = REQUIRED.get(key, [])
		for res in reg.all():
			if res == null:
				continue
			var id := StringName(res.get("id"))
			if String(id).is_empty():
				errors.append("%s: a def has an empty id (%s)" % [key, res.resource_path])
				continue
			if not _is_snake(String(id)):
				errors.append("%s '%s': id is not lowercase_snake" % [key, id])
			for field in required:
				var v = res.get(field)
				if v == null or (v is String and String(v).strip_edges().is_empty()):
					errors.append("%s '%s': required field '%s' is empty" % [key, id, field])

static func _check_duplicates(c, errors: Array) -> void:
	for key in REGISTRY_KEYS:
		var reg = c.registry(key)
		if reg == null:
			continue
		for dup in reg.duplicate_ids:
			errors.append("%s: duplicate id '%s' — only the first authored def was indexed" % [key, dup])

static func _check_references(c, errors: Array) -> void:
	for key in REFERENCES:
		var reg = c.registry(key)
		if reg == null:
			continue
		for res in reg.all():
			if res == null:
				continue
			var id := StringName(res.get("id"))
			for rule in REFERENCES[key]:
				var target_reg = c.registry(rule["target"])
				if target_reg == null:
					continue
				var field_val = res.get(rule["field"])
				if rule["kind"] == ARR:
					if field_val is Array:
						for ref in field_val:
							_check_ref(errors, key, id, rule, ref, target_reg)
				else:
					_check_ref(errors, key, id, rule, field_val, target_reg)

static func _check_ref(errors: Array, key: StringName, id: StringName, rule: Dictionary, ref, target_reg) -> void:
	var ref_id := StringName(ref)
	if String(ref_id).is_empty():
		return # empty id = an intentional "none" sentinel, not a dangling reference
	if not target_reg.has(ref_id):
		errors.append("%s '%s': %s -> unknown %s '%s'" % [key, id, rule["field"], rule["target"], ref_id])

# --- Helpers ---------------------------------------------------------------
static func _is_snake(s: String) -> bool:
	if _snake_re == null:
		_snake_re = RegEx.new()
		_snake_re.compile("^[a-z0-9_]+$")
	return _snake_re.search(s) != null
