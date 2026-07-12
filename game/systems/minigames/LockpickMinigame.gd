extends Minigame
class_name LockpickMinigame
## Lockpick overlay (FR-07-3, GDD §9.8): rotate the pick to the tension "give" arc and set it. A miss
## fails the attempt (the obstacle then rolls a pick SNAP via Lock.snap_chance). The Lockpicking
## attribute WIDENS the give arc + lowers snap odds; a higher difficulty tier narrows it. The
## scalable maths are pure static seams; the rotate/set glue is thin. See docs/tasks/07_minigames.md.

var _center_deg: float = 0.0        ## the (hidden) centre of the give arc this attempt
var _angle_deg: float = 0.0         ## the pick's current angle
var _half_width_deg: float = 25.0   ## effective give half-width after tier + attribute
var _readout: Label

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Give-arc HALF-WIDTH (degrees) after the Lockpicking attribute widens the tier base. Pure.
static func sweet_spot_width(base_deg: float, level: float, per_level_deg: float) -> float:
	return Minigame.scaled(base_deg, level, per_level_deg)

## Tier-adjusted base half-width before the attribute widens it — each tier above 1 narrows it,
## floored so a high tier is still fair. Pure.
static func arc_base_for_tier(base_deg: float, tier: int, tier_penalty_deg: float, min_deg: float) -> float:
	return maxf(min_deg, base_deg - float(maxi(0, tier - 1)) * tier_penalty_deg)

## Is the pick angle inside the give arc? |angle - centre| <= half-width, wrapping at ±180°. Pure.
static func is_in_sweet_spot(angle_deg: float, center_deg: float, half_width_deg: float) -> bool:
	return absf(wrapf(angle_deg - center_deg, -180.0, 180.0)) <= half_width_deg

# --- Effective geometry from config + injected context ---------------------
func effective_half_width() -> float:
	var tier_base := arc_base_for_tier(config.lockpick_arc_base_deg, difficulty,
		config.lockpick_arc_tier_penalty_deg, config.lockpick_arc_min_deg)
	return sweet_spot_width(tier_base, float(attribute_level), config.lockpick_arc_per_level_deg)

# --- Lifecycle -------------------------------------------------------------
func begin(ctx: Dictionary = {}) -> void:
	super.begin(ctx)
	_half_width_deg = effective_half_width()
	_center_deg = randf_range(-180.0, 180.0)
	_angle_deg = _center_deg + 180.0   # start opposite the give so it's never a free win
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # offsets too: anchors alone keep the 0x0 rect a code-built Control starts with
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.07, 0.85)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_CENTER)
	_readout.grow_horizontal = Control.GROW_DIRECTION_BOTH   # else the label's top-left sits at centre
	_readout.grow_vertical = Control.GROW_DIRECTION_BOTH
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_readout)
	_refresh()

func _process(delta: float) -> void:
	if _finished:
		return
	var turn := Input.get_axis(&"ui_left", &"ui_right")
	if turn != 0.0:
		_angle_deg = wrapf(_angle_deg + turn * 180.0 * delta, -180.0, 180.0)
		_refresh()
	if Input.is_action_just_pressed(&"ui_accept"):
		if is_in_sweet_spot(_angle_deg, _center_deg, _half_width_deg):
			_finish_solved()
		else:
			_finish_failed("miss")

func _refresh() -> void:
	if _readout != null:
		var hot := is_in_sweet_spot(_angle_deg, _center_deg, _half_width_deg)
		_readout.text = "LOCKPICK  ◄ ►  set: [Enter]   Esc: cancel\npick %d°   %s" % [
			int(round(_angle_deg)), "— feel the give —" if hot else ""]
