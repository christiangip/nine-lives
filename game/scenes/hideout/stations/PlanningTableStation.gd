extends StationPanel
## Planning Table (FR-13-8, closes the ↩ From 06 Intel reveal half): buy Intel with The Take (and/or
## Legacy) for a board contract to reveal its modifiers, loot manifest, and otherwise-invisible silent
## alarms. A stealth run's edge — knowing the building before you enter. Drives RunManager.buy_intel.

func _station_title() -> String:
	return "Planning Table"

func _populate(_body_container: VBoxContainer) -> void:
	var board: Array = RunManager.job_board
	if board.is_empty():
		_note("No contracts to plan. (Start a Streak to refresh the Job Map.)")
		return
	if Content == null or Content.intel == null:
		return
	var packets := Content.intel.all()
	_note("Casing costs money but pays off on a quiet run — reveal the threats before you commit.")
	for entry in board:
		var c := entry as Contract
		if c == null:
			continue
		_heading(_contract_headline(c))
		for res in packets:
			var intel := res as IntelDef
			if intel == null:
				continue
			var owned := _fully_revealed(c, intel)
			var price := "Take $%d" % intel.take_cost
			if intel.legacy_cost > 0:
				price += " + %d Legacy" % intel.legacy_cost
			var affordable := RunManager.take >= intel.take_cost \
				and ProgressionManager.legacy >= intel.legacy_cost
			var label := "  %s — %s" % [intel.display_name, intel.description]
			var btn := _action_row(label, "Bought" if owned else price, affordable and not owned)
			if not owned:
				btn.pressed.connect(_on_buy.bind(c, intel))

func _fully_revealed(c: Contract, intel: IntelDef) -> bool:
	for r in intel.reveals:
		if not RunManager.has_intel(c, String(r)):
			return false
	return true

func _on_buy(contract: Contract, intel: IntelDef) -> void:
	if RunManager.buy_intel(contract, intel):
		refresh()
