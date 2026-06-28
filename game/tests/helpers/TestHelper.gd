extends Node
class_name TestHelper
## Shared helpers/fixtures for GUT tests (build dummy loot, fake guards, seeds).

static func make_loot(weight: float, volume: float, value: int = 100) -> LootDef:
	var l := LootDef.new()
	l.weight = weight; l.volume = volume; l.value = value
	return l
