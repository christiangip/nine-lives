extends Minigame
class_name PickpocketMinigame
## Pickpocket overlay (FR-07-7, GDD §9.7/§9.8): a meter sweeps back and forth — stop it inside the
## safe zone to lift the item. The Pickpocketing attribute WIDENS the safe zone; a higher tier (a wary
## mark) narrows it. A miss FAILS and nudges the NPC suspicious (the NPC reaction wires in with the
## civilian roster — TODO[05]/TODO[11]). Focused close-up → pauses the world. Pure timing seams.
## See docs/tasks/07_minigames.md.

var _pos: float = 0.0        ## meter position in [0,1]
var _dir: float = 1.0        ## sweep direction (+1 / -1)
var _center: float = 0.5     ## safe-zone centre
var _half_width: float = 0.18
var _speed: float = 1.2
var _readout: Label

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Safe-zone HALF-WIDTH (fraction of the meter) the Pickpocketing attribute widens. Pure.
static func window_width(base: float, pickpocketing_level: float, per_level: float) -> float:
	return Minigame.scaled(base, pickpocketing_level, per_level)

## Tier-adjusted base half-width before the attribute widens it — a warier mark (higher tier) narrows
## it, floored. Pure.
static func window_base_for_tier(base: float, tier: int, tier_penalty: float, min_width: float) -> float:
	return maxf(min_width, base - float(maxi(0, tier - 1)) * tier_penalty)

## Did the stop land in the safe zone? |pos - centre| <= half-width. Pure.
static func is_in_window(pos: float, center: float, half_width: float) -> bool:
	return absf(pos - center) <= half_width

# --- Effective geometry from config + injected context ---------------------
func effective_window() -> float:
	var tier_base := window_base_for_tier(config.pickpocket_window_base, difficulty,
		config.pickpocket_window_tier_penalty, config.pickpocket_window_min)
	return window_width(tier_base, float(attribute_level), config.pickpocket_window_per_level)

# --- Lifecycle -------------------------------------------------------------
func begin(ctx: Dictionary = {}) -> void:
	super.begin(ctx)
	_half_width = effective_window()
	_speed = config.pickpocket_meter_speed
	_center = randf_range(0.25, 0.75)
	_pos = 0.0
	_dir = 1.0
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.07, 0.85)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_CENTER)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_readout)
	_refresh()

func _process(delta: float) -> void:
	if _finished:
		return
	_pos += _dir * _speed * delta
	if _pos >= 1.0:
		_pos = 1.0
		_dir = -1.0
	elif _pos <= 0.0:
		_pos = 0.0
		_dir = 1.0
	_refresh()
	if Input.is_action_just_pressed(&"ui_accept"):
		if is_in_window(_pos, _center, _half_width):
			_finish_solved()
		else:
			_finish_failed("caught")   # TODO[05]/[11]: nudge the NPC suspicious on this fail

func _refresh() -> void:
	if _readout == null:
		return
	const CELLS := 21
	var bar := ""
	for i in CELLS:
		var f := float(i) / float(CELLS - 1)
		if absf(f - _pos) <= 0.5 / float(CELLS - 1):
			bar += "|"
		elif is_in_window(f, _center, _half_width):
			bar += "="
		else:
			bar += "."
	_readout.text = "PICKPOCKET  [Enter] to grab in the zone   Esc: cancel\n%s" % bar
