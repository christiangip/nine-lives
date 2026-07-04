extends StationPanel
## Armory (FR-13-6, closes ↩ From 09.1): equip unlocked gear within per-slot capacity on the Streak's
## Loadout (RunManager.loadout()). Equip/unequip via Loadout.can_equip/equip/unequip; the capacity
## readout comes from Content.loadout. Research happens at the Workshop — locked gear can't be equipped.

const SLOT_NAMES := ["Tool", "Breach", "Gadget", "Weapon", "Utility", "Apparel"]

func _station_title() -> String:
	return "Armory"

func _populate(_body_container: VBoxContainer) -> void:
	var lo: Loadout = RunManager.loadout()
	if lo == null:
		_note("No loadout available.")
		return
	_note("Equip unlocked gear within each slot's capacity. Anything locked → research it at the Workshop.")
	if not lo.validate():
		_note("⚠ Current loadout is over capacity or holds locked gear — fix before a mission.")

	for slot in range(SLOT_NAMES.size()):
		_heading("%s   (%d / %d)" % [SLOT_NAMES[slot], lo.slot_used(slot), lo.slot_capacity(slot)])
		# Equipped in this slot → Unequip.
		for gid in lo.equipped_in(slot):
			var def := _gear(gid)
			if def == null:
				continue
			var btn := _action_row("  ✔ %s" % def.display_name, "Unequip", true)
			btn.pressed.connect(_on_unequip.bind(gid))
		# Unlocked-but-unequipped gear for this slot → Equip (enabled iff it fits).
		for res in _unlocked_for_slot(slot):
			var def := res as GearDef
			if lo.is_equipped(def.id):
				continue
			var can := lo.can_equip(def)
			var label := "  %s   (cost %d)" % [def.display_name, def.slot_cost]
			var btn := _action_row(label, "Equip", can)
			btn.pressed.connect(_on_equip.bind(def.id))

func _unlocked_for_slot(slot: int) -> Array:
	var out: Array = []
	if Content == null or Content.gear == null:
		return out
	for res in Content.gear.all():
		var def := res as GearDef
		if def != null and def.slot == slot and ProgressionManager.is_unlocked(def.id):
			out.append(def)
	out.sort_custom(func(a, b): return String(a.display_name) < String(b.display_name))
	return out

func _gear(gid: StringName) -> GearDef:
	return Content.gear.get_def(gid) as GearDef if Content != null and Content.gear != null else null

func _on_equip(gid: StringName) -> void:
	var def := _gear(gid)
	if def != null and RunManager.loadout().equip(def):
		refresh()

func _on_unequip(gid: StringName) -> void:
	if RunManager.loadout().unequip(gid):
		refresh()
