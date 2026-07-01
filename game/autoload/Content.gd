extends Node
## Content — content-registry hub (autoload). At boot it builds one ContentRegistry
## per *Def type, scanning game/resources/<category>/ (+ select data/*.json) and
## indexing by id, so new content appears with zero code edits. Reached as the
## autoload `Content` (no class_name, per the autoload convention).
## See docs/tasks/02_core_architecture.md (FR-02-3..5) and docs/ARCHITECTURE.md.

const CONTENT_SCHEMA_VERSION := 1   ## bump when a *Def schema changes (migration hook for 19/16)

const _RESOURCE_ROOT := "res://game/resources"
const _DATA_ROOT := "res://game/data"

# One registry per def type (FR-02-4). Populated in _ready().
var loot: ContentRegistry
var gear: ContentRegistry
var edges: ContentRegistry
var perks: ContentRegistry
var archetypes: ContentRegistry
var objectives: ContentRegistry
var modifiers: ContentRegistry
var enemies: ContentRegistry
var attributes: ContentRegistry
var stations: ContentRegistry
var intel: ContentRegistry
var detection: ContentRegistry
var ai: ContentRegistry
var obstacles: ContentRegistry
var minigames: ContentRegistry

var _registries: Dictionary = {}    ## StringName -> ContentRegistry

func _ready() -> void:
	_build()
	scan_all()

func _build() -> void:
	# Folder per def; explicit JSON files (not a data/*.json glob) keep the type unambiguous.
	loot = _make(&"loot", LootDef, "loot", [_DATA_ROOT.path_join("sample_loot.json")])
	gear = _make(&"gear", GearDef, "gear")
	edges = _make(&"edges", EdgeDef, "edges")
	perks = _make(&"perks", PerkDef, "perks")
	archetypes = _make(&"archetypes", ArchetypeDef, "archetypes",
		[_DATA_ROOT.path_join("sample_archetype_bank.json")])
	objectives = _make(&"objectives", ObjectiveDef, "objectives")
	modifiers = _make(&"modifiers", ModifierDef, "modifiers")
	enemies = _make(&"enemies", EnemyDef, "enemies")
	attributes = _make(&"attributes", AttributeDef, "attributes")
	stations = _make(&"stations", StationDef, "stations")
	intel = _make(&"intel", IntelDef, "intel")
	detection = _make(&"detection", DetectionConfigDef, "detection")
	ai = _make(&"ai", AIConfigDef, "ai")
	obstacles = _make(&"obstacles", ObstacleDef, "obstacles")   # heist obstacles (task 06)
	minigames = _make(&"minigames", MinigameConfigDef, "minigames")   # minigame tunables (task 07)

func _make(key: StringName, def_script: GDScript, folder: String, json_files: Array = []) -> ContentRegistry:
	var reg := ContentRegistry.new(def_script, [_RESOURCE_ROOT.path_join(folder)], json_files)
	_registries[key] = reg
	return reg

## Rescan every registry from disk (e.g. after authoring new content in-editor).
func scan_all() -> void:
	for reg in _registries.values():
		reg.scan()

## Registry for a def category by name (e.g. &"loot"), or null if unknown.
func registry(def_name) -> ContentRegistry:
	return _registries.get(StringName(def_name))

## One-shot lookup of a def by category + id. Named get_def (not get) to avoid
## shadowing the native Object.get().
func get_def(def_name, id) -> Resource:
	var reg := registry(def_name)
	return reg.get_def(id) if reg != null else null
