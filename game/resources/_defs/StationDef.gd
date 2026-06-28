extends Resource
class_name StationDef
## Hideout station manifest entry. Adding a station = add a StationDef + scene,
## with NO edits to a central switch. See docs/tasks/13_hideout_stations.md, GDD §6.2.

@export var id: StringName
@export var display_name: String
@export var scene_path: String
@export var unlock_legacy_cost: int = 0
@export var unlock_special_loot: StringName = &""
@export var ui_hooks: Dictionary = {}
