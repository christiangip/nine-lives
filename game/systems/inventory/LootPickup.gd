extends Interactable
class_name LootPickup
## World-placed loot (GDD §10.2/10.3): a Node3D wrapping a LootDef, collected on interact().
## Loose loot (needs_bagging) routes into the carrier's active Bag; pocketable loot is grabbed
## direct. Either being rejected by the two-axis cap (FR-08-1) leaves it in the world and emits
## a local pickup_rejected signal for HUD feedback (task 15) — mirrors Lock.pick_snapped/
## Obstacle.state_changed: a local signal, not a new (disallowed) EventBus one.
## See docs/tasks/08_loot_inventory.md (FR-08-1, FR-08-3).

signal pickup_rejected(axis: StringName)   ## local; HUD "full" feedback (task 15)

@export var def: LootDef
@export var def_id: StringName = &""   ## alt to inline def: look up Content.loot by id

var _consumed: bool = false

func _ready() -> void:
	_resolve_def()
	prompt = "Pick Up" if def == null or not def.needs_bagging else "Bag"

func _resolve_def() -> void:
	if def == null and not String(def_id).is_empty() and Content != null and Content.loot != null:
		def = Content.loot.get_def(def_id) as LootDef

func can_interact(_by: Node) -> bool:
	return not _consumed and def != null

## `by` must expose an `inventory: Inventory` property (PlayerController does). Routes to
## bag_loot() or pick_up_direct() by def.needs_bagging; either failing emits pickup_rejected
## with the specific axis so the HUD can say *why* pickup failed.
func interact(by: Node) -> void:
	if _consumed or def == null:
		return
	var inv = by.get("inventory") if by != null else null
	if inv == null:
		return
	var ok: bool = inv.bag_loot(def) if def.needs_bagging else inv.pick_up_direct(def)
	if not ok:
		pickup_rejected.emit(_reject_axis(inv))
		return
	_consumed = true
	EventBus.loot_picked_up.emit(String(def.id))
	EventBus.carry_changed.emit(inv.current_weight(), inv.current_volume())
	queue_free()

func _reject_axis(inv) -> StringName:
	if inv.current_weight() + def.weight > inv.weight_cap:
		return &"weight"
	if inv.current_volume() + def.volume > inv.volume_cap:
		return &"volume"
	return &"hands"
