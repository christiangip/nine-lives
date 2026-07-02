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
const _STATE_NAMES := ["Unaware", "Suspicious", "Searching", "Alerted", "Pursuit"]

var _label: Label
var _det: Dictionary = {}     ## actor_id -> [state, fill]
var _phase: int = 0
var _alarm: String = ""

func _ready() -> void:
	_equip_dev_loadout()
	_build_mission()
	_build_overlay()
	EventBus.detection_changed.connect(_on_detection)
	EventBus.pursuit_phase_changed.connect(func(p: int) -> void: _phase = p)
	EventBus.alarm_tripped.connect(func(k: String, _pos: Vector3) -> void: _alarm = k)

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
		add_child(root)
		print("[MissionGreybox] built '%s' seed %d — %d sections, %d actors, %d gates" % [
			archetype, mission_seed, root.layout.sections.size(), root.layout.actors.size(), root.layout.gates.size()])
	else:
		push_error("[MissionGreybox] build failed for '%s' seed %d" % [archetype, mission_seed])

## Force go-loud (L) — the mission has no scripted alarm trigger, so this stands in for tripping one.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		var p := _player()
		EventBus.alarm_tripped.emit("loud", p.global_position if p != null else global_position)

func _on_detection(actor_id: int, state: int, fill: float) -> void:
	_det[actor_id] = [state, fill]

# --- Debug overlay ---------------------------------------------------------
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)

func _process(_delta: float) -> void:
	if _label == null:
		return
	_label.text = "%s\n\n%s" % [_controls(), _status()]

func _controls() -> String:
	return "[TASK 11 DEV GREYBOX]  WASD move · mouse look · Shift sprint · C crouch · Z prone · Q/E lean\n" + \
		"F interact/pick-up · V takedown · T throw bag · G drop body · LMB fire · 1 weapon · 4 gadget · L = GO LOUD · Esc pause"

func _status() -> String:
	var carry := "empty"
	var p := _player()
	if p != null and p.get("inventory") != null:
		var inv = p.inventory
		carry = "%.1f kg / %.1f L   in-hand $%d" % [inv.current_weight(), inv.current_volume(), inv.in_hand_value()]
	var ds := _max_detection()
	var det_name: String = _STATE_NAMES[clampi(ds[0], 0, _STATE_NAMES.size() - 1)]
	var alarm := _alarm if _alarm != "" else "none"
	return "SECURED (Notoriety) $%d   Take $%d   Heat %.2f\nCarrying: %s\nAlert: %s (%.0f%%)   Pursuit phase: %d   Alarm: %s\nVault door: interact (F) — you hold the keycard cloner." % [
		RunManager.notoriety, RunManager.take, RunManager.heat, carry, det_name, ds[1] * 100.0, _phase, alarm]

func _max_detection() -> Array:
	var s := 0
	var f := 0.0
	for v in _det.values():
		s = maxi(s, int(v[0]))
		f = maxf(f, float(v[1]))
	return [s, f]

func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D
