extends Control
class_name CompassEye
## The combined FP detection indicator (task 15, FR-15-5; locked decision Q1). ONE widget under the
## crosshair: a central "eye" that fills grey→yellow→orange→red with the strongest detection meter, ringed
## by direction ticks where the lit tick points toward the most-alarming guard. Direction is resolved from
## detection_changed's actor_id (== the emitting DetectionSensor's instance id) via instance_from_id(),
## bearing-projected against the active camera. Colour + a state SYMBOL + the lit-tick position are three
## redundant cues, so it's readable without colour (FR-15-7). EventBus stays FROZEN — this only listens to
## the pre-existing detection_changed. Pure seams (detection_visual / bearing_tick) are unit-tested.
## See docs/tasks/15_ui_hud_menus.md and GDD §8.0/§15.

const TICK_COUNT := 12
## State → short symbol (redundant, non-colour cue). Indexed by DetectionSensor.DetectionState.
const STATE_SYMBOLS := ["", "?", "?!", "!"]
const _SEARCHING := 2             ## DetectionState.SEARCHING — the threshold at which a threat gets its own lit tick
const _ALERTED := 3               ## DetectionState.ALERTED — the "fully spotted" commit

var _actors: Dictionary = {}      ## actor_id:int -> [state:int, fill:float]
var _primary_state: int = 0
var _primary_fill: float = 0.0
var _primary_tick: int = -1       ## lit direction tick, or -1 when unknown/ahead-only
var _threat_ticks: Dictionary = {}  ## tick_index -> strongest state of any threat (>= SEARCHING) at that bearing
var _colorblind: int = 0          ## gameplay/colorblind palette mode (task 21, FR-21-1)
var _reduce_flashing: bool = false
var _prev_state: int = 0
var _pulse_t: float = 0.0         ## 0..1 escalation pulse, decays; set to 1 when the state rises (task 21 juice)
var _spotted_flash: float = 0.0   ## 0..1, decays; set to 1 the instant detection commits to ALERTED (the "SPOTTED!" moment)

func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colorblind = _read_colorblind()
	_reduce_flashing = _read_reduce_flashing()
	if not EventBus.detection_changed.is_connected(_on_detection_changed):
		EventBus.detection_changed.connect(_on_detection_changed)
	if not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)

func _on_settings_changed(section: String) -> void:
	if section == "gameplay":
		_colorblind = _read_colorblind()
		_reduce_flashing = _read_reduce_flashing()
		queue_redraw()

func _read_colorblind() -> int:
	var s := Services.settings()
	return int(s.get_value("gameplay", "colorblind")) if s != null else 0

func _read_reduce_flashing() -> bool:
	var s := Services.settings()
	return s != null and bool(s.get_value("gameplay", "reduce_flashing"))

func _on_detection_changed(actor_id: int, state: int, fill: float) -> void:
	# Drop fully-recovered detectors so they stop skewing the "most alarming" pick.
	if state <= 0 and fill <= 0.01:
		_actors.erase(actor_id)
	else:
		_actors[actor_id] = [state, fill]

func _process(delta: float) -> void:
	_recompute_primary()
	# Escalation pulse: a brief expanding ring when the alert state rises (suppressed by Reduce Flashing).
	if _primary_state > _prev_state and not _reduce_flashing:
		_pulse_t = 1.0
	# The "fully spotted" commit: an unmistakable flash + SPOTTED! text the instant any threat reaches
	# ALERTED (the Searching→Alerted jump), so the player can't miss going from "hunted" to "made".
	if _primary_state >= _ALERTED and _prev_state < _ALERTED:
		_spotted_flash = 1.0
	_prev_state = _primary_state
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - delta * 2.5)
	if _spotted_flash > 0.0:
		_spotted_flash = maxf(0.0, _spotted_flash - delta * 1.3)
	queue_redraw()

# --- Pure seams (headless-testable) --------------------------------------------
## Visual mapping for a detection (state, fill) under a colorblind `mode` (task 21). Returns the clamped fill,
## the (mode-adjusted) state colour band, and a redundant symbol so the cue survives colour-blindness /
## greyscale (FR-15-7 / FR-21-1). Pure. `mode` defaults to 0 so existing callers/tests are unaffected.
static func detection_visual(state: int, fill: float, mode: int = 0) -> Dictionary:
	var s := clampi(state, 0, UITheme.DETECTION_COLORS.size() - 1)
	return {
		"fill": clampf(fill, 0.0, 1.0),
		"color": UITheme.detection_color_for(s, mode),
		"symbol": STATE_SYMBOLS[clampi(s, 0, STATE_SYMBOLS.size() - 1)],
	}

## Which ring tick (0 = straight ahead, increasing clockwise) points at `target_pos` from the player,
## given the camera basis (forward = -z, right = +x). Returns 0..tick_count-1. Pure/deterministic.
static func bearing_tick(player_pos: Vector3, cam_basis: Basis, target_pos: Vector3, tick_count: int) -> int:
	var d := target_pos - player_pos
	var forward := -cam_basis.z
	var right := cam_basis.x
	# Flatten to the ground plane so pitch doesn't twist the compass.
	var fwd2 := Vector2(forward.x, forward.z)
	var right2 := Vector2(right.x, right.z)
	var d2 := Vector2(d.x, d.z)
	if d2.length() < 0.001 or fwd2.length() < 0.001:
		return 0
	var ang := atan2(d2.dot(right2.normalized()), d2.dot(fwd2.normalized()))  # 0 ahead, + to the right
	var idx := int(round(ang / TAU * float(tick_count)))
	return ((idx % tick_count) + tick_count) % tick_count

# --- Direction resolution ------------------------------------------------------
func _recompute_primary() -> void:
	var best_id := 0
	var best_state := -1
	var best_fill := -1.0
	_threat_ticks.clear()
	# Defensive: drop any detector whose sensor has been freed (belt-and-suspenders with the sensor's
	# _exit_tree UNAWARE emit), so a taken-down guard can't keep the compass lit.
	for id in _actors.keys():
		if not is_instance_id_valid(id):
			_actors.erase(id)
	for id in _actors:
		var sf: Array = _actors[id]
		var st := int(sf[0])
		var fl := float(sf[1])
		if st > best_state or (st == best_state and fl > best_fill):
			best_state = st; best_fill = fl; best_id = id
		# Every threat that's actively hunting you (Searching+) lights its own tick, so multiple
		# converging guards read as a flanking situation, not just the single most-alarming bearing.
		if st >= _SEARCHING:
			var t := _tick_for_actor(id)
			if t >= 0:
				_threat_ticks[t] = maxi(int(_threat_ticks.get(t, 0)), st)
	if best_state < 0:
		_primary_state = 0; _primary_fill = 0.0; _primary_tick = -1
		return
	_primary_state = best_state
	_primary_fill = best_fill
	_primary_tick = _tick_for_actor(best_id)

## Resolve the emitting sensor's world position (actor_id == its instance id) and bearing-project it.
func _tick_for_actor(actor_id: int) -> int:
	if not is_instance_id_valid(actor_id):
		return -1
	var node := instance_from_id(actor_id)
	if not (node is Node3D):
		return -1
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return -1
	return bearing_tick(cam.global_position, cam.global_transform.basis,
		(node as Node3D).global_position, TICK_COUNT)

# --- Drawing -------------------------------------------------------------------
func _draw() -> void:
	var center := size * 0.5
	var ring_r := minf(size.x, size.y) * 0.5 - 8.0
	var vis := detection_visual(_primary_state, _primary_fill, _colorblind)
	var col: Color = vis["color"]

	# Direction tick ring: tick 0 at top (12 o'clock), clockwise. Every hunting threat lights its tick
	# (per-threat colour) for a flanking read; the most-alarming bearing is the brightest + most enlarged.
	for i in TICK_COUNT:
		var a := -PI * 0.5 + float(i) / float(TICK_COUNT) * TAU
		var dir := Vector2(cos(a), sin(a))
		var is_primary := i == _primary_tick and _primary_state > 0
		var threat_state := int(_threat_ticks.get(i, 0))
		var lit := is_primary or threat_state > 0
		var tick_col := Color(1, 1, 1, 0.18)
		if is_primary:
			tick_col = col
		elif threat_state > 0:
			tick_col = UITheme.detection_color_for(threat_state, _colorblind)
		var inner := ring_r - (7.0 if is_primary else (5.5 if lit else 4.0))
		var p0 := center + dir * inner
		var p1 := center + dir * ring_r
		draw_line(p0, p1, tick_col, (3.0 if is_primary else (2.5 if lit else 2.0)))

	# The eye: dark socket, then a state-coloured iris that grows with the detection fill, + a pupil.
	var eye_r := ring_r - 14.0
	draw_circle(center, eye_r, Color(0.05, 0.06, 0.08, 0.82))
	var iris_r := lerpf(eye_r * 0.22, eye_r, clampf(_primary_fill, 0.0, 1.0))
	draw_circle(center, iris_r, Color(col.r, col.g, col.b, 0.85))
	draw_circle(center, maxf(2.0, eye_r * 0.18), Color(0.05, 0.05, 0.07, 0.95))
	draw_arc(center, eye_r, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 2.0)

	# Escalation pulse: a brief expanding ring when the state just rose (juice; off under reduce_flashing).
	if _pulse_t > 0.0:
		var pr := ring_r + (1.0 - _pulse_t) * 10.0
		draw_arc(center, pr, 0.0, TAU, 32, Color(col.r, col.g, col.b, _pulse_t * 0.6), 3.0)

	# The "fully spotted" moment: a bold ring flash + SPOTTED! text. Under Reduce Flashing it's a steady,
	# non-strobing highlight rather than a bright pulse (FR-21-1) — still unmistakable, just gentler.
	if _spotted_flash > 0.0:
		var alerted_col := UITheme.detection_color_for(_ALERTED, _colorblind)
		var ring_a := (0.5 if _reduce_flashing else _spotted_flash * 0.9)
		draw_arc(center, ring_r + 6.0, 0.0, TAU, 40, Color(alerted_col.r, alerted_col.g, alerted_col.b, ring_a), 4.0)
		var f2 := UITheme.font()
		if f2 != null:
			var txt_a := (0.9 if _reduce_flashing else _spotted_flash)
			draw_string(f2, center + Vector2(-46, ring_r + 30.0), "SPOTTED!",
				HORIZONTAL_ALIGNMENT_CENTER, 92, 20, Color(alerted_col.r, alerted_col.g, alerted_col.b, txt_a))

	# Redundant, colour-independent state symbol above the eye.
	var symbol := String(vis["symbol"])
	if symbol != "":
		var f := UITheme.font()
		if f != null:
			draw_string(f, center + Vector2(-8, -eye_r - 6), symbol,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 22, col)
