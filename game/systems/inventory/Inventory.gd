extends RefCounted
class_name Inventory
## Two-axis carry brain (GDD §10.1): Carry Weight (kg) + Carry Volume (L/slots) caps, hand-slot
## occupancy (loot, a carried Bag, a dragged Body), bagging, key-item tracking, and secured/lost
## value bookkeeping. A pure-ish RefCounted (not a Node) so it's directly `.new()`-able and
## unit-testable with zero scene tree — the fixed contract game/tests/unit/test_carry_system.gd
## already assumes. Owned by PlayerController (one instance per player); cross-system effects
## (EventBus signals, RunManager banking) are the caller's job (LootPickup/DropPoint/Escape/
## PlayerController), keeping this class free of autoload dependencies, same as Lock/HackTarget's
## pure seams. See docs/tasks/08_loot_inventory.md (FR-08-1..9) and GDD §10.

const MAX_HAND_SLOTS: int = 2      ## GDD §10.1: "limited to 1-2"
const BAG_HAND_SLOTS: int = 1      ## a carried Bag occupies one hand (GDD §10.1 lists "gold bag" as a hand-slot example)
const BODY_HAND_SLOTS: int = 2     ## a dragged Body is "a heavy two-handed haul" (↩ from 05)
const BODY_WEIGHT_KG: float = 75.0
const MIN_HAND_SPEED_MULT: float = 0.35   ## floor so a full load never fully freezes movement

var weight_cap: float = 40.0    ## kg; PlayerController sets from config × Strength at _ready
var volume_cap: float = 20.0    ## L/slots

var _held_items: Dictionary = {}          ## StringName item_id -> true (keycards/keys/clues)
var _pocketed_loot: Array[LootDef] = []   ## grabbed-direct loot (weight/volume counted, no hand slot)
var _bag: Bag = null                      ## the single active loose-loot bag, or null
var _hand_items: Array[LootDef] = []      ## bulky/special loot occupying hands (hand_slots > 0)
var _carried_body: Body = null            ## the one Body being dragged, or null
var _in_hand_value: int = 0               ## sum of value NOT yet secured (lost on Catch)
var _secured_value: int = 0               ## sum of value already banked (survives Catch)

# --- FR-08-1: weight/volume/hand-slot accounting ----------------------------

## Current total weight (kg): pocketed loot + hand-slot loot + bag contents + carried body.
func current_weight() -> float:
	var w := 0.0
	for l in _pocketed_loot:
		w += l.weight
	for l in _hand_items:
		w += l.weight
	if _bag != null:
		w += _bag.total_weight()
	if _carried_body != null:
		w += BODY_WEIGHT_KG
	return w

## Current total volume (L/slots): pocketed loot + hand-slot loot + bag contents.
func current_volume() -> float:
	var v := 0.0
	for l in _pocketed_loot:
		v += l.volume
	for l in _hand_items:
		v += l.volume
	if _bag != null:
		v += _bag.total_volume()
	return v

## Hand slots currently occupied: hand-slot loot + (1 if a bag is held) + (2 if dragging a body).
## The single source of truth for FR-08-2's cap — a Bag and a dragged Body are naturally mutually
## exclusive under MAX_HAND_SLOTS (2 body + 1 bag = 3 > 2) purely from this accounting.
func hand_slots_used() -> int:
	var used := 0
	for l in _hand_items:
		used += l.hand_slots
	if _bag != null:
		used += BAG_HAND_SLOTS
	if _carried_body != null:
		used += BODY_HAND_SLOTS
	return used

## Would adding `loot` exceed Carry Weight, Carry Volume, or (for hand-slot loot) the hand-slot
## cap? Pure decision function — the exact seam test_carry_system.gd calls. (FR-08-1)
func can_pick_up(loot: LootDef) -> bool:
	if loot == null:
		return false
	if current_weight() + loot.weight > weight_cap:
		return false
	if current_volume() + loot.volume > volume_cap:
		return false
	if loot.hand_slots > 0 and hand_slots_used() + loot.hand_slots > MAX_HAND_SLOTS:
		return false
	return true

# --- FR-08-2: hand-slot movement/agility penalty ----------------------------

## Pure penalty math: speed multiplier given slots used, penalty-per-slot, and Strength's
## reduction (`strength_effect` = level * AttributeDef.effect_per_level, caller-resolved —
## mirrors Lock.resolve_attempt's lockpicking_level pattern). Clamped to a sane floor.
static func hand_speed_mult(slots_used: int, penalty_per_slot: float, strength_effect: float) -> float:
	if slots_used <= 0:
		return 1.0
	var raw := 1.0 - float(slots_used) * penalty_per_slot * (1.0 - clampf(strength_effect, 0.0, 1.0))
	return clampf(raw, MIN_HAND_SPEED_MULT, 1.0)

## True iff any hands are occupied — blocks vents/climb regardless of Strength (FR-08-2:
## Strength reduces the speed penalty, it doesn't free your hands).
func hands_block_movement() -> bool:
	return hand_slots_used() > 0

## The full penalty tuple PlayerController.apply_carry_penalty(speed_mult, blocks_climb,
## blocks_vents) expects, given the caller-resolved strength effect + config tunables.
func penalty_state(penalty_per_slot: float, strength_effect: float) -> Dictionary:
	var blocked := hands_block_movement()
	return {
		"speed_mult": hand_speed_mult(hand_slots_used(), penalty_per_slot, strength_effect),
		"blocks_climb": blocked,
		"blocks_vents": blocked,
	}

# --- FR-08-3: physical pickup / bagging routing -----------------------------

## Direct pickup of pocketable loot (needs_bagging == false). Returns false (no-op) if it
## needs bagging instead, or can_pick_up() rejects it.
func pick_up_direct(loot: LootDef) -> bool:
	if loot == null or loot.needs_bagging or not can_pick_up(loot):
		return false
	if loot.hand_slots > 0:
		_hand_items.append(loot)
	else:
		_pocketed_loot.append(loot)
	_in_hand_value += loot.value
	return true

## Add loose loot (needs_bagging == true) into the active bag, creating one if none exists and a
## hand is free. Returns false if it doesn't need bagging (route to pick_up_direct instead), no
## hand is free to start a new bag, or the weight/volume cap would be exceeded. (FR-08-3)
func bag_loot(loot: LootDef) -> bool:
	if loot == null or not loot.needs_bagging:
		return false
	if _bag == null and hand_slots_used() + BAG_HAND_SLOTS > MAX_HAND_SLOTS:
		return false
	if not can_pick_up(loot):
		return false
	if _bag == null:
		_bag = Bag.new()
	_bag.add(loot)
	_in_hand_value += loot.value
	return true

## Router for non-physical grants (e.g. HackTarget's data_loot download) — routes to bag_loot()
## or pick_up_direct() by the def's own needs_bagging flag, same as a LootPickup's interact().
func add_loot(loot: LootDef) -> bool:
	if loot == null:
		return false
	return bag_loot(loot) if loot.needs_bagging else pick_up_direct(loot)

# --- Key-item tracking (closes Obstacle.actor_has_item TODO[08]) -----------

## Register a held key/keycard/clue id (from a pocketable LootPickup, a data-loot grant, or a
## dragged Body's carried_item). Distinct from loot value — this is the boolean "do I hold this
## id" set Obstacle.actor_has_item() duck-types against.
func add_item(item_id: StringName) -> void:
	if item_id != &"":
		_held_items[item_id] = true

func has_item(item_id: StringName) -> bool:
	return _held_items.get(item_id, false)

# --- FR-05-2/FR-08 body drag (closes BiometricLock.is_carrying_keyholder TODO[08]) ---------

## Start dragging a downed Body (a heavy two-handed haul). Fails if already carrying one, or if
## the hand-slot cap would be exceeded (a body always costs BODY_HAND_SLOTS). On success also
## grants the body's carried_item (e.g. the Inspector's vault_keycard) into the held-item set —
## "plus the Inspector keycard pickup" per the task's ↩ From 05 banner.
func pick_up_body(body: Body) -> bool:
	if body == null or _carried_body != null:
		return false
	if hand_slots_used() + BODY_HAND_SLOTS > MAX_HAND_SLOTS:
		return false
	_carried_body = body
	add_item(body.carried_item)
	return true

## Release the carried body (drop_loot action, or lost on a Catch).
func put_down_body() -> Body:
	var b := _carried_body
	_carried_body = null
	return b

func is_carrying_body() -> bool:
	return _carried_body != null

## Does the currently-dragged body match `item_id`? The exact seam BiometricLock duck-types via
## by.is_carrying_keyholder(def.required_item). (↩ from 06)
func is_carrying_keyholder(item_id: StringName) -> bool:
	return _carried_body != null and _carried_body.carried_item == item_id

# --- FR-08-4: throwing (Strength-gated) --------------------------------------

## Max throw distance (m) for the active bag, given Strength. Pure. base_distance and
## per_effect_bonus come from PlayerConfigDef (no magic numbers).
static func throw_distance(base_distance: float, strength_effect: float, per_effect_bonus: float) -> float:
	return base_distance + strength_effect * per_effect_bonus

## Can the active bag be thrown? A dragged Body already makes this impossible via the shared
## hand-slot accounting (a bag can't be created/held while both hands are full of body), so this
## only needs to check a bag actually exists.
func can_throw_bag() -> bool:
	return _bag != null

## Detach and return the active bag for a throw (ThrownBag glue calls this, then spawns the
## physics projectile). Inventory no longer tracks its weight/volume/in-hand value until it's
## either re-picked-up or secured via DropPoint.receive_bag().
func release_bag_for_throw() -> Bag:
	var b := _bag
	if b != null:
		_in_hand_value -= b.total_value()
		_bag = null
	return b

## Re-adopt an already-assembled Bag (reclaiming a thrown bag that missed a Drop Point and
## settled — DroppedBag calls this) as the active carried bag. The exact reverse of
## release_bag_for_throw(). Fails if a bag is already held or no hand is free.
func adopt_bag(bag: Bag) -> bool:
	if bag == null or bag.is_empty() or _bag != null:
		return false
	if hand_slots_used() + BAG_HAND_SLOTS > MAX_HAND_SLOTS:
		return false
	_bag = bag
	_in_hand_value += bag.total_value()
	return true

# --- FR-08-5/6: securing + loss (Drop Point / Escape / Catch) ---------------

## Bank ALL current in-hand value (pocketed + hand-slot loot + bag); clears the physical loot
## from carry (it's "delivered"). Returns {"value": int, "special_hooks": Array[StringName]} so
## the caller (DropPoint/Escape) can fire FR-08-9's special-hook delivery without Inventory
## itself reaching into ProgressionManager. Does NOT clear held key-items or a carried body —
## those aren't "loot value."
func secure_all_carried() -> Dictionary:
	var hooks: Array[StringName] = []
	for l in _pocketed_loot:
		if l.special_hook != &"":
			hooks.append(l.special_hook)
	for l in _hand_items:
		if l.special_hook != &"":
			hooks.append(l.special_hook)
	if _bag != null:
		hooks.append_array(_bag.special_hooks())
	var amount := _in_hand_value
	_secured_value += amount
	_in_hand_value = 0
	_pocketed_loot.clear()
	_hand_items.clear()
	_bag = null
	return {"value": amount, "special_hooks": hooks}

## Bank a specific already-detached Bag's value (the thrown-bag-lands-in-a-Drop-Point path,
## where the bag is no longer "in" this Inventory — it's mid-flight). Distinct from
## secure_all_carried() because a thrown bag isn't part of current carry state anymore.
func secure_bag(bag: Bag) -> Dictionary:
	if bag == null or bag.is_empty():
		return {"value": 0, "special_hooks": []}
	var amount := bag.total_value()
	_secured_value += amount
	return {"value": amount, "special_hooks": bag.special_hooks()}

## FR-08-6: everything still in hand at a Catch is lost; secured_value is untouched. A dropped
## body is left behind too (its carried_item stays granted — you already frisked it on pickup).
## Returns the lost amount (for HUD/debug feedback).
func lose_in_hand_on_catch() -> int:
	var lost := _in_hand_value
	_in_hand_value = 0
	_pocketed_loot.clear()
	_hand_items.clear()
	_bag = null
	_carried_body = null
	return lost

func secured_value() -> int:
	return _secured_value

func in_hand_value() -> int:
	return _in_hand_value
