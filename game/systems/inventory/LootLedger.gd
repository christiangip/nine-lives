extends RefCounted
class_name LootLedger
## Minimal pure helper for Phase 08.4's "full-clear detection" (GDD §10.5: 100% completion as an
## aspiration). Deliberately NOT a scene-tracking tally/scanner — a live "every loot item placed
## in this level" registry is mission-flow infrastructure that belongs to task 11's
## MissionController (which listens to EventBus.loot_secured/carry_changed to build its own
## running total, per ARCHITECTURE.md). Task 08 only proves the boolean rule so 11 has something
## correct to call once it exists.
## See docs/tasks/08_loot_inventory.md (Phase 08.4).

## True iff every unit of value present at mission start has been secured. Pure. `total_value`
## and `secured_value` are both caller-supplied sums (task 11 assembles total_value at
## generation time; RunManager/Inventory tracks secured_value live).
static func is_full_clear(total_value: int, secured_value: int) -> bool:
	return total_value > 0 and secured_value >= total_value
