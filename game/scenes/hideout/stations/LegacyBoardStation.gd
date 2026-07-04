extends StationPanel
## Legacy Board (FR-13-7): buy permanent always-on Legacy Perks (task 12). Buy spends Legacy via
## buy_perk (prereq + cost gated, idempotent). Owned Perks are listed separately.

func _station_title() -> String:
	return "Legacy Board"

func _populate(_body_container: VBoxContainer) -> void:
	_note("Permanent passives bought with Legacy. Some require another Perk first.")
	if Content == null or Content.perks == null:
		return
	var defs := Content.perks.all()
	defs.sort_custom(func(a, b): return a.legacy_cost < b.legacy_cost)

	_heading("Available")
	var any := false
	for res in defs:
		var def := res as PerkDef
		if def == null or ProgressionManager.has_perk(def.id):
			continue
		any = true
		var can := ProgressionManager.can_buy_perk(def, ProgressionManager.meta_perks, ProgressionManager.legacy)
		var label := def.display_name
		var missing := _missing_prereqs(def)
		if not missing.is_empty():
			label += "   (needs %s)" % ", ".join(missing)
		var btn := _action_row(label, "Buy  %d" % def.legacy_cost, can)
		btn.pressed.connect(_on_buy.bind(def.id))
	if not any:
		_note("— every Perk is owned —")

	_heading("Owned")
	if ProgressionManager.meta_perks.is_empty():
		_note("— none yet —")
	else:
		for pid in ProgressionManager.meta_perks:
			var def := Content.perks.get_def(pid) as PerkDef
			_note("✔ %s" % (def.display_name if def != null else String(pid)))

func _missing_prereqs(def: PerkDef) -> Array:
	var out: Array = []
	for pre in def.prerequisites:
		if pre not in ProgressionManager.meta_perks:
			out.append(String(pre))
	return out

func _on_buy(perk_id: StringName) -> void:
	if ProgressionManager.buy_perk(perk_id):
		refresh()
