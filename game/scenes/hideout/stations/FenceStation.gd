extends StationPanel
## Fence Terminal (FR-13-10, closes ↩ From 09.2): convert delivered special loot into The Take, and
## restock consumables/tools with The Take (Loadout.restock). Stealth kit (tools/gadgets) is listed
## first; ammo is secondary. Converting a trophy removes it from the Stash (convert_stash_item).

func _station_title() -> String:
	return "Fence Terminal"

func _populate(_body_container: VBoxContainer) -> void:
	_restock_section()
	_convert_section()

# --- Restock consumables (spends The Take) ---------------------------------
func _restock_section() -> void:
	_heading("Restock — kit & consumables")
	_note("Top up gadgets and tools for the next contract. Spends The Take.")
	var lo: Loadout = RunManager.loadout()
	var any := false
	for res in _restockable():
		var def := res as GearDef
		any = true
		var held := lo.consumable_count(def.id)
		var cap := "" if def.max_count <= 0 else "/%d" % def.max_count
		var can := Loadout.can_restock(RunManager.take, def.restock_cost, 1, held, def.max_count)
		var label := "  %s   (have %d%s)" % [def.display_name, held, cap]
		var btn := _action_row(label, "Buy 1  $%d" % def.restock_cost, can)
		btn.pressed.connect(_on_restock.bind(def.id))
	if not any:
		_note("— research a consumable at the Workshop to restock it here —")

func _restockable() -> Array:
	var out: Array = []
	if Content == null or Content.gear == null:
		return out
	for res in Content.gear.all():
		var def := res as GearDef
		if def != null and def.consumable and def.restock_cost > 0 and ProgressionManager.is_unlocked(def.id):
			out.append(def)
	# Tools/gadgets before ammo/utility (stealth-first framing).
	out.sort_custom(func(a, b): return a.slot < b.slot)
	return out

func _on_restock(gear_id: StringName) -> void:
	var def := Content.gear.get_def(gear_id) as GearDef
	if def != null and RunManager.loadout().restock(def, 1) > 0:
		refresh()

# --- Convert special loot into The Take ------------------------------------
func _convert_section() -> void:
	_heading("Fence special loot")
	if ProgressionManager.stash.is_empty():
		_note("— no special loot to fence —")
		return
	_note("Selling a trophy pays out The Take but removes it from your Stash.")
	for hook in ProgressionManager.stash.duplicate():
		var def := _loot_by_hook(hook)
		var value := ProgressionManager.convert_value(def)
		var label := "  %s" % (def.display_name if def != null else String(hook))
		var btn := _action_row(label, "Sell  $%d" % value, value > 0)
		btn.pressed.connect(_on_sell.bind(StringName(hook)))

func _on_sell(hook: StringName) -> void:
	var value := ProgressionManager.convert_stash_item(hook)
	if value > 0:
		RunManager.add_take(value)
		refresh()

func _loot_by_hook(hook) -> LootDef:
	if Content == null or Content.loot == null:
		return null
	var want := StringName(hook)
	for res in Content.loot.all():
		var def := res as LootDef
		if def != null and def.special_hook == want:
			return def
	return null
