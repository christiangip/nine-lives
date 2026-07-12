extends DetectionSensor
class_name CameraEye
## A security camera's eye (world-gen Phase 1D). Reuses the ENTIRE DetectionSensor vision core — cone +
## multi-ray LoS + light + fill + the five states — so a mounted camera sees exactly like a guard and
## alerts nearby guards through the same frozen EventBus signals (player_spotted / detection_changed).
## It adds three camera-specific things on top:
##   • a PTZ yaw sweep so a fixed mount still watches an arc;
##   • going BLIND while its host HackTarget is looped / disabled / unpowered / hacked (the counter-play);
##   • raising the alarm once it fully spots the player (a camera has no GuardAI to escalate itself).
## See world-gen-fixes.md (Phase 1D) and docs/tasks/04_stealth_detection.md.

@export var sweep_deg: float = 0.0     ## peak PTZ yaw sweep (deg); 0 = fixed camera
@export var sweep_period: float = 6.0  ## seconds per full sweep cycle
@export var alarm_kind: String = "camera"

var host: Node = null                  ## the HackTarget this eye belongs to; defeating it blinds the eye
var _base_yaw: float = 0.0
var _sweep_t: float = 0.0
var _alarm_raised: bool = false

func _ready() -> void:
	super._ready()
	_base_yaw = rotation.y   ## whatever aim the realizer baked in (yaw toward the room) is the sweep centre

func _physics_process(delta: float) -> void:
	if _camera_defeated():
		if fill > 0.0 or state != DetectionState.UNAWARE:
			fill = 0.0
			_set_state(DetectionState.UNAWARE)   # drop the HUD/compass read while blinded
		return
	if sweep_deg > 0.001 and sweep_period > 0.001:
		_sweep_t += delta
		rotation.y = _base_yaw + deg_to_rad(sweep_deg) * sin(_sweep_t * TAU / sweep_period)
	super._physics_process(delta)   # the real cone/LoS/light/fill sense + its EventBus emits
	if state == DetectionState.ALERTED and not _alarm_raised:
		_alarm_raised = true
		EventBus.alarm_tripped.emit(alarm_kind, global_position)

## The pursuit ended (DetectionSensor de-latches on the phase-0 broadcast): re-arm the alarm, so a camera
## that spots the player again raises a FRESH one. Without this, `_alarm_raised` latched for the whole
## mission and a camera could only ever alarm once (discovery.md #1). Riding the signal (rather than a
## per-tick check) also re-arms a camera that is looped/unpowered at the moment the pursuit ends.
func _deescalate() -> void:
	super._deescalate()
	_alarm_raised = false

## Pure seam (unit-tested): is a camera with these flags currently blind?
static func is_defeated(disabled: bool, looped: bool, powered: bool, solved: bool) -> bool:
	return disabled or looped or solved or not powered

func _camera_defeated() -> bool:
	if host == null:
		return false
	return is_defeated(bool(host.get(&"disabled")), bool(host.get(&"looped")),
		bool(host.get(&"powered")), bool(host.get(&"solved")))
