extends StationPanel
## Workshop (FR-13-5): spend Legacy to permanently research gear/gadgets/mods (task 09/12). Research
## appends to ProgressionManager.unlocked_gear, which the Armory's Loadout.can_equip gate then honours.

const SLOT_NAMES := ["Tool", "Breach", "Gadget", "Weapon", "Utility", "Apparel"]

func _station_title() -> String:
	return "Workshop"

func _populate(_body_container: VBoxContainer) -> void:
	_note("Research permanently unlocks gear for the Armory. Prerequisites (if any) must be owned first.")
	if Content == null or Content.gear == null:
		return
	var defs := Content.gear.all()
	defs.sort_custom(func(a, b): return a.research_cost < b.research_cost)

	_heading("Available to research")
	var any_available := false
	for res in defs:
		var def := res as GearDef
		if def == null or def.research_cost <= 0 or ProgressionManager.is_unlocked(def.id):
			continue
		any_available = true
		var can := ProgressionManager.can_research(def, ProgressionManager.unlocked_gear, ProgressionManager.legacy)
		var prereq := StringName(def.params.get("research_prereq", &""))
		var label := "%s   [%s]" % [def.display_name, SLOT_NAMES[def.slot]]
		if prereq != &"" and not ProgressionManager.is_unlocked(prereq):
			label += "   (needs %s)" % prereq
		var btn := _action_row(label, "Research  %d" % def.research_cost, can)
		btn.pressed.connect(_on_research.bind(def.id))
	if not any_available:
		_note("— everything researchable is already unlocked —")

	_heading("Researched")
	var any_done := false
	for res in defs:
		var def := res as GearDef
		if def != null and def.research_cost > 0 and ProgressionManager.is_unlocked(def.id):
			any_done = true
			_note("✔ %s" % def.display_name)
	if not any_done:
		_note("— nothing yet —")

func _on_research(gear_id: StringName) -> void:
	if ProgressionManager.research_gear(gear_id):
		refresh()
