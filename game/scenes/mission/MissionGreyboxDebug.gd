extends Node3D
## Dev-only greybox driver + testing HUD for the task-11 manual playtest (F6). Builds ONE generated
## mission from a fixed seed (change `mission_seed`/`archetype`/`tier` in the Inspector + re-F6 to reroll)
## and adds a debug overlay — the real in-mission HUD is task 15, so this stands in so you can *read* the
## systems while testing. It also **equips a dev Loadout** (weapon + keycard-cloner + gadgets) on the
## Streak so `fire`/`gadget`/vault-clone are exercisable, and binds **L = force go-loud**.
## Colour key: blue capsule = guard · gold capsule = Inspector (carries the vault keycard) · cyan box =
## civilian · green box = Drop Point · red slab = Escape · tan box = loot (bright = the Mark).
## See docs/tasks/11_mission_generation.md.

@export var mission_seed: int = 20250702
@export var archetype: StringName = &"bank"
@export var tier: int = 2

## Equipped on the Streak so the loud/vault paths are testable (research-gated → dev-unlock first).
const _DEV_GEAR: Array[StringName] = [&"suppressed_pistol", &"keycard_cloner", &"lockpick_set", &"emp", &"smoke"]

var _label: Label
var _mission: Node3D           ## the built MissionController (read for the Phase-2 geometry check)
var _geo_line: String = ""     ## last KEY_V faithfulness readout

func _ready() -> void:
	_equip_dev_loadout()
	_build_mission()
	_build_overlay()

func _equip_dev_loadout() -> void:
	var lo := RunManager.loadout()
	for gid in _DEV_GEAR:
		if gid not in ProgressionManager.unlocked_gear:
			ProgressionManager.unlocked_gear.append(gid)   # dev-unlock (Armory research is task 13)
		var gd := Content.gear.get_def(gid) as GearDef
		if gd != null:
			lo.equip(gd)

func _build_mission() -> void:
	var c := Contract.new()
	c.archetype_id = archetype
	c.mission_seed = mission_seed
	c.tier = tier
	c.difficulty = tier
	var arch := Content.archetypes.get_def(archetype) as ArchetypeDef
	if arch != null and not arch.objective_ids.is_empty():
		c.objective_id = arch.objective_ids[0]
	var root := MissionGenerator.build(c)
	if root != null:
		_mission = root
		add_child(root)
		print("[MissionGreybox] built '%s' seed %d — %d sections, %d actors, %d gates" % [
			archetype, mission_seed, root.layout.sections.size(), root.layout.actors.size(), root.layout.gates.size()])
	else:
		push_error("[MissionGreybox] build failed for '%s' seed %d" % [archetype, mission_seed])

## Dev keys: L force go-loud (no scripted alarm exists yet); B toggle all light fixtures (blackout) so the
## light → shadow → detection coupling is testable (world-gen Phase 1C); P run the geometry-faithfulness
## check on the current mission (world-gen Phase 2C) — reports every room reachable + any corridor clips.
## (P not V — V is the player's takedown action.)
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_L:
			var p := _player()
			EventBus.alarm_tripped.emit("loud", p.global_position if p != null else global_position)
		KEY_B:
			for f in get_tree().get_nodes_in_group(&"lit"):
				if f.has_method("toggle"):
					f.toggle()
		KEY_P:
			_check_geometry()

## World-gen Phase 2C: prove every graph-connected room is physically reachable in the realized geometry.
func _check_geometry() -> void:
	if _mission == null:
		return
	var geo := MissionGeometry.faithful(_mission.layout)
	var rooms: int = _mission.layout.sections.size()
	_geo_line = "GEOMETRY %s — %d rooms, %d unreachable, %d corridor-clip cells" % [
		"OK" if geo.ok else "LOCKED-OUT", rooms, (geo.unreachable as Array).size(), int(geo.clip_cells)]
	print("[MissionGreybox] ", _geo_line, "  unreachable=", geo.unreachable)

# --- Debug overlay ---------------------------------------------------------
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_label = Label.new()
	# Bottom-left dev cheat-sheet — the real task-15 HUD (MissionController mounts it) now owns the live
	# carry/detection/pursuit readouts up top, so this only carries the controls list.
	_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.position = Vector2(16, -8)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)

func _process(_delta: float) -> void:
	if _label == null:
		return
	_label.text = _controls()

func _controls() -> String:
	var geo := ("\n" + _geo_line) if _geo_line != "" else ""
	return "[TASK 11 DEV GREYBOX — real HUD is task 15]  WASD move · mouse look · Shift sprint · C crouch · Z prone · Q/E lean\n" + \
		"F interact · V takedown · T throw · G drop body · LMB fire · 1 weapon · 4 gadget · L = GO LOUD · B = blackout · P = geometry check · Esc pause" + geo

func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D
