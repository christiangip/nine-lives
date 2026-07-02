extends Node
class_name TestHelper
## Shared helpers/fixtures for GUT tests (build dummy loot, fake guards, seeds).

static func make_loot(weight: float, volume: float, value: int = 100) -> LootDef:
	var l := LootDef.new()
	l.weight = weight; l.volume = volume; l.value = value
	return l

## Build an off-registry GearDef for pure-seam tests (task 09).
static func make_gear(id: StringName, slot: int, cost: int = 1, params: Dictionary = {}) -> GearDef:
	var g := GearDef.new()
	g.id = id; g.slot = slot; g.slot_cost = cost; g.params = params
	return g

## Best-effort recursive delete of a temp directory + its files (for test teardown).
static func rm_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not d.current_is_dir():
			d.remove(entry)
		entry = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(dir)
