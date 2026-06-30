extends Node
class_name TestHelper
## Shared helpers/fixtures for GUT tests (build dummy loot, fake guards, seeds).

static func make_loot(weight: float, volume: float, value: int = 100) -> LootDef:
	var l := LootDef.new()
	l.weight = weight; l.volume = volume; l.value = value
	return l

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
