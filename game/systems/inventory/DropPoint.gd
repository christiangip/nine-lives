extends Interactable
class_name DropPoint
## Infinite-capacity loot bank inside the level (GDD §10.4). The moment carried value reaches a
## Drop Point, it's SECURED — locked into Notoriety/Take even if the player is later Caught
## (FR-08-5/6, the "secured loot" critical rule). secure_from()/receive_bag() are the pure
## banking seams: interact() (walking up + interacting) and a thrown Bag's landing (ThrownBag,
## on a real physics collision) both go through the exact same logic, so a headless GUT test can
## call receive_bag() directly with no physics simulation required.
## See docs/tasks/08_loot_inventory.md (FR-08-4, FR-08-5, FR-08-9).

func _ready() -> void:
	prompt = "Drop Off Loot"

func can_interact(by: Node) -> bool:
	var inv = by.get("inventory") if by != null else null
	return inv != null and inv.in_hand_value() > 0

## Thin glue: resolve the carrier's Inventory and bank everything it's holding.
func interact(by: Node) -> void:
	var inv = by.get("inventory") if by != null else null
	secure_from(inv)

## The pure banking seam given an Inventory directly (no Node/duck-typing needed) — both
## interact() and tests call this to exercise FR-08-5/6 headlessly.
func secure_from(inv: Inventory) -> Dictionary:
	if inv == null:
		return {"value": 0, "special_hooks": []}
	var result := inv.secure_all_carried()
	_bank_result(result)
	return result

## The thrown-bag-lands-here seam: `bag` is already detached from `thrower_inventory` (mid-
## flight), so its value banks into that Inventory's secured tally without re-entering carry.
func receive_bag(bag: Bag, thrower_inventory: Inventory) -> int:
	if bag == null or thrower_inventory == null:
		return 0
	var result := thrower_inventory.secure_bag(bag)
	_bank_result(result)
	return result["value"]

func _bank_result(result: Dictionary) -> void:
	var amount: int = result.get("value", 0)
	if amount > 0:
		DropPoint.bank(amount, "carried_haul")
	for hook in result.get("special_hooks", []):
		ProgressionManager.add_to_stash(hook)

## Shared banking effect: the frozen EventBus.loot_secured signal + real RunManager
## accumulation. Static (and tree-independent — no global_position read) so DropPoint and
## Escape call identical logic without inheriting from each other (they don't share a
## Def/solved state machine, only this arithmetic), and so it's callable headlessly from a
## bare DropPoint.new() with no scene tree.
static func bank(amount: int, loot_id: String) -> void:
	if amount <= 0:
		return
	EventBus.loot_secured.emit(loot_id, amount)
	RunManager.add_notoriety(amount)
	RunManager.add_take(amount)
