extends StationPanel
## The Stash (FR-13-9): trophy room for delivered special/unique loot (ProgressionManager.stash). Some
## trophies grant set bonuses, summed via stash_set_bonus_total and read by other systems (task 12).

func _station_title() -> String:
	return "The Stash"

func _populate(_body_container: VBoxContainer) -> void:
	var stash: Array = ProgressionManager.stash
	if stash.is_empty():
		_note("Empty. Deliver SPECIAL-tier loot to a Drop Point / Escape and it enshrines here.")
		return

	_heading("Trophies")
	for hook in stash:
		var def := _loot_by_hook(hook)
		_note("★ %s" % (def.display_name if def != null else String(hook)))

	# Active set bonuses: aggregate every set-bonus key present across delivered trophies.
	var keys := _all_set_bonus_keys()
	if not keys.is_empty():
		_heading("Active set bonuses")
		for key in keys:
			var total := ProgressionManager.stash_set_bonus_total(key)
			if absf(total) > 0.0001:
				_note("• %s  +%.2f" % [key, total])

func _all_set_bonus_keys() -> Array:
	var out: Array = []
	for hook in ProgressionManager.stash:
		var def := _loot_by_hook(hook)
		if def == null:
			continue
		var bonus = def.params.get("set_bonus", {})
		if bonus is Dictionary:
			for k in bonus:
				if k not in out:
					out.append(k)
	return out

func _loot_by_hook(hook) -> LootDef:
	if Content == null or Content.loot == null:
		return null
	var want := StringName(hook)
	for res in Content.loot.all():
		var def := res as LootDef
		if def != null and def.special_hook == want:
			return def
	return null
