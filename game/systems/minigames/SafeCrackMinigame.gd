extends Minigame
class_name SafeCrackMinigame
## Safe-crack overlay (FR-07-4, GDD §9.8): chain dial clicks at the right numbers, felt as a cue that
## widens near each click. More wheels + a tighter cue at higher tiers; the Hacking attribute and the
## STETHOSCOPE gadget both WIDEN the cue. A found combo clue skips this entirely (handled by the Safe
## obstacle). Focused close-up → pauses the world. The scalable maths are pure seams. See docs/tasks/07_minigames.md.

var _wheels: int = 3
var _current: int = 0
var _targets: Array[float] = []
var _tol_deg: float = 6.0
var _dial_deg: float = 0.0
var _readout: Label

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Number of click-numbers to chain for a tier. Pure.
static func wheel_count(base: int, tier: int, per_tier: int) -> int:
	return maxi(1, base + maxi(0, tier - 1) * per_tier)

## Tier-adjusted base cue HALF-WIDTH (degrees) before gear/attribute widen it — tighter per tier,
## floored. Pure.
static func tolerance_base_for_tier(base_deg: float, tier: int, tier_penalty_deg: float, min_deg: float) -> float:
	return maxf(min_deg, base_deg - float(maxi(0, tier - 1)) * tier_penalty_deg)

## Cue half-width the stethoscope (bonus, else 0) + Hacking attribute widen. Pure.
static func tolerance(base_deg: float, stethoscope_bonus_deg: float, hacking_level: float, per_level_deg: float) -> float:
	return base_deg + stethoscope_bonus_deg + hacking_level * per_level_deg

## Is the dial on this wheel's click number? |dial - target| <= tolerance, wrapping at ±180°. Pure.
static func is_on_number(dial_deg: float, target_deg: float, tol_deg: float) -> bool:
	return absf(wrapf(dial_deg - target_deg, -180.0, 180.0)) <= tol_deg

# --- Effective geometry from config + injected context ---------------------
func effective_tolerance() -> float:
	var tier_base := tolerance_base_for_tier(config.safe_tolerance_base_deg, difficulty,
		config.safe_tolerance_tier_penalty_deg, config.safe_tolerance_min_deg)
	var steth := config.safe_stethoscope_bonus_deg if has_gear(&"stethoscope") else 0.0
	return tolerance(tier_base, steth, float(attribute_level), config.safe_tolerance_per_level_deg)

# --- Lifecycle -------------------------------------------------------------
func begin(ctx: Dictionary = {}) -> void:
	super.begin(ctx)
	_wheels = wheel_count(config.safe_wheels_base, difficulty, config.safe_wheels_per_tier)
	_tol_deg = effective_tolerance()
	_targets.clear()
	for _i in _wheels:
		_targets.append(randf_range(-180.0, 180.0))
	_current = 0
	_dial_deg = 0.0
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
	var turn := Input.get_axis(&"ui_left", &"ui_right")
	if turn != 0.0:
		_dial_deg = wrapf(_dial_deg + turn * 160.0 * delta, -180.0, 180.0)
		_refresh()
	if Input.is_action_just_pressed(&"ui_accept") and _current < _targets.size():
		if is_on_number(_dial_deg, _targets[_current], _tol_deg):
			_current += 1
			if _current >= _wheels:
				_finish_solved()
			else:
				_refresh()

func _refresh() -> void:
	if _readout == null:
		return
	var on := _current < _targets.size() and is_on_number(_dial_deg, _targets[_current], _tol_deg)
	_readout.text = "SAFE  ◄ ► spin, [Enter] click   Esc: cancel\nwheel %d/%d   dial %d°   %s" % [
		_current + 1, _wheels, int(round(_dial_deg)), "*click*" if on else "…listen…"]
