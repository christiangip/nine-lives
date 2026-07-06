extends StationPanel
## Locksmith — a pack-local Hideout station for the "The Estate Job" worked-example expansion (task 19).
## Proves FR-19-7: a new station ships as a StationDef (stations/locksmith.tres) + this scene, with NO
## core edit — HideoutManifest surfaces it purely from Content.stations, and the panel reuses the tested
## StationPanel base + Loadout.restock seam (the Fence idiom) to top up picks/tools before a job. Lives
## entirely under game/packs/ so disabling the pack removes it cleanly.
## See docs/CONTENT_PACKS.md and docs/tasks/19_expansion_framework.md.

func _station_title() -> String:
	return "Locksmith"

func _populate(_body_container: VBoxContainer) -> void:
	_note("Your friend on the outside. Restock lockpicks and tools before the next job — spends The Take.")
	var lo: Loadout = RunManager.loadout()
	if lo == null:
		_note("No loadout available.")
		return
	_heading("Restock — picks & tools")
	var any := false
	for res in _restockable_tools():
		var def := res as GearDef
		any = true
		var held := lo.consumable_count(def.id)
		var cap := "" if def.max_count <= 0 else "/%d" % def.max_count
		var can := Loadout.can_restock(RunManager.take, def.restock_cost, 1, held, def.max_count)
		var label := "  %s   (have %d%s)" % [def.display_name, held, cap]
		var btn := _action_row(label, "Buy 1  $%d" % def.restock_cost, can)
		btn.pressed.connect(_on_restock.bind(def.id))
	if not any:
		_note("— research a pick-pouch or tool at the Workshop to restock it here —")

## Tool-slot (0) consumables that are Fence-restockable and unlocked. Property-based — never branches on id.
func _restockable_tools() -> Array:
	var out: Array = []
	if Content == null or Content.gear == null:
		return out
	for res in Content.gear.all():
		var def := res as GearDef
		if def != null and def.slot == 0 and def.consumable and def.restock_cost > 0 and ProgressionManager.is_unlocked(def.id):
			out.append(def)
	out.sort_custom(func(a, b): return String(a.display_name) < String(b.display_name))
	return out

func _on_restock(gear_id: StringName) -> void:
	var def := Content.gear.get_def(gear_id) as GearDef
	if def != null and RunManager.loadout().restock(def, 1) > 0:
		refresh()
