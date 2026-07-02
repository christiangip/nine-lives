extends RefCounted
class_name Loadout
## The equipped-gear brain (GDD §11, FR-09-1/6/8): gear is equipped per slot within per-slot capacity
## limits, gated by permanent Workshop research (unlocked in ProgressionManager), and consumables track
## a count restocked with The Take (RunManager). A pure-ish RefCounted (not a Node) like Inventory, so
## it's directly `.new()`-able and unit-tests headlessly. Owned by RunManager (the per-Streak equipped
## set) and read by PlayerController for gadget queries + the MinigameHost for gear bonuses. Cross-system
## effects stay the caller's job and EventBus is FROZEN — loadout changes fire a LOCAL signal, matching
## Inventory.carry_full / Obstacle.state_changed. See docs/tasks/09_loadout_gear_gadgets.md.

signal loadout_changed   ## local; the Armory UI (task 13) + HUD (task 15) listen — world stays EventBus-driven

var config: LoadoutConfigDef

var _equipped: Dictionary = {}     ## slot(int) -> Array[StringName gear_id]
var _consumables: Dictionary = {}  ## gear_id(StringName) -> count(int)

func _init(p_config: LoadoutConfigDef = null) -> void:
	config = p_config
	_resolve_config()

func _resolve_config() -> void:
	if config == null:
		var c := Services.content()
		if c != null and c.loadout != null:
			config = c.loadout.get_def(&"default") as LoadoutConfigDef
	if config == null:
		config = LoadoutConfigDef.new()   # headless / no-registry fallback: schema defaults

# --- FR-09-1: slot capacity accounting --------------------------------------

## Total slot_cost equipped in a slot. Pure given _equipped.
func slot_used(slot: int) -> int:
	var used := 0
	for gid in _equipped.get(slot, []):
		var g := _def(gid)
		if g != null:
			used += g.slot_cost
	return used

func slot_capacity(slot: int) -> int:
	return config.capacity_for(slot)

## Would `incoming_cost` still fit under `capacity` given `used`? The pure seam test_slot_limits calls.
static func fits(used: int, capacity: int, incoming_cost: int) -> bool:
	return used + incoming_cost <= capacity

func is_equipped(gear_id: StringName) -> bool:
	for slot in _equipped:
		if gear_id in _equipped[slot]:
			return true
	return false

func equipped_in(slot: int) -> Array:
	return (_equipped.get(slot, []) as Array).duplicate()

# --- Equip / unequip (FR-09-1 + FR-09-4 research gating) --------------------

## True iff `gear` is researched (permanent unlock) AND its slot still has room. Locked gear can't be
## equipped until Workshop research lands it in ProgressionManager (FR-09-4).
func can_equip(gear: GearDef) -> bool:
	if gear == null or is_equipped(gear.id):
		return false
	if not is_unlocked(gear.id):
		return false
	return fits(slot_used(gear.slot), slot_capacity(gear.slot), gear.slot_cost)

## Is this gear permanently unlocked? Reads ProgressionManager (downward dependency, no back-reference).
func is_unlocked(gear_id: StringName) -> bool:
	var prog := Services.progression()
	if prog == null:
		return false
	return prog.is_unlocked(gear_id)

func equip(gear: GearDef) -> bool:
	if not can_equip(gear):
		return false
	var arr: Array = _equipped.get(gear.slot, [])
	arr.append(gear.id)
	_equipped[gear.slot] = arr
	loadout_changed.emit()
	return true

func unequip(gear_id: StringName) -> bool:
	for slot in _equipped:
		var arr: Array = _equipped[slot]
		var idx := arr.find(gear_id)
		if idx != -1:
			arr.remove_at(idx)
			loadout_changed.emit()
			return true
	return false

# --- FR-09-6: consumable counts + restock (spends The Take) -----------------

func consumable_count(gear_id: StringName) -> int:
	return int(_consumables.get(gear_id, 0))

## Can `qty` of a consumable be bought for `take` at `unit_cost` each, staying at/under `max_count`
## from `current`? Pure — the affordability + stack-cap seam test_consumable_restock calls.
static func can_restock(take: int, unit_cost: int, qty: int, current: int, max_count: int) -> bool:
	if qty <= 0 or unit_cost < 0:
		return false
	if max_count > 0 and current + qty > max_count:
		return false
	return take >= unit_cost * qty

## Restock `qty` units of a consumable gear, spending The Take (RunManager). Returns the count added
## (0 on failure — not unlocked, not consumable, unaffordable, or over the stack cap). The Fence station
## UI is task 13/14; this is the pure economy seam it drives. (FR-09-6)
func restock(gear: GearDef, qty: int = 1) -> int:
	if gear == null or not gear.consumable or not is_unlocked(gear.id):
		return 0
	var run := Services.run()
	var take: int = int(run.take) if run != null else 0
	var current := consumable_count(gear.id)
	if not can_restock(take, gear.restock_cost, qty, current, gear.max_count):
		return 0
	if run != null:
		run.take -= gear.restock_cost * qty
	_consumables[gear.id] = current + qty
	loadout_changed.emit()
	return qty

## Spend one unit of a consumable (EMP/smoke/lockpick/…). Returns false if none are held. (FR-09-6)
func consume(gear_id: StringName) -> bool:
	var n := consumable_count(gear_id)
	if n <= 0:
		return false
	_consumables[gear_id] = n - 1
	loadout_changed.emit()
	return true

# --- Gadget queries (closes the ↩ From 06 gadget hooks, TODO[09]) -----------

## Is a gadget with `flag` currently equipped (and, if consumable, still in stock)? The single seam
## behind PlayerController.has_glasscutter() / can_clone_keycard() / has_biometric_spoof().
func has_gadget(flag: StringName) -> bool:
	for slot in _equipped:
		for gid in _equipped[slot]:
			var g := _def(gid)
			if g != null and g.gadget_flag() == flag:
				if g.consumable and consumable_count(gid) <= 0:
					return false
				return true
	return false

## A tunable from the first equipped gadget advertising `flag` (else `fallback`). Lets a system read
## a gear bonus without knowing which slot it's in — e.g. soft-soled gear's Silence bonus (FR-09-7). Pure.
func gadget_param(flag: StringName, key: StringName, fallback: Variant) -> Variant:
	for slot in _equipped:
		for gid in _equipped[slot]:
			var g := _def(gid)
			if g != null and g.gadget_flag() == flag:
				return g.param(key, fallback)
	return fallback

## Gadget-flag → true map for every equipped tool/gadget, for MinigameHost gear injection
## (stethoscope widens the safe cue, hacking rig eases hacks, …). Closes TODO[09]. (FR-09-2)
func gear_flags() -> Dictionary:
	var flags: Dictionary = {}
	for slot in _equipped:
		for gid in _equipped[slot]:
			var g := _def(gid)
			if g != null:
				flags[String(g.gadget_flag())] = true
	return flags

## The equipped BREACH tool's def (drill/thermite/C4), or null. Its upgrade params feed BreachPoint (06).
func breach_tool() -> GearDef:
	var arr: Array = _equipped.get(GearDef.Slot.BREACH, [])
	return _def(arr[0]) if not arr.is_empty() else null

## The equipped WEAPON defs (for task 10 to build Weapon instances from).
func weapons() -> Array[GearDef]:
	var out: Array[GearDef] = []
	for gid in _equipped.get(GearDef.Slot.WEAPON, []):
		var g := _def(gid)
		if g != null:
			out.append(g)
	return out

# --- FR-09-8: pre-mission validation + serialization ------------------------

## Every equipped piece is unlocked and every slot is within capacity. Called pre-mission (FR-09-8);
## the Armory (13) also calls it before committing a loadout.
func validate() -> bool:
	for slot in _equipped:
		if slot_used(slot) > slot_capacity(slot):
			return false
		for gid in _equipped[slot]:
			if not is_unlocked(gid):
				return false
	return true

## Serialize the equipped set + consumable counts (FR-09-8 "serialized into the Streak/save"). The
## save schema wiring is task 16; this is the round-trippable form it stores.
func to_dict() -> Dictionary:
	var eq: Dictionary = {}
	for slot in _equipped:
		eq[slot] = (_equipped[slot] as Array).duplicate()
	return {"equipped": eq, "consumables": _consumables.duplicate()}

func from_dict(data: Dictionary) -> void:
	_equipped.clear()
	_consumables.clear()
	for slot in data.get("equipped", {}):
		var arr: Array[StringName] = []
		for gid in data["equipped"][slot]:
			arr.append(StringName(gid))
		_equipped[int(slot)] = arr
	for gid in data.get("consumables", {}):
		_consumables[StringName(gid)] = int(data["consumables"][gid])
	loadout_changed.emit()

# --- Internal --------------------------------------------------------------
func _def(gear_id) -> GearDef:
	var c := Services.content()
	if c == null or c.gear == null:
		return null
	return c.gear.get_def(StringName(gear_id)) as GearDef
