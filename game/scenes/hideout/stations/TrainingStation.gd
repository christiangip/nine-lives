extends StationPanel
## Training Area (FR-13-4): spend Legacy to raise attributes (task 12). Lists every AttributeDef with
## its level, trained effect, and next-level cost; Train spends the cost curve via train_attribute.

func _station_title() -> String:
	return "Training Area"

func _populate(_body_container: VBoxContainer) -> void:
	_note("Spend Legacy to raise your attributes. Higher levels feed every system that reads them.")
	if Content == null or Content.attributes == null:
		return
	var defs := Content.attributes.all()
	defs.sort_custom(func(a, b): return String(a.display_name) < String(b.display_name))
	for res in defs:
		var def := res as AttributeDef
		if def == null:
			continue
		var level := ProgressionManager.attribute_level(def.id)
		var cost := ProgressionManager.attribute_cost(def, level)
		var maxed := cost < 0
		var effect := ProgressionManager.attribute_effect(def.id)
		var label := "%s — Lv %d/%d   (effect %.2f)" % [def.display_name, level, def.max_level, effect]
		var btn_text := "MAX" if maxed else "Train  %d" % cost
		var affordable := not maxed and ProgressionManager.legacy >= cost
		var btn := _action_row(label, btn_text, affordable)
		if not maxed:
			btn.pressed.connect(_on_train.bind(def.id))

func _on_train(attr_id: StringName) -> void:
	if ProgressionManager.train_attribute(attr_id):
		refresh()
