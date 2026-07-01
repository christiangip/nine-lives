extends RefCounted
class_name Bag
## A single bagged unit of loose loot (GDD §10.3: "loose loot (cash, gold) needs bagging
## first"). Aggregates the weight/volume/value of everything stuffed into it so it can be
## carried, thrown, and landed-in-a-Drop-Point as ONE discrete object — the concrete unit
## FR-08-4's throwing (and Inventory.release_bag_for_throw/DropPoint.receive_bag) acts on.
## See docs/tasks/08_loot_inventory.md (FR-08-3/4).

var contents: Array[LootDef] = []

func add(loot: LootDef) -> void:
	contents.append(loot)

func total_weight() -> float:
	var w := 0.0
	for l in contents:
		w += l.weight
	return w

func total_volume() -> float:
	var v := 0.0
	for l in contents:
		v += l.volume
	return v

func total_value() -> int:
	var v := 0
	for l in contents:
		v += l.value
	return v

## Non-empty special_hook ids across contents (FR-08-9), in case a SPECIAL-tier item is ever
## bagged (unusual, but not disallowed by any FR).
func special_hooks() -> Array[StringName]:
	var out: Array[StringName] = []
	for l in contents:
		if l.special_hook != &"":
			out.append(l.special_hook)
	return out

func is_empty() -> bool:
	return contents.is_empty()
