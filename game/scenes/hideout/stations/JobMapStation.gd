extends StationPanel
## The Job Map (FR-13-3): diegetic contract select. Pins come from RunManager.job_board (task 11);
## each shows archetype/tier/objective, its revealed modifiers + loot manifest IF Intel was bought at
## the Planning Table (otherwise "??? — buy Intel"), and a Launch button → GameManager.enter_mission.

func _station_title() -> String:
	return "The Job Map"

func _populate(_body_container: VBoxContainer) -> void:
	var board: Array = RunManager.job_board
	if board.is_empty():
		_note("No contracts on the board. (Start a Streak to refresh the Job Map.)")
		return
	_note("Pick a contract. Buy Intel at the Planning Table to reveal modifiers and the loot manifest before you commit.")
	for entry in board:
		var c := entry as Contract
		if c == null:
			continue
		_heading(_contract_headline(c))
		# Modifiers — hidden until Intel bought (FR-13-3).
		if RunManager.has_intel(c, "modifiers"):
			var names: Array = []
			for mid in RunManager.revealed_modifiers(c):
				names.append(_modifier_name(mid))
			_note("Modifiers: %s" % ("none" if names.is_empty() else ", ".join(names)))
		else:
			_note("Modifiers: ??? — buy Intel")
		# Loot manifest — revealed by Intel.
		if RunManager.has_intel(c, "manifest"):
			_note("Manifest: %s" % ", ".join(_contract_manifest(c)))
		if RunManager.has_intel(c, "silent_alarms"):
			_note("Silent alarms marked for this job.")
		var launch := _action_row("", "Launch heist", true)
		launch.pressed.connect(_on_launch.bind(c))

func _on_launch(contract: Contract) -> void:
	# GameManager validates the loadout + builds the mission (FR-11-3 / FR-09-8).
	GameManager.enter_mission(contract)
