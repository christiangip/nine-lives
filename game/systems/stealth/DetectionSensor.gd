extends Node3D
class_name DetectionSensor
## Vision-cone + light + distance detection accumulator. Attach to guards/cameras.
## See docs/tasks/04_stealth_detection.md and GDD §8.1-§8.3.

enum DetectionState { UNAWARE, SUSPICIOUS, SEARCHING, ALERTED, PURSUIT }

@export var vision_angle_deg: float = 90.0
@export var vision_range: float = 14.0

var state: int = DetectionState.UNAWARE
var fill: float = 0.0   ## 0..1 detection meter toward the player

func _process(delta: float) -> void:
	pass # TODO[04]: LoS raycast, cone test, light/stance/cover modifiers, fill++/--

func _can_see_player() -> bool:
	return false # TODO[04]

func _set_state(s: int) -> void:
	if s != state:
		state = s
		EventBus.detection_changed.emit(get_instance_id(), state, fill)
